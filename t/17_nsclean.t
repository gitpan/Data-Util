#!perl -w

use strict;
use Test::More tests => 11;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/lib";

{
	package Foo;
	use NSClean;

	::ok foo(), 'foo';
	::ok bar(), 'bar';
	::ok baz(), 'baz';

	our $foo = 'a';
	our @foo = 'b';
	our %foo = (c => 'd');
}

ok exists $Foo::{foo}, '*Foo::foo exists';

SKIP:{
	skip 'does not see PERL_DONT_CREATE_GVSV in Pure Perl', 1, if exists $INC{'Data/Util/PurePerl.pm'};
	ok !exists $Foo::{bar}, '*Foo::bar does not exists';
}

is_deeply eval q{\\$Foo::foo}, \'a';
is_deeply eval q{\\@Foo::foo}, ['b'];
is_deeply eval q{\\%Foo::foo}, {c => 'd'};

is(Foo->can('foo'), undef);
is(Foo->can('bar'), undef);
is(Foo->can('baz'), \&Foo::baz);
