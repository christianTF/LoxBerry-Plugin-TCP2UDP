#!/usr/bin/perl

use warnings;
use strict;
use CGI;
use LoxBerry::Log;
require "$lbpbindir/libs/config.pm";

our $cgi = CGI->new;
$cgi->import_names('R');

# Init logfile
my $log = LoxBerry::Log->new ( name => 'Service Control', stdout => 1, addtime => 1 );
LOGSTART "TCP2UDP Controller";

LOGINF "Reading config file";

# if (! $config::pcfg{$host . '.name'}) {
	# LOGCRIT "Host $host not defined in config file.";
	# LOGEND "Terminating.";
# }

startall();

sub startall
{
	
	foreach my $host (@config::hostkeys) {
		print STDERR "Host $host: Name $config::pcfg{$host . '.name'}\n";
		starthost($host);
	
	}
}

sub starthost
{
	my ($host) = @_;
	$host = uc($host);
	my @output = qx { pkill -f "tcp2udp-singlesocket.pl host=$host" };
	print "@output";
	sleep(0.5);
	system ("su - loxberry -c \'$lbpbindir/tcp2udp-singlesocket.pl host=$host\' > /dev/null 2>&1 &");


}

sub killhost
{
	my ($host) = @_;
	$host = uc($host);
	my @output = qx { pkill -f "tcp2udp-singlesocket.pl host=$host" };
	print "@output";
}

