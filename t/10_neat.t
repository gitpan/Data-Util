#!perl -w

use warnings 'FATAL';

use strict;
use Test::More tests => 12;

use Tie::Scalar;
use Tie::Array;
use Tie::Hash;

{
	package Foo;
	use overload '""' => sub{ 'Foo!' }, fallback => 1;

	sub new{ bless {}, shift }
}
use Data::Util qw(neat);

is neat(42), 42, 'neat()';
is neat(3.14), 3.14;
is neat("foo\n"), q{"foo\n"};
is neat(undef), 'undef';
is neat(*ok), '*main::ok';
like neat(qr{foo}), qr/qr{.*foo.*}/;

like neat(Foo->new(42)), qr/^Foo=HASH\(.+\)$/, 'for an overloaded object';

tie my $s, 'Tie::StdScalar', "foo\n";
is neat($s), q{"foo\n"}, 'for magical scalar';

my $x;

$x = tie my @a, 'Tie::StdArray';
$x->[0] = 42;

is neat($a[0]), 42, 'for magical scalar (aelem)';

$x = tie my %h, 'Tie::StdHash';
$x->{foo} = 'bar';

is neat($h{foo}), '"bar"', 'for magical scalar (helem)';

# recursive
my @rec;
push @rec, \@rec;
ok neat(\@rec), 'neat(recursive array) is safe';

my %rec;
$rec{self} = \%rec;
ok neat(\%rec), 'neat(recursive hash) is safe';

