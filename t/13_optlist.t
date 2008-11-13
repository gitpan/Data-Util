#!perl -w

use strict;
use Test::More tests => 41;
use Test::Exception;

use Data::Util qw(:all);

use constant PP_ONLY => $INC{'Data/Util/PurePerl.pm'};

BEGIN{
	package Foo;
	sub new{
		bless {}, shift;
	}
}
use constant true  => 1;
use constant false => 0;

# mkopt

is_deeply mkopt(undef), [];

is_deeply mkopt([]), [], 'mkopt';
is_deeply mkopt(['foo']), [ [foo => undef] ];
is_deeply mkopt([foo => undef]), [ [foo => undef] ];
is_deeply mkopt([foo => [42]]), [ [foo => [42]] ];
is_deeply mkopt([qw(foo bar baz)]), [ [foo => undef], [bar => undef], [baz => undef]];

is_deeply mkopt({foo => undef}), [ [foo => undef] ];
is_deeply mkopt({foo => [42]}),  [ [foo => [42]] ];

is_deeply mkopt([qw(foo bar baz)], undef, true), [[foo => undef], [bar => undef], [baz => undef]], 'unique';

is_deeply mkopt([foo => [], qw(bar)], undef, false, 'ARRAY'), [[foo => []], [bar => undef]], 'validation';
is_deeply mkopt([foo => [], qw(bar)], undef, false, ['CODE', 'ARRAY']), [[foo => []], [bar => undef]];
is_deeply mkopt([foo => anon_scalar], undef, false, 'SCALAR'), [[foo => anon_scalar]];
is_deeply mkopt([foo => \&ok],       undef, false, 'CODE'),   [[foo => \&ok]];
is_deeply mkopt([foo => Foo->new], undef, false, 'Foo'), [[foo => Foo->new]];

SKIP:{
	skip "for XS specific function", 2 if PP_ONLY;
	is_deeply mkopt([foo => [], qw(bar)], undef, false, {foo => 'ARRAY'}),   [[foo => []], [bar => undef]];
	is_deeply mkopt([foo => [], bar => {}], undef, false, {foo => ['CODE', 'ARRAY'], bar => 'HASH'}), [[foo => []], [bar => {}]];
}
# mkopt_hash

is_deeply mkopt_hash([]), {}, 'mkopt_hash';
is_deeply mkopt_hash(['foo']), { foo => undef };
is_deeply mkopt_hash([foo => undef]), { foo => undef };
is_deeply mkopt_hash([foo => [42]]), { foo => [42] };
is_deeply mkopt_hash([qw(foo bar baz)]), { foo => undef, bar => undef, baz => undef };

is_deeply mkopt_hash({foo => undef}), { foo => undef };
is_deeply mkopt_hash({foo => [42]}),  { foo => [42] };

is_deeply mkopt_hash([foo => [], qw(bar)], undef, 'ARRAY'), {foo => [], bar => undef}, 'validation';
is_deeply mkopt_hash([foo => [], qw(bar)], undef, ['CODE', 'ARRAY']), {foo => [], bar => undef};
is_deeply mkopt_hash([foo => Foo->new], undef, 'Foo'), {foo => Foo->new};

SKIP:{
	skip "for XS specific function", 2 if PP_ONLY;
	is_deeply mkopt_hash([foo => [], qw(bar)], undef, {foo => 'ARRAY'}),   {foo => [], bar => undef};
	is_deeply mkopt_hash([foo => [], bar => {}], undef, {foo => ['CODE', 'ARRAY'], bar => 'HASH'}), {foo => [], bar => {}};
}
# XS specific misc. check
my $key = 'foo';
my $ref = mkopt([$key]);
$ref->[0][0] .= 'bar';
is $key, 'foo';
$ref = mkopt_hash([$key]);
$key .= 'bar';
is_deeply $ref, {foo => undef};

sub f{
	return mkopt(@_);
}
my $a = mkopt(my $foo = ['foo']); push @$foo, 42;
my $b = mkopt(my $bar = ['bar']); push @$bar, 42;
is_deeply $a, [[foo => undef]], '(use TARG)';
is_deeply $b, [[bar => undef]], '(use TARG)';

# unique
throws_ok{
	mkopt [qw(foo foo)], "mkopt", 1;
} qr/multiple definitions/i, 'unique-mkopt';
throws_ok{
	mkopt_hash [qw(foo foo)], "mkopt", 1;
} qr/multiple definitions/i, 'unique-mkopt_hash';

# validation
throws_ok{
	mkopt [foo => []], "test", 0, 'HASH';
} qr/ARRAY-ref values are not valid.* in test opt list/;
throws_ok{
	mkopt [foo => []], "test", 0, [qw(SCALAR CODE HASH)];
} qr/ARRAY-ref values are not valid.* in test opt list/;
throws_ok{
	mkopt [foo => []], "test", 0, 'Bar';
} qr/ARRAY-ref values are not valid.* in test opt list/;

throws_ok{
	mkopt [foo => Foo->new], "test", 0, 'Bar';
} qr/Foo-ref values are not valid.* in test opt list/;
throws_ok{
	mkopt [foo => Foo->new], "test", 0, ['CODE', 'Bar'];
} qr/Foo-ref values are not valid.* in test opt list/;


dies_ok{
	mkopt anon_scalar();
};
dies_ok{
	mkopt_hash anon_scalar();
};
