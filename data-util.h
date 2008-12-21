/* Data-Util/data-util.h */

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#include "c99portability.h"

#include "mro_compat.h"
#include "str_util.h"

#ifndef SvRXOK
#define SvRXOK(sv) ((bool)(SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG) && mg_find(SvRV(sv), PERL_MAGIC_qr)))
#endif

#ifndef isGV_with_GP
#define isGV_with_GP(maybe_gv) (isGV(maybe_gv))
#endif

#ifndef HvNAME_get
#define HvNAME_get(hv) HvNAME(hv)
#endif

#ifndef HvNAMELEN_get
#define HvNAMELEN_get(hv) (strlen(HvNAME_get(hv)))
#endif

#define PUSHary(ary, start, len) STMT_START{      \
		I32 i;                            \
		I32 const length = (len);         \
		for(i = (start) ;i < length; i++){\
			PUSHs(ary[i]);            \
		}                                 \
	} STMT_END
#define XPUSHary(ary, start, len) STMT_START{     \
		I32 i;                            \
		I32 const length = (len);         \
		EXTEND(SP, length);               \
		for(i = (start) ;i < length; i++){\
			PUSHs(ary[i]);            \
		}                                 \
	} STMT_END


#define is_string(x) (SvOK(x) && !SvROK(x) && (SvPOKp(x) ? SvCUR(x) > 0 : TRUE))

#define neat(x) du_neat(aTHX_ x)

const char*
du_neat(pTHX_ SV* x);


/* curry ingand modifiers */

/* modifier accessros */
enum{
	M_BEFORE,
	M_AROUND,
	M_AFTER,
	M_CURRENT,
	M_LENGTH
};

#define mg_find_by_vtbl(sv, vtbl) my_mg_find_by_vtbl(aTHX_ sv, vtbl)
MAGIC*
my_mg_find_by_vtbl(pTHX_ SV* const sv, const MGVTBL* const vtbl);


XS(XS_Data__Util_curried);
XS(XS_Data__Util_modified);
