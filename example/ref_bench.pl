#!perl -w
use strict;
use warnings FATAL => 'all';

use Benchmark qw(:all);

use Params::Util qw(_ARRAY0);
use Data::Util qw(:all);

my $o = [];

print "Params::Util::_ARRAY0() vs. Scalar::Util::Ref::is_array_ref() vs. ref()\n";

foreach my $o([], {}, bless({}, 'Foo'), undef){
	print "\nFor ", neat($o), "\n";

	my $i;
	cmpthese timethese -1 => {
		'_ARRAY0' => sub{
			for(1 .. 10){
				if(_ARRAY0($o)){
					;
				}
			}
		},

		'is_array_ref' => sub{
			for(1 .. 10){
				if(is_array_ref($o)){
					;
				}
			}
		},
		'ref() eq "ARRAY"' => sub{
			for(1 ..10){
				if(ref($o) eq 'ARRAY'){
					;
				}
			}
		},
	};
}
