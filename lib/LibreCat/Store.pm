package LibreCat::Store;

use Catmandu::Sane;
use JSON::MaybeXS qw(encode_json);
use LibreCat::Worker::Indexer;
#use LibreCat::App::Catalogue::Controller::File;
#use LibreCat::App::Catalogue::Controller::Material;
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has store => (
    is => 'ro',
    required => 1,
    # TODO: check if this is a Catmandu::Store
);

has search_store => (
    is => 'lazy',
);

sub _build_search_store {
    Catmandu->store('search');
}

sub generate_id {
    my ($self, $bag) = @_;

    $self->store->bag($bag)->generate_id;
}

sub get {
    my ($self, $bag, $id) = @_;

    $self->store->bag($bag)->get($id);
}

sub update {
    my ($self, $bag, $rec) = @_;

    $self->log->info("updating $bag");

    if ($self->log->is_debug) {
        $self->log->debug(encode_json($rec));
    }

    $rec = $self->_store_record($bag, $rec);
    $self->_index_record($bag, $rec->{_id});

    $rec;
}

sub delete {
    my ($self, $bag, $id) = @_;

    my $del_record = $self->store->bag($bag)->get($id);

    if ($bag eq 'publication' &&
        ($del_record->{oai_deleted} || $del_record->{status} eq 'public')
        )
    {
            $del_record ->{oai_deleted}  = 1;
            $del_record->{status} = 'deleted';

            $self->update($bag, $del_record);
    }
    else {
        $self->purge($bag, $id);
    }


}

sub purge {
    my ($self, $bag, $id) = @_;

    # TODO: what to do with all relations/files?

    $self->store->bag($bag)->delete($id);

    $self->search_store->bag($bag)->delete($id);
    $self->search_store->bag($bag)->commit;

    return 1;
}

sub get_version {
    my ($self, $bag, $id, $version) = @_;

    if ($self->store->bag($bag)->can('version_bag')) {
        $self->store->bag($bag)->get_version($id, $version);
    }
    else {
        return {};
    }
}

sub get_previous_version {
    my ($self, $bag, $id) = @_;

    if ($self->store->bag($bag)->can('version_bag')) {
        $self->store->bag($bag)->get_previous_version($id);
    }
    else {
        return {};
    }

}

sub get_history {
    my ($self, $bag, $id) = @_;

    if ($self->store->bag($bag)->can('version_bag')) {
        $self->store->bag($bag)->get_history($id);
    }
    else {
        return {};
    }
}

sub _store_record {
    my ($self, $bag, $rec, $skip_citation) = @_;

    if ($bag eq 'publication') {
    #    LibreCat::App::Catalogue::Controller::File::handle_file($rec);

        if ($rec->{related_material}) {
        #    LibreCat::App::Catalogue::Controller::Material::update_related_material($rec);
        }

        # Set for every update the user_id of the last editor
        unless ($rec->{user_id}) {
            # Edit by a user via the command line?
            my $super_id = Catmandu->config->{store}->{builtin_users}->{options}->{init_data}->[0]->{_id};
            $rec->{user_id} = $super_id;
        }
    }

    # memoize fixes
    state $fixes = {};
    my $fix = $fixes->{$bag} //= $self->_create_fixer("update_$bag.fix");
    $fix->fix($rec);

    state $cite_fix = Catmandu::Fix->new(fixes => ["add_citation()"]);
    if ($bag eq 'publication' && !$skip_citation) {
        $cite_fix->fix($rec);
    }

    # clean all the fields that are not part of the JSON schema
    state $validator_pkg = Catmandu::Util::require_package(ucfirst($bag),
        'LibreCat::Validator');

    if ($validator_pkg) {
        my @white_list = $validator_pkg->new->white_list;
        for my $key (keys %$rec) {
            unless (grep(/^$key$/, @white_list)) {
                $self->log->debug("deleting invalid key: $key");
                delete $rec->{$key}
            }
        }
    }

    $self->log->debug("storing record in $bag...");
    $self->log->debug(encode_json($rec));

    $self->store->bag($bag)->add($rec);
}

sub _index_record {
    my ($self, $bag, $id) = @_;

    $self->log->debug("indexing record '$id' in $bag...");
    #$self->log->debug(encode_json($rec));
    LibreCat::Worker::Indexer->new->index_record({bag => $bag, id=> $id});

    1;
}

sub _create_fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix `$file'");

    for my $p (@{LibreCat->layers->fixes_paths}) {
        $self->log->debug("testing `$p/$file'");
        if (-r "$p/$file") {
            $self->log->debug("found `$p/$file'");
            return Catmandu::Fix->new(fixes => ["$p/$file"]);
        }
    }

    $self->log->error("can't find a fixer for: `$file'");

    return Catmandu::Fix->new(fixes => ["nothing()"]);
}

sub _is_bag_valid {
    my ($self, $bag) = @_;

    grep { $bag eq $_ } keys %{$self->config->{store}{options}{bags}}
        ? 1 : 0 ;
}

1;
