package Teng::Plugin::Static;
use strict;
use warnings;
use utf8;
use 5.10.0;

our $VERSION = '0.01';
our $AUTHOR  = 'cpan:KARUPA';

use Data::Validator;
use Class::Load qw/load_class/;
use File::Spec;
use File::Basename qw/dirname/;
use File::Path qw/make_path/;
use Storable qw/store retrieve/;
use Class::Inspector;
use Teng::Static::Iterator;
use Teng::Static::List;
use Mouse::Util qw/get_code_package/;

sub init {
    my($class, $caller, $opt) = @_;

    my %data;
    foreach my $data_class (@{ $opt->{data_class} }) {
        load_class($data_class);
        my $data_class_data = $class->load_data_from_class($data_class);
        foreach my $table_name (keys %$data_class_data) {
            die "already loaded data. table_name = ${table_name}." if exists $data{$table_name};
            $data{$table_name} = Teng::Static::List->new(
                data       => $data_class_data->{$table_name},
                table_name => $table_name,
            );
        }
    }

    $class->export_methods(\%data => $caller);
}

sub load_data_from_class {
    my($class, $data_class) = @_;

    my %data;
    if ($class->is_cache_alived($data_class)) {
        %data = %{ $class->restore_from_cache($data_class) };
    }
    else {
        foreach my $table_name ( @{ Class::Inspector->methods($data_class => 'public') } ) {
            next if $table_name =~ /^(?:BEGIN|CHECK|END|import|unimport)$/;
            next if get_code_package( $data_class->can($table_name) ) ne $data_class;

            $data{$table_name} = $data_class->$table_name;
        }

        $class->store_to_cache($data_class => \%data);
    }

    return \%data;
}

sub export_methods {
    my($class, $data, $export_to) = @_;

    foreach my $method (keys %{ $class->method_tmpl }) {
        my $code = $class->method_tmpl->{$method}->($data => $export_to);
        next unless $code;
        {
            no strict 'refs';
            *{"${export_to}::${method}"} = $code;
        }
    }
}

sub method_tmpl {
    return +{
        search => sub {
            my($data, $export_to) = @_;
            my $super = $export_to->can('search');
            return sub {
                my ($self, $table_name, $where, $opt) = @_;

                if (exists $data->{$table_name}) {
                    my $list = $data->{$table_name}->search($where, $opt);
                    my $itr = Teng::Static::Iterator->new(
                        list             => $list,
                        teng             => $self,
                        row_class        => $self->{schema}->get_row_class($table_name),
                        table            => $self->{schema}->get_table( $table_name ),
                        table_name       => $table_name,
                        suppress_object_creation => $self->{suppress_row_objects},
                    );

                    return wantarray ? $itr->all : $itr;
                }
                else {
                    return $self->$super($table_name, $where, $opt);
                }
            };
        },
        single => sub {
            my($data, $export_to) = @_;
            my $super = $export_to->can('single');
            return sub {
                my ($self, $table_name, $where, $opt) = @_;
                if (exists $data->{$table_name}) {
                    my $row = $data->{$table_name}->single($where, $opt);
                    return unless $row;
                    return $row if $self->{suppress_row_objects};
                    return $self->{schema}->get_row_class($table_name)->new(
                        {
                            sql            => undef,
                            row_data       => $row,
                            teng           => $self,
                            table          => $self->{schema}->get_table( $table_name ),
                            table_name     => $table_name,
                            select_columns => [ keys %$row ],
                        }
                    );
                }
                else {
                    return $self->$super($table_name, $where, $opt);
                }
            };
        },
        lookup => sub {
            my($data, $export_to) = @_;
            my $super = $export_to->can('lookup');
            return unless $super;
            return sub {
                my ($self, $table_name, $where, $opt) = @_;
                if (exists $data->{$table_name}) {
                    my $row = $data->{$table_name}->single($where, $opt);
                    return unless $row;
                    return $row if $self->{suppress_row_objects};
                    return $self->{schema}->get_row_class($table_name)->new(
                        {
                            sql            => undef,
                            row_data       => $row,
                            teng           => $self,
                            table          => $self->{schema}->get_table( $table_name ),
                            table_name     => $table_name,
                            select_columns => [ keys %$row ],
                        }
                    );
                }
                else {
                    return $self->$super($table_name, $where, $opt);
                }
            };
        },
        ## TODO: insert/create/update/delete/sql
    };
}

sub cache_path {
    my($class, $data_class) = @_;
    my $path = File::Spec->catfile(
        File::Spec->tmpdir,
        Class::Inspector->filename($data_class) . '.dat'
    );
    make_path(dirname($path)) unless -d dirname($path);

    return $path
}

sub is_cache_alived {
    my($class, $data_class) = @_;

    my $path       = Class::Inspector->resolved_filename($data_class);
    my $cache_path = $class->cache_path($data_class);
    if (-f $cache_path) {
        my $real_mtime  = (stat($path))[9];
        my $cache_mtime = (stat($cache_path))[9];
        if ($real_mtime <= $cache_mtime) {
            return 1;
        }
    }

    return 0;
}

sub store_to_cache {
    my($class, $data_class, $data) = @_;
    store $data, $class->cache_path($data_class);
}

sub restore_from_cache {
    my($class, $data_class) = @_;
    return retrieve($class->cache_path($data_class));
}

1;
__END__

=head1 NAME

Teng::Plugin::Static - Perl extention to do something

=head1 VERSION

This document describes Teng::Plugin::Static version 0.01.

=head1 SYNOPSIS

    use Teng::Plugin::Static;

=head1 DESCRIPTION

# TODO

=head1 INTERFACE

=head2 Functions

=head3 C<< hello() >>

# TODO

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<perl>

=head1 AUTHOR

Kenta Sato E<lt>karupa@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, Kenta Sato. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
