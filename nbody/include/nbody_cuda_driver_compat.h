/*
 * nbody_cuda_driver_compat.h
 *
 * Windows/MinGW host-pass compatibility layer: maps the CUDA *runtime*
 * API subset used by nbody_cuda.cu's host code onto the CUDA *driver*
 * API (cuda.h), so the host side can be compiled by x86_64-w64-mingw32-g++
 * and linked against nvcuda.dll (import lib generated with dlltool).
 * No CUDA toolkit is needed on/for Windows: kernels are compiled on
 * Linux with nvcc into a multi-arch fatbin and embedded as a C array.
 *
 * Only active when NBODY_CUDA_DRIVER_API is defined (the MinGW host
 * pass). The Linux build never includes this file's mappings and is
 * completely unchanged.
 *
 * Follows the same single-source philosophy as nbody_hip_compat.h.
 */

#ifndef _NBODY_CUDA_DRIVER_COMPAT_H_
#define _NBODY_CUDA_DRIVER_COMPAT_H_

#ifdef NBODY_CUDA_DRIVER_API

#if defined(NBODY_HIP_DRIVER_API)
#include "nbody_hip_shim.h"   /* HIP module/driver API, hand-declared */
#else
#include <cuda.h>             /* CUDA driver API only */
#endif
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/* CUDA source decorators, neutralized for the plain-C++ host pass.
 * Structs shared between host and device (Morton128 etc.) keep their
 * exact layout via the aligned attribute. */
#define __host__
#define __device__
#define __forceinline__ inline
#define __align__(n) __attribute__((aligned(n)))

/* ----- basic type + constant mappings ----- */

typedef CUresult     cudaError_t;
typedef CUstream     cudaStream_t;
typedef CUevent      cudaEvent_t;
typedef CUgraph      cudaGraph_t;
typedef CUgraphExec  cudaGraphExec_t;

#define cudaSuccess                     CUDA_SUCCESS
#define cudaEventDisableTiming          CU_EVENT_DISABLE_TIMING
#define cudaStreamCaptureModeThreadLocal CU_STREAM_CAPTURE_MODE_THREAD_LOCAL

enum cudaMemcpyKind {
    cudaMemcpyHostToDevice,
    cudaMemcpyDeviceToHost,
    cudaMemcpyDeviceToDevice
};

/* ----- context management -----
 * The runtime API auto-initializes a primary context; the driver API
 * does not. nbEnsureCudaCtx() is called from every entry wrapper that
 * can be the first CUDA touch. Uses the primary context (retain), so
 * any future interop with runtime-API components stays possible. */
int nbEnsureCudaCtx(void);          /* 0 on success */
CUdevice nbCudaDevice(void);        /* valid after nbEnsureCudaCtx */

/* Set by nbLaunch(); read back by cudaGetLastError(). Mirrors the
 * runtime's sticky-error pattern the host code relies on
 * ("kernel<<<>>>; err = cudaGetLastError();"). */
extern CUresult nb_last_launch_err;

/* ----- error strings ----- */

static inline const char* cudaGetErrorString(CUresult e) {
    const char* s = NULL;
    cuGetErrorString(e, &s);
    return s ? s : "unknown CUDA driver error";
}

static inline CUresult cudaGetLastError(void) {
    CUresult e = nb_last_launch_err;
    nb_last_launch_err = CUDA_SUCCESS;
    return e;
}

/* ----- memory ----- */

static inline CUresult cudaMalloc(void** p, size_t n) {
    CUdeviceptr d = 0;
    CUresult e = cuMemAlloc(&d, n);
    *p = (void*)(uintptr_t)d;
    return e;
}
static inline CUresult cudaFree(void* p) {
    if (!p) return CUDA_SUCCESS;
    return cuMemFree((CUdeviceptr)(uintptr_t)p);
}
static inline CUresult cudaMemcpy(void* dst, const void* src, size_t n, enum cudaMemcpyKind k) {
    switch (k) {
        case cudaMemcpyHostToDevice:   return cuMemcpyHtoD((CUdeviceptr)(uintptr_t)dst, src, n);
        case cudaMemcpyDeviceToHost:   return cuMemcpyDtoH(dst, (CUdeviceptr)(uintptr_t)src, n);
        case cudaMemcpyDeviceToDevice: return cuMemcpyDtoD((CUdeviceptr)(uintptr_t)dst, (CUdeviceptr)(uintptr_t)src, n);
    }
    return CUDA_ERROR_INVALID_VALUE;
}
static inline CUresult cudaMemcpyAsync(void* dst, const void* src, size_t n, enum cudaMemcpyKind k, CUstream s) {
    switch (k) {
        case cudaMemcpyHostToDevice:   return cuMemcpyHtoDAsync((CUdeviceptr)(uintptr_t)dst, src, n, s);
        case cudaMemcpyDeviceToHost:   return cuMemcpyDtoHAsync(dst, (CUdeviceptr)(uintptr_t)src, n, s);
        case cudaMemcpyDeviceToDevice: return cuMemcpyDtoDAsync((CUdeviceptr)(uintptr_t)dst, (CUdeviceptr)(uintptr_t)src, n, s);
    }
    return CUDA_ERROR_INVALID_VALUE;
}
static inline CUresult cudaMemset(void* p, int v, size_t n) {
    return cuMemsetD8((CUdeviceptr)(uintptr_t)p, (unsigned char)v, n);
}
static inline CUresult cudaMallocHost(void** p, size_t n) {
    return cuMemAllocHost(p, n);
}
static inline CUresult cudaFreeHost(void* p) {
    if (!p) return CUDA_SUCCESS;
    return cuMemFreeHost(p);
}

/* ----- streams / events / sync ----- */

static inline CUresult cudaStreamCreate(CUstream* s)      { return cuStreamCreate(s, CU_STREAM_DEFAULT); }
static inline CUresult cudaStreamDestroy(CUstream s)      { return cuStreamDestroy(s); }
static inline CUresult cudaStreamSynchronize(CUstream s)  { return cuStreamSynchronize(s); }
static inline CUresult cudaStreamWaitEvent(CUstream s, CUevent e, unsigned f) { return cuStreamWaitEvent(s, e, f); }
static inline CUresult cudaEventCreateWithFlags(CUevent* e, unsigned f) { return cuEventCreate(e, f); }
static inline CUresult cudaEventDestroy(CUevent e)        { return cuEventDestroy(e); }
static inline CUresult cudaEventRecord(CUevent e, CUstream s) { return cuEventRecord(e, s); }
static inline CUresult cudaEventSynchronize(CUevent e)    { return cuEventSynchronize(e); }
static inline CUresult cudaDeviceSynchronize(void)        { return cuCtxSynchronize(); }

/* ----- graphs (driver API has full stream-capture support) ----- */

static inline CUresult cudaStreamBeginCapture(CUstream s, int mode) {
    return cuStreamBeginCapture(s, (CUstreamCaptureMode)mode);
}
static inline CUresult cudaStreamEndCapture(CUstream s, CUgraph* g) {
    return cuStreamEndCapture(s, g);
}
static inline CUresult cudaGraphInstantiate(CUgraphExec* ge, CUgraph g, void* a, void* b, size_t c) {
    (void)a; (void)b; (void)c;
    return cuGraphInstantiate(ge, g, 0);
}
static inline CUresult cudaGraphLaunch(CUgraphExec ge, CUstream s) { return cuGraphLaunch(ge, s); }
static inline CUresult cudaGraphExecDestroy(CUgraphExec ge)        { return cuGraphExecDestroy(ge); }
static inline CUresult cudaGraphDestroy(CUgraph g)                 { return cuGraphDestroy(g); }

/* ----- device query ----- */

struct cudaDeviceProp {
    char name[256];
    int  multiProcessorCount;
    int  major;
    int  minor;
    int  warpSize;
};

static inline CUresult cudaGetDeviceCount(int* n) {
    if (nbEnsureCudaCtx()) { *n = 0; return CUDA_ERROR_NOT_INITIALIZED; }
    return cuDeviceGetCount(n);
}
static inline CUresult cudaGetDevice(int* d) {
    if (nbEnsureCudaCtx()) return CUDA_ERROR_NOT_INITIALIZED;
    *d = (int)nbCudaDevice();
    return CUDA_SUCCESS;
}
static inline CUresult cudaGetDeviceProperties(struct cudaDeviceProp* p, int ordinal) {
    CUdevice dev;
    CUresult e = cuDeviceGet(&dev, ordinal);
    if (e != CUDA_SUCCESS) return e;
    memset(p, 0, sizeof(*p));
    cuDeviceGetName(p->name, sizeof(p->name), dev);
    cuDeviceGetAttribute(&p->multiProcessorCount, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev);
    cuDeviceGetAttribute(&p->major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev);
    cuDeviceGetAttribute(&p->minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev);
    cuDeviceGetAttribute(&p->warpSize, CU_DEVICE_ATTRIBUTE_WARP_SIZE, dev);
    return CUDA_SUCCESS;
}

/* ----- kernel launch -----
 * Kernels live in an embedded fatbin (built by nvcc on Linux, bin2c'd).
 * nbCudaLoadModule() loads it and resolves every kernel's CUfunction
 * by its extern "C" name into the nbfn_* handles below.
 *
 * nbLaunch packs the (by-value copied, hence addressable) arguments
 * into the void* array cuLaunchKernel expects. Argument TYPES at each
 * call site must match the kernel signature exactly: unlike <<<>>>,
 * no implicit conversions happen. Call sites are audited for this. */

int nbCudaLoadModule(void);   /* 0 on success; idempotent */

/* ----- custom stable radix sort (replaces CUB DeviceRadixSort on the
 * driver-API build; implemented in nbody_cuda_win_sort) ----- */
size_t nbWinRadixSortQueryTemp(int nbody);
CUresult nbWinRadixSortPairs(void* d_keys_in, void* d_keys_out,
                             void* d_vals_in, void* d_vals_out,
                             void* d_temp, size_t tempBytes,
                             int nbody, CUstream stream);

#define NB_KERNEL_LIST(X)               \
    X(nbCUDAForceExactKernel)           \
    X(nbCUDABoundingBoxKernel)          \
    X(nbCUDABuildTreeClearKernel)       \
    X(nbCUDAComputeMortonKernel)        \
    X(nbCUDAMortonFusedKernel)          \
    X(nbCUDAMortonSwapCountersKernel)   \
    X(nbCUDAMortonSeedRootKernel)       \
    X(nbCUDASummarizationClearKernel)   \
    X(nbCUDASortKernel)                 \
    X(nbCUDASortIdentityKernel)         \
    X(nbCUDASortSerialDFSKernel)        \
    X(nbCUDAWinSortHistKernel)          \
    X(nbCUDAWinSortScanKernel)          \
    X(nbCUDAWinSortScatterKernel)       \
    X(nbCUDABuildTreeKernel)            \
    X(nbCUDASummarizationKernel)        \
    X(nbCUDAQuadMomentsKernel)          \
    X(nbCUDACellPackKernel)             \
    X(nbCUDAForceTreeKernel)            \
    X(nbCUDAExternalPotentialKernel)    \
    X(nbCUDAIntegrationKernel)

#define NB_DECLARE_FN(k) extern CUfunction nbfn_##k;
NB_KERNEL_LIST(NB_DECLARE_FN)
#undef NB_DECLARE_FN

#ifdef __cplusplus
template <typename... As>
static inline void nbLaunch(CUfunction f, unsigned gx, unsigned bx,
                            size_t shmem, CUstream stream, As... as) {
    void* params[] = { (void*)&as..., NULL };
    nb_last_launch_err = cuLaunchKernel(f, gx, 1, 1, bx, 1, 1,
                                        (unsigned)shmem, stream, params, NULL);
}
#endif

/* Launch macros. The Linux/nvcc build defines these as plain <<<>>>
 * expansions (see nbody_cuda.cu); these are the driver-API versions. */
#define NB_LAUNCH(kern, grid, block, ...) \
    nbLaunch(nbfn_##kern, (unsigned)(grid), (unsigned)(block), 0, (CUstream)0, __VA_ARGS__)
#define NB_LAUNCH_S(kern, grid, block, shmem, stream, ...) \
    nbLaunch(nbfn_##kern, (unsigned)(grid), (unsigned)(block), (size_t)(shmem), (stream), __VA_ARGS__)

#endif /* NBODY_CUDA_DRIVER_API */

#endif /* _NBODY_CUDA_DRIVER_COMPAT_H_ */
