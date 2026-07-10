/*
 * nbody_cuda_win_sort.cpp
 *
 * Windows/MinGW driver-API build only. Host-side orchestration of the
 * stable 128-bit-key radix sort that replaces cub::DeviceRadixSort on
 * this build (CUB's host launcher cannot be compiled by MinGW).
 *
 * STATUS: stub. The driver-API build currently defaults to the legacy
 * atomicCAS buildTree (bit-identical results, verified), so these are
 * never called. The real implementation (device kernels in
 * nbody_cuda.cu + multi-pass orchestration here) flips the Morton
 * default back on. Must be a STABLE sort: CUB's is, and permutation
 * identity with the Linux build depends on it.
 */

#ifdef NBODY_CUDA_DRIVER_API

#include "nbody_cuda_driver_compat.h"
#include <stdio.h>

size_t nbWinRadixSortQueryTemp(int nbody) {
    (void)nbody;
    /* placeholder workspace so the buffer-alloc path stays happy;
     * the real sort will size its histogram/scan scratch here. */
    return 256;
}

CUresult nbWinRadixSortPairs(void* d_keys_in, void* d_keys_out,
                             void* d_vals_in, void* d_vals_out,
                             void* d_temp, size_t tempBytes,
                             int nbody, CUstream stream) {
    (void)d_keys_in; (void)d_keys_out; (void)d_vals_in; (void)d_vals_out;
    (void)d_temp; (void)tempBytes; (void)nbody; (void)stream;
    fprintf(stderr, "[nbody_cuda_win] Morton sort not implemented yet on this build\n");
    return CUDA_ERROR_NOT_SUPPORTED;
}

#endif /* NBODY_CUDA_DRIVER_API */
