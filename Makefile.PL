use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Data::Util',
    AUTHOR              => q{Lukas Mai <l.mai@web.de>},
    VERSION_FROM        => 'lib/Data/Util.pm',
    ABSTRACT_FROM       => 'lib/Data/Util.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Defaults::Mauke' => 0,
        'Exporter' => '5.57',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Data-Util-*' },
);
