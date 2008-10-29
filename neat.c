/* neat.c */

#include "data-util.h"

void
du_neat_cat(pTHX_ SV* const dsv, SV* x, const int level){

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
					du_neat_cat(aTHX_ dsv, *svp, level+1);
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
				du_neat_cat(aTHX_ dsv, val, level+1);

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

const char*
du_neat(pTHX_ SV* x){
	SV* const dsv = newSV(100);
	sv_2mortal(dsv);
	sv_setpvs(dsv, "");

	ENTER;
	SAVETMPS;

	du_neat_cat(aTHX_ dsv, x, 0);

	FREETMPS;
	LEAVE;

	return SvPVX(dsv);
}
