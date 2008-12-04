/*
----------------------------------------------------------------------------

    mro_compat.h - Provides mro functions for XS

    Automatically created by Devel::MRO/0.01_001, running under perl 5.10.0

    Copyright (c) 2008, Goro Fuji <gfuji(at)cpan.org>.

    This program is free software; you can redistribute it and/or
    modify it under the same terms as Perl itself.

----------------------------------------------------------------------------

Privides:
	AV*  mro_get_linear_isa(HV* stash)
	UV   mro_get_pkg_gen(HV* stash)
	void mro_method_changed_in(HV* stash)

    See "perldoc mro" for details.


 */

#ifndef mro_get_linear_isa
#define NEED_MRO_COMPAT

#define mro_get_linear_isa(stash) my_mro_get_linear_isa(aTHX_ stash)
AV* my_mro_get_linear_isa(pTHX_ HV* const stash);

#define mro_method_changed_in(stash) ((void)PL_sub_generation++)

#ifndef mro_get_pkg_gen
#define mro_get_pkg_gen(stash) (PL_sub_generation)
#endif

#else /* !mro_get_linear_isa */

#ifndef mro_meta_init /* missing in 5.10.0 */
#define mro_meta_init(stash) Perl_mro_meta_init(aTHX_ stash)
#endif

#ifndef mro_get_pkg_gen
#define mro_get_pkg_gen(stash) (HvMROMETA(stash)->pkg_gen)
#endif

#endif /* mro_get_linear_isa */
