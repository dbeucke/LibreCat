package LibreCat::Cmd::counter;

use Catmandu::Sane;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat counter set <ID>
librecat counter get

E.g.

librecat counter set 100000

EOF
}

sub command_opt_spec {
    my ($class) = @_;

    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/get|set/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'set') {
        return $self->_set(@$args);
    }
}

sub _get {
    my ($self) = @_;

    my $data = LibreCat->store->get('info', 'info_id');
    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _set {
    my ($self, $id) = @_;

    croak "usage: $0 set <ID>" unless defined($id);

}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::project - manage librecat projects

=head1 SYNOPSIS

    librecat counter set <ID>
    librecat counter get

    E.g.

    librecat counter set 100000

=cut
