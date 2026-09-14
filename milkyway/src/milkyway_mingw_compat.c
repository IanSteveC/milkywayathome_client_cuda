/* MinGW compatibility shims for the vendored CORE-MATH sources
 * (milkyway_math_funcs.c).
 *
 * GCC lowers __builtin_roundeven() to a call to the C23 libm function
 * roundeven() when no hardware rounding instruction is available (we build
 * for baseline SSE2, no SSE4.1/AVX). glibc provides roundeven; mingw-w64's
 * libmingwex does not, so the Windows cross-link fails in cr_tgamma /
 * cr_lgamma. Provide it here. Algorithm is CORE-MATH's own portable
 * fallback (round-half-away, then fix ties to even), so results are
 * identical to glibc's roundeven for every finite double. */
#if defined(__MINGW32__) || defined(__MINGW64__)

#include <stdint.h>

double roundeven(double x)
{
    double ix = __builtin_round(x); /* nearest, ties away from 0 */
    if (__builtin_fabs(ix - x) == 0.5)
    {
        /* tie: if ix is odd, step back toward x by one */
        union { double f; uint64_t n; } u, v;
        u.f = ix;
        v.f = ix - __builtin_copysign(1.0, x);
        if (__builtin_ctzll(v.n) > __builtin_ctzll(u.n))
            ix = v.f;
    }
    return ix;
}

#else
typedef int milkyway_mingw_compat_not_empty;
#endif
