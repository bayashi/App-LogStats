use strict;
use warnings;
use Test::More 0.88;
use Test::Output;
use Test::Exception;

use App::LogStats;

{
    no warnings 'redefine';
    local *App::LogStats::is_interactive = sub { 1 };
}

{
    my $stats = App::LogStats->new;
    isa_ok($stats, 'App::LogStats');

    stdout_is { $stats->run; } '', 'just run';
}

{
    my $stats = App::LogStats->new;
    throws_ok {
        $stats->run('_no_exists_file_');
    } qr/^_no_exists_file_: No such file/, 'no_exists_file';
}

{
    my $expect = <<'_TXT_';

.----------------.
|         |    1 |
+---------+------+
| count   |   10 |
| sum     |   55 |
+---------+------+
| average | 5.50 |
+---------+------+
| max     |   10 |
| min     |    1 |
| range   |    9 |
'---------+------'
_TXT_
    my $stats = App::LogStats->new;
    stdout_is { $stats->run('share/log1'); } $expect, 'share/log1';
}

done_testing;