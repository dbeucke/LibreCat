package LibreCat::Cmd::project;

use Catmandu::Sane;
use LibreCat::Validator::Project;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat project [options] list [<cql-query>]
librecat project [options] export [<cql-query>]
librecat project [options] add <FILE>
librecat project [options] get <id>
librecat project [options] delete <id>
librecat project [options] valid <FILE>

options:
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat project export 'id = P1'

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
    ['total=i', ""] ,
    ['start=i',""] ,
    );
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/list|export|get|add|delete|valid/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
    }
    elsif ($cmd eq 'export') {
        return $self->_export(@$args);
    }
    elsif ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        return $self->_delete(@$args);
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = Catmandu->store('search')->bag('project')->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $count = $it->each(
        sub {
            my ($item) = @_;
            my $id     = $item->{_id};
            my $name   = $item->{name};

            printf "%-40.40s %s\n", $id, $name;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = Catmandu->store('search')->bag('project')->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($it);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat->store->get('project', $id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret       = 0;
    my $importer  = Catmandu->importer('YAML', file => $file);
    my $validator = LibreCat::Validator::Project->new;

    my $records = $importer->select(
        sub {
            my $rec = $_[0];

            if ($validator->is_valid($rec)) {
                $rec->{_id} //= LibreCat->store->generate_id('project');
                LibreCat->store->_store_record('project', $rec);
                print "added $rec->{_id}\n";
                return 1;
            }
            else {
                print STDERR join("\n",
                    "ERROR: not a valid project",
                    @{$validator->last_errors}),
                    "\n";
                $ret = 2;
                return 0;
            }
        }
    );

    my $index = Catmandu->store('search')->bag('project');
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result = LibreCat->store->delete('project', $id);

    if ($result) {
        print "deleted $id\n";
        return 0;
    }
    else {
        print STDERR "ERROR: delete $id failed";
        return 2;
    }
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = LibreCat::Validator::Project->new;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors();
                my $id = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        print STDERR "ERROR $id: $err\n";
                    }
                }
                else {
                    print STDERR "ERROR $id: not valid\n";
                }
            }

            $ret = -1;
        }
    );

    return $ret == 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::project - manage librecat projects

=head1 SYNOPSIS

    librecat project list [<cql-query>]
    librecat project export [<cql-query>]
    librecat project add <FILE>
    librecat project get <id>
    librecat project delete <id>
    librecat project valid <FILE>

    options:
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
=cut
