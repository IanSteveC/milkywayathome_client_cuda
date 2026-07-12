/*
 * nbody_hip_shim.h
 *
 * Windows/MinGW HIP host build ONLY (NBODY_HIP_DRIVER_API). Hand-declared
 * minimal HIP module/driver API so the MinGW host pass never includes any
 * ROCm header -- the same discipline the CUDA Windows build uses with
 * cuda.h. amdhip64.dll exports these C symbols on Windows exactly as
 * libamdhip64.so does on Linux (HIP is a single portable C ABI).
 *
 * The driver-API host code (nbody_cuda_driver_compat.h, _driver_runtime,
 * _win_sort, and the driver Eval blocks in nbody_cuda.cu) is written
 * against the CUDA driver API (cu-star / CU-star names). HIP mirrors that
 * API almost one-to-one, so this header aliases every such token those
 * files use onto its hip equivalent: mostly #defines, with wrappers for the
 * few calls whose signatures differ (error string, graph instantiate,
 * host alloc/free).
 *
 * Enum integer values are HIP's own (read from ROCm 7.2 headers) and are
 * validated against a live runtime on Linux (build_hip_driver harness)
 * before shipping: the harness confirms hipDeviceGetAttribute(WARP_SIZE)
 * returns the true wavefront size on real hardware.
 */

#ifndef NBODY_HIP_SHIM_H
#define NBODY_HIP_SHIM_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ----- handle + scalar types ----- */
typedef int   hipError_t;
typedef int   hipDevice_t;        /* CUdevice analog (ordinal) */
typedef void* hipDeviceptr_t;
typedef void* hipCtx_t;
typedef void* hipModule_t;
typedef void* hipFunction_t;
typedef void* hipStream_t;
typedef void* hipEvent_t;
typedef void* hipGraph_t;
typedef void* hipGraphExec_t;
typedef int   hipStreamCaptureMode;
typedef int   hipDeviceAttribute_t;

/* ----- constants (ROCm 7.2 enum values) ----- */
#define hipSuccess                                0
#define hipErrorInvalidValue                      1
#define hipErrorNotInitialized                    3
#define hipEventDisableTiming                     2
#define hipStreamCaptureModeThreadLocal           1
#define hipHostMallocDefault                      0
#define hipDeviceAttributeComputeCapabilityMajor  23
#define hipDeviceAttributeComputeCapabilityMinor  61
#define hipDeviceAttributeMultiprocessorCount     63
#define hipDeviceAttributeWarpSize                87

/* ----- the amdhip64 C ABI this host uses, as one X-macro list -----
 * NB_HIP_API(_) expands _(ret, name, (paramtypes)) per function. Used to
 * declare the surface here and (in the loader TU) to define pointers and
 * resolve them. Direct-link builds get plain prototypes; NBODY_HIP_DYNLOAD
 * builds get function pointers filled in at runtime from the DLL/.so, so
 * the app never hard-links a specific amdhip64 name and runs CPU-only when
 * no HIP runtime is present. */
#define NB_HIP_API(_) \
  _(hipError_t,  hipInit,                  (unsigned int)) \
  _(hipError_t,  hipDeviceGet,             (hipDevice_t*, int)) \
  _(hipError_t,  hipGetDeviceCount,        (int*)) \
  _(hipError_t,  hipDeviceGetName,         (char*, int, hipDevice_t)) \
  _(hipError_t,  hipDeviceGetAttribute,    (int*, hipDeviceAttribute_t, hipDevice_t)) \
  _(hipError_t,  hipDevicePrimaryCtxRetain,(hipCtx_t*, hipDevice_t)) \
  _(hipError_t,  hipCtxSetCurrent,         (hipCtx_t)) \
  _(hipError_t,  hipDeviceSynchronize,     (void)) \
  _(hipError_t,  hipModuleLoadData,        (hipModule_t*, const void*)) \
  _(hipError_t,  hipModuleGetFunction,     (hipFunction_t*, hipModule_t, const char*)) \
  _(hipError_t,  hipModuleLaunchKernel,    (hipFunction_t, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int, hipStream_t, void**, void**)) \
  _(const char*, hipGetErrorString,        (hipError_t)) \
  _(hipError_t,  hipMalloc,                (void**, size_t)) \
  _(hipError_t,  hipFree,                  (void*)) \
  _(hipError_t,  hipHostMalloc,            (void**, size_t, unsigned int)) \
  _(hipError_t,  hipHostFree,              (void*)) \
  _(hipError_t,  hipMemcpyHtoD,            (hipDeviceptr_t, const void*, size_t)) \
  _(hipError_t,  hipMemcpyDtoH,            (void*, hipDeviceptr_t, size_t)) \
  _(hipError_t,  hipMemcpyHtoDAsync,       (hipDeviceptr_t, const void*, size_t, hipStream_t)) \
  _(hipError_t,  hipMemcpyDtoHAsync,       (void*, hipDeviceptr_t, size_t, hipStream_t)) \
  _(hipError_t,  hipMemcpyDtoD,            (hipDeviceptr_t, hipDeviceptr_t, size_t)) \
  _(hipError_t,  hipMemcpyDtoDAsync,       (hipDeviceptr_t, hipDeviceptr_t, size_t, hipStream_t)) \
  _(hipError_t,  hipMemsetD8,              (hipDeviceptr_t, unsigned char, size_t)) \
  _(hipError_t,  hipStreamCreateWithFlags, (hipStream_t*, unsigned int)) \
  _(hipError_t,  hipStreamDestroy,         (hipStream_t)) \
  _(hipError_t,  hipStreamSynchronize,     (hipStream_t)) \
  _(hipError_t,  hipStreamWaitEvent,       (hipStream_t, hipEvent_t, unsigned int)) \
  _(hipError_t,  hipStreamBeginCapture,    (hipStream_t, hipStreamCaptureMode)) \
  _(hipError_t,  hipStreamEndCapture,      (hipStream_t, hipGraph_t*)) \
  _(hipError_t,  hipEventCreateWithFlags,  (hipEvent_t*, unsigned int)) \
  _(hipError_t,  hipEventRecord,           (hipEvent_t, hipStream_t)) \
  _(hipError_t,  hipEventSynchronize,      (hipEvent_t)) \
  _(hipError_t,  hipEventDestroy,          (hipEvent_t)) \
  _(hipError_t,  hipGraphInstantiate,      (hipGraphExec_t*, hipGraph_t, void*, void*, size_t)) \
  _(hipError_t,  hipGraphLaunch,           (hipGraphExec_t, hipStream_t)) \
  _(hipError_t,  hipGraphExecDestroy,      (hipGraphExec_t)) \
  _(hipError_t,  hipGraphDestroy,          (hipGraph_t))

#if defined(NBODY_HIP_DYNLOAD)
/* runtime-resolved function pointers (defined in nbody_hip_loader.cpp) */
#define NB_HIP_DECL_PTR(ret, name, params) extern ret (*name) params;
NB_HIP_API(NB_HIP_DECL_PTR)
#undef NB_HIP_DECL_PTR
int nbHipLoadRuntime(void);   /* 0 on success; LoadLibrary/dlopen + resolve */
#else
/* direct-link prototypes (Linux validation harness links libamdhip64.so) */
#define NB_HIP_DECL_FN(ret, name, params) ret name params;
NB_HIP_API(NB_HIP_DECL_FN)
#undef NB_HIP_DECL_FN
#endif

#ifdef __cplusplus
}
#endif

/* ----- CU* type aliases used by the driver host code ----- */
typedef hipError_t           CUresult;
typedef hipDevice_t          CUdevice;
typedef hipDeviceptr_t       CUdeviceptr;
typedef hipCtx_t             CUcontext;
typedef hipModule_t          CUmodule;
typedef hipFunction_t        CUfunction;
typedef hipStream_t          CUstream;
typedef hipEvent_t           CUevent;
typedef hipGraph_t           CUgraph;
typedef hipGraphExec_t       CUgraphExec;
typedef hipStreamCaptureMode CUstreamCaptureMode;

/* ----- constant aliases ----- */
#define CUDA_SUCCESS                                 hipSuccess
#define CUDA_ERROR_INVALID_VALUE                     hipErrorInvalidValue
#define CUDA_ERROR_NOT_INITIALIZED                   hipErrorNotInitialized
#define CU_EVENT_DISABLE_TIMING                      hipEventDisableTiming
#define CU_STREAM_CAPTURE_MODE_THREAD_LOCAL          hipStreamCaptureModeThreadLocal
#define CU_STREAM_DEFAULT                            0u
#define CU_DEVICE_ATTRIBUTE_WARP_SIZE                hipDeviceAttributeWarpSize
#define CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT     hipDeviceAttributeMultiprocessorCount
#define CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR hipDeviceAttributeComputeCapabilityMajor
#define CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR hipDeviceAttributeComputeCapabilityMinor

/* ----- function aliases (identical signatures) ----- */
#define cuInit                    hipInit
#define cuDeviceGet               hipDeviceGet
#define cuDeviceGetCount          hipGetDeviceCount
#define cuDeviceGetName           hipDeviceGetName
#define cuDeviceGetAttribute      hipDeviceGetAttribute
#define cuDevicePrimaryCtxRetain  hipDevicePrimaryCtxRetain
#define cuCtxSetCurrent           hipCtxSetCurrent
#define cuCtxSynchronize          hipDeviceSynchronize
#define cuModuleLoadData          hipModuleLoadData
#define cuModuleGetFunction       hipModuleGetFunction
#define cuLaunchKernel            hipModuleLaunchKernel
#define cuMemAlloc                hipMalloc
#define cuMemFree                 hipFree
#define cuMemHostAlloc            hipHostMalloc
#define cuMemcpyHtoD              hipMemcpyHtoD
#define cuMemcpyDtoH              hipMemcpyDtoH
#define cuMemcpyHtoDAsync         hipMemcpyHtoDAsync
#define cuMemcpyDtoHAsync         hipMemcpyDtoHAsync
#define cuMemcpyDtoD              hipMemcpyDtoD
#define cuMemcpyDtoDAsync         hipMemcpyDtoDAsync
#define cuMemsetD8                hipMemsetD8
#define cuStreamCreate            hipStreamCreateWithFlags
#define cuStreamDestroy           hipStreamDestroy
#define cuStreamSynchronize       hipStreamSynchronize
#define cuStreamWaitEvent         hipStreamWaitEvent
#define cuStreamBeginCapture      hipStreamBeginCapture
#define cuStreamEndCapture        hipStreamEndCapture
#define cuEventCreate             hipEventCreateWithFlags
#define cuEventRecord             hipEventRecord
#define cuEventSynchronize        hipEventSynchronize
#define cuEventDestroy            hipEventDestroy
#define cuGraphLaunch             hipGraphLaunch
#define cuGraphExecDestroy        hipGraphExecDestroy
#define cuGraphDestroy            hipGraphDestroy

/* ----- wrappers (signatures differ from the CUDA driver API) ----- */
static inline hipError_t nbHipMemAllocHost(void** p, size_t n) {
    return hipHostMalloc(p, n, hipHostMallocDefault);
}
#define cuMemAllocHost            nbHipMemAllocHost

static inline hipError_t nbHipMemFreeHost(void* p) {
    return hipHostFree(p);
}
#define cuMemFreeHost             nbHipMemFreeHost

static inline hipError_t nbHipGetErrorString(hipError_t e, const char** s) {
    *s = hipGetErrorString(e);
    return hipSuccess;
}
#define cuGetErrorString          nbHipGetErrorString

static inline hipError_t nbHipGraphInstantiate(hipGraphExec_t* ge, hipGraph_t g,
                                               unsigned long long flags) {
    (void)flags;
    return hipGraphInstantiate(ge, g, (void*)0, (void*)0, 0);
}
#define cuGraphInstantiate        nbHipGraphInstantiate

#endif /* NBODY_HIP_SHIM_H */
