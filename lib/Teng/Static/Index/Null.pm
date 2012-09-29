package Teng::Static::Index::Null;
use strict;
use warnings;
use utf8;

use Class::Accessor::Lite (
    new => 1,
    ro  => [qw/data/]
);

sub initialize { shift }
sub search { shift->data }

1;
