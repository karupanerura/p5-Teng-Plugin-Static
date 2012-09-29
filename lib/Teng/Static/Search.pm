package Teng::Static::Search;
use strict;
use warnings;
use utf8;
use 5.10.0;

use parent qw/Exporter/;
our @EXPORT_OK   = qw/search is_match offset limit order_by/;
our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

use Carp ();
use Data::Validator;
use Regexp::Common;
use Scalar::Util qw/reftype/;
use List::MoreUtils qw/any all uniq/;

sub search {
    state $v = Data::Validator->new(
        data => 'ArrayRef[HashRef]',
        cond => 'HashRef',
        opt  => +{ isa => 'HashRef', default => sub { +{} } },
    )->with(qw/StrictSequenced/);
    my $args = $v->validate(@_);

    my $result = [
        grep { is_match($_, $args->{cond}) } @{ $args->{data} }
    ];

    $result = order_by($result, delete($args->{opt}->{order_by})) if exists $args->{opt}->{order_by};
    $result = offset($result, delete($args->{opt}->{offset}))     if exists $args->{opt}->{offset};
    $result = limit($result, delete($args->{opt}->{limit}))       if exists $args->{opt}->{limit};

    Carp::croak("Unsupported option '$_'.") foreach keys %{ $args->{opt} };

    return $result;
}

sub is_match {
    state $v = Data::Validator->new(
        data => 'HashRef',
        cond => 'HashRef',
    )->with(qw/StrictSequenced/);
    my $args = $v->validate(@_);

    my $data = $args->{data};
    my $cond = $args->{cond};

    MAIN_LOOP: foreach my $key (keys %$cond) {
        my $is_match = 1;

        # 存在しないkeyで検索しようとしたら死ぬ
        Carp::croak "Unknwon key: $key" unless exists $data->{$key};

        if ( my $ref = reftype($cond->{$key}) ) {
            if ($ref eq 'ARRAY') {
                my @search_conds = @{ $cond->{$key} };
                if (my $type = $search_conds[0]) {
                    if ($type =~ /^-(?:or|and)$/) {
                        shift(@search_conds);
                    }
                    else {
                        $type = '-or';
                    }

                    if ($type eq '-and') {
                        $is_match = all { is_match($data, +{ $key => $_ }) } @search_conds;
                        return 0 unless ($is_match);
                    }
                    elsif ($type eq '-or') {
                        $is_match = any { is_match($data, +{ $key => $_ }) } @search_conds;
                        return 0 unless ($is_match);
                    }
                }
            }
            elsif ($ref eq 'HASH') {
                OP_MATCH: foreach my $op (keys %{ $cond->{$key} }) {
                    if (lc($op) eq 'between') {
                        my($low, $high) = @{ $cond->{$key}{$op} };
                        return 0 unless ($low <= $data->{$key} and $data->{$key} <= $high);
                    }
                    elsif (lc($op) eq 'like') {
                        my $rx =  quotemeta($cond->{$key}{$op});
                           $rx =~ s/\\%/.*/xsmg;
                           $rx =  '^' . $rx . '$';
                        return 0 unless $data->{$key} =~ /$rx/xsmg;
                    }
                    elsif (lc($op) eq 'in') {
                        $is_match = is_match($data, +{ $key => $cond->{$key}{$op} });
                        return 0 unless ($is_match);
                    }
                    elsif (lc($op) eq 'not in') {
                        $is_match = !is_match($data, +{ $key => $cond->{$key}{$op} });
                        return 0 unless ($is_match);
                    }
                    else {
                        my $key_op = $op;

                        ## fixed op
                        my $is_str = (($data->{$key} ^ $data->{$key}) || '') ne '0' ? 1 : 0;
                        $op = 'ne' if $is_str && $op eq '!=';
                        $op = 'eq' if $is_str && $op eq '=';

                        $is_match = eval "(\$data->{\$key} $op \$cond->{\$key}{\$key_op}) ? 1 : 0"; ## no critic
                        die $@ if $@;

                        return 0 unless $is_match;
                    }
                }
            }
            else {
                Carp::croak("Unsupported reference type '$ref'.");
            }
        }
        else {
            $is_match = ($data->{$key} eq $cond->{$key});
        }

        return 0 unless ($is_match);
    }

    return 1;
}

sub order_by {
    state $v = Data::Validator->new(
        data     => 'ArrayRef[HashRef]',
        order_by => 'Defined',
    )->with(qw/StrictSequenced/);
    my $args = $v->validate(@_);

    my $data     = $args->{data};
    my $order_by = $args->{order_by};

    # copied from SQL::Maker and arranged
    $order_by = [$order_by] unless ref($order_by) eq 'ARRAY';
    my @orders;
    my $push_order = sub {
        my ($col, $case) = @_;

        $case = uc($case);
        Carp::croak "Unknown case: $case" unless any { $case eq $_ } qw/ASC DESC/;
        push @orders, { column => $col, desc => $case };
    };
    for my $term (@{$order_by}) {
        my ($col, $case);
        if (ref $term eq 'ARRAY') {
            for my $order (@$term) {
                if (ref $order eq 'HASH') {
                    # Skinny-ish [{foo => 'DESC'}, {bar => 'ASC'}]
                    ($col, $case) = each %$order;
                }
                else {
                    # just ['foo DESC', 'bar ASC']
                    ($col, $case) = split /\s+/, $order, 2;
                    $case //= 'ASC';
                }

                $push_order->($col, $case);
            }
        }
        elsif (ref $term eq 'HASH') {
            # Skinny-ish {foo => 'DESC'}
            ($col, $case) = each %$term;

            $push_order->($col, $case);
        }
        else {
            # just 'foo DESC, bar ASC'
            for my $order (split /,\s*/, $term) {
                ($col, $case) = split /\s+/, $order, 2;
                $case //= 'ASC';

                $push_order->($col, $case);
            }
        }
    }

    my %type;
    foreach my $column (keys %{ $data->[0] }) {
        $type{$column} = ($data->[0]{$column} =~ /$RE{num}{real}/) ?
            'Num':
            'Str';
    }

    my @sorted = @$data;
    foreach my $order (@orders) {
        @sorted = sort {
            ($type{$order->{column}} eq 'Str') ?
                ($order->{desc} eq 'ASC') ?
                    ($a->{$order->{column}} cmp $b->{$order->{column}}):
                    ($b->{$order->{column}} cmp $a->{$order->{column}}):
            ($type{$order->{column}} eq 'Num') ?
                ($order->{desc} eq 'ASC') ?
                    ($a->{$order->{column}} <=> $b->{$order->{column}}):
                    ($b->{$order->{column}} <=> $a->{$order->{column}}):
            Carp::croak("column '$order->{column}' is undefinded type. Can't sort.");
        } @sorted;
    }

    \@sorted;
}

sub offset {
    state $v = Data::Validator->new(
        data   => 'ArrayRef[HashRef]',
        offset => 'Int',
    )->with(qw/StrictSequenced/);
    my $args = $v->validate(@_);
    return $args->{data} if $args->{offset} == 0;

    my @data = @{ $args->{data} };
    splice(@data, 0, $args->{offset});

    return \@data;
}

sub limit {
    state $v = Data::Validator->new(
        data  => 'ArrayRef[HashRef]',
        limit => 'Int',
    )->with(qw/StrictSequenced/);
    my $args = $v->validate(@_);
    return   $args->{data}        if $args->{limit} >= @{ $args->{data} };
    return [ $args->{data}->[0] ] if $args->{limit} == 1;

    my @data = @{ $args->{data} };
    splice(@data, $args->{limit}, scalar(@data) - $args->{limit});

    return \@data;
}

1;
