package t::eg::Static;
use strict;
use warnings;
use utf8;

use parent qw/Teng/;

__PACKAGE__->load_plugin('Static' => +{
    data_class => [qw/t::eg::Static::Data/]
});

1;
