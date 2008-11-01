package Data::Util::PurePerl;

package
	Data::Util;

use strict;
use warnings;

use Carp ();
use Scalar::Util ();
use overload ();


Carp::croak(q{Don't use Data::Util::PurePerl directly, use Data::Util instead})
	if caller() ne 'Data::Util';


my %fail_handler;

*fast_isa = \&UNIVERSAL::isa;

sub _overloaded{
	return Scalar::Util::blessed($_[0])
		&& overload::Method($_[0], $_[1]);
}

sub _is_string{
	return defined($_[0]) && !ref($_[0]);
}

sub is_scalar_ref{
	return ref($_[0]) eq 'SCALAR' || ref($_[0]) eq 'REF' || _overloaded($_[0], '${}');
}
sub is_array_ref{
	return ref($_[0]) eq 'ARRAY' || _overloaded($_[0], '@{}');
}
sub is_hash_ref{
	return ref($_[0]) eq 'HASH' || _overloaded($_[0], '%{}');
}
sub is_code_ref{
	return ref($_[0]) eq 'CODE' || _overloaded($_[0], '&{}');
}
sub is_glob_ref{
	return ref($_[0]) eq 'GLOB' || _overloaded($_[0], '*{}');
}
sub is_regex_ref{
	return ref($_[0]) eq 'Regexp';
}
sub is_instance{
	my($obj, $class) = @_;
	Carp::croak('Invalid class name ', neat($class), ' supplied')
		unless _is_string($class);

	return Scalar::Util::blessed($obj) && $obj->isa($class);
}

sub scalar_ref{
	return ref($_[0]) eq 'SCALAR' || ref($_[0]) eq 'REF' || _overloaded($_[0], '${}')
		? $_[0] : _fail('a SCALAR reference', neat($_[0]));

}
sub array_ref{
	return ref($_[0]) eq 'ARRAY' || _overloaded($_[0], '@{}')
		? $_[0] : _fail('a SCALAR reference', neat($_[0]));
}
sub hash_ref{
	return ref($_[0]) eq 'HASH' || _overloaded($_[0], '%{}')
		? $_[0] : _fail('a HASH reference', neat($_[0]));
}
sub code_ref{
	return ref($_[0]) eq 'CODE' || _overloaded($_[0], '&{}')
		? $_[0] : _fail('a CODE reference', neat($_[0]));
}
sub glob_ref{
	return ref($_[0]) eq 'GLOB' || _overloaded($_[0], '*{}')
		? $_[0] : _fail('a GLOB reference', neat($_[0]));
}
sub regex_ref{
	return ref($_[0]) eq 'Regexp'
		? $_[0] : _fail('a regular expression reference', neat($_[0]));
}
sub instance{
	my($obj, $class) = @_;
	Carp::croak('Invalid class name ', neat($class), ' supplied')
		unless _is_string($class);

	return Scalar::Util::blessed($obj) && $obj->isa($class)
		? $obj : _fail("an instance of $class", neat($obj));
}

sub get_stash{
	my($package) = @_;
	return undef unless _is_string($package);

	$package =~ s/^:://;

	my $pack = *main::;
	foreach my $part(split /::/, $package){
		return undef unless $pack = $pack->{$part . '::'};
	}
	return *{$pack}{HASH};
}

sub anon_scalar{
	my($s) = @_;
	return \$s;  # not \$_[0]
}

sub install_subroutine{
	my($into, $as, $code) = @_;

	Carp::croak('Usage: Data::Util::install_subroutine(into, as, code)')
		if @_ != 3;

	_is_string($into)
		or Carp::croak('Invalid package name ' . neat($into) . ' supplied');

	_is_string($as)
		or Carp::croak('Invalid subroutine name ' . neat($as) . ' supplied');

	is_code_ref($code)
		or Carp::croak('Invalid CODE reference ' . neat($code) . ' supplied');

	my $slot = do{ no strict 'refs'; \*{ $into . '::' . $as } };

	if(defined &{$slot}){
		warnings::warnif(redefine => "subroutine $as redefined");
	}

	no warnings 'redefine';
	*{$slot} = \&{$code};
}

sub get_code_info{
	my($code) = @_;
	ref($code) eq 'CODE' or Carp::croak('Invalid CODE reference '.neat($code));

	require B;
	my $cv = B::svref_2object($code);
	return ($cv->GV->STASH->NAME, $cv->GV->NAME);
}

sub neat{
	my($s) = @_;

	if(ref $s){
		return overload::StrVal($s);
	}
	elsif(defined $s){
		return $s   if Scalar::Util::looks_like_number($s);
		return "$s" if is_glob_ref(\$s);
		require B;
		return B::perlstring($s);
	}
	else{
		return 'undef';
	}
}


sub _fail_handler{
	my $pkg = shift;

	my $h = $fail_handler{$pkg};

	if(@_){
		my $handler = shift;
		if(is_code_ref($handler)){
			$fail_handler{$pkg} = $handler;
		}
		else{
			Carp::croak('Not a CODE reference', neat($handler));
		}
	}
	return $h;
}

sub _fail{
	my($valid, $invalid) = @_;

	my $msg = "Validation failed: you must supply $valid, not $invalid";

	my $pkg = caller(1);
	if($fail_handler{$pkg}){
		Carp::croak( $fail_handler{$pkg}->($msg) );
	}
	else{
		Carp::confess($msg);
	}
}

1;
