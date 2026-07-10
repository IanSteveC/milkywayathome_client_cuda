/*
 * nbody_cuda_win_sort.cpp
 *
 * Windows/MinGW driver-API build only. Host-side orchestration of the
 * stable 128-bit LSD radix sort that replaces cub::DeviceRadixSort on
 * this build. 16 passes x 8 bits over (Morton128, int) pairs,
 * ascending + stable => output permutation identical to CUB's, so the
 * tree and every downstream bit match the Linux build exactly.
 * Kernels live in the embedded fatbin (nbCUDAWinSort* in nbody_cuda.cu).
 */

#ifdef NBODY_CUDA_DRIVER_API

#include "nbody_cuda_driver_compat.h"
#include <stdio.h>

#define NB_WSORT_CHUNK 1024

size_t nbWinRadixSortQueryTemp(int nbody) {
    size_t nBlocks = ((size_t)nbody + NB_WSORT_CHUNK - 1) / NB_WSORT_CHUNK;
    return 256u * nBlocks * sizeof(unsigned int);
}

CUresult nbWinRadixSortPairs(void* d_keys_in, void* d_keys_out,
                             void* d_vals_in, void* d_vals_out,
                             void* d_temp, size_t tempBytes,
                             int nbody, CUstream stream) {
    if (nbCudaLoadModule()) return CUDA_ERROR_NOT_INITIALIZED;
    const unsigned nBlocks = (unsigned)((nbody + NB_WSORT_CHUNK - 1) / NB_WSORT_CHUNK);
    const int total = (int)(256u * nBlocks);
    if (tempBytes < (size_t)total * sizeof(unsigned int)) return CUDA_ERROR_INVALID_VALUE;

    /* CUB semantics: input in (keys_in, vals_in), result in (keys_out,
     * vals_out). 16 passes ping-pong; seed OUT with a DtoD copy so the
     * even pass count ends in the out buffers. */
    CUresult e;
    e = cuMemcpyDtoDAsync((CUdeviceptr)(uintptr_t)d_keys_out,
                          (CUdeviceptr)(uintptr_t)d_keys_in,
                          (size_t)nbody * 16u, stream);
    if (e != CUDA_SUCCESS) return e;
    e = cuMemcpyDtoDAsync((CUdeviceptr)(uintptr_t)d_vals_out,
                          (CUdeviceptr)(uintptr_t)d_vals_in,
                          (size_t)nbody * sizeof(int), stream);
    if (e != CUDA_SUCCESS) return e;

    void* kA = d_keys_out; void* vA = d_vals_out;   /* current in */
    void* kB = d_keys_in;  void* vB = d_vals_in;    /* current out */

    for (int pass = 0; pass < 16; ++pass) {
        nbLaunch(nbfn_nbCUDAWinSortHistKernel, nBlocks, 256, 0, stream,
                 kA, nbody, pass, d_temp);
        if (nb_last_launch_err != CUDA_SUCCESS) return nb_last_launch_err;
        nbLaunch(nbfn_nbCUDAWinSortScanKernel, 1, 256, 0, stream,
                 d_temp, total);
        if (nb_last_launch_err != CUDA_SUCCESS) return nb_last_launch_err;
        nbLaunch(nbfn_nbCUDAWinSortScatterKernel, nBlocks, 256, 0, stream,
                 kA, vA, kB, vB, nbody, pass, d_temp);
        if (nb_last_launch_err != CUDA_SUCCESS) return nb_last_launch_err;
        void* t;
        t = kA; kA = kB; kB = t;
        t = vA; vA = vB; vB = t;
    }
    /* after 16 swaps the result is back in (keys_out, vals_out) == kA */
    return CUDA_SUCCESS;
}

#endif /* NBODY_CUDA_DRIVER_API */
