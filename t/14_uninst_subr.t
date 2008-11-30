#!perl -w

use strict;
use Test::More tests => 23;
use Test::Exception;

use constant HAS_SCOPE_GUARD => eval{ require Scope::Guard };

use Data::Util qw(:all);

{
	package Base;
	sub f{42};
	package Derived;
	our @ISA = qw(Base);
	sub f;
}

sub foo(){ (42, 43) }

my $before = \*foo;

our $foo = 10;

ok defined(&foo), 'before uninstalled';
ok __PACKAGE__->can('foo'), 'can';

uninstall_subroutine(__PACKAGE__, 'foo');

my $after = do{ no strict 'refs'; \*{'foo'} };

ok !defined(&foo), 'after uninstalled';
ok !__PACKAGE__->can('foo'), 'cannot';

is $foo, 10, 'remains other slots';
is $before, $after, 'compare globs directly';

uninstall_subroutine(__PACKAGE__, 'foo'); # ok

uninstall_subroutine('Derived' => 'f');
is scalar(get_code_info(Derived->can('f'))), 'Base::f', 'uninstall subroutine stubs';
is(Derived->f(), 42);

sub f1{}
sub f2{}
sub f3{}

uninstall_subroutine(__PACKAGE__, qw(f1 f2 f3 f4));

ok !__PACKAGE__->can('f1');
ok !__PACKAGE__->can('f2');
ok !__PACKAGE__->can('f3');
ok !__PACKAGE__->can('f4');


SKIP:{
	skip 'requires Scope::Guard', 2 unless HAS_SCOPE_GUARD;

	my $i = 1;
	{
		my $s = Scope::Guard->new(sub{ $i--; pass 'closure released' });

		install_subroutine(__PACKAGE__, closure => sub{ $s });
	}

	uninstall_subroutine(__PACKAGE__, 'closure');
	is $i, 0, 'closed values released';
}

our $BAX = 42;
{
	no warnings 'misc';

	use constant BAR => 3.14;
	use constant BAZ => BAR * 2;
	is(BAR(), 3.14);

	uninstall_subroutine(__PACKAGE__, 'BAR', 'BAZ', 'BAX');
}
is $BAX, 42;
ok !__PACKAGE__->can('BAR');
ok !__PACKAGE__->can('BAZ');

lives_ok{
	uninstall_subroutine('UndefinedPackage','foo');
};

throws_ok{
	use constant FOO => 42;
	use warnings FATAL => 'misc';
	uninstall_subroutine(__PACKAGE__, 'FOO');
} qr/Constant subroutine FOO uninstalled/;

dies_ok{
	uninstall_subroutine(undef, 'foo');
};
dies_ok{
	uninstall_subroutine(__PACKAGE__, undef);
};
throws_ok{
	uninstall_subroutine();
} qr/^Usage: /;


