#!perl -w

use strict;
use Test::More tests => 5;

use Data::Util qw(get_stash);

sub get_stash_pp{
	my($pkg) = @_;
	no strict 'refs';

	return \%{$pkg . '::'};
}
foreach my $pkg( qw(main strict Data::Util ::main::Data::Util) ){
	is get_stash($pkg), get_stash_pp($pkg), "get_stash for $pkg";
}

ok !defined(get_stash('not exists')), 'does not create a new stash';
