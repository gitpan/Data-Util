#!perl -w

use strict;
use Test::More tests => 6;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/lib";

{
	package Foo;
	use NSClean;
	use Test::More;

	ok foo(), 'foo';
	ok bar(), 'bar';
	ok baz(), 'baz';
}

is(Foo->can('foo'), undef);
is(Foo->can('bar'), undef);
is(Foo->can('baz'), \&Foo::baz);
