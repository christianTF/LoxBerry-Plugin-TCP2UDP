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

if ($R::action eq "query") {
	print qx { sudo $lbpbindir/elevatedhelper.pl action=query };
	exit;
}

if ($R::action eq "service") {
	print qx { sudo $lbpbindir/elevatedhelper.pl action=service key=$R::key value=$R::value};
	exit;
}


	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "501 Action not implemented");
	print "{status: 'Not implemented'}";

exit;

