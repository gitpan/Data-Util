package Data::Util::PurePerl;

die qq{Don't use Data::Util::PurePerl directly, use Data::Util instead.\n}
	if caller() ne 'Data::Util';

package
	Data::Util;

use strict;
use warnings;

#use warnings::unused;

use Scalar::Util ();
use overload ();

sub _croak{
	require Data::Util::Error;
	goto &Data::Util::Error::croak;
}
sub _fail{
	my($name, $value) = @_;
	_croak(sprintf 'Validation failed: you must supply %s, not %s', $name, neat($value));
}

sub _overloaded{
	return Scalar::Util::blessed($_[0])
		&& overload::Method($_[0], $_[1]);
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
	_fail('a class name', $class)
		unless is_string($class);

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
		? $_[0] : _fail('a SCALAR reference', $_[0]);

}
sub array_ref{
	return ref($_[0]) eq 'ARRAY' || _overloaded($_[0], '@{}')
		? $_[0] : _fail('an ARRAY reference', $_[0]);
}
sub hash_ref{
	return ref($_[0]) eq 'HASH' || _overloaded($_[0], '%{}')
		? $_[0] : _fail('a HASH reference', $_[0]);
}
sub code_ref{
	return ref($_[0]) eq 'CODE' || _overloaded($_[0], '&{}')
		? $_[0] : _fail('a CODE reference', $_[0]);
}
sub glob_ref{
	return ref($_[0]) eq 'GLOB' || _overloaded($_[0], '*{}')
		? $_[0] : _fail('a GLOB reference', $_[0]);
}
sub regex_ref{
	return ref($_[0]) eq 'Regexp'
		? $_[0] : _fail('a regular expression reference', $_[0]);
}
sub instance{
	my($obj, $class) = @_;

	_fail('a class name', $class)
		unless is_string($class);

	return Scalar::Util::blessed($obj) && $obj->isa($class)
		? $obj : _fail("an instance of $class", $obj);
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
	_fail('an invocant', $x);
}

sub is_value{
	return defined($_[0]) && !ref($_[0]) && ref(\$_[0]) ne 'GLOB';
}
sub is_string{
	no warnings 'uninitialized';
	return !ref($_[0]) && ref(\$_[0]) ne 'GLOB' && length($_[0]) > 0;
}

sub is_number{
	return 0 if !defined($_[0]) || ref($_[0]);

	return 1 if $_[0] eq '0 but true';

	return $_[0] =~ m{
		\A \s*
			[+-]?
			(?= \d | \.\d)
			\d*
			(\.\d*)?
			(?: [Ee] (?: [+-]? \d+) )?
		\s* \z
	}xms;
}

sub is_integer{
	return 0 if !defined($_[0]) || ref($_[0]);

	return 1 if $_[0] eq '0 but true';

	return $_[0] =~ m{
		\A \s*
			[+-]?
			\d+
		\s* \z
	}xms;
}

sub get_stash{
	my($package) = @_;
	return undef unless is_string($package);

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

sub neat{
	my($s) = @_;

	if(ref $s){
		if(ref($s) eq 'CODE'){
			return sprintf '\\&%s(0x%x)', scalar(get_code_info($s)), Scalar::Util::refaddr($s);
		}
		elsif(ref($s) eq 'Regexp'){
			return qq{qr{$s}};
		}
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


sub install_subroutine{
	_croak('Usage: install_subroutine(package, name => code, ...)') unless @_;

	my $into = shift;
	is_string($into)  or _fail('a package name', $into);

	if((@_ % 2) != 0){
		_croak('Odd number of arguments for install_subroutine');
	}

	while(my($as, $code) = splice @_, 0, 2){
		is_string($as)    or _fail('a subroutine name', $as);
		is_code_ref($code) or _fail('a CODE reference', $code);

		my $slot = do{ no strict 'refs'; \*{ $into . '::' . $as } };

		if(defined &{$slot}){
			warnings::warnif(redefine => "Subroutine $as redefined");
		}

		no warnings 'redefine';
		*{$slot} = \&{$code};
	}
	return;
}
sub uninstall_subroutine {
	_croak('Usage: uninstall_subroutine(package, name, ...)') unless @_;

	my $package = shift;

	is_string($package) or _fail('a package name', $package);
	my $stash = get_stash($package) or return 0;

	require B;

	for(my $i = 0; $i < @_; $i++){
		my $name = $_[$i];
		is_string($name) or _fail('a subroutine name', $name);

		my $specified_code = is_code_ref($_[$i+1]) ? $_[++$i] : undef;

		my $glob = $stash->{$name};


		if(ref(\$glob) ne 'GLOB'){
			if(ref $glob){
				warnings::warnif(misc => "Constant subroutine $name uninstalled");
			}
			delete $stash->{$name};
			next;
		}

		my $code = *{$glob}{CODE};
		if(not defined $code){
			next;
		}

		if(defined $specified_code && $specified_code != $code){
			next;
		}

		if(B::svref_2object($code)->CONST){
			warnings::warnif(misc => "Constant subroutine $name uninstalled");
		}

		delete $stash->{$name};

		my $newglob = do{ no strict 'refs'; \*{$package . '::' . $name} }; # vivify
		delete $stash->{$glob};

		# copy all the slot except for CODE
		foreach my $slot( qw(SCALAR ARRAY HASH IO FORMAT) ){
			*{$newglob} = *{$glob}{$slot} if defined *{$glob}{$slot};
		}
	}

	return;
}

sub get_code_info{
	my($code) = @_;

	is_code_ref($code) or _fail('a CODE reference', $code);

	require B;
	my $gv = B::svref_2object(\&{$code})->GV;
	return unless $gv->isa('B::GV');
	return wantarray ? ($gv->STASH->NAME, $gv->NAME) : join('::', $gv->STASH->NAME, $gv->NAME);
}

sub curry{
	my $is_method = !is_code_ref($_[0]);

	my $proc;
	$proc = shift if !$is_method;

	my $args = \@_;

	my @tmpl;

	my $i = 0;
	my $maxp = -1;
	foreach my $arg(@_){
		if(is_scalar_ref($arg) && Scalar::Util::looks_like_number($$arg)){
			push @tmpl, sprintf '$_[%d]', $$arg;
			$maxp = $$arg if $maxp < $$arg;
		}
		elsif(defined($arg) && (\$arg) == \*_){
			push @tmpl, '@_[$maxp .. $#_]';
		}
		else{
			push @tmpl, sprintf '$args->[%d]', $i;
		}
		$i++;
	}

	$maxp++;

	my($pkg, $file, $line, $hints, $bitmask) = (caller 0 )[0, 1, 2, 8, 9];
	my $body = sprintf <<'END_CXT', $pkg, $line, $file;
BEGIN{ $^H = $hints; ${^WARNING_BITS} = $bitmask; }
package %s;
#line %s %s
END_CXT

	if($is_method){
		my $selfp = shift @tmpl;
		$proc     = shift @tmpl;
		$body .= sprintf q{ sub {
			my $self   = %s;
			my $method = %s;
			$self->$method(%s);
		} }, $selfp, defined($proc) ? $proc : 'undef', join(q{,}, @tmpl);
	}
	else{
		$body .= sprintf q{ sub { $proc->(%s) } }, join q{,}, @tmpl;
	}
	eval $body or die $@;
}

BEGIN{
	my %modifiers;

	my $initializer;
	$initializer = sub{
		require Hash::Util::FieldHash::Compat;
		Hash::Util::FieldHash::Compat::fieldhash(\%modifiers);
		undef $initializer;
	};

	sub wrap_subroutine{
		warnings::warnif(deprecated => 'wrap_subroutine() has been deprecated, use modify_subroutine() instead');
		goto &modify_subroutine;
	}
	sub modify_subroutine{
		my $code   = code_ref  shift;

		if((@_ % 2) != 0){
			_croak('Odd number of arguments for modify_subroutine()');
		}
		my %args   = @_;

		my(@before, @around, @after);

		@before = map{ code_ref $_ } @{array_ref $args{before}} if exists $args{before};
		@around = map{ code_ref $_ } @{array_ref $args{around}} if exists $args{around};
		@after  = map{ code_ref $_ } @{array_ref $args{after}}  if exists $args{after};

		@before = reverse @before; # last-defined-first-called

		my %props = (
			before      => \@before,
			around      => \@around,
			after       => \@after,
			original    => $code,
			current_ref => \$code,
		);

		#$code = curry($_, (my $tmp = $code), *_) for @around;
		for my $ar(@around){
			my $base = $code;
			$code = sub{ $ar->($base, @_) };
		}
		my($pkg, $file, $line, $hints, $bitmask) = (caller 0)[0, 1, 2, 8, 9];

		my $context = sprintf <<'END_CXT', $pkg, $line, $file;
BEGIN{ $^H = $hints; ${^WARNING_BITS} = $bitmask; }
package %s;
#line %s %s
END_CXT

		my $modified = eval $context . q{sub{
			$_->(@_) for @before;
			if(wantarray){ # list context
				my @ret = $code->(@_);
				$_->(@_) for @after;
				return @ret;
			}
			elsif(defined wantarray){ # scalar context
				my $ret = $code->(@_);
				$_->(@_) for @after;
				return $ret;
			}
			else{ # void context
				$code->(@_);
				$_->(@_) for @after;
				return;
			}
		}} or die $@;

		$initializer->() if $initializer;

		$modifiers{$modified} = \%props;
		return $modified;
	}

	my %valid_modifiers = map{ $_ => undef } qw(before around after original);

	sub subroutine_modifier{
		my $modified = code_ref shift;

		my $props_ref = $modifiers{$modified};

		unless(@_){ # subroutine_modifier($subr) - only checking
			return defined $props_ref;
		}
		unless($props_ref){ # otherwise, it should be modified subroutines
			_fail('a modified subroutine', $modified);
		}

		my($name, @subs) = @_;
		(is_string($name) && exists $valid_modifiers{$name}) or _fail('a modifier property', $name);


		if($name eq 'original'){
			if(@subs){
				_croak('Cannot reset the original subroutine');
			}
			return $props_ref->{$name};
		}
		else{ # before, around, after
			my $property = $props_ref->{$name};
			if(@subs){
				if($name eq 'before'){
					unshift @{$property}, reverse map{ code_ref $_ } @subs;
				}
				else{
					push @{$property}, map{ code_ref $_ } @subs;
				}

				if($name eq 'around'){
					my $current_ref = $props_ref->{current_ref};
					for my $ar(@subs){
						my $base = $$current_ref;
						$$current_ref = sub{ $ar->($base, @_) };
					}
				}
			}
			return @{$property} if defined wantarray;
		}

		return;
	}
}
#
# mkopt() and mkopt_hash() are originated from Data::OptList
#

my %test_for = (
	CODE   => \&is_code_ref,
	HASH   => \&is_hash_ref,
	ARRAY  => \&is_array_ref,
	SCALAR => \&is_scalar_ref,
	GLOB   => \&is_glob_ref,
);


sub __is_a {
	my ($got, $expected) = @_;

	return scalar grep{ __is_a($got, $_) } @{$expected} if ref $expected;

	my $t = $test_for{$expected};
	return defined($t) ? $t->($got) : is_instance($got, $expected);
}

sub mkopt{
	my($opt_list, $moniker, $require_unique, $must_be) = @_;

	return [] unless $opt_list;

	$opt_list = [
		map { $_ => (ref $opt_list->{$_} ? $opt_list->{$_} : ()) } keys %$opt_list
	] if is_hash_ref($opt_list);

	my @return;
	my %seen;

	my $vh = is_hash_ref($must_be);
	my $validator = $must_be;

	if(defined($validator) && (!$vh && !is_array_ref($validator) && !is_string($validator))){
		_fail('a type name, or ARRAY or HASH reference', $validator);
	}

	for(my $i = 0; $i < @$opt_list; $i++) {
		my $name = $opt_list->[$i];
		my $value;

		if($require_unique && $seen{$name}++) {
			_croak("Validation failed: Multiple definitions provided for $name in $moniker opt list")
		}

		if   ($i == $#$opt_list)             { $value = undef;            }
		elsif(not defined $opt_list->[$i+1]) { $value = undef; $i++       }
		elsif(ref $opt_list->[$i+1])         { $value = $opt_list->[++$i] }
		else                                 { $value = undef;            }

		if (defined $value and defined( $vh ? ($validator = $must_be->{$name}) : $validator )){
			unless(__is_a($value, $validator)) {
				_croak("Validation failed: ".ref($value)."-ref values are not valid for $name in $moniker opt list");
			}
		}

		push @return, [ $name => $value ];
	}

	return \@return;
}

sub mkopt_hash {
	my($opt_list, $moniker, $must_be) = @_;
	return {} unless $opt_list;

	my %hash = map { $_->[0] => $_->[1] } @{ mkopt($opt_list, $moniker, 1, $must_be) };
	return \%hash;
}

1;
__END__

=head1 NAME

Data::Util::PurePerl - The Pure Perl backend for Data::Util

=head1 DESCRIPTION

This module is a backend for C<Data::Util>.

Don't use this module directly; C<use Data::Util> instead.

=cut
