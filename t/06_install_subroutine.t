#!perl -w

use strict;
use Test::More tests => 14;
use Test::Exception;

sub foo{
	42;
}
sub bar{
	52;
}
{
	package Foo;
	use Data::Util qw(install_subroutine);

}



use B();

sub get_subname{
	my $cv = B::svref_2object(shift);
	return$cv->GV->NAME;
}



no warnings 'redefine';

Foo->install_subroutine(foo => \&foo);

is  Foo::foo(), foo(), 'defined';

Foo->install_subroutine(foo => \&bar);

is Foo::foo(), bar(), 'redefined';

Foo->install_subroutine(foo => sub{ 314 });

is Foo::foo(), 314;
is get_subname(\&Foo::foo), 'foo';

Foo->install_subroutine(foo => \&foo);

is Foo::foo(), foo();
is get_subname(\&Foo::foo), 'foo';

{
	my $count = 0;
	Foo->install_subroutine(foo => sub{ ++$count });
}

is Foo::foo(), 1, 'install closure';
is Foo::foo(), 2;
is get_subname(\&Foo::foo), 'foo';


use warnings FATAL => 'redefine';

throws_ok{
	Foo->install_subroutine();
} qr/^Usage/;

throws_ok{
	Foo->install_subroutine("foo");
} qr/^Usage/;

throws_ok{
	Data::Util::install_subroutine(-1, foo => \&foo);
} qr/Package -1 does not exist/;

throws_ok{
	Foo->install_subroutine(PI => 3.14);
} qr/Invalid CODE reference/;

throws_ok{
	Foo->install_subroutine(3.14 => 'PI');
} qr/Invalid subroutine name/;
