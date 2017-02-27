use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat load => (layer_paths => [qw(t/layer)]);

use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::counter';
    use_ok $pkg;
}

require_ok $pkg;

# empty db
Catmandu->store->bag('info')->delete_all;

subtest 'initial_call' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['counter']);
    ok $result->error, 'threw an exception';
};

subtest 'initial_get' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['counter']);
    ok $result->error, 'threw an exception';
};

subtest 'set_get' => sub {
    my $result = test_app(qq|LibreCat::CLI| => ['counter', 'set', '1234']);
    ok !$result->error, "threw no exception";

    my $output = $result->stdout;
    ok $output, "output exists";
    like $output , qr/^added 1234/, 'set id was successful';

    $result = test_app(qq|LibreCat::CLI| => ['counter', 'get']);
    ok !$result->error, 'threw no exception';

    $output = $result->stdout;
    ok $output, "output exists";
    like $output , qr/1234/, 'get new id';

};

done_testing;
