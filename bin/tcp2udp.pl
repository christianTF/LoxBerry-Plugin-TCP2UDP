use IO::Select;
use IO::Socket;
use IO::Socket::Timeout;
use LoxBerry::Log;

require "$lbpbindir/libs/config.pm";

# Init Vars
my $berrytcpport = $config::pcfg{'Main.berrytcpport'};

## Listen to a guest TCP connection
our @tcpin_sock;
our @in_list;

foreach my $host (@config::hostkeys) {
	my $port = $config::pcfg{"$host.lbinport"};
	print STDERR "Opening TCP-in port for host " . $config::pcfg{$host . '.name'} . ": Port " . $port . "\n";
	$tcpin_sock[$host] = create_in_socket($tcpin_sock[$host], $port, 'tcp');
	$in_list[$host] = IO::Select->new ($tcpin_sock[$host]);
	
	
	
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
	if($socket) {
		close($socket);
	}
		
	$socket = IO::Socket::INET->new( %params )
		or die "Couldn't connect to $remotehost:$port : $@\n";
	sleep (1);
	if ($socket->connected) {
		print "Created $proto out socket to $remotehost on port $port\n";
	} else {
		print "WARNING: Socket to $remotehost on port $port seems to be offline - will retry\n";
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

