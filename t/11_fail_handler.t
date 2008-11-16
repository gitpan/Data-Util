#!perl -w

use strict;
use Test::More tests => 4;
use Test::Exception;

BEGIN{
	use_ok 'Data::Util::Error';
}

{

	package Foo;
	use Data::Util::Error sub{ 'FooError' };
	use Data::Util qw(:validate);

	sub f{
		array_ref(@_);
	}
}
{
	package Bar;
	use Data::Util::Error sub{ 'BarError' };
	use Data::Util qw(:validate);

	sub f{
		array_ref(@_);
	}
}

{
	package Baz;
	use base qw(Foo);
	use Data::Util qw(:validate);

	sub g{
		array_ref(@_);
	}
}

throws_ok{
	Foo::f({});
} qr/FooError/;
throws_ok{
	Bar::f({});
} qr/BarError/;

throws_ok{
	Baz::g({});
} qr/FooError/;
