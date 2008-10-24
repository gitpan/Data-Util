#!perl -w

use strict;
use Benchmark qw(:all);

use Data::Util qw(neat);

BEGIN{
	*UNIVERSAL::fast_isa = \&Data::Util::fast_isa;
}

BEGIN{
	package Base;
	sub new{
		bless {} => shift;
	}
	
	package Foo;
	our @ISA = qw(Base);
	package Foo::X;
	our @ISA = qw(Foo);
	package Foo::X::X;
	our @ISA = qw(Foo::X);
	package Foo::X::X::X;
	our @ISA = qw(Foo::X::X);

	package Unrelated;
	our @ISA = qw(Base);

	package SpecificIsa;
	our @ISA = qw(Base);
	sub isa{
		$_[1] eq 'Foo';
	}
}

print "Benchmark: UNIVERSAL::isa vs. Data::Util::fast_isa\n";

foreach my $x (Foo->new, Foo::X::X::X->new, Unrelated->new, SpecificIsa->new){
	print "\nFor ", neat($x), "\n";

	my $i = 0;

	cmpthese -1 => {
		'original' => sub{
			for(1 .. 10){
				if($x->isa('Foo')){
					;
				}
			}
		},
		'fast_isa' => sub{
			for(1 .. 10){
				if($x->fast_isa('Foo')){
					;
				}
			}
		},
	};
}
