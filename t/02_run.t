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

    test_log(<<'_TXT_', 'share/log1');

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


test_log(<<'_TXT_', 'share/log2');

.--------------.
|         |  1 |
+---------+----+
| count   |  5 |
| sum     | 15 |
+---------+----+
| average |  3 |
+---------+----+
| max     |  5 |
| min     |  1 |
| range   |  4 |
'---------+----'
_TXT_

done_testing;

sub test_log {
    my ($expect, @cmd) = @_;

    my $stats = App::LogStats->new;
    stdout_is { $stats->run(@cmd); } $expect, join(' ', @cmd);
}
