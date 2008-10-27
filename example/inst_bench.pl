#!perl -w

use strict;
use Benchmark qw(:all);

use Data::Util qw(:all), @ARGV;
use Scalar::Util qw(blessed);

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

print "Perl $] on $^O\n";

foreach my $x (Foo->new, Foo::X::X::X->new, Unrelated->new, undef, {}){
	print 'For ', neat($x), "\n";

	my $i = 0;

	cmpthese -1 => {
		'ref&eval{}' => sub{
			for(1 .. 10){
				$i++ if ref($x) && eval{ $x->isa('Foo') };
			}
		},
		'scalar_util' => sub{
			for(1 .. 10){
				$i++ if blessed($x) && $x->isa('Foo');
			}
		},
		'is_instance()' => sub{
			for(1 .. 10){
				$i++ if is_instance($x, 'Foo');
			}
		},
	};

	print "\n";
}
