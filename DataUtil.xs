/* Data-Util/Util.xs */

#include "data-util.h"


#define MY_CXT_KEY "Data::Util::_guts" XS_VERSION

typedef struct{
	GV* universal_isa;

	GV* croak;
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



static void
my_croak(pTHX_ const char* const fmt, ...)
	__attribute__format__(__printf__, pTHX_1, pTHX_2);

static void
my_croak(pTHX_ const char* const fmt, ...){
	dMY_CXT;
	dSP;
	SV* message;
	va_list args;

	SAVETMPS;
	ENTER;

	if(!MY_CXT.croak){
		Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT, newSVpvs("Data::Util::Error"), NULL, NULL);
		MY_CXT.croak = CvGV(get_cv("Data::Util::Error::croak", GV_ADD));
		SvREFCNT_inc_simple_void_NN(MY_CXT.croak);
	}

	va_start(args, fmt);
	message = vnewSVpvf(fmt, &args);
	va_end(args);

	sv_2mortal(message);

	PUSHMARK(SP);
	XPUSHs(message);
	PUTBACK;

	call_sv((SV*)MY_CXT.croak, G_VOID);

	/* not reached */
	FREETMPS;
	LEAVE;
}


static bool
has_amagic_converter(pTHX_ SV* const sv, const my_ref_t t){
	const AMT* amt;
	int o = 0;

	if(!SvAMAGIC(sv)) return FALSE;

	amt = (AMT*)mg_find((SV*)SvSTASH(SvRV(sv)), PERL_MAGIC_overload_table)->mg_ptr;
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
		/* not reached */
		return FALSE;
	}

	return !!amt->table[o];
}

#define check_type(sv, t) my_check_type(aTHX_ sv, t)
static inline bool
my_check_type(pTHX_ SV* const sv, const my_ref_t t){
	if(!SvROK(sv)){
		return FALSE;
	}

	if(SvOBJECT(SvRV(sv))){
		if(t == T_RX){ /* regex? */
			return SvRXOK(sv);
		}
		else{
			return has_amagic_converter(aTHX_ sv, t);
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


#define deref_av(sv) my_deref_av(aTHX_ sv)
#define deref_hv(sv) my_deref_hv(aTHX_ sv)
#define deref_cv(sv) my_deref_cv(aTHX_ sv)
#define deref_gv(sv) my_deref_gv(aTHX_ sv)

static AV*
my_deref_av(pTHX_ SV* sv){
	if(has_amagic_converter(aTHX_ sv, T_AV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_av);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)){
		my_croak(aTHX_ "Not %s reference", ref_names[T_AV]);
	}
	return (AV*)SvRV(sv);
}
static HV*
my_deref_hv(pTHX_ SV* sv){
	if(has_amagic_converter(aTHX_ sv, T_HV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_hv);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)){
		my_croak(aTHX_ "Not %s reference", ref_names[T_HV]);
	}
	return (HV*)SvRV(sv);
}
static CV*
my_deref_cv(pTHX_ SV* sv){
	if(has_amagic_converter(aTHX_ sv, T_CV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_cv);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV)){
		my_croak(aTHX_ "Not %s reference", ref_names[T_CV]);
	}
	return (CV*)SvRV(sv);
}
#if 0
static GV*
my_deref_gv(pTHX_ SV* sv){
	if(has_amagic_converter(aTHX_ sv, T_GV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_gv);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVGV)){
		my_croak(aTHX_ "Not %s reference", ref_names[T_GV]);
	}
	return (GV*)SvRV(sv);
}
#endif

#define canon_pkg(x)  my_canon_pkg(aTHX_ x)
static inline const char*
my_canon_pkg(pTHX_ const char* name){
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
	else if(strEQ(klass_name, "UNIVERSAL")){
		return TRUE;
	}
	else{
		AV*  const stash_linear_isa = mro_get_linear_isa(stash);
		SV**       svp = AvARRAY(stash_linear_isa) + 1;   /* skip this class */
		SV** const end = svp + AvFILLp(stash_linear_isa); /* start + 1 + last index */

		while(svp != end){
			if(strEQ(klass_name, canon_pkg(SvPVX(*svp)))){
				return TRUE;
			}
			svp++;
		}
	}
	return FALSE;
}

/* returns &PL_sv_yes or &PL_sv_no */
static SV*
instance_of(pTHX_ SV* const x, SV* const klass){
	dVAR;
	if( !is_string(klass) ){
		my_croak(aTHX_ "Invalid %s %s supplied", "class name", neat(klass));
	}

	if( !(SvROK(x) && SvOBJECT(SvRV(x))) ){
		return &PL_sv_no;
	}
	else{
		dMY_CXT;
		HV* const stash = SvSTASH(SvRV(x));
		GV* const isa   = gv_fetchmeth_autoload(stash, "isa", sizeof("isa")-1, 0 /* special zero, not flags */);
		SV* retval;

		if(isa == NULL || GvCV(isa) == GvCV(MY_CXT.universal_isa)){
			return boolSV( isa_lookup(stash, SvPV_nolen_const(klass)) );
		}

		/* call their own isa() method */
		{
			dSP;
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
		}

		return retval;
	}
}

#define type_isa(sv, type) my_type_isa(aTHX_ sv, type)
static bool
my_type_isa(pTHX_ SV* const sv, SV* const type){
	const char* const typestr = SvPV_nolen_const(type);
	switch(typestr[0]){
	case 'S':
		if(strEQ(typestr, "SCALAR")){
			return check_type(sv, T_SV);
		}
		break;
	case 'A':
		if(strEQ(typestr, "ARRAY")){
			return check_type(sv, T_AV);
		}
		break;
	case 'H':
		if(strEQ(typestr, "HASH")){
			return check_type(sv, T_HV);
		}
		break;
	case 'C':
		if(strEQ(typestr, "CODE")){
			return check_type(sv, T_CV);
		}
		break;
	case 'G':
		if(strEQ(typestr, "GLOB")){
			return check_type(sv, T_GV);
		}
		break;
	}
	return instance_of(aTHX_ sv, type) == &PL_sv_yes;
}

static SV*
my_mkopt(pTHX_ SV* const opt_list, SV* const moniker, const bool require_unique, SV* must_be, const my_ref_t result_type){
	SV* ret;
	AV* opt_av = NULL;
	AV* result_av = NULL;
	HV* result_hv = NULL;

	I32 i;
	I32 len;
	HV* seen = NULL;
	HV* vhv = NULL; /* validator HV */
	AV* vav = NULL; /* validator AV */
	const bool with_validation = SvOK(must_be) ? TRUE : FALSE;

	if(result_type == T_AV){
		result_av = newAV();
		ret = (SV*)result_av;
	}
	else{
		result_hv = newHV();
		ret = (SV*)result_hv;
	}

	if(check_type(opt_list, T_HV)){
		HV* hv = deref_hv(opt_list);
		char* key;
		I32 keylen;
		SV* val;
		hv_iterinit(hv);
		opt_av = newAV();
		sv_2mortal((SV*)opt_av);

		while((val = hv_iternextsv(hv, &key, &keylen))){
			av_push(opt_av, newSVpvn(key, keylen));
			if(SvROK(val)){
				SvREFCNT_inc_simple_void_NN(val);
				av_push(opt_av, val);
			}
		}
	}
	else if(!SvOK(opt_list)){
		goto end;
	}
	else{
		opt_av = deref_av(opt_list);
	}


	if(require_unique){
		seen = newHV();
		sv_2mortal((SV*)seen);
	}

	if(with_validation){
		if(check_type(must_be, T_HV)){
			vhv = deref_hv(must_be);
		}
		else if(check_type(must_be, T_AV)){
			vav = deref_av(must_be);
		}
		else if(!is_string(must_be)){
			my_croak(aTHX_ "Validation failed: you must supply %s reference, not %s", "a type name, or ARRAY or HASH", neat(must_be));
		}
	}

	len = av_len(opt_av) + 1;
	for(i = 0; i < len; i++){
		SV* name = *av_fetch(opt_av, i, TRUE);
		SV* value;

		if(require_unique){
			HE* he = hv_fetch_ent(seen, name, TRUE, 0U);
			SV* count = hv_iterval(seen, he);
			if(SvTRUE(count)){
				my_croak(aTHX_ "Multiple definitions provided for %"SVf" in %"SVf" opt list", name, moniker);
			}
			sv_inc(count); /* count++ */
		}

		if( (i+1) == len ){ /* last */
			value = &PL_sv_undef;
		}
		else{
			value = *av_fetch(opt_av, i+1, TRUE);
			if(SvTYPE(value) == SVt_NULL){
				value = &PL_sv_undef;
				i++;
			}
			else if(SvROK(value)){
				i++;
			}
			else{
				value = &PL_sv_undef;
			}
		}

		if(with_validation && SvOK(value)){
			if(vhv){
				HE* he = hv_fetch_ent(vhv, name, FALSE, 0U);
				vav = NULL;
				if(he){
					SV* sv = hv_iterval(vhv, he);
					if(check_type(sv, T_AV)){
						vav = deref_av(sv);
					}
					else if(SvOK(sv)){
						must_be = sv;
					}
					else{
						goto store_pair;
					}
				}else{
					goto store_pair;
				}
			}

			if(vav){
				I32 j;
				const I32 l = av_len(vav)+1;
				for(j = 0; j < l; j++){
					if(type_isa(value, *av_fetch(vav, j, TRUE))){
						break;
					}
				}
				if(j == l) goto validation_failed;
			}
			else{
				if(!type_isa(value, must_be)){
					validation_failed:
					my_croak(aTHX_ "Validation failed: %s-ref values are not valid for %"SVf" in %"SVf" opt list",
						sv_reftype(SvRV(value), TRUE), name, moniker);
				}
			}
		}

		store_pair:
		if(result_type == T_AV){ /* push @result, [$name => $value] */
			AV* pair = newAV();
			av_store(pair, 0, newSVsv(name));
			av_store(pair, 1, newSVsv(value));
			av_push(result_av, newRV_noinc((SV*)pair));
		}
		else{ /* $result{$name} = $value */
			hv_store_ent(result_hv, name, newSVsv(value), 0U);
		}
	}

	end:
	return newRV_noinc(ret);
}

static void
initialize_my_cxt(pTHX_ my_cxt_t* const cxt){
	cxt->universal_isa = CvGV(get_cv("UNIVERSAL::isa", GV_ADD));
	SvREFCNT_inc_simple_void_NN(cxt->universal_isa);

	cxt->croak = NULL;
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
CODE:
	SvGETMAGIC(x);
	ST(0) = boolSV(check_type(x, (my_ref_t)ix));
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
CODE:
	SvGETMAGIC(x);
	if(check_type(x, (my_ref_t)ix)){
		XSRETURN(1); /* return the first value */
	}
	my_croak(aTHX_ "Validation failed: you must supply %s reference, not %s,",
		ref_names[ix], neat(x));

void
is_instance(x, klass)
	SV* x
	SV* klass
CODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	ST(0) = instance_of(aTHX_ x, klass);
	XSRETURN(1);

void
instance(x, klass)
	SV* x
	SV* klass
CODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	if( instance_of(aTHX_ x, klass) == &PL_sv_yes ){
		XSRETURN(1); /* return $_[0] */
	}
	my_croak(aTHX_ "Validation failed: you must supply an instance of %"SVf", not %s",
		klass, neat(x));

void
invocant(x)
	SV* x
ALIAS:
	is_invocant = 0
	invocant    = 1
PREINIT:
	bool result;
CODE:
	SvGETMAGIC(x);
	if(SvROK(x)){
		result = SvOBJECT(SvRV(x)) ? TRUE : FALSE;
	}
	else if(SvOK(x)){
		result = gv_stashsv(x, FALSE) ? TRUE : FALSE;
	}
	else{
		result = FALSE;
	}
	if(ix == 0){ /* is_invocant() */
		ST(0) = boolSV(result);
		XSRETURN(1);
	}
	else{ /* invocant() */
		if(result){ /* XXX: do{ package ::Foo; ::Foo->something; } causes an fatal error */
			dXSTARG;
			sv_setsv(TARG, x); /* copy the pv and flags */
			sv_setpv(TARG, canon_pkg(SvPV_nolen_const(x)));
			ST(0) = TARG;
			XSRETURN(1);
		}
		my_croak(aTHX_ "Validation failed: you must supply an invocant, not %s", neat(x));
	}


HV*
get_stash(package_name)
	SV* package_name
CODE:
	SvGETMAGIC(package_name);
	if(is_string(package_name)){
		RETVAL = gv_stashsv(package_name, FALSE);
	}
	else{
		RETVAL = NULL;
	}
	if(!RETVAL){
		XSRETURN_UNDEF;
	}
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

void
install_subroutine(into, ...)
	SV* into
PREINIT:
	CV* code_cv        = NULL;
	const char* name   = NULL;
	STRLEN   namelen   = 0;
	GV* gv;
	HV* stash = NULL;
	int i;
CODE:
	SvGETMAGIC(into);
	if(is_string(into)){
		stash = gv_stashsv(into, TRUE);
	}
	else{
		my_croak(aTHX_ "Invalid %s %s supplied",
			"package name", neat(into));
	}
	if((items % 2) == 0){ /* ((items-1) % 2) != 0 */
		my_croak(aTHX_ "Odd number of arguments for %s", GvNAME(CvGV(cv)));
	}
	for(i = 1; i < items; i += 2){
		SV* as   = ST(i);
		SV* code = ST(i+1);
		SvGETMAGIC(as);
		if(is_string(as)){
			name    = SvPV_const(as, namelen);
		}
		else{
			my_croak(aTHX_ "Invalid %s %s supplied", "subroutine name", neat(as));
		}
		SvGETMAGIC(code);
		if(check_type(code, T_CV)){
			code_cv = deref_cv(code);
			if(SvTYPE(SvRV(code)) != SVt_PVCV){
				code = newRV_inc((SV*)code_cv);
				sv_2mortal(code);
			}
		}
		else{
			my_croak(aTHX_ "Invalid %s %s supplied", "CODE reference", neat(code));
		}
		gv = (GV*)*hv_fetch(stash, name, namelen, TRUE);
		if(SvTYPE(gv) != SVt_PVGV) gv_init(gv, stash, name, namelen, GV_ADDMULTI);
		SvSetMagicSV((SV*)gv, code); /* *foo = \&bar */
		if(strEQ(GvNAME(CvGV(code_cv)), "__ANON__")){ /* check anonymousity by name, not by CvANON flag */
			CvGV(code_cv) = gv;
			CvANON_off(code_cv);
		}
	}

void
uninstall_subroutine(package, ...)
	SV* package
PREINIT:
	HV* stash        = NULL;
	STRLEN namelen   = 0;
	const char* name = NULL;
	GV** gvp;
	CV*  cv;
	int i;
CODE:
	SvGETMAGIC(package);
	if(is_string(package)){
		stash = gv_stashsv(package, FALSE);
	}
	else{
		my_croak(aTHX_ "Invalid %s %s supplied",
			"package name", neat(package));
	}
	if(!stash) XSRETURN_EMPTY;

	for(i = 1; i < items; i++){
		SV* subr = ST(i);
		SvGETMAGIC(subr);
		if(is_string(subr)){
			name    = SvPV_const(subr, namelen);
		}
		else{
			my_croak(aTHX_ "Invalid %s %s supplied", "subroutine name", neat(subr));
		}
		gvp = (GV**)hv_fetch(stash, name, namelen, FALSE);
		if(!gvp) continue;
		SvGETMAGIC((SV*)*gvp);
		if(SvROK((SV*)*gvp)){
			if(ckWARN(WARN_MISC)){
				Perl_warner(aTHX_ packWARN(WARN_MISC), "Constant subroutine %s uninstalled", name);
			}
			hv_delete(stash, name, namelen, G_DISCARD);
			continue;
		}
		if(SvTYPE(*gvp) != SVt_PVGV){
			continue;
		}
		if((cv = GvCVu(*gvp))){
			if(cv_const_sv(cv) && ckWARN(WARN_MISC)){
				Perl_warner(aTHX_ packWARN(WARN_MISC), "Constant subroutine %s uninstalled", name);
			}
			SvREFCNT_dec(cv);
			GvCV(*gvp) = NULL;
		}
	}
	mro_method_changed_in(stash);

void
get_code_info(code)
	CV* code
PREINIT:
	GV* gv;
	const char* stash_name;
PPCODE:
	gv = CvGV(code);
	if(gv){
		stash_name = HvNAME(GvSTASH(gv));
		assert(stash_name);

		if(GIMME_V == G_ARRAY){
			EXTEND(SP, 2);
			mPUSHp(stash_name, strlen(stash_name));
			mPUSHp(GvNAME(gv), GvNAMELEN(gv));
		}
		else{
			SV* sv = newSVpvf("%s::%*s", stash_name, (int)GvNAMELEN(gv), GvNAME(gv));
			sv_2mortal(sv);
			XPUSHs(sv);
		}
	}

#define UNDEF &PL_sv_undef

#define mkopt(opt_list, moniker, require_unique, must_be) \
		my_mkopt(aTHX_ opt_list, moniker, require_unique, must_be, T_AV)
#define mkopt_hash(opt_list, moniker, must_be) \
		my_mkopt(aTHX_ opt_list, moniker, TRUE, must_be, T_HV)


SV*
mkopt(opt_list, moniker = UNDEF, require_unique = FALSE, must_be = UNDEF)
	SV* opt_list
	SV* moniker
	bool require_unique
	SV* must_be

SV*
mkopt_hash(opt_list, moniker = UNDEF, must_be = UNDEF)
	SV* opt_list
	SV* moniker
	SV* must_be
