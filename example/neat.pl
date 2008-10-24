#!perl -w

use strict;
use Data::Util qw(neat);

sub say{ print @_, "\n" }

say neat "foo";
say neat "12345678901234567890";
say neat "\t\r\n";
say neat 3.14;
say neat 42;
say neat *foo;
say neat \&foo;
say neat [];
say neat bless {} => 'Foo';
say neat undef;

use Tie::Scalar;
tie my $t, 'Tie::StdScalar';
$t = qr/foo/;
say neat $t;
