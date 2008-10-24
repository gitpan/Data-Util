#!perl -w

use strict;
use Test::More tests => 12;
use Test::Exception;

BEGIN{
	use_ok 'Data::Util' =>  qw(is_method set_method_attribute);
}

sub f{}

sub lf :lvalue{}
sub mf :method{}
sub lmf :lvalue :method{}

my $lambda  = sub{};
my $mlambda = sub :method{};

ok !is_method(\&f);
ok !is_method(\&lf);
ok  is_method(\&mf);
ok  is_method(\&lmf);

ok !is_method($lambda), 'lambda';
ok  is_method($mlambda), 'lambda method';

{
	no warnings 'once';
	ok !is_method(\&undefined);
}

throws_ok{
	is_method(undef);
} qr/not a code reference/;
throws_ok{
	is_method('mf');
} qr/not a code reference/;

set_method_attribute(\&f, 1);
ok  is_method(\&f), 'set_method_attribute (ON)';
set_method_attribute(\&f, 0);
ok !is_method(\&f), 'set_method_attribute (OFF)';

