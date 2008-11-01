use 5.008_001;
use strict;
use warnings;
use inc::Module::Install;

name 'Data-Util';

all_from 'lib/Data/Util.pm';

requires 'XSLoader'   => 0.06;

test_requires 'Test::More'      => 0.62;
test_requires 'Test::Exception' => 0.27;

author_tests 'xt';

my $use_xs = can_cc();

for (@ARGV){
	/^-pm/ and $use_xs = 0;
	/^-xs/ and $use_xs = 1;
}
warn can_cc();
if($use_xs){
	makemaker_args(
		DEFINE => '-DINLINE_STR_EQ',
		OBJECT => '$(O_FILES)',
	);
}
else{
	makemaker_args(
		XS => {},
		C  => [],
	);
}

WriteMakefile(
	clean => {
		FILES => q{
			Data-Util-*
			*.stackdump
			*.gcov *.gcda *.gcno
			*.out
			nytprof
			cover_db,
		},
	},
);
