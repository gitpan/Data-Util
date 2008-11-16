package Data::Util::Error;

use strict;
use warnings;

sub import{
	my $class = shift;
	if(@_){
		$class->fail_handler(scalar(caller) => @_);
	}
}

my %fail_handler;
sub fail_handler{
	shift; # this class
	my $pkg = shift;
	my $h = $fail_handler{$pkg};

	if(@_){
		$fail_handler{$pkg} = shift;
	}

	return $h;
}

sub croak{
	if($] < 5.010_000){
		require MRO::Compat;
	}

	my $caller_pkg;
	my $i = 0;
	while($caller_pkg = caller $i){
		if($caller_pkg ne 'Data::Util'){
			last;
		}
		$i++;
	}

	my $fail_handler;
	foreach my $pkg(@{mro::get_linear_isa($caller_pkg)}){
		if($fail_handler = $fail_handler{$pkg}){
			last;
		}
	}

	require Carp;
	local $Carp::CarpLevel = $Carp::CarpLevel + $i;
	die $fail_handler ? &{$fail_handler} : &Carp::longmess;
}
1;
__END__

=head1 NAME

Data::Util::Error - Deals with package-specific errors in Data::Util

=head1 SYNOPSIS

	package Foo;
	use Data::Util::Error sub{ Foo::Exception->throw(@_) };
	use Data::Util qw(:validate);

	sub f{
		my $x_ref = array_ref shift; # Foo::Exception is thrown if invalid
		# ...
	}

=head1 Functions

=over 4

=item Data::Util::Error->fail_handler()

=item Data::Util::Error->fail_handler($handler)

=item Data::Util::Error::croak(@args)

=back

=cut
