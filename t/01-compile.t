#!perl

use Test::More tests => 3;

use Defaults::Mauke;

use Data::Util;

is list2re(qw[! a abc ab foo bar baz ** *]), qr/abc|bar|baz|foo|\*\*|ab|\!|\*|a/, 'list2re';
is +(byval { s/foo/bar/ } 'foo-foo'), 'bar-foo', 'byval';
is_deeply [mapval { tr[a-d][1-4] } qw[foo bar baz]], [qw[foo 21r 21z]], 'mapval';
