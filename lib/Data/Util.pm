package Data::Util;

use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.04';

use Carp (); # for default fail handler
use Exporter ();
use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

our @EXPORT_OK = qw(
	is_scalar_ref is_array_ref is_hash_ref is_code_ref is_glob_ref is_regex_ref
	is_instance

	scalar_ref array_ref hash_ref code_ref glob_ref regex_ref
	instance

	anon_scalar neat

	get_stash
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,

	check   => [qw(
		is_scalar_ref is_array_ref is_hash_ref is_code_ref
		is_glob_ref is_regex_ref is_instance
	)],
	validate  => [qw(
		scalar_ref array_ref hash_ref code_ref
		glob_ref regex_ref instance
	)],
);

sub import{
	my $i = 0;
	while($i < @_){
		my $cmd = $_[$i];

		if($cmd eq '-fast_isa'){
			no warnings 'redefine';
			*UNIVERSAL::isa = \&fast_isa;
			splice @_, $i, 1;
		}
		elsif($cmd eq '-fail_handler'){
			_fail_handler(scalar(caller), $_[$i+1]);
			splice @_, $i, 2;
		}
		else{
			$i++;
		}
	}
	goto &Exporter::import;
}


1;
__END__

=head1 NAME

Data::Util - A selection of utilities for data and data types

=head1 VERSION

This document describes Data::Util version 0.04

=head1 SYNOPSIS

	use Data::Util qw(:validate);

	sub foo{
		my $sref = scalar_ref(shift);
		my $aref = array_ref(shift);
		my $href = hash_ref(shift);
		my $cref = code_ref(shift);
		my $gref = glob_ref(shift);
		my $rref = regex_ref(shift);
		my $obj  = instance(shift, 'Foo');
		# ...
	}

	use Data::Util qw(:check);

	sub bar{
		my $x = shift;
		if(is_scalar_ref $x){
			# $x is an array reference
		}
		# ...
		elsif(is_instance $x, 'Foo'){
			# $x is an instance of Foo
		}
		# ...
	}

	# to generate an anonymous scalar reference
	use Data::Util qw(anon_scalar)

	my $ref_to_undef = anon_scalar();

	$x = anon_scalar($x); # OK


=head1 DESCRIPTION

This module provides utility subroutines for data and data types.

=head1 INTERFACE

=head2 Check functions

Check functions are introduced by the C<:check> tag, which check the argument
type.

These functions also checks overloading magic, e.g. C<${}> for a SCALAR reference.

=over 4

=item is_scalar_ref($x)

For a SCALAR reference.

=item is_array_ref($x)

For an ARRAY reference.

=item is_hash_ref($x)

For a HASH reference.

=item is_code_ref($x)

For a CODE reference.

=item is_glob_ref($x)

For a GLOB reference.

=item is_regex_ref($x)

For a regular expression reference.

=item is_instance($x, $class)

For an instance of a class.

It is equivalent to something like
C<Scalar::Util::blessed($x) && $x->isa($class) ? $x : undef>,
but significantly faster and easy to use.

=back


=head2 Validating functions

Validating functions are introduced by the C<:validate> tag, and returns the
first argument C<$x>.
These are like the C<:check> functions but dies if the argument type
is not the wanted type.

These functions also checks overloading magic, e.g. C<${}> for a SCALAR reference.

=over 4


=item scalar_ref($x)

For a SCALAR reference.

=item array_ref($x)

For an ARRAY reference.

=item hash_ref($x)

For a HASH reference.

=item code_ref($x)

For a CODE reference.

=item glob_ref($x)

For a GLOB reference.

=item regex_ref($x)

For a regular expression reference.

=item instance($x, $class)

For an instance of a class.

=back

=head2 Other utilities

=over 4

=item anon_scalar()

Generates an anonymous scalar reference to C<undef>.

=item anon_scalar(expr)

Generates an anonymous scalar reference to I<expr>.

=item neat(expr)

Returns a neat string that is suitable to display.

=item get_stash(package_name)

Returns the symbol table hash (also known as B<stash>) of I<package_name>.

It is similar to C<< do{ no strict 'refs'; \%{$package_name . '::'} } >>,
but does B<not> create the stash if I<package_name> does not exist.

=back

=head2 Subdirectives

=over 4

=item -fast_isa

Replaces C<UNIVERSAL::isa()> by C<fast_isa>, which is even faster.

This alternative subroutine passes all the F<PERL-DIST/t/op/universal.t>
(included as F<Data-Util/t/10_fast_isa.t>).

This subdirective is global-scoped.

=item -fail_handler => \&handler

Set a custom fail handler. The handler is called when a
validation fails.

This subdirective is package-scoped.

=back

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-scalar-util-ref@rt.cpan.org/>, or through the web interface at
L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<Params::Util>.

L<Scalar::Util>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
