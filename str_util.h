#ifndef SCALAR_UTIL_REF_STR_UTIL_H
#define SCALAR_UTIL_REF_STR_UTIL_H

#ifdef INLINE_STR_EQ

#undef strnEQ
static inline int
strnEQ(const char* const x, const char* const y, const size_t n){
	size_t i;
	for(i = 0; i < n; i++){
		if(x[i] != y[i]){
			return FALSE;
		}
		else if(x[i] == '\0'){
			return TRUE; /* y[i] is also '\0' */
		}
	}
	return TRUE;
}
#undef strEQ
static inline int
strEQ(const char* x, const char* y){
	size_t i;
	for(i = 0; ; i++){
		if(x[i] != y[i]){
			return FALSE;
		}
		else if(x[i] == '\0'){
			return TRUE; /* y[i] is also '\0' */
		}
	}
	return TRUE; /* not reached */
}

#endif /* !INLINE_STR_EQ */

#endif
