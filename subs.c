/*
	Data-Util/subs.c
*/

#include "data-util.h"

extern MGVTBL curried_vtbl;
extern MGVTBL wrapped_vtbl;





XS(XS_Data__Util_curried){
	dVAR; dXSARGS;
	MAGIC* const mg = mg_find((SV*)cv, PERL_MAGIC_ext);

	assert(mg);
	assert(mg->mg_virtual == &curried_vtbl);

	SP -= items;
	/*
		args: [    x,     y, undef,     z , @_ ]
		pls:  [undef, undef,    *_, undef]

		->
		SP:   [    x,     y,    @_,     z]
	*/
	{
		AV* const args         = (AV*)mg->mg_obj;
		SV**      args_ary     = AvARRAY(args);
		I32 const len          = AvFILLp(args) + 1;

		AV* const pls          = (AV*)mg->mg_ptr; /* placeholders */
		SV**const pls_ary      = AvARRAY(pls);

		I32  maxp              = -1;
		SV** expanded          = NULL; // expanded *_

		I32 const is_method    = XSANY.any_i32;
		I32 const start_idx    = is_method ? 2 : 1;
		I32 push_size          = len - 1; /* -1: proc */
		I32 i;
		SV* proc;

		/* fill in args */
		for(i = 0; i < len; i++){
			SV* const sv = pls_ary[i];
			if(SvIOK(sv)){ /* subscriptive placeholder */
				IV p = SvIVX(sv);
				if(p < 0) p += items + 1;

				if(p >= 0 && p <= items){
					/* NOTE: no need to SvREFCNT_inc(args_ary[i]),
					 *       because it removed from args_ary before call_sv()
					 */
					args_ary[i] = ST(p);
				}

				if(p > maxp) maxp = p;
			}
			else if(SvTYPE(sv) == SVt_PVGV){ // *_
				if(!expanded){
					I32 j;

					/* 
					   Arguments @_ is pushed into the end of args,
					   not calling SvREFCNT_inc().
					*/

					av_extend(args, len + items); /* realloc */
					args_ary = AvARRAY(args);

					expanded = &args_ary[len];
					for(j = 0; j < items; j++){
						/* NOTE: no need to SvREFCNT_inc(ST(j)),
						*  bacause AvFILLp(args) remains len-1.
						*  That's okey.
						*/
						expanded[j] = ST(j);
					}
				}
				push_size += items;
			}
		}

		PUSHMARK(SP);
		EXTEND(SP, push_size);

		if(is_method){
			PUSHs( args_ary[0] ); /* invocant */
			proc = args_ary[1];   /* method */
		}
		else{
			proc = args_ary[0];  /* code ref */
		}

		for(i = start_idx; i < len; i++){
			if(SvTYPE(pls_ary[i]) == SVt_PVGV){
				PUSHav(args, len + (maxp+1), len + items);
			}
			else{
				PUSHs(args_ary[i]);
			}
		}
		PUTBACK;

		/* NOTE: need to clean up args before call_sv(), because call_sv() might die */
		for(i = 0; i < len; i++){
			if(SvIOK(pls_ary[i])){
				/* NOTE: no need to SvREFCNT_dec(args_ary[i]) */
				args_ary[i] = &PL_sv_undef;
			}
		}

		call_sv(proc, GIMME_V | is_method);
	}
}

static void
my_call_av(pTHX_ AV* const subs, AV* const args){
	const I32 subs_len = AvFILLp(subs) + 1;
	const I32 args_len = AvFILLp(args) + 1;
	I32 i;
	dSP;

	for(i = 0; i < subs_len; i++){
		PUSHMARK(SP);
		XPUSHav(args, 0, args_len);
		PUTBACK;

		call_sv(AvARRAY(subs)[i], G_VOID | G_DISCARD);
	}
}

XS(XS_Data__Util_wrapped){
	dVAR; dXSARGS;
	MAGIC* mg = mg_find((SV*)cv, PERL_MAGIC_ext);

	assert(mg);
	assert(mg->mg_virtual == &wrapped_vtbl);

	SP -= items;
	{
		AV* const subs_av = (AV*)mg->mg_obj;
		AV* const before  = (AV*)AvARRAY(subs_av)[M_BEFORE];
		SV* const current = (SV*)AvARRAY(subs_av)[M_CURRENT];
		AV* const after   = (AV*)AvARRAY(subs_av)[M_AFTER];
		dXSTARG;
		AV* const args = (AV*)TARG;
		I32 i;
		SvUPGRADE(TARG, SVt_PVAV);

		av_extend(args, items - 1);
		for(i = 0; i < items; i++){
			AvARRAY(args)[i] = ST(i); /* no need to SvREFCNT_inc() */
		}

		my_call_av(aTHX_ before, args);

		PUSHMARK(SP);
		XPUSHav(args, 0, items);
		PUTBACK;

		call_sv(current, GIMME_V);

		my_call_av(aTHX_ after, args);
	}
	/* Don't XSRETURN(n) */
}
