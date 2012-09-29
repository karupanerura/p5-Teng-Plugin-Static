package Teng::Static::List;
use strict;
use warnings;
use utf8;
use 5.10.0;

use Class::Accessor::Lite (
    rw => [qw/table_name index/]
);

use Clone qw/clone/;
use Data::Validator;
use Teng::Static::Index::Null;
use Teng::Static::Search;

sub new {
    state $v = Data::Validator->new(
        table_name => 'Str',
        data       => 'ArrayRef[HashRef]',
    )->with(qw/Method/);
    my($class, $args) = $v->validate(@_);

    my $self = bless +{
        table_name => $args->{table_name}
    } => $class;
    $self->index(
        $self->create_index(data => $args->{data})
    );

    $self->index->initialize;
    return $self;
}

sub create_index {
    state $v = Data::Validator->new(
        data => 'ArrayRef[HashRef]',
    )->with(qw/Method/);
    my($self, $args) = $v->validate(@_);

    return Teng::Static::Index::Null->new(
        data => $args->{data}
    );
}

sub search {
    my $self = shift;
    my $cond = shift;

    my $data = $self->index->search($cond);
    return clone( Teng::Static::Search::search($data, $cond, @_) );
}

sub single { clone(shift->search(@_)->[0]) }

1;
