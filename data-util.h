/* Data-Util/data-util.h */

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "c99portability.h"

#include "mro_compat.h"
#include "str_util.h"


#define my_SvNIOK(sv) (SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVp_IOK|SVp_NOK))
#define my_SvPOK(sv)  (SvFLAGS(sv) & (SVp_POK | SVf_POK))

#ifndef SvRXOK
#define SvRXOK(sv) ((bool)(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG) && mg_find(SvRV(sv), PERL_MAGIC_qr)))
#endif

#define is_string(x) (SvOK(x) && !SvROK(x))

#define PUSHav(av, start, len) STMT_START{        \
		SV** const ary = AvARRAY(av);     \
		I32 i;                            \
		I32 const length = (len);         \
		for(i = (start) ;i < length; i++){\
			PUSHs(ary[i]);            \
		}                                 \
	} STMT_END
#define XPUSHav(av, start, len) STMT_START{       \
		SV** const ary = AvARRAY(av);     \
		I32 i;                            \
		I32 const length = (len);         \
		EXTEND(SP, length);               \
		for(i = (start) ;i < length; i++){\
			PUSHs(ary[i]);            \
		}                                 \
	} STMT_END


#define neat(x) du_neat(aTHX_ x)
#define neat_cat(dsv, x, level) du_neat_cat(aTHX_ dsv, x, level)

void
du_neat_cat(pTHX_ SV* const dsv, SV* x, const int level);

const char*
du_neat(pTHX_ SV* x);


/* curry ingand modifiers */

/* modifier accessros */
enum{
	M_BEFORE,
	M_AROUND,
	M_AFTER,
	M_ORIGINAL,
	M_CURRENT,
	M_LENGTH
};

#define mg_find_by_vtbl(sv, vtbl) my_mg_find_by_vtbl(aTHX_ sv, vtbl)
MAGIC*
my_mg_find_by_vtbl(pTHX_ SV* const sv, const MGVTBL* const vtbl);


XS(XS_Data__Util_curried);
XS(XS_Data__Util_modified);
