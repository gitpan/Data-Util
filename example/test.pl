#!perl -w

use strict;
use Data::Util qw(:all);
use Data::Dumper;



sub foo{
	print Dumper \@_;
}
sub Foo::bar{
	print Dumper \@_;
}

curry(\&foo, *_, \0, 42, \1)->(1, 2, 3);

use feature 'say';
curry(\0, \1, *_)->('Foo', 'bar', 1, 2, 3);
use DDS;
Dump curry(\0, \1, \3);
