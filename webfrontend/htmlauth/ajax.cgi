#!/usr/bin/perl

use LoxBerry::System;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
$cgi->import_names('R');
my  $version = "0.1.1";

if ($R::action eq "change") {
	my $success;
	if ($R::key eq "licvc1" || $R::key eq "licmpeg2" || $R::key eq "kodiautostart") {
		print qx { sudo $lbpbindir/elevatedhelper.pl action=change key=$R::key value=$R::value };
	}
	exit;

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

