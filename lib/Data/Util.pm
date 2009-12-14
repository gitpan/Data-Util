package Data::Util;

use Defaults::Mauke;
use Exporter qw[import];

our $VERSION = '0.02';
our @EXPORT = our @EXPORT_OK = qw[list2re byval mapval];

fun list2re(@args) {
	my $re = join '|', map quotemeta, sort {length $b <=> length $a || $a cmp $b } @args;
	qr/$re/
}

fun byval($f, $x) :(&$) {
	local *_ = \$x;
	$f->($_);
	$x
}

fun mapval($f, @xs) :(&@) {
	map { $f->($_); $_ } @xs
}

1

__END__

=head1 NAME

Data::Util - various utility functions

=head1 SYNOPSIS

 use Data::Util;
 
 my $re = list2re qw/foo bar baz/;
 print byval { s/foo/bar/ } $text;
 foo(mapval { chomp } @lines);

=head1 DESCRIPTION

This module defines a few generally useful utility functions. I got tired of
redefining or working around them, so I wrote this module.

=head2 Functions

=over 4

=item list2re LIST

Converts a list of strings to a regex that matches any of the strings.
Especially useful in combination with C<keys>. Example:

 my $re = list2re keys %hash;
 $str =~ s/($re)/$hash{$1}/g;

=item byval BLOCK SCALAR

Takes a code block and a value, runs the block with C<$_> set to that value,
and returns the final value of C<$_>. The global value of C<$_> is not
affected. C<$_> isn't aliased to the input value either, so modifying C<$_>
in the block will not affect the passed in value. Example:

 foo(byval { s/!/?/g } $str);
 # Calls foo() with the value of $str, but all '!' have been replaced by '?'.
 # $str itself is not modified.

=item mapval BLOCK LIST

Works like a combination of C<map> and C<byval>; i.e. it behaves like
C<map>, but C<$_> is a copy, not aliased to the current element, and the return
value is taken from C<$_> again (it ignores the value returned by the
block). Example:

 my @foo = mapval { chomp } @bar;
 # @foo contains a copy of @bar where all elements have been chomp'd.
 # This could also be written as chomp(my @foo = @bar); but that's not
 # always possible.

=back

=head1 AUTHOR

Lukas Mai, C<< <l.mai at web.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Lukas Mai.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
