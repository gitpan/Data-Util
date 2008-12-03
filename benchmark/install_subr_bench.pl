#!perl -w

use strict;

use Benchmark qw(:all);

use FindBin qw($Bin);
use lib $Bin;
use Common;

use Data::Util qw(:all);

signeture 'Data::Util' => \&install_subroutine;


my $pkg  = do{ package Foo; __PACKAGE__ };
my $foo = \&foo;
my $bar = \&bar;

sub foo{}
sub bar{}

print "Installing a subroutine:\n";
cmpthese timethese -1 => {
	installer => sub{
		no warnings 'redefine';
		install_subroutine($pkg, foo => $foo);
	},
	direct => sub{
		no warnings 'redefine';
		no strict 'refs';
		*{$pkg . '::foo'} = $foo;
	},
};

print "\nInstalling two subroutines:\n";
cmpthese timethese -1 => {
	installer => sub{
		no warnings 'redefine';
		install_subroutine($pkg, foo => $foo, bar => $bar);
	},
	direct => sub{
		no warnings 'redefine';
		no strict 'refs';
		*{$pkg . '::foo'} = $foo;
		*{$pkg . '::bar'} = $bar;
	},
};
