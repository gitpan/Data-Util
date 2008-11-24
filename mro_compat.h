/*
 *   mro_compat.h - provides mro_get_linear_isa() using DFS algorithm
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
#define USE_MRO_COMPAT

#define mro_get_linear_isa(stash) my_mro_get_linear_isa_dfs(aTHX_ stash)
AV* my_mro_get_linear_isa_dfs(pTHX_ HV* const stash);

#define mro_method_changed_in(statsh) my_mro_method_changed_in(aTHX_ stash)
void my_mro_method_changed_in(pTHX_ HV* const stash);

#endif /* !mro_get_linear_isa */

