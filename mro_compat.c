/*
 *   mro_compat.c - provides mro functions for 5.8.x
 */
#include "mro_compat.h"

#ifdef NEED_MRO_COMPAT

#define ISA_CACHE "::LINEALIZED_ISA_CACHE::"

AV*
my_mro_get_linear_isa(pTHX_ HV* const stash){
	GV* const cachegv = *(GV**)hv_fetchs(stash, ISA_CACHE, TRUE);
	AV* isa;
	SV* gen;
	CV* get_linear_isa;

	if(!isGV(cachegv))
		gv_init(cachegv, stash, ISA_CACHE, sizeof(ISA_CACHE)-1, TRUE);

	isa = GvAVn(cachegv);
	gen = GvSVn(cachegv);

	if(SvIOK(gen) && SvIVX(gen) == (IV)mro_get_pkg_gen(stash)){
		return isa; /* returns the cache if available */
	}
	else{
		SvREADONLY_off(isa);
		av_clear(isa);
	}

	get_linear_isa = get_cv("mro::get_linear_isa", FALSE);
	if(!get_linear_isa){
		ENTER;
		SAVETMPS;

		Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT, newSVpvs("MRO::Compat"), NULL, NULL);
		get_linear_isa = get_cv("mro::get_linear_isa", TRUE);

		FREETMPS;
		LEAVE;
	}

	{
		SV* avref;
		dSP;

		ENTER;
		SAVETMPS;

		PUSHMARK(SP);
		mXPUSHp(HvNAME(stash), strlen(HvNAME(stash)));
		PUTBACK;

		call_sv((SV*)get_linear_isa, G_SCALAR);

		SPAGAIN;
		avref = POPs;
		PUTBACK;

		if(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV){
			AV* const av  = (AV*)SvRV(avref);
			I32 const len = AvFILLp(av) + 1;
			I32 i;
			sv_setiv(gen, (IV)mro_get_pkg_gen(stash));

			for(i = 0; i < len; i++){
				HV* const stash = gv_stashsv(AvARRAY(av)[i], FALSE);
				if(stash)
					av_push(isa, newSVpv(HvNAME(stash), 0));
			}
			SvREADONLY_on(isa);
		}
		else{
			Perl_croak(aTHX_ "mro::get_linear_isa() didn't return an ARRAY reference");
		}

		FREETMPS;
		LEAVE;
	}
	return GvAV(cachegv);
}


#endif /* !NEED_MOR_COMPAT */