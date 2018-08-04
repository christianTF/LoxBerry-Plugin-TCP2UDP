#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use LoxBerry::Log;

our $cgi = CGI->new;
$cgi->import_names('R');

# Init logfile
my $log = LoxBerry::Log->new ( name => 'Service Control', stdout => 1, addtime => 1 );
LOGSTART "TCP2UDP Controller";

LOGINF "Reading config file";
require "$lbpbindir/libs/config.pm";

# if (! $config::pcfg{$host . '.name'}) {
	# LOGCRIT "Host $host not defined in config file.";
	# LOGEND "Terminating.";
# }

if ($R::action eq 'service' and $R::value eq 'restart') {
	LOGINF "Service restart for host $R::key requested";
	LOGINF "Killing host $R::key";
	killhost($R::key);
	sleep(0.5);
	LOGINF "Starting host $R::key";
	starthost($R::key);
	exit(0);
}


killall();
startall();

sub startall
{
	
	foreach my $host (@config::hostkeys) {
		LOGINF "Host $host: Name $config::pcfg{$host . '.name'}\n";
		starthost($host);
	
	}
}

sub starthost
{
	my ($host) = @_;
	$host = uc($host);
	system ("su - loxberry -c \'$lbpbindir/tcp2udp-singlesocket.pl host=$host\' > /dev/null 2>&1 &");
}

sub killhost
{
	my ($host) = @_;
	$host = uc($host);
	my @output = qx { pkill -f "tcp2udp-singlesocket.pl host=$host" };
	print "@output";
}

sub killall
{
	my @output = qx { pkill -f "tcp2udp-singlesocket.pl host=" };
	print "@output";
}
