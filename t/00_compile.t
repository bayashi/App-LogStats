use strict;
use Test::More tests => 2;

BEGIN {
    use_ok 'App::LogStats';
}

my $stats = App::LogStats->new;
isa_ok($stats, 'App::LogStats');
