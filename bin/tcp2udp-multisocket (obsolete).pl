#!/usr/bin/perl

use IO::Select;
#use IO::Socket;
use IO::Socket::Timeout;
use IO::Socket::IP;

use LoxBerry::Log;

require "$lbpbindir/libs/config.pm";

# Init Vars
my $berrytcpport = $config::pcfg{'Main.berrytcpport'};

# Get Miniservers
my %miniservers;
%miniservers = LoxBerry::System::get_miniservers();
if (! %miniservers) {
    print STDERR "No Miniservers configured. Terminating.";
    exit(1); # Keine Miniserver vorhanden
}

## Listen to a guest TCP connection
our @tcpin_sock;
our @tcpout_sock;
our @udpout_sock;
our $in_list = IO::Select->new();


foreach my $host (@config::hostkeys) {
	my $inport = $config::pcfg{"$host.lbinport"};
	print STDERR "Opening TCP-in port for host " . $config::pcfg{$host . '.name'} . ": Port " . $inport . "\n";
	
	# Create In-Port on LoxBerry
	$tcpin_sock[$host] = create_in_socket($tcpin_sock[$host], $inport, 'tcp');
	
	$in_list->add($tcpin_sock[$host]);
	
	# Create Out-Port socket for external device
	if(!is_enabled($config::pcfg{"$host.hostondemand"})) {
		my $hostname = $config::pcfg{"$host.hostname"};
		my $hostport = $config::pcfg{"$host.hostport"};
		$tcpout_sock[$host] = create_out_socket($tcpout_sock[$host], $hostport, 'tcp', $hostname);
		$tcpout_sock[$host]->flush;
	}
	
	# Create Out-Port socket for udp answer
	if ($config::pcfg{"$host.returnms"} and %miniservers{$config::pcfg{"$host.returnms"} }) {
		my $hostname = $miniservers{$config::pcfg{"$host.returnms"}}{IPAddress};
		my $hostport = $config::pcfg{"$host.returnport"};
		$udpout_sock[$host] = create_out_socket($udpout_sock[$host], $hostport, 'udp', $hostname);
	}
		
	
	
}


my $continue = 1;

while ($continue) {

	# Relay external TCP messages to UDP
	foreach my $host (@config::hostkeys) {
		#print STDERR "Relay for $host...\n";
		relay_tcp2udp($tcpout_sock[$host], $udpout_sock[$host]);
	}

	# Listen to incoming TCP guests
	if (my @in_ready = $in_list->can_read(0.2)) {
		my $newconnection = 0;
		foreach $guest (@in_ready) {
			foreach my $host (@config::hostkeys) {
				if($guest == $tcpin_sock[$host]) {
					print STDERR "Guest is Socket\n";
				
					my $new = $tcpin_sock[$host]->accept or die "ERROR: It seems that this port is already occupied - Another instance running?\nQUITTING with error: $! ($@)\n";
					my $newremote = $new->peerhost();
					print STDERR "New guest connection accepted from $newremote.\n";
					$in_list->add($new);
				}
			}
			if ($newconnection == 0) {
				$guest->recv(my $guest_line, 1024);
				
				if (index($guest_line, 'connquit') != -1) {
					print STDERR "Quitting...\n";
					# print $guest "Quitting.\n";
					$in_list->remove($guest);
					$guest->close;
				} elsif(index($guest_line, 'daemonquit') != -1) {  
					print STDERR "Quitting daemon.";
					$continue = 0;
				} else {
					my $udpsock = $udpout_sock[$host];
					print STDERR $guest_line;
					print $udpsock $guest_line;
				}
			}
		}
	}
}
	
	
	

sub relay_tcp2udp
{

	my ($exttcpsock, $msudpsock) = @_;
	
	return if (!$exttcpsock);
	
	while (my $inputstring = $exttcpsock->getline) {
		print STDERR "New string: $inputstring\n";
		$inputstring = substr $inputstring, 0, 255;
		print $msudpsock $inputstring;
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
		
	$socket = IO::Socket::IP->new( %params )
		or print STDERR "Couldn't connect to $remotehost:$port : $@\n";
	sleep (1.5);
	if ($socket->connected) {
		print "Created $proto out socket to $remotehost on port $port\n";
	} else {
		print STDERR "WARNING: Socket to $remotehost on port $port seems to be offline - will retry\n";
	}
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
	print STDERR "Could not create socket for port $port: $!\n" unless $socket;
	# In some OS blocking mode must be expricitely disabled
	IO::Handle::blocking($socket, 0);
	print "server waiting for $proto client connection on port $port\n";
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
sub to_ms 
{
	
	my ($playerid, $label, $text) = @_;
	
	if (! $lms2udp_usehttpfortext) { return; }
	
	#my $playeridenc = uri_escape( $playerid );
	#my $labelenc = uri_escape ( $label );
	my $textenc = uri_escape( $text );
	
	my $player_label = uri_escape( 'LMS ' . $playerid . ' ' . $label);
	
	
	$url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	$url_nopass = "http://$miniserveradmin:*****\@$miniserverip\:$miniserverport/dev/sps/io/$player_label/$textenc";
	$ua = LWP::UserAgent->new;
	$ua->timeout(1);
	print "DEBUG: #$playerid# #$label# #$text#\n";
	print "DEBUG: -->URL $url_nopass\n";
	$response = $ua->get($url);
	return $response;
}

