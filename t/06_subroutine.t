#!perl -w

use strict;
use Test::More tests => 25;
use Test::Exception;

use Data::Util qw(get_code_info);

use constant PP_ONLY => $INC{'Data/Util/PurePerl.pm'};

sub get_subname{
	return join '::', get_code_info(@_);
}

sub foo{
	42;
}
sub bar{
	52;
}
{
	package Base;
	sub foo{
		'Base::foo';
	}
	package Foo;
	our @ISA = qw(Base);
	use Data::Util qw(install_subroutine);

	sub baz{}

	package Callable;
	use overload
		'&{}' => 'codify',
	;
	sub new{
		my $class = shift;
		bless {@_} => $class;
	}
	sub codify{
		my $self = shift;
		$self->{code};
	}
}

is_deeply get_subname(\&foo), 'main::foo', 'get_code_info()';
is_deeply get_subname(\&Foo::baz), 'Foo::baz', 'get_code_info()';

is_deeply get_subname(\&undefined_subr), 'main::undefined_subr';

no warnings 'redefine';

Foo->foo(); # touch the chache

Foo->install_subroutine(foo => \&foo);

is Foo::foo(), foo(), 'as function';
is(Foo->foo(), foo(), 'as method');

Foo->install_subroutine(foo => \&bar);

is Foo::foo(), bar(), 'redefined';

Foo->install_subroutine(foo => sub{ 314 });

is Foo::foo(), 314, 'install anonymous subr';
SKIP:{
	skip 'in testing perl only', 1 if PP_ONLY;
	is get_subname(\&Foo::foo), 'Foo::foo', '...named';
}

Foo->install_subroutine(foo => \&foo);

is Foo::foo(), foo();
SKIP:{
	skip 'in testing perl only', 1 if PP_ONLY;
	is get_subname(\&Foo::foo), 'main::foo';
}

{
	my $count = 0;
	Foo->install_subroutine(foo => sub{ ++$count });
}

is Foo::foo(), 1, 'install closure';
is Foo::foo(), 2;

SKIP:{
	skip 'in testing perl only', 1 if PP_ONLY;
	is get_subname(\&Foo::foo), 'Foo::foo';
}

Foo->install_subroutine(foo => \&undefined_subr);
dies_ok{
	Foo::foo();
} 'install undefined subroutine';


Foo->install_subroutine(ov1 => Callable->new(code => sub{ 'overloaded' }));
is Foo::ov1(), 'overloaded', 'overload';

Foo->install_subroutine(ov2 => Callable->new(code => sub{ die 'dies in codify' }));

throws_ok{
	Foo::ov2();
} qr/dies in codify/;

dies_ok{
	Foo->install_subroutine(ov3 => Callable->new(code => []));
};
dies_ok{
	Foo->install_subroutine(ov4 => Callable->new(code => undef));
};

use warnings FATAL => 'redefine';

throws_ok{
	get_code_info(undef);
} qr/Invalid CODE reference/;

throws_ok{
	Foo->install_subroutine();
} qr/^Usage/;

throws_ok{
	Foo->install_subroutine("foo");
} qr/^Usage/;

throws_ok{
	Data::Util::install_subroutine(undef, foo => \&foo);
} qr/Invalid package name/;

throws_ok{
	Foo->install_subroutine(PI => 3.14);
} qr/Invalid CODE reference/;

throws_ok{
	Foo->install_subroutine(undef, sub{});
} qr/Invalid subroutine name/;
throws_ok{
	Foo->install_subroutine([], sub{});
} qr/Invalid subroutine name/;
