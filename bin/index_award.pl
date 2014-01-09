#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Getopt::Std;
use Data::Dumper;

getopts('u:m:d');
our $opt_u;
# m for multiple indices
our $opt_m;
our $opt_d;

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
my $mongoBag = Catmandu->store('award')->bag('preise');
my $academyBag = Catmandu->store('award')->bag('academy');
my $awardBag = Catmandu->store('award')->bag('awards');
my $preisBag = Catmandu->store('search')->bag('award');

if ($opt_d){
	$preisBag->delete_all;
	exit;
}
elsif ($opt_u) { # update process
	my $award = $mongoBag->get($opt_u);
	#print Dumper $award;
	if($award){
		$award->{id} = $award->{_id};
		$award->{academyData} = $academyBag->get($award->{academyId}) if $award->{academyId};
		$award->{academyData}->{id} = $award->{academyData}->{_id} if $award->{academyData};
		$award->{awardData} = $awardBag->get($award->{awardId}) if $award->{awardId};
		$award->{awardData}->{id} = $award->{awardData}->{_id} if $award->{awardData};
		$preisBag->add($award);
	}
	else {
		$preisBag->delete($opt_u);
	}
	
} else { # initial indexing

	my $allAward = $mongoBag->to_array;
	
	foreach (@$allAward){
		my $aw = $_;
		$aw->{id} = $aw->{_id};
		# get academy data
		$aw->{academyData} = $academyBag->get($aw->{academyId}) if $aw->{academyId};
		$aw->{academyData}->{id} = $aw->{academyData}->{_id} if $aw->{academyData};
		# get award data
		$aw->{awardData} = $awardBag->get($aw->{awardId}) if $aw->{awardId};
		$aw->{awardData}->{id} = $aw->{awardData}->{_id} if $aw->{awardData};
		$preisBag->add($aw);
	}
	#not needed:
	#$awardBag->add_many($allAward);

}

$preisBag->commit;

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