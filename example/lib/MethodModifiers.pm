package # it's an example for modify_subroutine()
	MethodModifiers;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT    = qw(before around after);
our @EXPORT_OK = (@EXPORT, qw(add_method_modifier));
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use Data::Util qw(
	modify_subroutine
	subroutine_modifier
	install_subroutine
	get_code_info
);

sub _croak{
	require Data::Util::Error;
	goto &Data::Util::Error::croak;
}

sub add_method_modifier{
	my($class, $type, $args) = @_;

	my($code) = pop @{$args};

	foreach my $method(@{$args}){
		my $entity = $class->can($method)
			or _croak(qq{The method '$method' is not found in the inheritance hierarchy for class $class});

		if(!subroutine_modifier($entity) or (get_code_info($entity))[0] ne $class){
			$entity = modify_subroutine($entity);

			no warnings 'redefine';
			install_subroutine($class, $method => $entity);
		}

		subroutine_modifier($entity, $type => $code);
	}
	return;
}

sub before{
	my $into = caller;
	add_method_modifier($into, before => [@_]);
}
sub around{
	my $into = caller;
	add_method_modifier($into, around => [@_]);
}
sub after{
	my $into = caller;
	add_method_modifier($into, after  => [@_]);
}


1;
__END__

=head1 NAME

MethodModifiers - Provides Moose-like method modifiers

=head1 SYNOPSIS

	package Foo;
	use warnings;
	use Data::Util qw(:all);
	use MethodModifiers;

	before old_method =>
		curry \&warnings::warnif, deprecated => q{"old_method" is deprecated, use "new_method" instead};

	my $success = 0;
	after qw(foo bar baz) => sub{ $success++ };

	around foo => sub{
		my $next = shift;
		my $self = shift;

		$self->$next(map{ instance $_, 'Foo' } @_);
	};

=head1 DESCRIPTION

This module is an implementation of C<Class::Method::Modifiers> that
provides C<Moose>-like method modifiers.

This is just a front-end of C<Data::Util::modify_subroutine()> and
C<Data::Util::subroutine_modifier()>

See L<Data::Util> for details.

=head1 INTERFACE

=head2 Default exported functions

=over 4

=item before(method(s) => code)

=item around(method(s) => code)

=item after(method(s) => code)

=back

=head2 Exportable functions

=over 4

=item add_method_modifier(class, modifer_type, args)

=back

=head1 SEE ALSO

L<Data::Util>.

L<Method::Modifiers>

L<Moose>.

L<Class::Method::Modifiers>.

=cut
