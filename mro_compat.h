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
#define mro_get_linear_isa(stash) my_mro_get_linear_isa_dfs(aTHX_ stash)

AV* my_mro_get_linear_isa_dfs(pTHX_ HV* stash);

#define USE_MRO_COMPAT

#endif
