use 5.008_001;
use strict;
use warnings;
use inc::Module::Install;

name 'Data-Util';

all_from 'lib/Data/Util.pm';

requires 'XSLoader'   => 0.06;

test_requires 'Test::More'      => 0.62;
test_requires 'Test::Exception' => 0.27;

WriteMakefile(
	DEFINE => '-DINLINE_STR_EQ',
	OBJECT => '$(O_FILES)',
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
