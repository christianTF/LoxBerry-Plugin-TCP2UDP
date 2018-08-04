#!/usr/bin/perl

use LoxBerry::System;
use CGI;
use warnings;
use strict;
require "$lbpbindir/libs/config.pm";


our $cgi = CGI->new;
$cgi->import_names('R');
my  $version = "0.1.1";

if ($R::action eq "change") {
	my $success;
	my ($host, $key) = split('-', $R::key);
	if (substr(uc($host),  0, 4) eq 'HOST') {
		$host = uc(substr($host,  4));
		
		$config::plugincfg->param("HOST$host.$key", $R::value) if ($R::value);
		$config::plugincfg->delete("HOST$host.$key") if (!$R::value);
		$config::plugincfg->save();
		
		print $cgi->header(-type => 'application/json;charset=utf-8',
							-status => "204 No Content");
		exit;
	}
}

if ($R::action eq "delete_block") {
	my $newkeys = '';
	foreach my $hostkey (@config::hostkeys_all) {
		next if ($hostkey eq $R::key);
		$newkeys = "$newkeys $hostkey" if ($newkeys ne '');
		$newkeys = "$hostkey" if ($newkeys eq '');
		
	}
	$newkeys =~ s/\ /,\ /g;
	$config::plugincfg->param("Main.hostkeys", $newkeys);
	$config::plugincfg->set_block("HOST" . $R::key);
	$config::plugincfg->save;
		print $cgi->header(-type => 'application/json;charset=utf-8',
							-status => "204 No Content");
		exit;
}

if ($R::action eq "add_block") {
	my $newkeys = '';
	@config::hostkeys_all = sort @config::hostkeys_all;
	# foreach my $hostkey (@config::hostkeys_all) {
		# print STDERR "Sort Hostkey $hostkey\n";
	# }
	
	my $newnumber = $config::hostkeys_all[-1] + 1;
	push(@config::hostkeys_all, $newnumber);
	print STDERR "Newnumber: $newnumber\n";
	foreach my $hostkey (@config::hostkeys_all) {
		$newkeys = "$newkeys $hostkey" if ($newkeys ne '');
		$newkeys = "$hostkey" if ($newkeys eq '');
		
	}
	$newkeys =~ s/\ /,\ /g;
	$config::plugincfg->param("Main.hostkeys", $newkeys);
	$config::plugincfg->set_block("HOST" . $newnumber, { returnms => 1 });
	$config::plugincfg->save;
		print $cgi->header(-type => 'application/json;charset=utf-8',
							-status => "204 No Content");
		exit;
}



if ($R::action eq "query") {
	print qx { sudo $lbpbindir/elevatedhelper.pl action=query };
	exit;
}

if ($R::action eq "service") {
	print qx { sudo $lbpbindir/tcp2udp-control.pl action=service key=HOST{$R::key} value=$R::value};
	print $cgi->header(-type => 'application/json;charset=utf-8',
							-status => "204 No Content");
	exit;
}


	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "501 Action not implemented");
	print "{status: 'Not implemented'}";

exit;

