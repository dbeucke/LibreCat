package Locale::Maketext::Lexicon::Catmandu::Config;

use Catmandu::Sane;

sub parse {
    my ($self, $key) = @_;
    Catmandu->config->{i18n}{locale}{$key};
}

1;