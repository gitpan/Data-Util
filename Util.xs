#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "c99portability.h"

#include "mro_compat.h"
#include "str_util.h"

#define my_SvNIOK(sv) (SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVp_IOK|SVp_NOK))

#ifndef SvRXOK
#define SvRXOK(sv) ((bool)(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG) && mg_find(SvRV(sv), PERL_MAGIC_qr)))
#endif


#define MY_CXT_KEY "Data::Util::_guts" XS_VERSION


typedef struct{
	GV* universal_isa;

	CV* default_fail_handler;
	HV* fail_handler_map;
} my_cxt_t;
START_MY_CXT;


typedef enum{
	T_NOT_REF,
	T_SV,
	T_AV,
	T_HV,
	T_CV,
	T_GV,
	T_IO,
	T_FM,
	T_RX,
	T_OBJECT
} my_ref_t;

static const char* const ref_names[] = {
	NULL, /* NOT_REF */
	"a SCALAR",
	"an ARRAY",
	"a HASH",
	"a CODE",
	"a GLOB",
	NULL, /* IO */
	"a FORMAT",
	NULL, /* RE */
	NULL  /* OBJECT */
};


#define neat(x) my_neat(aTHX_ x)
static void
my_neat_cat(pTHX_ SV* dsv, SV* x, int level){

	if(level > 2){
		sv_catpvs(dsv, "...");
		return;
	}

	if(SvROK(x)){
		x = SvRV(x);

		if(SvOBJECT(x)){
			Perl_sv_catpvf(aTHX_ dsv, "%s=%s(0x%p)",
				sv_reftype(x, TRUE), sv_reftype(x, FALSE), x);
			return;
		}
		else if(SvTYPE(x) == SVt_PVAV){
			SV** svp;
			I32 len = av_len((AV*)x);

			sv_catpvs(dsv, "[");
			if(len >= 0){
				svp = av_fetch((AV*)x, 0, FALSE);

				if(*svp){
					my_neat_cat(aTHX_ dsv, *svp, level+1);
				}
				else{
					sv_catpvs(dsv, "undef");
				}
				if(len > 0){
					sv_catpvs(dsv, ", ...");
				}
			}
			sv_catpvs(dsv, "]");
		}
		else if(SvTYPE(x) == SVt_PVHV){
			I32 klen;
			char* key;
			SV* val;

			hv_iterinit((HV*)x);
			val = hv_iternextsv((HV*)x, &key, &klen);

			sv_catpvs(dsv, "{");
			if(val){
				bool need_quote = TRUE;
				if(isIDFIRST(*key)){
					const char* k   = key;
					const char* end = key + klen - 1 /*'\0'*/;

					need_quote = FALSE;
					while(k != end){
						++k;
						if(!isALNUM(*k)){
							need_quote = TRUE;
							break;
						}
					}
				}
				if(need_quote){
					SV* sv = newSV(klen + 5);
					sv_2mortal(sv);
					key = pv_display(sv, key, klen, klen, klen);
				}
				Perl_sv_catpvf(aTHX_ dsv, "%s => ", key);
				my_neat_cat(aTHX_ dsv, val, level+1);

				if(hv_iternext((HV*)x)){
					sv_catpvs(dsv, ", ...");
				}
			}

			sv_catpvs(dsv, "}");
		}
		else{
			Perl_sv_catpvf(aTHX_ dsv, "%s(0x%p)", sv_reftype(x, FALSE), x);
		}
	}
	else if(SvTYPE(x) == SVt_PVGV){
		sv_catsv(dsv, x);
	}
	else if(SvOK(x)){
		if(my_SvNIOK(x)){
			Perl_sv_catpvf(aTHX_ dsv, "%"NVgf, SvNV(x));
		}
		else{
			STRLEN cur;
			char* const pv = SvPV(x, cur);
			static const STRLEN pvlim = 15;
			SV* sv = newSV(pvlim + 5);
			sv_2mortal(sv);
			pv_display(sv, pv, cur, cur, pvlim);
			sv_catsv(dsv, sv);
		}
	}
	else{
		sv_catpvs(dsv, "undef");
	}
}

static const char*
my_neat(pTHX_ SV* x){
	SV* const dsv = newSV(100);
	sv_2mortal(dsv);
	sv_setpvs(dsv, "");

	ENTER;

	my_neat_cat(aTHX_ dsv, x, 0);

	LEAVE;

	return SvPVX(dsv);
}

static void
my_croak(pTHX_ const char* const fmt, ...){
	dMY_CXT;
	SV* handler;
	SV** svp = NULL;

	const char* stashpv;

	SV* mess;
	dSP;

	va_list args;
	va_start(args, fmt);

	assert(PL_curcop != NULL);
	stashpv = CopSTASHPV(PL_curcop);
	assert(stashpv != NULL);

	if(!MY_CXT.fail_handler_map){
		MY_CXT.fail_handler_map = newHV();
	}
	svp = hv_fetch(MY_CXT.fail_handler_map,
		stashpv, strlen(stashpv), FALSE);
	if(svp){
		assert(SvRV(*svp));
		handler = SvRV(*svp);
	}
	else{
		handler = (SV*)MY_CXT.default_fail_handler; /* \&Carp::confess */
	}

	assert(handler != NULL);
	assert(SvTYPE(handler) == SVt_PVCV);

	SAVETMPS;
	ENTER;

	mess = vnewSVpvf(fmt, &args);
	sv_2mortal(mess);

	PUSHMARK(SP);
	PUSHs(mess);
	PUTBACK;

	call_sv(handler, G_SCALAR);

	/* when the handler returned */
	sv_setsv(ERRSV, POPs);
	Perl_croak(aTHX_ NULL); /* re-throw */

	/* not reached */
	FREETMPS;
	LEAVE;

	va_end(args);
}

static bool
has_amagic_converter(pTHX_ SV* const sv, const my_ref_t t){
	const AMT* const amt = (AMT*)mg_find((SV*)SvSTASH(SvRV(sv)), PERL_MAGIC_overload_table)->mg_ptr;
	int o = 0;

	assert(amt);
	assert(AMT_AMAGIC(amt));

	switch(t){
	case T_SV:
		o = to_sv_amg;
		break;
	case T_AV:
		o = to_av_amg;
		break;
	case T_HV:
		o = to_hv_amg;
		break;
	case T_CV:
		o = to_cv_amg;
		break;
	case T_GV:
		o = to_gv_amg;
		break;
	default:
		return FALSE;
	}

	return !!amt->table[o];
}

static inline bool
my_ref_type(pTHX_ SV* const sv, const my_ref_t t){
	if(!SvROK(sv)){
		return FALSE;
	}

	if(SvOBJECT(SvRV(sv))){
		if(t == T_RX){ /* regex? */
			return SvRXOK(sv);
		}
		if(SvAMAGIC(sv)){
			return has_amagic_converter(aTHX_ sv, t);
		}
		else{
			return FALSE;
		}
	}


	switch(SvTYPE(SvRV(sv))){
	case SVt_PVAV: return T_AV == t;
	case SVt_PVHV: return T_HV == t;
	case SVt_PVCV: return T_CV == t;
	case SVt_PVGV: return T_GV == t;
#if 0 /* IO is always SvOBJECT */
	case SVt_PVIO: return T_IO == t;
#endif
	case SVt_PVFM: return T_FM == t;
	default:       NOOP;
	}

	return T_SV == t;
}


#define canon_pkg(x)  my_canon_pkg(aTHX_ x)
static inline const char*
my_canon_pkg(pTHX_ const char* name){
/*
	HV* stash = gv_stashpvn(name, strlen(name), FALSE);
	return stash ? HvNAME(stash) : name;
*/
	/* ""  -> "main" */
	if(name[0] == '\0'){
		return "main";
	}

	/* "::Foo" -> "Foo" */
	if(name[0] == ':' && name[1] == ':'){
		name += 2;
	}

	/* "main::main::main::Foo" -> "Foo" */
	while(strnEQ(name, "main::", sizeof("main::")-1)){

		name += sizeof("main::")-1;
	}

	return name;
}

#define isa_lookup(x, y) my_isa_lookup(aTHX_ x, y)

static int
my_isa_lookup(pTHX_ HV* const stash, const char* klass_name){
	const char* const stash_name = canon_pkg(HvNAME(stash));

	klass_name = canon_pkg(klass_name);

	if(strEQ(stash_name, klass_name)){
		return TRUE;
	}
	else{
		AV*  const stash_linear_isa = mro_get_linear_isa(stash);
		SV**       svp = AvARRAY(stash_linear_isa) + 1; /* skip this class */
		SV** const end = svp + AvFILLp(stash_linear_isa); /* start + 1 + last index */

		while(svp != end){
			if(strEQ(klass_name, canon_pkg(SvPVX(*svp)))){
				return TRUE;
			}
			svp++;
		}
		return strEQ(klass_name, "UNIVERSAL");
	}
}

/* returns &PL_sv_yes or &PL_sv_no */
static SV*
instance_of(pTHX_ SV* const x, SV* const klass){
	dVAR;
	/* from pp_bless() in pp.c */
	if( !SvOK(klass) || (!SvGMAGICAL(klass) && !SvAMAGIC(klass) && SvROK(klass)) ){
		Perl_croak(aTHX_ "%s supplied as a class name", neat(klass));
	}

	if( !(SvROK(x) && SvOBJECT(SvRV(x))) ){
		return &PL_sv_no;
	}
	else{
		dSP;
		dMY_CXT;
		SV* retval;
		HV* const stash = SvSTASH(SvRV(x));
		GV* const isa   = gv_fetchmeth_autoload(stash, "isa", sizeof("isa")-1, 0 /* special zero, not flags */);

		if(isa == NULL || GvCV(isa) == GvCV(MY_CXT.universal_isa)){
			return boolSV( isa_lookup(stash, SvPV_nolen_const(klass)) );
		}

		/* call the specific isa() method */
		ENTER;
		SAVETMPS;

		PUSHMARK(SP);
		EXTEND(SP, 2);
		PUSHs(x);
		PUSHs(klass);
		PUTBACK;

		call_sv((SV*)isa, G_SCALAR);

		SPAGAIN;

		retval = boolSV( SvTRUE(TOPs) );
		POPs;

		PUTBACK;

		FREETMPS;
		LEAVE;

		return retval;
	}
}


static void
initialize_my_cxt(pTHX_ my_cxt_t* const cxt){
	cxt->universal_isa = CvGV(get_cv("UNIVERSAL::isa", GV_ADD));
	SvREFCNT_inc_simple_void_NN(cxt->universal_isa);

	cxt->default_fail_handler = get_cv("Carp::confess", TRUE);
	SvREFCNT_inc_simple_void_NN(cxt->default_fail_handler);

	cxt->fail_handler_map = NULL;
}



MODULE = Data::Util		PACKAGE = Data::Util

PROTOTYPES: DISABLE

BOOT:
{
	MY_CXT_INIT;
	initialize_my_cxt(aTHX_ &MY_CXT);
}

void
CLONE(...)
CODE:
	MY_CXT_CLONE;
	initialize_my_cxt(aTHX_ &MY_CXT);
	PERL_UNUSED_VAR(items);

void
is_scalar_ref(x)
	SV* x
ALIAS:
	is_scalar_ref = T_SV
	is_array_ref  = T_AV
	is_hash_ref   = T_HV
	is_code_ref   = T_CV
	is_glob_ref   = T_GV
	is_regex_ref  = T_RX
PPCODE:
	SvGETMAGIC(x);
	ST(0) = my_ref_type(aTHX_ x, (my_ref_t)ix) ?&PL_sv_yes : &PL_sv_no;
	XSRETURN(1);

void
scalar_ref(x)
	SV* x
ALIAS:
	scalar_ref = T_SV
	array_ref  = T_AV
	hash_ref   = T_HV
	code_ref   = T_CV
	glob_ref   = T_GV
	regex_ref  = T_RX
PPCODE:
	SvGETMAGIC(x);
	if(my_ref_type(aTHX_ x, (my_ref_t)ix)){
		XSRETURN(1); /* return the first value */
	}
	my_croak(aTHX_ "Validation failed: you must supply %s reference, not %s,",
		ref_names[ix], neat(x));

void
is_instance(x, klass)
	SV* x
	SV* klass
PPCODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	if( instance_of(aTHX_ x, klass) == &PL_sv_yes ){
		/* ST(0) = x; */
		XSRETURN(1);
	}

void
instance(x, klass)
	SV* x
	SV* klass
PPCODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	if( instance_of(aTHX_ x, klass) == &PL_sv_yes ){
		/* ST(0) = x; */
		XSRETURN(1);
	}
	my_croak(aTHX_ "Validation failed: you must supply an instance of %"SVf,
		klass, neat(x));

bool
fast_isa(sv, name)
	SV* sv
	const char* name
PREINIT:
	HV* stash;
CODE:
	if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))
		|| (SvGMAGICAL(sv) && SvPOKp(sv) && SvCUR(sv))))
		XSRETURN_UNDEF;
	
	SvGETMAGIC(sv);
	if (SvROK(sv)) {
		sv = SvRV(sv);
		if (strEQ(sv_reftype(sv, FALSE), name))
			XSRETURN_YES;

		stash = SvOBJECT(sv) ? SvSTASH(sv) : NULL;
	}
	else {
		stash = gv_stashsv(sv, FALSE);
	}
	RETVAL = stash ? isa_lookup(stash, name) : FALSE;
OUTPUT:
	RETVAL

SV*
anon_scalar(referent = undef)
CODE:
	RETVAL = newRV_noinc(items == 0 ? newSV(0) : newSVsv(ST(0)));
OUTPUT:
	RETVAL


const char*
neat(expr)
	SV* expr

HV*
get_stash(package_name)
	SV* package_name
CODE:
	RETVAL = gv_stashsv(package_name, FALSE);
	if(!RETVAL){
		XSRETURN_UNDEF;
	}
OUTPUT:
	RETVAL

SV*
_fail_handler(pkg, code = NULL)
	SV* pkg
	CV* code
PREINIT:
	dMY_CXT;
	STRLEN len;
	const char* pv = SvPV_const(pkg, len);
	SV** old;
CODE:
	if(!MY_CXT.fail_handler_map){
		MY_CXT.fail_handler_map = newHV();
	}
	old = hv_fetch(MY_CXT.fail_handler_map, pv, len, FALSE);
	if(code){
		hv_store(MY_CXT.fail_handler_map,
			pv, len, newRV_inc((SV*)code), 0U/*hash*/);
	}
	if(!old){
		XSRETURN_UNDEF;
	}
	RETVAL = *old;
	SvREFCNT_inc_simple_void_NN(RETVAL);
OUTPUT:
	RETVAL

