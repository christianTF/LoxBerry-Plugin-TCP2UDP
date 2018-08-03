#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use IO::Select;
#use IO::Socket;
use IO::Socket::Timeout;
use IO::Socket::IP;
use LoxBerry::Log;

# Beim Reconnect kann es zu SIGPIPE kommen, wodurch Perl beendet wird.
$SIG{PIPE} = sub {
	LOGDEB "SIGPIPE @_";
};


our $cgi = CGI->new;
$cgi->import_names('R');

if (!$R::host) {
	print STDERR "tcp2udp: No HOST defined.\n";
	exit(10);
}

my $host = uc($R::host);

# my $lock = LoxBerry::System::lock(lockfile => "tcp2udp_$host", wait => 120);

# Init logfile
my $log = LoxBerry::Log->new ( name => $host, stdout => 1, addtime => 1 );
LOGSTART "TCP2UDP Daemon for host $host";

LOGINF "Reading config file";
require "$lbpbindir/libs/config.pm";

if (! $config::pcfg{$host . '.name'}) {
	LOGCRIT "Host $host not defined in config file.";
	LOGEND "Terminating.";
}

LOGINF "Reading Miniservers";
my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();
if (! %miniservers) {
    LOGCRIT "No Miniservers configured.";
	LOGEND "Terminating.";
    exit(11); # No Miniservers defined in LoxBerry
}

## Listen to a guest TCP connection
our $tcpin_sock;
our $tcpout_sock;
our $udpout_sock;


my $inport = $config::pcfg{"$host.lbinport"};
LOGINF "Opening TCP-IN port for host " . $config::pcfg{$host . '.name'} . ": Port " . $inport;
	
# Create In-Port on LoxBerry
$tcpin_sock = create_in_socket($tcpin_sock, $inport, 'tcp');
my $in_list = IO::Select->new($tcpin_sock);
	
# Create Out-Port socket for external device
if(!is_enabled($config::pcfg{"$host.hostondemand"})) {
	connect_host();
	$tcpout_sock->flush;
} else {
	LOGINF "Connection to external device is set to 'connect on demand' - No connection established.";
}

# Create Out-Port socket for udp answer
if ($config::pcfg{"$host.returnms"} and %miniservers{$config::pcfg{"$host.returnms"} }) {
	my $hostname = $miniservers{$config::pcfg{"$host.returnms"}}{IPAddress};
	my $hostport = $config::pcfg{"$host.returnport"};
	LOGINF "Opening UDP socket to Miniserver $hostname:$hostport";
	LOGINF "Check the UDP Monitor in Loxone Config for a welcome message!";
	$udpout_sock = create_out_socket($udpout_sock, $hostport, 'udp', $hostname);
	print $udpout_sock "Hello " . $miniservers{$config::pcfg{"$host.returnms"}}{Name} . "! TCP2UDP Plugin is calling from LoxBerry " . lbfriendlyname();
}
		
my $continue = 1;

while ($continue) {
	# Relay external TCP messages to UDP
	relay_tcp2udp($tcpout_sock, $udpout_sock);
	
	# Listen to incoming TCP guests
	if (my @in_ready = $in_list->can_read(0.2)) {
		foreach my $guest (@in_ready) {
			if($guest == $tcpin_sock) {
				my $new = $tcpin_sock->accept 
				or do {
					LOGCRIT "ERROR: It seems that this port is already occupied - Another instance running?";
					LOGEND "Terminating with error: $! ($@)";
					exit(111);
				};
				my $newremote = $new->peerhost();
				LOGINF "New guest connection accepted from $newremote.";
				$in_list->add($new);

			} else {

				$guest->recv(my $guest_line, 1024);
				if (index($guest_line, 'quitconn') != -1) {
					LOGOK "quitconn - Guest requested to quit the connection.";
					$in_list->remove($guest);
					$guest->close;
				} elsif(index($guest_line, 'quitdaemon') != -1) {  
					LOGOK "quitdaemon - Guest requested to terminate the daemon.";
					$continue = 0;
				} else {
					my $guest_line_chomped = $guest_line;
					chomp $guest_line_chomped;
					LOGDEB "Forward " . $miniservers{$config::pcfg{"$host.returnms"}}{Name} . "->" . $config::pcfg{"$host.name"} . ": " . $guest_line_chomped;
					if (!$tcpout_sock) {
						connect_host();
					}
					my $res = print $tcpout_sock $guest_line;
					# $tcpout_sock->send($guest_line);
					if (!$res) {
						LOGWARN "Remote device seems to be disconnected - Reconnecting...";
						connect_host();
						LOGINF "   Retry sending";
						$res = print $tcpout_sock $guest_line if ($tcpout_sock);
						if (!$res) {
							 LOGWARN "Re-send failed.";
						}
				}
							
					
				}
			}
		}
	}
}
	
	
	

sub relay_tcp2udp
{

	my ($exttcpsock, $msudpsock) = @_;
	
	if (! $exttcpsock) {
		# LOGDEB "No open connection to device.";
		return;
	}
	if (! $msudpsock) {
		LOGERR "No open UDP connection to Miniserver.";
		return;
	}

	while (my $inputstring = $exttcpsock->getline) {
		if (is_enabled($config::pcfg{"$host.returnprefix"})) {
			$inputstring = $config::pcfg{"$host.name"} . ": " . $inputstring;
			
		}
		my $inputstring_chomped = $inputstring;
		chomp $inputstring_chomped;
		LOGDEB "Return  " . $config::pcfg{"$host.name"} . "->" . $miniservers{$config::pcfg{"$host.returnms"}}{Name} . ": $inputstring_chomped";
		$inputstring = substr $inputstring, 0, 255;
		print $msudpsock $inputstring;
	}
}


sub connect_host
{
	my $hostname = $config::pcfg{"$host.hostname"};
	my $hostport = $config::pcfg{"$host.hostport"};
	LOGINF "Opening TCP-OUT port to device $hostname:$hostport";
	$tcpout_sock->shutdown(2) if ($tcpout_sock);
	$tcpout_sock->close if ($tcpout_sock);
	sleep(1);
	$tcpout_sock = create_out_socket($tcpout_sock, $hostport, 'tcp', $hostname);
	if($config::pcfg{"$host.hostinitialcommand"}) {
		LOGINF "Initial LB->" . $config::pcfg{"$host.name"} . ": " . $config::pcfg{"$host.hostinitialcommand"};
		print $tcpout_sock $config::pcfg{"$host.hostinitialcommand"} . "\n\r";
	}
}






















#################################################################################
# Create Out Socket
# Params: $socket, $port, $proto (tcp, udp), $remotehost
# Returns: $socket
#################################################################################

sub create_out_socket 
{
	my ($socket, $port, $proto, $remotehost) = @_;
	
	my %params = (
		PeerHost  => $remotehost,
		PeerPort  => $port,
		Proto     => $proto,
		Blocking  => 0
	);
	
	if ($proto eq 'tcp') {
		$params{'Type'} = SOCK_STREAM;
	} elsif ($proto eq 'udp') {
		# $params{'LocalAddr'} = 'localhost';
	}
	# if($socket) {
		# close($socket);
	# }
		
	$socket = IO::Socket::IP->new( %params );
	if(! $socket) {
		LOGERR "Couldn't connect to $remotehost:$port : $@";
		return undef;
	}
	# sleep (3);
	# if ($socket->connected) {
		# LOGOK "Created $proto out socket to $remotehost on port $port";
	# } else {
		# LOGWARN "WARNING: Socket to $remotehost on port $port seems to be offline - will retry";
	# }
	LOGDEB "Setting timeouts for socket to $remotehost:$port";
	IO::Socket::Timeout->enable_timeouts_on($socket);
	$socket->read_timeout(2);
	$socket->write_timeout(2);
	return $socket;
}

#################################################################################
# Create In Socket
# Params: $socket, $port, $proto (tcp, udp)
# Returns: $socket
#################################################################################

sub create_in_socket 
{

	my ($socket, $port, $proto) = @_;
	
	my %params = (
		LocalHost  => '0.0.0.0',
		LocalPort  => $port,
		Type       => SOCK_STREAM,
		Proto      => $proto,
		Listen     => 5,
		Reuse      => 1,
		Blocking   => 0
	);
	$socket = new IO::Socket::INET ( %params );
	if (! $socket) {
		LOGERR "Could not create $proto socket for port $port: $!";
		return undef;
	}
	# In some OS blocking mode must be expricitely disabled
	IO::Handle::blocking($socket, 0);
	LOGOK "server waiting for $proto client connection on port $port";
	return $socket;
}

#####################################################
# Miniserver REST Calls for Strings
# Uses globals
# Used for 
#	- Title
#	- Mode
#	- Player name
#####################################################
# sub to_ms 
# {
	
	# my ($playerid, $label, $text) = @_;
	
	# if (! $lms2udp_usehttpfortext) { return; }
	
	# #my $playeridenc = uri_escape( $playerid );
	# #my $labelenc = uri_escape ( $label );
	# my $textenc = uri_escape( $text );
	
	# my $player_label = uri_escape( 'LMS ' . $playerid . ' ' . $label);
	
	
	# $url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	# $url_nopass = "http://$miniserveradmin:*****\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	# $ua = LWP::UserAgent->new;
	# $ua->timeout(1);
	# print "DEBUG: #$playerid# #$label# #$text#\n";
	# print "DEBUG: -->URL $url_nopass\n";
	# $response = $ua->get($url);
	# return $response;
# }

END {
   LOGEND "Execution stopped";
   # my $unlockstatus = LoxBerry::System::unlock(lockfile => "tcp2udp_$host");
}