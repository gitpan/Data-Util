#!perl -w

use strict;
use Test::More tests => 4;
use Test::Exception;

use Data::Util qw(get_code_info install_subroutine);

use Attribute::Handlers;
sub UNIVERSAL::Foo :ATTR(CODE, BEGIN){
	my($pkg, $sym, $subr) = @_;

	lives_ok{
		is_deeply [get_code_info($subr)], [], 'get_code_info';
	};
}

sub f :Foo;
sub g :Foo{}
