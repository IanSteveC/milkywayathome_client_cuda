#ifndef _NBODY_MATH_FUNCS_H_
#define _NBODY_MATH_FUNCS_H_

/* nbody_config.h must come first: milkyway_math.h selects crlibm (mw_exp ->
 * exp_rn etc.) only if NBODY_CRLIBM is already defined. Upstream v1.97's
 * ordering (milkyway_math.h first) silently compiled gammln/gser/gcf/
 * GammaFunc against the host libm exp/log, reintroducing a platform-libm
 * dependency in the incomplete-gamma path (cutoff NFW/Cored, Einasto). */
#include "nbody_config.h"
#include "milkyway_math.h"
#include "nbody_types.h"
#include "nbody_potential_types.h"

typedef real (*ODE2ndDeriv)(real, real, real, const Dwarf *params);
real ODE2ndOrderSolver(real xEval, int stepsPerx, real yInit, real yPrimeInit, ODE2ndDeriv f, const Dwarf* params, int returnXWhen0);

real GammaFunc(const real z);

real UpperIncompleteGammaFunc(real a, real x);
real LowerIncompleteGammaFunc(real a, real x);
real ErrorFunc(real x);
real ComplementaryErrorFunc(real x);
real ComplementaryErrorFuncApprox(real x);

real first_derivative(real (*func)(const Dwarf*, real), real x, const Dwarf* comp1);
real second_derivative(real (*func)(const Dwarf*, real), real x, const Dwarf* comp1);
real gauss_quad(real (*func)(real, const Dwarf*, const Dwarf*, real, mwbool), real lower, real upper, const Dwarf* comp1, const Dwarf* comp2, real energy, mwbool isDark);

#if NBODY_CUDA
/* GPU phase-1 offload hook (defined in nbody_mixeddwarf.c, where the dwarf
 * integrand 'fun' is visible). nx holds 4 reals per node (x1n,x2n,x3n,coef1);
 * on success fills fv[3*nIter] and returns 1; returns 0 to use the CPU path. */
int nbGaussQuadTryGPU(real (*func)(real, const Dwarf*, const Dwarf*, real, mwbool),
                      const real* nx, int nIter, const Dwarf* comp1, const Dwarf* comp2,
                      real energy, mwbool isDark, real* fv);
#endif

#endif /* _NBODY_MATH_FUNCS_H_ */