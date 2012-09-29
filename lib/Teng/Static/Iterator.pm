package Teng::Static::Iterator;
use strict;
use warnings;
use utf8;

use Carp ();

use parent qw/ Teng::Iterator /;

sub next {
    my $self = shift;

    if (my $row = shift @{ $self->{list} }) {
        if ($self->{suppress_object_creation}) {
            return $row;
        }
        else {
            return $self->{row_class}->new(
                {
                    sql            => undef,
                    row_data       => $row,
                    teng           => $self->{teng},
                    table          => $self->{table},
                    table_name     => $self->{table_name},
                    select_columns => [ keys %$row ],
                }
            );
        }
    }
    else {
        return;
    }
}

sub all {
    my $self = shift;

    my $result = $self->{list};
    if (@$result and not $self->{suppress_object_creation}) {
        $result = [map {
            $self->{row_class}->new(
                {
                    sql            => undef,
                    row_data       => $_,
                    teng           => $self->{teng},
                    table          => $self->{table},
                    table_name     => $self->{table_name},
                    select_columns => [ keys %$_ ],
                }
            )
        } @$result ];
    }

    return wantarray ? @$result : $result;
}

1;
