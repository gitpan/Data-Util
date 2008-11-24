#!perl -w

use strict;
use Test::More tests => 7;

use Test::Exception;


my $count1 = 0;
my $count2 = 0;
BEGIN{
	package Base;

	sub foo{ 'Base::foo' }
	sub bar{ 'Base::bar' }
	sub baz{ 'Base::baz' }

	package Derived;
	our @ISA = qw(Base);
	use Data::Util::MethodModifiers;

	before foo => sub{ $count1++ };
	around bar => sub{ $count1++; my $next = shift; $next->(@_); };
	after  baz => sub{ $count1++ };

	package MoreDerived;
	our @ISA = qw(Derived);
	use Data::Util::MethodModifiers;

	before foo => sub{ $count2++ };
	after  foo => sub{ $count2++ };

	around bar => sub{ $count2++ };
}

Base->$_() for qw(foo bar baz);

is $count1, 0;
is $count2, 0;

Derived->$_() for qw(foo bar baz);

is $count1, 3;
is $count2, 0;

$count1 = 0;
$count2 = 0;
MoreDerived->$_() for qw(foo bar baz);

is $count1, 2;
is $count2, 3;

throws_ok{
	package X;
	use Data::Util::MethodModifiers;

	before 'foo' => sub{};
} qr/not found/;
