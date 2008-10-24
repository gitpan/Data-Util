#!perl -w

use strict;
use Benchmark qw(:all);
use Data::Util qw(anon_scalar);

cmpthese timethese -1 => {
	anon_scalar => sub{
		for(1 .. 10){
			my $ref = anon_scalar();
		}
	},
	'\do{my $tmp}' => sub{
		for(1 .. 10){
			my $ref = \do{ my $tmp };
		}
	},
};

