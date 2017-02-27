package LibreCat::Cmd::user;

use Catmandu::Sane;
use LibreCat::Validator::Researcher;
use App::bmkpasswd qw(passwdcmp mkpasswd);
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat user [options] list [<cql-query>]
librecat user [options] export [<cql-query>]
librecat user [options] add <FILE>
librecat user [options] get <id>
librecat user [options] delete <id>
librecat user [options] valid <FILE>
librecat user [options] passwd <id>

options:
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat user list 'id = 1234'

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

    my $commands = qr/list|export|get|add|delete|valid|passwd/;

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
    elsif ($cmd eq 'passwd') {
        return $self->_passwd(@$args);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = Catmandu->store('search')->bag('researcher')->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $count = $it->each(
        sub {
            my ($item)   = @_;
            my $id       = $item->{_id};
            my $login    = $item->{login} // '---';
            my $name     = $item->{full_name} // '---';
            my $status   = $item->{account_status} // '---';
            my $is_admin = $item->{super_admin} // 0;

            printf "%-2.2s %-40.40s %-20.20s %-40.40s %-10.10s\n",
                $is_admin ? "*" : " ", $id, $login, $name, $status;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = Catmandu->store('search')->bag('researcher')->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($it);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat->store->get('researcher', $id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret       = 0;
    my $importer  = Catmandu->importer('YAML', file => $file);
    my $validator = LibreCat::Validator::Researcher->new;

    my $records = $importer->select(
        sub {
            my $rec = $_[0];

            $rec->{_id} //= LibreCat->store->generate_id('researcher');
            $rec->{password} = mkpasswd($rec->{password})
                if exists $rec->{password};

            if ($validator->is_valid($rec)) {
                LibreCat->store->_store_record('researcher', $rec);
                print "added $rec->{_id}\n";
                return 1;
            }
            else {
                print STDERR join("\n",
                    "ERROR: not a valid researcher",
                    @{$validator->last_errors}),
                    "\n";
                $ret = 2;
                return 0;
            }
        }
    );

    my $index = Catmandu->store('search')->bag('researcher');
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result = LibreCat->store->delete('researcher', $id);

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

    my $validator = LibreCat::Validator::Researcher->new;

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

sub _passwd {
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat->store->get('person', $id);

    my $name = $data->{full_name};

    print "Password: ";
    system('/bin/stty', '-echo');
    my $password1 = <STDIN> ; chop($password1);
    system('/bin/stty', 'echo');

    print "\nRepeat password: ";
    system('/bin/stty', '-echo');
    my $password2 = <STDIN> ; chop($password2);
    system('/bin/stty', 'echo');

    unless ($password1 eq $password2) {
        print STDERR "Passwords don't match\n";
        return 2;
    }

    $data->{password} = mkpasswd($password2);

    $data = LibreCat->store->update('researcher', $data);

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::user - manage librecat users

=head1 SYNOPSIS

    librecat user list [<cql-query>]
    librecat user export [<cql-query>]
    librecat user add <FILE>
    librecat user get <id>
    librecat user delete <id>
    librecat user valid <FILE>
    librecat user [options] passwd <id>

    options:
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)

=cut
