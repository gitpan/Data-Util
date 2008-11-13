package Data::Util::PurePerl;

die qq{Don't use Data::Util::PurePerl directly, use Data::Util instead\n}
	if caller() ne 'Data::Util';

package
	Data::Util;

use strict;
use warnings;

use Scalar::Util ();
use overload ();


sub _croak{
	require Data::Util::Error;
	Data::Util::Error->throw(@_);
}
sub _fail{
	require Data::Util::Error;
	Data::Util::Error->throw(sprintf 'Validation failed: you must supply %s, not %s', @_);
}

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
	_fail('a class name', neat $class)
		unless _is_string($class);

	return Scalar::Util::blessed($obj) && $obj->isa($class);
}
sub is_invocant{
	my($x) = @_;
	if(ref $x){
		return !!Scalar::Util::blessed($x);
	}
	else{
		return !!get_stash($x);
	}
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

	_fail('a class name', neat($class))
		unless _is_string($class);

	return Scalar::Util::blessed($obj) && $obj->isa($class)
		? $obj : _fail("an instance of $class", neat($obj));
}

sub invocant{
	my($x) = @_;
	if(ref $x){
		if(Scalar::Util::blessed($x)){
			return $x;
		}
	}
	else{
		if(get_stash($x)){
			$x =~ s/^:://;
			$x =~ s/(?:main::)+//;
			return $x eq '' ? 'main' : $x;
		}
	}
	_fail('an invocant', neat($x));
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

	_croak('Usage: Data::Util::install_subroutine(into, as, code)')
		if @_ != 3;

	_is_string($into)  or _fail('a package name', neat($into));
	_is_string($as)    or _fail('a subroutine name', neat($as));
	is_code_ref($code) or _fail('a CODE reference', neat($code));

	my $slot = do{ no strict 'refs'; \*{ $into . '::' . $as } };

	if(defined &{$slot}){
		warnings::warnif(redefine => "subroutine $as redefined");
	}

	no warnings 'redefine';
	*{$slot} = \&{$code};
}

sub get_code_info{
	my($code) = @_;

	is_code_ref($code) or _fail('a CODE reference', neat($code));

	require B;
	my $cv = B::svref_2object(\&{$code});
	return unless $cv->GV->isa('B::GV');
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

sub mkopt{
	require Data::OptList;
	goto &Data::OptList::mkopt;
}
sub mkopt_hash{
	require Data::OptList;
	goto &Data::OptList::mkopt_hash;
}

1;
