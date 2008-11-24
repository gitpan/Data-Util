#!perl -w

use strict;
use Data::Util qw(:all);
use Benchmark qw(:all);

use FindBin qw($Bin);
use lib $Bin;
use Common;

signeture 'Data::Util' => \&wrap_subroutine;

sub f  { 42 }

sub before  { 1 }
sub around  {
	my $f = shift;
	$f->(@_) + 1;
}
sub after   { 1 }

my @before = (\&before, \&before);
my @around = (\&around);
my @after  = (\&after, \&after);

my $wrapped = wrap_subroutine(\&f, before => \@before, around => \@around, after => \@after);

sub wrap{
	my $subr   = shift;
	my @before = @{(shift)};
	my @around = @{(shift)};
	my @after  = @{(shift)};

	$subr = curry($_, (my $tmp = $subr), *_) for @around;

	return sub{
		$_->(@_) for @before;
		my @ret = wantarray ? $subr->(@_) : scalar $subr->(@_);
		$_->(@_) for @after;
		return wantarray ? @ret : $ret[0];
	};
}
my $closure = wrap(\&f, \@before, \@around, \@after);

$wrapped->(-1) == 43 or die $wrapped->(-10);
$closure->(-2) == 43 or die $closure->(-20);

print "Creation of wrapped subs:\n";
cmpthese timethese -1 => {
	wrap => sub{
		my $w = wrap_subroutine(\&f, before => \@before, around => \@around, after => \@after);
	},
	closure => sub{
		my $w = wrap(\&f, \@before, \@around, \@after);
	},
};

sub combined{
	$_->(@_) for @before;
	around(\&f, @_);
	$_->(@_) for @after;
}

print "Calling wrapped subs:\n";
cmpthese timethese -1 => {
	wrap => sub{
		$wrapped->(42);
	},
	closure => sub{
		$closure->(42);
	},
	combined => sub{
		combined(42);
	},

};

