#!perl -w

use strict;
use Benchmark qw(:all);
use Data::Util qw(:all);
use Data::OptList();


print "Perl $] on $^O\n";

my @args = ([qw(foo bar), baz => []], "moniker", 0);

use Test::More 'no_plan';
is_deeply Data::Util::mkopt(@args), Data::OptList::mkopt(@args);

print "mkopt()\n";
print "no-unique, no-validation\n";
cmpthese -1 => {
	'OptList' => sub{
		for(1 .. 10){
			my $opt_ref = Data::OptList::mkopt(@args);
		}
	},
	'Util' => sub{
		for(1 .. 10){
			my $opt_ref = Data::Util::mkopt(@args);
		}
	},
};

@args = ([qw(foo bar), baz => []], "moniker", 1);
print "unique, no-validation\n";
cmpthese -1 => {
	'OptList' => sub{
		for(1 .. 10){
			my $opt_ref = Data::OptList::mkopt(@args);
		}
	},
	'Util' => sub{
		for(1 .. 10){
			my $opt_ref = Data::Util::mkopt(@args);
		}
	},
};

@args = ([qw(foo bar), baz => []], "moniker", 0, 'ARRAY');
print "no-unique, validation\n";
cmpthese -1 => {
	'OptList' => sub{
		for(1 .. 10){
			my $opt_ref = Data::OptList::mkopt(@args);
		}
	},
	'Util' => sub{
		for(1 .. 10){
			my $opt_ref = Data::Util::mkopt(@args);
		}
	},
};

@args = ([qw(foo bar), baz => []], "moniker", 1, 'ARRAY');
print "unique, validation\n";
cmpthese -1 => {
	'OptList' => sub{
		for(1 .. 10){
			my $opt_ref = Data::OptList::mkopt(@args);
		}
	},
	'Util' => sub{
		for(1 .. 10){
			my $opt_ref = Data::Util::mkopt(@args);
		}
	},
};

@args = ([qw(foo bar), baz => []]);
print "mkopt_hash()\n";
cmpthese -1 => {
	'OptList' => sub{
		for(1 .. 10){
			my $opt_ref = Data::OptList::mkopt_hash(@args);
		}
	},
	'Util' => sub{
		for(1 .. 10){
			my $opt_ref = Data::Util::mkopt_hash(@args);
		}
	},
};
