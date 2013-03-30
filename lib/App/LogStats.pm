package App::LogStats;
use strict;
use warnings;
use Getopt::Long qw/GetOptionsFromArray/;
use Pod::Usage;
use IO::Interactive qw/is_interactive/;
use Text::ASCIITable;

our $VERSION = '0.01';

use Class::Accessor::Lite (
    new => 1,
    rw  => [qw/
        result
        config
    /],
);

our @RESULT_LIST = (qw/
    count sum _line_ average median mode _line_ max min range
/);
our %MORE_RESULT = (
    median => 1,
    mode   => 1,
);

sub run {
    my $self = shift;
    $self->_prepare(\@_)->_loop->_finalize;
}

sub _finalize {
    my $self = shift;

    return unless $self->result->{show_result};

    if ($self->config->{tsv}) {
        $self->_put_tsv;
    }
    else {
        $self->_put_table;
    }
}

sub _put_tsv {
    my $self = shift;

    my @fields = sort keys %{$self->config->{field}};

    print "\n" unless $self->config->{quiet};
    print join("\t", '', @fields), "\n";
    for my $col (@RESULT_LIST) {
        next if !$self->config->{more} && $MORE_RESULT{$col};
        next if $col eq '_line_';
        my @rows;
        for my $i (@fields) {
            push @rows, $self->_normalize($self->result->{$i}{$col});
        }
        print join("\t", $col, @rows), "\n";
    }
}

sub _put_table {
    my $self = shift;

    my @fields = sort keys %{$self->config->{field}};

    my $t = Text::ASCIITable->new;
    $t->setCols('', @fields);
    for my $col (@RESULT_LIST) {
        next if !$self->config->{more} && $MORE_RESULT{$col};
        if ($col eq '_line_') {
            $t->addRowLine;
            next;
        }
        my @rows;
        for my $i (@fields) {
            push @rows, $self->_normalize($self->result->{$i}{$col});
        }
        $t->addRow($col, @rows);
    }
    print "\n" unless $self->config->{quiet};
    print $t;
}

sub _normalize {
    my ($self, $value) = @_;

    return '-' unless defined $value;

    if ($value =~ m!\.!) {
        $value = sprintf("%.". $self->config->{digit}. "f",  $value);
    }

    unless ($self->config->{no_comma}) {
        my ($n, $d) = split /\./, $value;
        while ( $n =~ s!(.*\d)(\d\d\d)!$1,$2! ){};
        $value = $d ? "$n\.$d" : $n;
    }

    return $value;
}

sub _loop {
    my $self = shift;

    my $r = +{};

    while ( my $line = <STDIN> ) {
        print $line unless $self->config->{quiet};
        chomp $line;
        next unless defined $line;
        $self->_calc_line($r, [ split $self->config->{delimiter}, $line ]);
    }

    $self->_after_calc($r);

    $self->result($r);
    $self;
}

sub _calc_line {
    my ($self, $r, $elements) = @_;

    my $i = 0;
    for my $element (@{$elements}) {
        $i++;
        next unless $self->config->{field}{$i};
        if ( ($self->config->{strict} && $element =~ m!^[\d\.]+$!)
                || (!$self->config->{strict} && $element =~ m!\d!) ) {
            my ($num) = ($element =~ m!^([\d\.]+)!);
            $r->{$i}{count}++;
            $r->{$i}{sum} += $num;
            $r->{$i}{max} = $num
                if !defined $r->{$i}{max} || $num > $r->{$i}{max};
            $r->{$i}{min} = $num
                if !defined $r->{$i}{min} || $num < $r->{$i}{min};
            push @{$r->{$i}{list}}, $num if $self->config->{more};
        }
    }
}

sub _after_calc {
    my ($self, $r) = @_;

    for my $i (keys %{$r}) {
        next unless $r->{$i}{count};
        $r->{$i}{average} = $r->{$i}{sum} / $r->{$i}{count};
        if ($self->config->{more}) {
            $r->{$i}{median} = $self->_calc_median($r->{$i}{list});
            $r->{$i}{mode}   = $self->_calc_mode($r->{$i}{list});
        }
        $r->{$i}{range}   = $r->{$i}{max} - $r->{$i}{min};
        $r->{show_result} ||= 1;
    }
}

sub _calc_median {
    my ($self, $list) = @_;

    return unless ref $list eq 'ARRAY';
    return $list->[0] unless @{$list} > 1;
    @{$list} = sort { $a <=> $b } @{$list};
    return $list->[ $#{$list} / 2 ] if @{$list} & 1;
    my $mid = @{$list} / 2;
    return ( $list->[ $mid - 1 ] + $list->[ $mid ] ) / 2;
}

sub _calc_mode {
    my ($self, $list) = @_;

    return unless ref $list eq 'ARRAY';
    return $list->[0] unless @{$list} > 1;
    my %hash;
    $hash{$_}++ for @{$list};
    my $max_val = ( sort { $hash{$b} <=> $hash{$a} } keys %hash )[0];
    for my $key (keys %hash) {
        delete $hash{$key} unless $key == $max_val;
    }
    return $self->_calc_average([keys %hash]);
}

sub _calc_average {
    my ($self, $list) = @_;

    my $sum = 0;
    for my $i (@{$list}) {
        $sum += $i;
    }
    return $sum / scalar(@{$list});
}

sub _prepare {
    my ($self, $argv) = @_;

    my $config = +{};
    $self->_merge_opt($config, $argv);

    $self->config($config);

    $self;
}

sub _merge_opt {
    my ($self, $config, $argv) = @_;

    Getopt::Long::Configure('bundling');
    GetOptionsFromArray(
        $argv,
        'd|delimiter=s' => \$config->{delimiter},
        'f|fields=s'    => \$config->{fields},
        'q|quiet'       => \$config->{quiet},
        'di|digit=i'    => \$config->{digit},
        's|strict'      => \$config->{strict},
        'no-comma'      => \$config->{no_comma},
        'tsv'           => \$config->{tsv},
        'more'          => \$config->{more},
        'h|help'        => sub {
            pod2usage(1);
        },
        'v|version' => sub {
            print "cl v$App::LogStats::VERSION\n";
            exit 1;
        },
    ) or pod2usage(2);

    if (!$config->{digit} || $config->{digit} !~ m!^\d+$!) {
        $config->{digit} = 2;
    }

    $config->{delimiter} = "\t" unless defined $config->{delimiter};

    if ($config->{fields}) {
        for my $f ( split ',', $config->{fields} ) {
            $config->{field}->{$f} = 1;
        }
        delete $config->{fields};
    }
    else {
        $config->{field}->{1} = 1;
    }
}

1;

__END__

=head1 NAME

App::LogStats - calculate lines


=head1 SYNOPSIS

    use App::LogStats;

    my $cl = App::LogStats->new;
    $cl->run(@ARGV);


=head1 DESCRIPTION

App::LogStats helps you to calculate data from lines.

See: L<stats> command


=head1 METHODS

=head2 run

to run command


=head1 REPOSITORY

App::LogStats is hosted on github
<http://github.com/bayashi/App-LogStats>


=head1 AUTHOR

Dai Okabayashi E<lt>bayashi@cpan.orgE<gt>


=head1 SEE ALSO

L<stats>

few stats codes were copied from L<Statistics::Lite>


=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
