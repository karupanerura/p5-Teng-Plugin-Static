package eg::Static::Data;
use strict;
use warnings;
use utf8;

use DateTimeX::Factory;
DateTimeX::Factory->set_time_zone('Asia/Tokyo');

sub kvs {
    my @data;
    my $now = DateTimeX::Factory->now->strftime('%Y-%m-%d %H:%M:%S');
    foreach my $id (1 .. 100) {
        push @data => +{
            id         => $id,
            key        => "key_$id",
            val        => "val_$id",
            expired_at => $now
        };
    }

    return \@data;
}

1;
