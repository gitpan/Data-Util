#!perl -w

use strict;
use Test::More tests => 41;
use Test::Exception;

use constant HAS_SCOPE_GUARD => eval{ require Scope::Guard };

use Data::Util qw(:all);

sub foo{ @_ }

my @tags;
sub before{ push @tags, 'before'; }
sub around{ push @tags, 'around'; my $next = shift; $next->(@_) }
sub after { push @tags, 'after'; }

ok is_code_ref(wrap_subroutine(\&foo)), 'wrap_subroutine()';

my $w = wrap_subroutine \&foo,
	before => [\&before],
	around => [\&around],
	after => [\&after];

lives_ok{
	ok  subroutine_modifier($w);
	ok !subroutine_modifier(\&foo);
};

is_deeply [subroutine_modifier $w, 'before'], [\&before], 'getter:before';
is_deeply [subroutine_modifier $w, 'around'], [\&around], 'getter:around';
is_deeply [subroutine_modifier $w, 'after'],  [\&after],  'getter:after';
is_deeply [subroutine_modifier $w, 'original'], [\&foo],  'getter:around';

is_deeply [scalar $w->(1 .. 10)], [10], 'call with scalar context';
is_deeply \@tags, [qw(before around after)];

@tags = ();
is_deeply [$w->(1 .. 10)], [1 .. 10],   'call with list context';
is_deeply \@tags, [qw(before around after)];

$w = wrap_subroutine \&foo;
subroutine_modifier $w, before => \&before;
@tags = ();
is_deeply [$w->(1 .. 10)], [1 .. 10];
is_deeply \@tags, [qw(before)], 'add :before modifiers';

$w = wrap_subroutine \&foo;
subroutine_modifier $w, around => \&around;
@tags = ();
is_deeply [$w->(1 .. 10)], [1 .. 10];
is_deeply \@tags, [qw(around)], 'add :around modifiers';

$w = wrap_subroutine \&foo;
subroutine_modifier $w, after  => \&after;
@tags = ();
is_deeply [$w->(1 .. 10)], [1 .. 10];
is_deeply \@tags, [qw(after)], 'add :after modifiers';

$w = wrap_subroutine \&foo, before => [(\&before) x 10], around => [(\&around) x 10], after => [(\&after) x 10];

@tags = ();
is_deeply [$w->(42)], [42];
is_deeply \@tags, [('before') x 10, ('around') x 10, ('after') x 10], 'with multiple modifiers';

subroutine_modifier $w, before => \&before, \&before;
subroutine_modifier $w, around => \&around, \&around;
subroutine_modifier $w, after  => \&after,  \&after;

@tags = ();
is_deeply [$w->(1 .. 10)], [1 .. 10];
is_deeply \@tags, [('before') x 12, ('around') x 12, ('after') x 12], 'add modifiers';

# calling order and copying

sub f1{
	push @tags, 'f1';
	my $next = shift;
	$next->(@_);
}
sub f2{
	push @tags, 'f2';
	my $next = shift;
	$next->(@_);
}
sub f3{
	push @tags, 'f3';
	my $next = shift;
	$next->(@_);
}


sub before2{ push @tags, 'before2' }
sub before3{ push @tags, 'before3' }

sub after2 { push @tags, 'after2'  }
sub after3 { push @tags, 'after3'  }

$w = wrap_subroutine \&foo, around => [\&f1];
subroutine_modifier $w, around => \&f2, \&f3;
@tags = ();
$w->();
is_deeply \@tags, ['f3', 'f2', 'f1'], ':around order';

$w = wrap_subroutine \&foo, around => [ \&f1, \&f2, \&f3 ];
@tags = ();
$w->();
is_deeply \@tags, ['f3', 'f2', 'f1'], ':around order';


$w = wrap_subroutine \&foo, before => [\&before];
subroutine_modifier $w, before => \&before2, \&before3;
@tags = ();
$w->();
is_deeply \@tags, ['before3', 'before2', 'before'], ':before order';

$w = wrap_subroutine \&foo, before => [ \&before, \&before2, \&before3 ];
@tags = ();
$w->();
is_deeply \@tags, ['before3', 'before2', 'before'], ':before order';


$w = wrap_subroutine \&foo, after => [\&after];
subroutine_modifier $w, after => \&after2, \&after3;
@tags = ();
$w->();
is_deeply \@tags, ['after', 'after2', 'after3'], ':after order';

$w = wrap_subroutine \&foo, after => [ \&after, \&after2, \&after3 ];
@tags = ();
$w->();
is_deeply \@tags, ['after', 'after2', 'after3'], ':after order';

# GC

SKIP:{
	skip 'requires Scope::Gurard for testing GC',    3 unless HAS_SCOPE_GUARD;
	skip 'Pure Perl version in 5.8.x has a problem', 3 if $] < 5.010;

	@tags = ();
	for(1 .. 10){
		my $gbefore = Scope::Guard->new(\&before);
		my $gafter  = Scope::Guard->new(\&after);

		my $w = wrap_subroutine \&foo, before => [sub{ $gbefore }], after => [sub{ $gafter }]; # makes closures
	}
	is_deeply [sort @tags], [sort((qw(after before)) x 10)], 'closed values are released';

	@tags = ();
	my $i = 0;
	for(1 .. 10){
		my $gbefore = Scope::Guard->new(\&before);
		my $gafter  = Scope::Guard->new(\&after);

		my $w = wrap_subroutine \&foo, before => [sub{ $gbefore }], after => [sub{ $gafter }];
		$w->(Scope::Guard->new( sub{ $i++ } ));
	}
	is_deeply [sort @tags], [sort((qw(after before)) x 10)], '... called and released';
	is $i, 10, '... and the argument is also released';
}

# FATAL

dies_ok{
	wrap_subroutine(undef);
};
dies_ok{
	wrap_subroutine(\&foo, []);
};

dies_ok{
	wrap_subroutine(\&foo, before => [1]);
};
dies_ok{
	wrap_subroutine(\&foo, around => [1]);
};
dies_ok{
	wrap_subroutine(\&foo, after => [1]);
};

$w = wrap_subroutine(\&foo);

throws_ok{
	subroutine_modifier($w, 'foo');
} qr/Validation failed:.* a modifier property/;
throws_ok{
	subroutine_modifier($w, undef);
} qr/Validation failed:.* a modifier property/;
throws_ok{
	subroutine_modifier(\&foo, 'original');
} qr/Validation failed:.* a wrapped subroutine/;

throws_ok{
	subroutine_modifier($w, before => 'foo');
} qr/Validation failed:.* a CODE reference/;

throws_ok{
	subroutine_modifier($w, original => \&foo);
} qr/Cannot reset the original subroutine/;
