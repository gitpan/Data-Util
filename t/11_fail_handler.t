#!perl -w

use strict;
use Test::More tests => 4;
use Test::Exception;

{
	package Foo;
	use Data::Util qw(:validate), -fail_handler => sub{ join '', 'Foo: ', @_ };

	sub f{
		array_ref(@_);
	}
}
{
	package Bar;
	use Data::Util qw(:validate), -fail_handler => sub{ join '', 'Bar: ', @_ };

	sub f{
		array_ref(@_);
	}
}

throws_ok{
	Foo::f({});
} qr/Foo: Validation failed/;
throws_ok{
	Bar::f({});
} qr/Bar: Validation failed/;

dies_ok{
	Data::Util->import(-fail_handler => undef);
} 'invalid fail handler';
dies_ok{
	Data::Util->import(-fail_handler => 'foo');
} 'invalid fail handler';
