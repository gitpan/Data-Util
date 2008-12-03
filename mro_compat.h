/*
 *   mro_compat.h - provides mro functions for 5.8.x

 	AV*  mro_get_linear_isa(stash)
 	void mro_method_changed_in(stash)
 	UV   mro_get_pkg_gen(stash)
 */

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#ifndef GvSVn
#define GvSVn(x) GvSV(x)
#endif

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
