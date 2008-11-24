/* Data-Util/DataUtil.xs */

#include "data-util.h"


#define MY_CXT_KEY "Data::Util::_guts" XS_VERSION


#define string(sv, len, name) (SvGETMAGIC(sv), (is_string(sv) ? NOOP : my_fail(aTHX_ name, sv)), SvPV_const(sv, len))


typedef struct{
	GV* universal_isa;

	GV* croak;
} my_cxt_t;
START_MY_CXT;

/* null magic virtual table to identify magic functions */
MGVTBL curried_vtbl;
MGVTBL wrapped_vtbl;

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
	"a SCALAR reference",
	"an ARRAY reference",
	"a HASH reference",
	"a CODE reference",
	"a GLOB reference",
	NULL, /* IO */
	NULL, /* FM */
	"a regular expression reference", /* RX */
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

static void
my_fail(pTHX_ const char* const name, SV* value){
	my_croak(aTHX_ "Validation failed: you must supply %s, not %s", name, neat(value));
}


static bool
my_has_amagic_converter(pTHX_ SV* const sv, const my_ref_t t){
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
			return my_has_amagic_converter(aTHX_ sv, t);
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

static AV*
my_deref_av(pTHX_ SV* sv){
	SvGETMAGIC(sv);
	if(my_has_amagic_converter(aTHX_ sv, T_AV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_av);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)){
		my_fail(aTHX_ ref_names[T_AV], sv);
	}
	return (AV*)SvRV(sv);
}
static HV*
my_deref_hv(pTHX_ SV* sv){
	SvGETMAGIC(sv);
	if(my_has_amagic_converter(aTHX_ sv, T_HV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_hv);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)){
		my_fail(aTHX_ ref_names[T_HV], sv);
	}
	return (HV*)SvRV(sv);
}
static CV*
my_deref_cv(pTHX_ SV* sv){
	SvGETMAGIC(sv);
	if(my_has_amagic_converter(aTHX_ sv, T_CV)){
		SV* const* sp = &sv; /* used in tryAMAGICunDEREF macro */
		tryAMAGICunDEREF(to_cv);
	}

	if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV)){
		my_fail(aTHX_ ref_names[T_CV], sv);
	}
	return (CV*)SvRV(sv);
}

#define validate(sv, t) my_validate_ref(aTHX_ sv, t)
static SV*
my_validate_ref(pTHX_ SV* const sv, my_ref_t const ref_type){
	if(!check_type(sv, ref_type)){
		my_fail(aTHX_ ref_names[ref_type], sv);
	}
	return sv;
}


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


static int
my_isa_lookup(pTHX_ HV* const stash, const char* klass_name){
	const char* const stash_name = my_canon_pkg(aTHX_ HvNAME(stash));

	klass_name = my_canon_pkg(aTHX_ klass_name);

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
			if(strEQ(klass_name, my_canon_pkg(aTHX_ SvPVX(*svp)))){
				return TRUE;
			}
			svp++;
		}
	}
	return FALSE;
}

/* returns &PL_sv_yes or &PL_sv_no */
static SV*
my_instance_of(pTHX_ SV* const x, SV* const klass){
	dVAR;
	if( !is_string(klass) ){
		my_fail(aTHX_ "a class name", klass);
	}

	if( !(SvROK(x) && SvOBJECT(SvRV(x))) ){
		return &PL_sv_no;
	}
	else{
		dMY_CXT;
		HV* const stash = SvSTASH(SvRV(x));
		GV* const isa   = gv_fetchmeth_autoload(stash, "isa", sizeof("isa")-1, 0 /* special zero, not flags nor bool */);
		SV* retval;

		/* common cases */
		if(isa == NULL || GvCV(isa) == GvCV(MY_CXT.universal_isa)){
			return boolSV( my_isa_lookup(aTHX_ stash, SvPV_nolen_const(klass)) );
		}

		/* special cases */
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
	return my_instance_of(aTHX_ sv, type) == &PL_sv_yes;
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
			my_fail(aTHX_ "a type info", must_be);
		}
	}

	len = av_len(opt_av) + 1;
	for(i = 0; i < len; i++){
		SV* const name = *av_fetch(opt_av, i, TRUE);
		SV* value;

		if(require_unique){
			HE* const he = hv_fetch_ent(seen, name, TRUE, 0U);
			SV* const count = hv_iterval(seen, he);
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
				HE* const he = hv_fetch_ent(vhv, name, FALSE, 0U);
				vav = NULL;
				if(he){
					SV* const sv = hv_iterval(vhv, he);
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
					my_croak(aTHX_ "%s-ref values are not valid for %"SVf" in %"SVf" opt list",
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

/*
	$code = curry($_, (my $tmp = $code), *_) for @around;
*/
static SV*
my_build_around_code(pTHX_ SV* code_ref, AV* const around){
	I32 const len = av_len(around) + 1;
	I32 i;
	for(i = 0; i < len; i++){
		CV* current;
		SV* const sv = validate(*av_fetch(around, i, TRUE), T_CV);
		AV* const args         = newAV();
		AV* const placeholders = newAV();

		av_store(args, 0, newSVsv(sv)); /* base proc */
		av_store(args, 1, code_ref);    /* first argument */
		av_store(args, 2, &PL_sv_undef);/* placeholder */
		SvREFCNT_inc_simple_void_NN(code_ref);

		av_store(placeholders, 2, (SV*)PL_defgv); // *_
		SvREFCNT_inc_simple_void_NN(PL_defgv);

		current = newXS(NULL /* anonymous */, XS_Data__Util_curried, __FILE__);
		sv_magicext((SV*)current, (SV*)args, PERL_MAGIC_ext, &curried_vtbl, (const char*)placeholders, HEf_SVKEY);

		SvREFCNT_dec(args);         /* because: refcnt++ in sv_magicext() */
		SvREFCNT_dec(placeholders); /* because: refcnt++ in sv_magicext() */

		code_ref = newRV_noinc((SV*)current);
		sv_2mortal(code_ref);
	}
	return code_ref;
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
	my_fail(aTHX_ ref_names[ix], x);

void
is_instance(x, klass)
	SV* x
	SV* klass
CODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	ST(0) = my_instance_of(aTHX_ x, klass);
	XSRETURN(1);

void
instance(x, klass)
	SV* x
	SV* klass
CODE:
	SvGETMAGIC(x);
	SvGETMAGIC(klass);
	if( my_instance_of(aTHX_ x, klass) == &PL_sv_yes ){
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
			sv_setpv(TARG, my_canon_pkg(aTHX_ SvPV_nolen_const(x)));
			ST(0) = TARG;
			XSRETURN(1);
		}
		my_fail(aTHX_ "an invocant", x);
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
	GV* gv;
	HV* stash = NULL;
	int i;
CODE:
	SvGETMAGIC(into);
	if(is_string(into)){
		stash = gv_stashsv(into, TRUE);
	}
	else{
		my_fail(aTHX_ "a package name", into);
	}
	if( ((items-1) % 2) != 0 ){
		my_croak(aTHX_ "Odd number of arguments for %s", GvNAME(CvGV(cv)));
	}
	for(i = 1; i < items; i += 2){
		SV* as   = ST(i);
		SV* code = ST(i+1);
		STRLEN namelen;
		const char* const name = string(as, namelen, "a subroutine name");
		CV* const code_cv = deref_cv(code);

		if(SvTYPE(SvRV(code)) != SVt_PVCV){ /* overloaded object */
			code = newRV_inc((SV*)code_cv);
			sv_2mortal(code);
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
	int i;
CODE:
	SvGETMAGIC(package);
	if(is_string(package)){
		stash = gv_stashsv(package, FALSE);
	}
	else{
		my_fail(aTHX_ "a package name", package);
	}
	if(!stash) XSRETURN_EMPTY;

	for(i = 1; i < items; i++){
		STRLEN namelen;
		const char* const name = string(ST(i), namelen, "a subroutine name");
		GV** const gvp = (GV**)hv_fetch(stash, name, namelen, FALSE);
		CV* code;

		if(!gvp) continue;

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
		if((code = GvCVu(*gvp))){
			if(cv_const_sv(code) && ckWARN(WARN_MISC)){
				Perl_warner(aTHX_ packWARN(WARN_MISC), "Constant subroutine %s uninstalled", name);
			}
			SvREFCNT_dec(code);
			GvCV(*gvp) = NULL;
		}
	}
	mro_method_changed_in(stash);

void
get_code_info(code)
	CV* code
PREINIT:
	GV* gv;
PPCODE:
	gv = CvGV(code);
	if(gv){
		const char* stash_name = HvNAME(GvSTASH(gv));
		assert(stash_name);

		if(GIMME_V == G_ARRAY){
			EXTEND(SP, 2);
			mPUSHp(stash_name, strlen(stash_name));
			mPUSHp(GvNAME(gv), GvNAMELEN(gv));
		}
		else{
			SV* const sv = newSVpvf("%s::%*s", stash_name, (int)GvNAMELEN(gv), GvNAME(gv));
			mXPUSHs(sv);
		}
	}


SV*
curry(code, ...)
	SV* code
PREINIT:
	CV* curried;
	AV* args;
	AV* placeholders;
	I32 is_method;
	I32 i;
CODE:
	SvGETMAGIC(code);
	is_method = check_type(code, T_CV) ? 0 : G_METHOD;

	args         = newAV();
	placeholders = newAV();

	av_extend(args,         items-1);
	av_extend(placeholders, items-1);

	for(i = 0; i < items; i++){
		SV* const sv = ST(i);
		SvGETMAGIC(sv);

		if(SvROK(sv) && SvIOK(SvRV(sv)) && !SvOBJECT(SvRV(sv))){ // \0, \1, ...
			av_store(args, i, &PL_sv_undef);
			av_store(placeholders, i, newSVsv(SvRV(sv)));
		}
		else if(sv == (SV*)PL_defgv){ // *_ (always *main::_)
			av_store(args, i, &PL_sv_undef);
			av_store(placeholders, i, sv);
			SvREFCNT_inc_simple_void_NN(sv);
		}
		else{
			av_store(args, i, sv); /* not copy */
			av_store(placeholders, i, &PL_sv_undef);
			SvREFCNT_inc_simple_void_NN(sv);
		}
	}
	curried = newXS(NULL /* anonymous */, XS_Data__Util_curried, __FILE__);
	CvXSUBANY(curried).any_i32 = is_method;

	sv_magicext((SV*)curried, (SV*)args, PERL_MAGIC_ext, &curried_vtbl, (const char*)placeholders, HEf_SVKEY);
	SvREFCNT_dec((SV*)args);         /* refcnt++ in sv_magicext() */
	SvREFCNT_dec((SV*)placeholders); /* refcnt++ in sv_magicext() */

	RETVAL = newRV_noinc((SV*)curried);
OUTPUT:
	RETVAL

SV*
wrap_subroutine(code, ...)
	CV* code
PREINIT:
	SV* original;
	CV* wrapped;
	SV* current;
	AV* before;
	AV* around;
	AV* after;
	AV* modifiers; /* (before, around, after, original, current) */
	I32 i;
CODE:
	if( ((items - 1) % 2) != 0 ){
		my_croak(aTHX_ "Odd number of arguments for %s", GvNAME(CvGV(cv)));
	}

	before = newAV(); sv_2mortal((SV*)before);
	around = newAV(); sv_2mortal((SV*)around);
	after  = newAV(); sv_2mortal((SV*)after );

	for(i = 1; i < items; i += 2){ /* modifier_type => [subroutine(s)] */
		STRLEN mt_len;
		const char* const modifier_type = string(ST(i), mt_len, "a modifer type");
		AV*         const          subs = deref_av(ST(i+1));
		I32         const      subs_len = av_len(subs) + 1;
		AV* av = NULL;
		I32 j;

		if(strEQ(modifier_type, "before")){
			av = before;
		}
		else if(strEQ(modifier_type, "around")){
			av = around;
		}
		else if(strEQ(modifier_type, "after")){
			av = after;
		}
		else{
			my_croak(aTHX_ "Invalid modifier type %s", neat(ST(i)));
		}

		av_extend(av, AvFILLp(av) + subs_len - 1);
		for(j = 0; j < subs_len; j++){
			SV* code_ref = validate(*av_fetch(subs, j, TRUE), T_CV);
			av_push(av, newSVsv(code_ref)); /* must be copy */
		}
	}

	modifiers = newAV();
	sv_2mortal((SV*)modifiers);

	original = newRV_inc((SV*)code);
	sv_2mortal(original);

	current = my_build_around_code(aTHX_ original, around);

	av_store(modifiers, M_CURRENT,  SvREFCNT_inc_simple_NN(current));
	av_store(modifiers, M_ORIGINAL, SvREFCNT_inc_simple_NN(original));

	av_store(modifiers, M_BEFORE, SvREFCNT_inc_simple_NN(before));
	av_store(modifiers, M_AROUND, SvREFCNT_inc_simple_NN(around));
	av_store(modifiers, M_AFTER,  SvREFCNT_inc_simple_NN(after));

	wrapped = newXS(NULL /* anonymous */, XS_Data__Util_wrapped, __FILE__);
	sv_magicext((SV*)wrapped, (SV*)modifiers, PERL_MAGIC_ext, &wrapped_vtbl, NULL, 0);

	RETVAL = newRV_noinc((SV*)wrapped);
OUTPUT:
	RETVAL


void
subroutine_modifier(code, ...)
	CV* code
PREINIT:
	/* Usage:
		subroutine_modifier(code)                 # check
		subroutine_modifier(code, property)       # get
		subroutine_modifier(code, property, subs) # set
	*/
	MAGIC* mg;
	AV* modifiers; /* (before, around, after, original, current) */
	SV* command;
	const char* command_pv;
PPCODE:
	mg = mg_find((SV*)code, PERL_MAGIC_ext);
	modifiers = (AV*)(mg && mg->mg_virtual == &wrapped_vtbl ? mg->mg_obj : NULL);
	if(items == 1){ /* check only */
		ST(0) = boolSV(modifiers);
		XSRETURN(1);
	}
	if(!modifiers){
		my_fail(aTHX_ "a wrapped subroutine", ST(0) /* ref to code */);
	}

	command = ST(1);
	SvGETMAGIC(command);
	if(!is_string(command)) goto invalid_command;

	command_pv = SvPV_nolen_const(command);
	if(strEQ(command_pv, "original")){
		if(items != 2){
			my_croak(aTHX_ "Cannot reset the original subroutine");
		}
		XPUSHs(*av_fetch(modifiers, M_ORIGINAL, FALSE));
	}
	else if(strEQ(command_pv, "before") || strEQ(command_pv, "around") || strEQ(command_pv, "after")){
		I32 idx =
			  strEQ(command_pv, "before") ? M_BEFORE
			: strEQ(command_pv, "around") ? M_AROUND
			:                               M_AFTER;
		AV* property = (AV*)*av_fetch(modifiers, idx, FALSE);
		if(items != 2){ /* add */
			I32 i;
			for(i = 2; i < items; i++){
				av_push(property, newSVsv(validate(ST(i), T_CV)));
			}

			if(idx == M_AROUND){
				AV* const around = (AV*)sv_2mortal((SV*)av_make(items-2, &ST(2)));
				SV* const current = my_build_around_code(aTHX_
					*av_fetch(modifiers, M_CURRENT, FALSE),
					around);
				av_store(modifiers, M_CURRENT, current);
				SvREFCNT_inc_simple_void_NN(current);
			}
		}
		XPUSHav(property, 0, av_len(property)+1);
	}
	else{
		invalid_command:
		my_fail(aTHX_ "a modifier command", command);
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
