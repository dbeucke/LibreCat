#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

getopts('u:m:');
our $opt_u;

# m for multiple indices
our $opt_m;

if($opt_m && $opt_m eq "backend2"){
	Catmandu->load('/srv/www/app-catalog/index2');
}
elsif($opt_m && $opt_m eq "backend1"){
	Catmandu->load('/srv/www/app-catalog/index1');
}
else {
	Catmandu->load;
}
my $conf = Catmandu->config;

my $pre_fixer = Catmandu::Fix->new(fixes => [
			'start_end_year_from_date()',
		]);

my $mongoBag = Catmandu->store('project')->bag;
my $projBag = Catmandu->store('search')->bag('project');

if ($opt_u) { # update process
	my $project = $mongoBag->get($opt_u);
	#print Dumper $project;
	$pre_fixer->fix($project);
	($project) ? ($projBag->add($project)) : ($projBag->delete($opt_u));
	
} else { # initial indexing

	my $allProj = $mongoBag->to_array;
	foreach (@$allProj){
		$pre_fixer->fix($_);
		$projBag->add($_)
	}
	#$projBag->add_many($allProj);

}

$projBag->commit;

=head1 SYNOPSIS

Script for indexing project data

=head2 Initial indexing

perl index_project.pl

# fetches all data from project mongodb and pushes it into the search store

=head2 Update process

perl index_project.pl -u 'ID'

# fetches one record with the id 'ID' and pushes it into the search storej or deletes it if 'ID' not found anymore

=head1 VERSION

0.02, Oct. 2012

=cut