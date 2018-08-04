use Config::Simple;
use LoxBerry::System;

package config;

my $plugincfg = new Config::Simple("$LoxBerry::System::lbpconfigdir/tcp2udp.cfg");
our %pcfg = $plugincfg->vars();

print STDERR "Configfile version $pcfg{'Main.ConfigVersion'}\n";

# Evaluate keys of configured hosts
our @hostkeys_all = $plugincfg->param('Main.hostkeys');
our $hostkeys;
#print STDERR "Hostkeys: " . @hostkeys . "\n";

my $i;
foreach my $key (@hostkeys_all) {
		$i++;
		# print STDERR "Index $i Key $key Value $pcfg{'HOST' . $key . '.name'}\n";
		if (!$pcfg{'HOST' . $key . '.name'} or !$pcfg{'HOST' . $key . '.hostname'} or !$pcfg{'HOST' . $key . '.hostport'} or !$pcfg{'HOST' . $key . '.returnport'} or !LoxBerry::System::is_enabled($pcfg{'HOST' . $key . '.activated'})) {
			# print STDERR "  $key is null\n";
			
		} else {
			push @hostkeys, 'HOST' . $key;
		}
}
foreach my $host (@hostkeys) {
	print STDERR "Host $host: Name $pcfg{$host . '.name'}\n";
}


sub generate_form_array
{
	
	# Build Miniserver list
	my %miniservers = LoxBerry::System::get_miniservers();
	my @miniserverarray;
	my %miniserverhash;
	my $i = 1;

	foreach my $ms (sort keys %miniservers)
	{
		push @miniserverarray, $ms;
		$miniserverhash{"$ms"} = $miniservers{$ms}{Name};
		$i++;
	}
	
	# Build array for HTML::Template
	our @hosts = ();
	
	foreach my $host (@hostkeys_all) {
		# print STDERR "Host $host: Name $pcfg{$host . '.name'}\n";
		my $exthost = $plugincfg->get_block("HOST$host");
		$$exthost{'host'} = $host;
		
		# Generate Miniserver dropdown HTML
		my $selMiniserver = $main::cgi->popup_menu(
			  -name    => "HOST${host}returnms",
			  -values  => \@miniserverarray,
			  -labels  => \%miniserverhash,
			  -default => $$exthost{'returnms'}
		  );
		$$exthost{'miniserverhtml'} = $selMiniserver;
		
		push (@hosts, $exthost);
	
	}




}






#####################################################
# Finally 1; ########################################
#####################################################
1;
