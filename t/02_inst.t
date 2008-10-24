#!perl -w
use strict;
use Test::More tests => 31;

use Data::Util qw(is_instance instance);

BEGIN{
	package Foo;
	sub new{ bless {}, shift }

	package Bar;
	our @ISA = qw(Foo);

	package Foo_or_Bar;
	our @ISA = qw(Foo);

	package Baz;
	sub new{ bless {}, shift }
	sub isa{
		my($x, $y) = @_;
		return $y eq 'Foo';
	}

	package Broken;
	sub isa; # pre-declaration only

	package AL;
	sub new{ bless {}, shift }
	sub DESTROY{}
	sub isa;

	sub AUTOLOAD{
		#our $AUTOLOAD; ::diag "$AUTOLOAD(@_)";
		1;
	}

	package AL_stubonly;

	sub new{ bless{}, shift; }
	sub DESTROY{};
	sub isa;

	sub AUTOLOAD;

}

ok  is_instance(Foo->new, 'Foo'), 'is_instance';
ok !is_instance(Foo->new, 'Bar');
ok  is_instance(Foo->new, 'UNIVERSAL'), 'is_instance of UNIVERSAL';

ok  is_instance(Bar->new, 'Foo');
ok  is_instance(Bar->new, 'Bar');

ok  is_instance(Baz->new, 'Foo');
ok !is_instance(Baz->new, 'Bar');
ok !is_instance(Baz->new, 'Baz');

ok is_instance(Foo_or_Bar->new, 'Foo');
ok!is_instance(Foo_or_Bar->new, 'Bar');
@Foo_or_Bar::ISA = qw(Bar);
ok is_instance(Foo_or_Bar->new, 'Bar'), 'ISA changed dynamically';


# no object reference

ok !is_instance('Foo', 'Foo');
ok !is_instance({},    'Foo');

ok !is_instance({}, 'HASH');

ok !eval{ is_instance(Broken->new(), 'Broken'); 1 };

ok is_instance(AL->new, 'AL');
ok is_instance(AL->new, 'Foo');

ok !eval{ is_instance(AL_stubonly->new, 'AL'); 1 };

isa_ok instance(Foo->new, 'Foo'), 'Foo', 'instance';
isa_ok instance(Bar->new, 'Foo'), 'Foo';

ok !eval{ instance(undef, 'Foo');1 };
ok !eval{ instance(1, 'Foo');1 };
ok !eval{ instance('', 'Foo'); 1};
ok !eval{ instance({}, 'Foo');1 };
ok !eval{ instance(Foo->new, 'Bar');1 };

my $universal_isa = UNIVERSAL->can('isa');
undef *UNIVERSAL::isa;

ok is_instance(Bar->new, 'Foo'), 'is_instance() works even if UNIVERSAL::isa wis deleted';
ok eval{ instance(Bar->new, 'Foo') };

*UNIVERSAL::isa = $universal_isa;

# error
ok !eval{ is_instance('Foo', Foo->new());1 }, 'illigal argument order';
ok !eval{ is_instance([], []);1 }, 'illigal use';
ok !eval{ is_instance(); 1}, 'not enough argument';
ok !eval{ is_instance([], undef); 1 }, 'uninitialized class';
