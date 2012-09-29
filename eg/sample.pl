use strict;
use warnings;
use utf8;
use 5.10.0;

use eg::Static;
use Test::mysqld;

my $mysqld = Test::mysqld->new(
    my_cnf => +{
        'skip-networking' => '', # no TCP socket
    },
) or die $Test::mysqld::errstr;

my @connect_info = $mysqld->dsn(dbname => 'test');
my $db = eg::Static->new(+{ connect_info => \@connect_info });
# $db->dbh->do(do { local $/; <DATA> });


my $iter;
say 'between 10 and 20';
$iter  = $db->search(kvs => +{ id => +{ between => [10, 20] } }, +{});
while (my $row = $iter->next) {
    say $row->val;
}

say 'between 10 and 20 order by id desc';
$iter  = $db->search(kvs => +{ id => +{ between => [10, 20] } }, +{ order_by => +{ id => 'DESC'} });
while (my $row = $iter->next) {
    say $row->val;
}

say 'between 10 and 20 order by id desc limit 5';
$iter  = $db->search(kvs => +{ id => +{ between => [10, 20] } }, +{ order_by => +{ id => 'DESC'}, limit => 5 });
while (my $row = $iter->next) {
    say $row->val;
}

__DATA__
CREATE TABLE kvs (
    id           INTEGER UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    key          VARCHAR(32)       NOT NULL,
    val          TEXT              NOT NULL,
    expired_at   DATETIME          NOT NULL,
    INDEX expired_at (expired_at),
    INDEX key (key)
) ENGINE=InnoDB;
