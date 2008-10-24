/*
 *   mro_compat.c - provides mro_get_linear_isa() using DFS algorithm
 */


#include "mro_compat.h"
#include "str_util.h"

#ifdef USE_MRO_COMPAT

#define ISA_CACHE "::LINEAR_ISA_DFS::CACHE::"

static void
my_dfs(pTHX_ const char* const name, HV* stash, AV* retval, int level){
	GV** const gvp = (GV**)hv_fetchs(stash, "ISA", FALSE);
	AV* isa_av;

	if(level > 100){
		Perl_croak(aTHX_ "Recursive inheritance detected in package '%s'",
			name);
	}

	if(gvp && (isa_av = GvAV(*gvp))){
		const I32 len = AvFILLp(isa_av) + 1;
		I32 i;

		for(i = 0; i < len; i++){
			SV* const base_sv    = AvARRAY(isa_av)[i];
			HV* const base_stash = gv_stashsv(base_sv, FALSE);
			const char* const base_name = base_stash ? HvNAME(base_stash) : SvPV_nolen_const(base_sv);
			SV* sv = newSVpv(base_name, 0);

			if(SvUTF8(base_sv)){
				SvUTF8_on(sv);
			}
			av_push(retval, sv);

			if(base_stash)
				my_dfs(aTHX_ name, base_stash, retval, level+1);
		}
	}
}

AV*
my_mro_get_linear_isa_dfs(pTHX_ HV* stash){
	GV* const gv = *(GV**)hv_fetchs(stash, ISA_CACHE, TRUE);
	AV* retval;
	SV* subgen;

	if(SvTYPE(gv) != SVt_PVGV)
		gv_init(gv, stash, ISA_CACHE, sizeof(ISA_CACHE)-1, TRUE);

	retval = GvAVn(gv);
	subgen = GvSVn(gv);

	if(SvIOK(subgen) && SvIVX(subgen) == (IV)PL_sub_generation){
		return retval;
	}
	else{
		sv_setiv(subgen, (IV)PL_sub_generation);
		av_clear(retval);
	}

	av_push(retval, newSVpv(HvNAME(stash), 0));
	my_dfs(aTHX_ HvNAME(stash), stash, retval, 0);

	return retval;
}


#endif
