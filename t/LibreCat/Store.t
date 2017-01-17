use Catmandu::Sane;
use Catmandu;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = "LibreCat::Store";
    use_ok $pkg;
}

require_ok $pkg;

my $store = $pkg->new( store => Catmandu->store );

#empty db
Catmandu->store->delete_all;

subtest "methods" => sub {
    can_ok $store, $_ for qw(generate_id get update delete purge);
};


subtest "generate_id" => sub {
    foreach my $bag ( qw(publication project department researcher research_group) ) {
        my $id = $store->generate_id($bag);
        ok $id, "ID for bag $bag";

        # check for differebt IDs
        ok $id ne $store->generate_id($bag), "different ids";
    }
};


subtest "one record cycle" => sub {
    my $bag = "publication";
    my $id = $store->generate_id($bag);
    ok $id, "ID for $bag";

    my $rec = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;
    $rec->{_id} = $id;
    my $saved_rec = $store->update($bag, $rec);

    ok $saved_rec, "saved record";
    is_deeply $saved_rec, $rec, "compare saved record with original";
    ok $store->get('publication', $id)->{_id} eq $id, "get record from db";

    my $del_record = $store->delete($bag, $id);
    ok $del_record, "deleted record";
    ok $del_record->{status} eq 'deleted', "correct status";
    ok $del_record->{title}, "metadata still present";

    my $purged = $store->purge($bag, $id);
    ok $purged, "purged";
    ok !$store->get($bag, $id), "no record there";
};

done_testing;
