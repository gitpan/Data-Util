#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "mro_compat.h"
#include "str_util.h"

#if PERL_REVISION == 5 && PERL_VERSION >= 10
#define HAS_LEXICAL_HH
#endif


#define my_SvNIOK(sv) (SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVp_IOK|SVp_NOK))


#define MY_CXT_KEY "Data::Util::_guts" XS_VERSION


typedef struct{
	GV* universal_isa;

	UV ins_depth;

	GV* error_handler;
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
	T_RE,
	T_OBJECT
} my_ref_t;


#define neat(x) my_neat(aTHX_ x)
static const char*
my_neat(pTHX_ SV* x){
	if(SvROK(x)){
		x = SvRV(x);

		if(SvOBJECT(x)){
			return Perl_form(aTHX_ "%s=%s(0x%p)",
				sv_reftype(x, TRUE), sv_reftype(x, FALSE), x);
		}
		else{
			return Perl_form(aTHX_ "%s(0x%p)", sv_reftype(x, FALSE), x);
		}
	}
	else if(SvOK(x)){
		if(my_SvNIOK(x)){
			return Perl_form(aTHX_ "%"NVgf, SvNV(x));
		}
		else{
			STRLEN cur;
			char* const pv = SvPV(x, cur);
			static const STRLEN pvlim = 15;
			SV* dsv = newSV(pvlim + 5);

			sv_2mortal(dsv);

			return pv_display(dsv, pv, cur, cur, pvlim);
		}
	}
	else if(SvTYPE(x) == SVt_PVGV){
		return SvPV_nolen_const(x);
	}

	return "undef";
}

static void
my_croak(pTHX_ const char* const fmt, ...){
	dMY_CXT;
	SV* handler = GvSV(MY_CXT.error_handler);

	va_list args;
	va_start(args, fmt);

	if(handler && SvOK(handler)){
		SV* mess;
		HV* stash;
		GV* gv;
		CV* cv;
		dSP;

		SAVETMPS;
		ENTER;

		cv = sv_2cv(handler, &stash, &gv, FALSE);

		mess = vnewSVpvf(fmt, &args);
		sv_2mortal(mess);


		PUSHMARK(SP);
		PUSHs(mess);
		PUTBACK;

		call_sv((SV*)cv, G_SCALAR);

		sv_setsv(ERRSV, POPs);
		Perl_croak(aTHX_ NULL);

		FREETMPS;
		LEAVE;

	}
	else{
		vcroak(fmt, &args);
	}
	va_end(args);
}

static inline void*
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
		return NULL;
	}

	return amt->table[o];
}

static bool
my_ref_type(pTHX_ SV* const sv, const my_ref_t t){
	if(!SvROK(sv)){
		return FALSE;
	}

	if(SvOBJECT(SvRV(sv))){
		if(SvAMAGIC(sv) && has_amagic_converter(aTHX_ sv, t)){
			return TRUE;
		}
		else if(t == T_RE && mg_find(SvRV(sv), PERL_MAGIC_qr)){
			return TRUE;
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

	cxt->error_handler = gv_fetchpv("Data::Util::ErrorHandler", TRUE, SVt_PV);
	SvREFCNT_inc_simple_void_NN(cxt->error_handler);
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
	is_regex_ref  = T_RE
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
	regex_ref  = T_RE
PPCODE:
	SvGETMAGIC(x);
	if(my_ref_type(aTHX_ x, (my_ref_t)ix)){
		XSRETURN(1); /* return the first value */
	}
	my_croak(aTHX_ "Validation for %s failed with value %s",
		GvNAME(CvGV(cv)), neat(x));

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
	/* else */
	my_croak(aTHX_ "Validation for %s failed with value %s",
		SvPV_nolen_const(klass), neat(x));


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

bool
is_method(code)
	CV* code
CODE:
	RETVAL = CvMETHOD(code);
OUTPUT:
	RETVAL

void
set_method_attribute(code, is_method)
	CV* code
	bool is_method
CODE:
	is_method ? CvMETHOD_on(code) : CvMETHOD_off(code);

