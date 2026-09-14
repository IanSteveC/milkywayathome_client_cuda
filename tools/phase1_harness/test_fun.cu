
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <cuda_runtime.h>
extern "C" {
#include "crlibm.h"
}
#include "nbody_cuda_crlibm.cuh"
#include "nbody_cuda_crlibm_exp.cuh"
#include "nbody_cuda_crlibm_atan.cuh"
static __device__ double nb_p1_atan(double x){ int u=0; double v=cuda_crlibm_atan_rn(x,&u); return u ? nan("") : v; }
namespace nbp1 {
#define NB_P1_QUAL __device__
#define fprintf(f, ...) printf(__VA_ARGS__)
#define stderr 0
#define set_model_params(x) ((void)0)
#define boinc_finish(x) ((void)0)
#define pow_rn  cuda_crlibm_pow_rn
#define log_rn  cuda_crlibm_log_rn
#define exp_rn  cuda_crlibm_exp_rn
#define atan_rn nb_p1_atan
#include "nbody_cuda_phase1_integrand.h"
#undef atan_rn
#undef exp_rn
#undef log_rn
#undef pow_rn
#undef boinc_finish
#undef set_model_params
#undef stderr
#undef fprintf
#undef NB_P1_QUAL
}

/* Block-per-node variant: 29 lanes evaluate the independent
 * potential/density sub-terms of fun() in parallel; lane 0 combines
 * them with the exact CPU stencil arithmetic (same coefficients, same
 * summation order, h = 0.001). Kernel wall drops from the SUM of the
 * ~29 serial evaluations to the SLOWEST single one. Bit-exact:
 * validated against the host fun() in the standalone harness. */
extern "C" __global__ void nbCUDAPhase1FunBlockKernel(
    const double* __restrict__ xs, int n,
    nbp1::Dwarf c1, nbp1::Dwarf c2, double energy, int isDark,
    double* __restrict__ out)
{
    const int node = blockIdx.x;
    if (node >= n) return;
    const double ri = xs[node];
    const double h  = 0.001;
    const nbp1::Dwarf* dc = isDark ? &c2 : &c1;
    __shared__ double ev[29];

    /* v1.97 CPU stencils: centered 5-point when ri >= 2h, otherwise a
     * forward 5-point stencil over (x, x+h, .., x+4h) so no probe goes
     * negative (nbody_math_funcs.c first_derivative/second_derivative).
     * ri is block-uniform, so this branch never diverges. */
    const int centered = (ri >= 2.0 * h);

    const int l = threadIdx.x;
    if (l < 29)
    {
        double v = 0.0;
        if (centered)
        {
            switch (l) {
                /* pot c1 / c2, 1st-derivative points (p1..p4 order) */
                case 0:  v = nbp1::get_potential(&c1, (ri - 2.0 * h)); break;
                case 1:  v = nbp1::get_potential(&c1, (ri - h) );      break;
                case 2:  v = nbp1::get_potential(&c1, (ri + 2.0 * h)); break;
                case 3:  v = nbp1::get_potential(&c1, (ri + h));       break;
                case 4:  v = nbp1::get_potential(&c2, (ri - 2.0 * h)); break;
                case 5:  v = nbp1::get_potential(&c2, (ri - h) );      break;
                case 6:  v = nbp1::get_potential(&c2, (ri + 2.0 * h)); break;
                case 7:  v = nbp1::get_potential(&c2, (ri + h));       break;
                /* pot c1 / c2, 2nd-derivative points (p1..p5 order) */
                case 8:  v = nbp1::get_potential(&c1, (ri + 2.0 * h)); break;
                case 9:  v = nbp1::get_potential(&c1, (ri + h));       break;
                case 10: v = nbp1::get_potential(&c1, (ri));           break;
                case 11: v = nbp1::get_potential(&c1, (ri - h));       break;
                case 12: v = nbp1::get_potential(&c1, (ri - 2.0 * h)); break;
                case 13: v = nbp1::get_potential(&c2, (ri + 2.0 * h)); break;
                case 14: v = nbp1::get_potential(&c2, (ri + h));       break;
                case 15: v = nbp1::get_potential(&c2, (ri));           break;
                case 16: v = nbp1::get_potential(&c2, (ri - h));       break;
                case 17: v = nbp1::get_potential(&c2, (ri - 2.0 * h)); break;
                /* density (component per isDark), 1st then 2nd points */
                case 18: v = nbp1::get_density(dc, (ri - 2.0 * h)); break;
                case 19: v = nbp1::get_density(dc, (ri - h) );      break;
                case 20: v = nbp1::get_density(dc, (ri + 2.0 * h)); break;
                case 21: v = nbp1::get_density(dc, (ri + h));       break;
                case 22: v = nbp1::get_density(dc, (ri + 2.0 * h)); break;
                case 23: v = nbp1::get_density(dc, (ri + h));       break;
                case 24: v = nbp1::get_density(dc, (ri));           break;
                case 25: v = nbp1::get_density(dc, (ri - h));       break;
                case 26: v = nbp1::get_density(dc, (ri - 2.0 * h)); break;
                /* potential at ri for the denominator */
                case 27: v = nbp1::get_potential(&c1, ri); break;
                case 28: v = nbp1::get_potential(&c2, ri); break;
            }
        }
        else
        {
            /* forward stencil: f0..f4 at x + k*h, k = 0..4. The CPU's
             * first_ and second_derivative probe the same five points, so
             * one evaluation per point serves both (pure functions). */
            switch (l) {
                case 0:  v = nbp1::get_potential(&c1, ri);           break;
                case 1:  v = nbp1::get_potential(&c1, ri + h);       break;
                case 2:  v = nbp1::get_potential(&c1, ri + 2.0 * h); break;
                case 3:  v = nbp1::get_potential(&c1, ri + 3.0 * h); break;
                case 4:  v = nbp1::get_potential(&c1, ri + 4.0 * h); break;
                case 5:  v = nbp1::get_potential(&c2, ri);           break;
                case 6:  v = nbp1::get_potential(&c2, ri + h);       break;
                case 7:  v = nbp1::get_potential(&c2, ri + 2.0 * h); break;
                case 8:  v = nbp1::get_potential(&c2, ri + 3.0 * h); break;
                case 9:  v = nbp1::get_potential(&c2, ri + 4.0 * h); break;
                case 10: v = nbp1::get_density(dc, ri);           break;
                case 11: v = nbp1::get_density(dc, ri + h);       break;
                case 12: v = nbp1::get_density(dc, ri + 2.0 * h); break;
                case 13: v = nbp1::get_density(dc, ri + 3.0 * h); break;
                case 14: v = nbp1::get_density(dc, ri + 4.0 * h); break;
                /* potential at ri for the denominator */
                case 27: v = nbp1::get_potential(&c1, ri); break;
                case 28: v = nbp1::get_potential(&c2, ri); break;
                default: break;
            }
        }
        ev[l] = v;
    }
    __syncthreads();
    if (l != 0) return;

    /* ---- combine: EXACT transcription of the CPU arithmetic ---- */
    double first_deriv_psi, second_deriv_psi, first_deriv_density, second_deriv_density;
    if (centered)
    {
        double p1, p2, p3, p4, p5;
        /* first_derivative(get_potential, ri, c1/c2): (p1+p2+p3+p4) * inv(12.0*h) */
        p1 = 1.0 * ev[0];  p2 = - 8.0 * ev[1];  p3 = - 1.0 * ev[2];  p4 = 8.0 * ev[3];
        double fd1 = (p1 + p2 + p3 + p4) * ((double) 1.0 / (12.0 * h));
        p1 = 1.0 * ev[4];  p2 = - 8.0 * ev[5];  p3 = - 1.0 * ev[6];  p4 = 8.0 * ev[7];
        double fd2 = (p1 + p2 + p3 + p4) * ((double) 1.0 / (12.0 * h));
        first_deriv_psi = fd1 + fd2;
        /* second_derivative(get_potential, ...): (p1+..+p5) * inv(12.0*h*h) */
        p1 = - 1.0 * ev[8];  p2 = 16.0 * ev[9];  p3 = -30.0 * ev[10]; p4 = 16.0 * ev[11]; p5 = - 1.0 * ev[12];
        double sd1 = (p1 + p2 + p3 + p4 + p5) * ((double) 1.0 / (12.0 * h * h));
        p1 = - 1.0 * ev[13]; p2 = 16.0 * ev[14]; p3 = -30.0 * ev[15]; p4 = 16.0 * ev[16]; p5 = - 1.0 * ev[17];
        double sd2 = (p1 + p2 + p3 + p4 + p5) * ((double) 1.0 / (12.0 * h * h));
        second_deriv_psi = sd1 + sd2;
        /* density derivatives (single component) */
        p1 = 1.0 * ev[18]; p2 = - 8.0 * ev[19]; p3 = - 1.0 * ev[20]; p4 = 8.0 * ev[21];
        first_deriv_density = (p1 + p2 + p3 + p4) * ((double) 1.0 / (12.0 * h));
        p1 = - 1.0 * ev[22]; p2 = 16.0 * ev[23]; p3 = -30.0 * ev[24]; p4 = 16.0 * ev[25]; p5 = - 1.0 * ev[26];
        second_deriv_density = (p1 + p2 + p3 + p4 + p5) * ((double) 1.0 / (12.0 * h * h));
    }
    else
    {
        /* forward stencils, same expressions as the CPU:
         * 1st: (-25 f0 + 48 f1 - 36 f2 + 16 f3 - 3 f4) * inv(12h)
         * 2nd: ( 35 f0 -104 f1 +114 f2 - 56 f3 +11 f4) * inv(12h^2) */
        double fd1 = (-25.0 * ev[0] + 48.0 * ev[1] - 36.0 * ev[2] + 16.0 * ev[3] - 3.0 * ev[4]) * ((double) 1.0 / (12.0 * h));
        double fd2 = (-25.0 * ev[5] + 48.0 * ev[6] - 36.0 * ev[7] + 16.0 * ev[8] - 3.0 * ev[9]) * ((double) 1.0 / (12.0 * h));
        first_deriv_psi = fd1 + fd2;
        double sd1 = (35.0 * ev[0] - 104.0 * ev[1] + 114.0 * ev[2] - 56.0 * ev[3] + 11.0 * ev[4]) * ((double) 1.0 / (12.0 * h * h));
        double sd2 = (35.0 * ev[5] - 104.0 * ev[6] + 114.0 * ev[7] - 56.0 * ev[8] + 11.0 * ev[9]) * ((double) 1.0 / (12.0 * h * h));
        second_deriv_psi = sd1 + sd2;
        first_deriv_density  = (-25.0 * ev[10] + 48.0 * ev[11] - 36.0 * ev[12] + 16.0 * ev[13] - 3.0 * ev[14]) * ((double) 1.0 / (12.0 * h));
        second_deriv_density = (35.0 * ev[10] - 104.0 * ev[11] + 114.0 * ev[12] - 56.0 * ev[13] + 11.0 * ev[14]) * ((double) 1.0 / (12.0 * h * h));
    }

    if (first_deriv_psi == 0.0) first_deriv_psi = 1.0e-6;
    double dsqden_dpsisq = second_deriv_density * ((double) 1.0 / (first_deriv_psi))
        - first_deriv_density * second_deriv_psi * ((double) 1.0 / (((first_deriv_psi) * (first_deriv_psi))));
    double diff = fabs(energy - (ev[27] + ev[28]));
    double denominator;
    if (diff != 0.0) denominator = ((double) 1.0 / (sqrt(diff)));
    else denominator = ((double) 1.0 / (sqrt(fabs(energy - nbp1::potential(ri + 0.0001, &c1, &c2)))));
    out[node] = dsqden_dpsisq * denominator;
}

extern "C" __global__ void nbCUDAPhase1FunKernel(
    const double* __restrict__ xs, int n,
    nbp1::Dwarf c1, nbp1::Dwarf c2, double energy, int isDark,
    double* __restrict__ out)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) out[i] = nbp1::fun(xs[i], &c1, &c2, energy, isDark);
}


/* host reference: same header compiled as plain C++ against crlibm */
namespace href {
#define NB_P1_QUAL
#define set_model_params(x) ((void)0)
#define boinc_finish(x) ((void)0)
#include "nbody_cuda_phase1_integrand.h"
#undef boinc_finish
#undef set_model_params
#undef NB_P1_QUAL
}
static double urand(uint64_t* s){ *s ^= *s<<13; *s ^= *s>>7; *s ^= *s<<17; return (double)(*s>>11) * (1.0/9007199254740992.0); }
int main(int argc,char**argv){
    crlibm_init();
    FILE* f=fopen("dwarfs.bin","rb"); std::vector<href::Dwarf> dw; href::Dwarf d;
    while(fread(&d,sizeof(d),1,f)==1) dw.push_back(d); fclose(f);
    printf("loaded %zu dwarfs, sizeof=%zu (nbp1 %zu)\n", dw.size(), sizeof(href::Dwarf), sizeof(nbp1::Dwarf));
    const int N = argc>1 ? atoi(argv[1]) : 20000;
    double *dx,*dob,*dof; cudaMalloc(&dx,N*8); cudaMalloc(&dob,N*8); cudaMalloc(&dof,N*8);
    std::vector<double> xs(N), ob(N), of(N);
    uint64_t seed=88172645463325252ull;
    long total=0, mism_block=0, mism_fun=0, nan_flag=0, fwd=0; long pair_m[16][16][2]={{{0}}};
    /* component pairs: (i,j) for all i,j incl same-type pairs; isDark both */
    for(size_t i=0;i<dw.size();++i) for(size_t j=0;j<dw.size();++j) for(int isDark=0;isDark<2;++isDark){
        href::Dwarf c1=dw[i], c2=dw[j];
        double scale = c1.scaleLength + c2.scaleLength;
        for(int k=0;k<N;++k){
            double u=urand(&seed);
            /* 15% of nodes below 2h to exercise the forward stencil; rest log-uniform over 1e-3..50*scale */
            xs[k] = (u<0.15) ? urand(&seed)*0.002 : 1e-3*pow(50.0*scale/1e-3, urand(&seed));
        }
        /* energy: psi at a random radius, like dist_fun (energy = potential(r) - v^2/2) */
        double r0 = 1e-2*pow(20.0*scale/1e-2, urand(&seed));
        double energy = href::potential(r0,&c1,&c2) * (0.2 + 0.8*urand(&seed));
        cudaMemcpy(dx,xs.data(),N*8,cudaMemcpyHostToDevice);
        nbp1::Dwarf n1, n2; memcpy(&n1,&c1,sizeof n1); memcpy(&n2,&c2,sizeof n2);
        nbCUDAPhase1FunBlockKernel<<<N,32>>>(dx,N,n1,n2,energy,isDark,dob);
        nbCUDAPhase1FunKernel<<<(N+127)/128,128>>>(dx,N,n1,n2,energy,isDark,dof);
        if(cudaDeviceSynchronize()!=cudaSuccess){ printf("CUDA error\n"); return 2; }
        cudaMemcpy(ob.data(),dob,N*8,cudaMemcpyDeviceToHost); cudaMemcpy(of.data(),dof,N*8,cudaMemcpyDeviceToHost);
        for(int k=0;k<N;++k){
            double h = href::fun(xs[k],&c1,&c2,energy,isDark);
            total++; if(xs[k]<0.002) fwd++;
            if(std::isnan(ob[k]) || std::isnan(of[k])){ nan_flag++; continue; }   /* atan accurate-phase: host recompute path */
            if(memcmp(&h,&ob[k],8)!=0){ pair_m[i][j][isDark]++; if(mism_block<5) printf("BLOCK mismatch t%d/t%d dark=%d r=%.17g e=%.17g host=%.17g dev=%.17g\n",(int)c1.type,(int)c2.type,isDark,xs[k],energy,h,ob[k]); mism_block++; }
            if(memcmp(&h,&of[k],8)!=0){ if(mism_fun<5) printf("FUN mismatch t%d/t%d dark=%d r=%.17g host=%.17g dev=%.17g\n",(int)c1.type,(int)c2.type,isDark,xs[k],h,of[k]); mism_fun++; }
        }
    }
    for(size_t i=0;i<dw.size();++i) for(size_t j=0;j<dw.size();++j) for(int q=0;q<2;++q) if(pair_m[i][j][q]) printf("  pair dw[%zu](t%d) dw[%zu](t%d) dark=%d: %ld mismatches\n",i,(int)dw[i].type,j,(int)dw[j].type,q,pair_m[i][j][q]);
    printf("nodes=%ld (forward-stencil nodes=%ld)  nan-flagged=%ld (%.4f%%)  BLOCK mismatches=%ld  FUN mismatches=%ld\n", total,fwd,nan_flag,100.0*nan_flag/total,mism_block,mism_fun);
    return (mism_block||mism_fun)?1:0;
}
