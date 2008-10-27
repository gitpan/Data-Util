#!perl -w

use strict;
use warnings FATAL => 'all';
use Test::More tests => 10;

use Tie::Scalar;

use Data::Util qw(get_stash neat);

sub get_stash_pp{
	my($pkg) = @_;
	no strict 'refs';

	return \%{$pkg . '::'};
}

foreach my $pkg( qw(main strict Data::Util ::main::Data::Util)){
	is get_stash($pkg), get_stash_pp($pkg), "get_stash for $pkg";
}

foreach my $pkg('not exists', 1, undef, [], *ok, ){
	ok !defined(get_stash $pkg), 'get_stash for ' . neat($pkg) . '(invalid value)';
}

tie my($ts), 'Tie::StdScalar', 'main';
is get_stash($ts), get_stash_pp('main'), 'for magic variable';

