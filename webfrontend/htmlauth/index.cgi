#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
my  $version = "0.1.1";


##########################################################################
# Template and language settings
##########################################################################

# Main
my $maintemplate = HTML::Template->new(
	filename => "$lbptemplatedir/settings.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params => 0,
	#associate => $pcfg,
);

my %L = LoxBerry::System::readlanguage($maintemplate, "language.ini");

# Navigation Bar
our %navbar;
$navbar{1}{Name} = "KODI Settings";
$navbar{1}{URL} = 'index.cgi';
$navbar{1}{Notify_Package} = $lbpplugindir;
 
$navbar{2}{Name} = "KODI Webinterface";
$navbar{2}{URL} = "http://" . lbhostname . ":8080";
$navbar{2}{target} = "_blank";
 
$navbar{1}{active} = 1;

$maintemplate->param( PLUGINNAME => 'KODI for LoxBerry' );

LoxBerry::Web::lbheader("KODI for LoxBerry", "http://www.loxwiki.eu:80", "kodi_main.html");
print LoxBerry::Log::get_notifications_html($lbpplugindir);
print $maintemplate->output;
LoxBerry::Web::lbfooter();

exit;
