package t::eg::Static::Schema;
use strict;
use warnings;
use utf8;

use Teng::Schema::Declare;
use DateTimeX::Factory;
DateTimeX::Factory->set_time_zone('Asia/Tokyo');

table {
    name 'kvs';
    pk qw/id/;
    columns qw/id key val expired_at/;

    inflate 'expired_at' => sub {
        my ($col_value) = @_;
        return unless $col_value;
        return if $col_value eq '0000-00-00 00:00:00';
        return DateTimeX::Factory->from_mysql_datetime($col_value);
    };
    deflate 'expired_at' => sub {
        my ($col_value) = @_;
        return '0000-00-00 00:00:00' unless $col_value;
        return $col_value unless ref $col_value;
        return $col_value->strftime('%Y-%m-%d %H:%M:%S');
    };
    row_class 't::eg::Static::Row::Kvs';
};

1;
