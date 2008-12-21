/*
	Data-Util/subs.c

	XS code templates for curry() and modify_subroutine()
*/
#include "data-util.h"

MGVTBL curried_vtbl;
MGVTBL modified_vtbl;

MAGIC*
my_mg_find_by_vtbl(pTHX_ SV* const sv, const MGVTBL* const vtbl){
	MAGIC* mg;
	for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
		if(mg->mg_virtual == vtbl){
			break;
		}
	}
	return mg;
}

XS(XS_Data__Util_curried){
	dVAR; dXSARGS;
	MAGIC* const mg = mg_find_by_vtbl((SV*)cv, &curried_vtbl);
	assert(mg);

	SP -= items;
	/*
	  NOTE:
	  Curried subroutines have two properties, "args" and "pls"(placeholders).
	  Geven a curried subr created by "curry(\&f, $x, *_, $y, \0)":
		args: [   $x, undef,    $y, undef]
		pls:  [undef,    *_, undef,     0]

	  Here the curried subr is called with arguments.
	  Firstly, the arguments are set to args, expanding subscriptive placeholders,
	  but the placeholder "*_" is set to the end of args.
	  	args: [   $x,      undef,    $y, $_[0], @_[1 .. $#_] ]
	  Then, args are pushed into SP, expanding "*_".
		SP:   [   $x, @_[1..$#_],    $y, $_[0] ]
	  Finally, args are cleand up.
	  	args: [   $x,      undef,    $y, undef ]
	*/
	{
		AV* const args         = (AV*)mg->mg_obj;
		SV**      args_ary     = AvARRAY(args);
		I32 const len          = AvFILLp(args) + 1;

		AV* const pls          = (AV*)mg->mg_ptr; /* placeholders */
		SV**const pls_ary      = AvARRAY(pls);

		I32  maxp              = -1;
		SV** expanded          = NULL; // indicates *_

		I32 const is_method    = XSANY.any_i32;
		I32 const start_idx    = is_method ? 2 : 1;
		I32 push_size          = len - 1; /* -1: proc */
		I32 i;
		SV* proc;

		/* fill in args */
		for(i = 0; i < len; i++){
			SV* const sv = pls_ary[i];

			if(isGV(sv)){ /* symbolic placeholder *_ */
				if(!expanded){
					I32 j;

					av_extend(args, len + items);
					args_ary = AvARRAY(args); /* maybe realloc()-ed */

					/* 
					   All the arguments @_ is pushed into the end of args,
					   not calling SvREFCNT_inc().
					*/

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
			else if(SvIOKp(sv)){ /* subscriptive placeholders */
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
			if(isGV(pls_ary[i])){
				PUSHary(args_ary, len + (maxp+1), len + items);
			}
			else{
				PUSHs(args_ary[i]);
			}
		}
		PUTBACK;

		/* NOTE: need to clean up args before call_sv(), because call_sv() might die */
		for(i = 0; i < len; i++){
			if(SvIOKp(pls_ary[i])){
				/* NOTE: no need to SvREFCNT_dec(args_ary[i]) */
				args_ary[i] = &PL_sv_undef;
			}
		}

		call_sv(proc, GIMME_V | is_method);
	}
}

/* call an av of cv with args_ary */
static void
my_call_av(pTHX_ AV* const subs, SV** const args_ary, I32 const args_len){
	I32 const subs_len = AvFILLp(subs) + 1;
	I32 i;

	for(i = 0; i < subs_len; i++){
		dSP;

		PUSHMARK(SP);
		XPUSHary(args_ary, 0, args_len);
		PUTBACK;

		call_sv(AvARRAY(subs)[i], G_VOID | G_DISCARD);
	}
}

XS(XS_Data__Util_modified){
	dVAR; dXSARGS;
	MAGIC* const mg = mg_find_by_vtbl((SV*)cv, &modified_vtbl);
	assert(mg);

	SP -= items;
	{
		AV* const subs_av = (AV*)mg->mg_obj;
		AV* const before  = (AV*)AvARRAY(subs_av)[M_BEFORE];
		SV* const current = (SV*)AvARRAY(subs_av)[M_CURRENT];
		AV* const after   = (AV*)AvARRAY(subs_av)[M_AFTER];
		I32 i;

		dXSTARG;
		AV* const args = (AV*)TARG;
		SV** args_ary;
		SvUPGRADE(TARG, SVt_PVAV);

		av_extend(args, items - 1);
		args_ary = AvARRAY(args);

		for(i = 0; i < items; i++){
			args_ary[i] = ST(i); /* no need to SvREFCNT_inc() */
		}

		my_call_av(aTHX_ before, args_ary, items);

		PUSHMARK(SP);
		XPUSHary(args_ary, 0, items);
		PUTBACK;

		call_sv(current, GIMME_V);

		my_call_av(aTHX_ after, args_ary, items);
	}
	/* Don't XSRETURN(n) */
}
