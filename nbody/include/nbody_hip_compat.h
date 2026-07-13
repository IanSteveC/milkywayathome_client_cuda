/*
 * nbody_hip_compat.h — CUDA → HIP portability layer for nbody_cuda.cu.
 *
 * Included ONLY when compiling the GPU translation unit with hipcc for
 * AMD (__HIP__). The NVIDIA/CUDA build never sees this
 * file, so the CUDA build process is unchanged.
 *
 * Strategy: nbody_cuda.cu is written in the CUDA dialect; everything it
 * uses has a 1:1 HIP equivalent. We map the host-API names with macros
 * and provide a minimal cub::DeviceRadixSort shim backed by rocPRIM
 * (which has decomposer support for our 128-bit Morton key; hipCUB in
 * ROCm 7.2 does not). Kernel-side intrinsics (__shfl_sync, __ballot_sync,
 * __any_sync, __all_sync, __syncwarp, __ldg, __threadfence*, atomics)
 * are provided natively by ROCm >= 6.2 and need no mapping.
 *
 * Wavefront size: the per-lane tree walk's RESULTS are warp-width
 * agnostic by design (each lane accumulates exactly the cells it
 * accepts, in tree-DFS order; the warp vote only steers traversal).
 * However the 32-bit masks and threadIdx/32 indexing assume 32-lane
 * execution, so we require wave32 (RDNA gfx10+). A runtime check in
 * the device-init path rejects wave64 (CDNA) devices until the masks
 * are parameterized.
 */

#ifndef _NBODY_HIP_COMPAT_H_
#define _NBODY_HIP_COMPAT_H_

#if !defined(__HIP__)
#  error "nbody_hip_compat.h must only be included in HIP/AMD builds"
#endif

#include <hip/hip_runtime.h>

/* rocPRIM radix sort with decomposer support (for Morton128 keys). */
#include <rocprim/device/device_radix_sort.hpp>

/* ----- host API: types ----- */
#define cudaError_t       hipError_t
#define cudaStream_t      hipStream_t
#define cudaEvent_t       hipEvent_t
#define cudaGraph_t       hipGraph_t
#define cudaGraphExec_t   hipGraphExec_t
#define cudaDeviceProp    hipDeviceProp_t

/* ----- host API: enums / constants ----- */
#define cudaSuccess                      hipSuccess
#define cudaMemcpyHostToDevice           hipMemcpyHostToDevice
#define cudaMemcpyDeviceToHost           hipMemcpyDeviceToHost
#define cudaEventDisableTiming           hipEventDisableTiming
#define cudaStreamCaptureModeThreadLocal hipStreamCaptureModeThreadLocal

/* ----- host API: functions ----- */
#define cudaDeviceSynchronize    hipDeviceSynchronize
#define cudaEventCreateWithFlags hipEventCreateWithFlags
#define cudaEventDestroy         hipEventDestroy
#define cudaEventRecord          hipEventRecord
#define cudaEventSynchronize     hipEventSynchronize
#define cudaFree                 hipFree
#define cudaFreeHost             hipHostFree
#define cudaGetDevice            hipGetDevice
#define cudaGetDeviceCount       hipGetDeviceCount
#define cudaGetDeviceProperties  hipGetDeviceProperties
#define cudaSetDevice            hipSetDevice
#define cudaGetErrorString       hipGetErrorString
#define cudaGetLastError         hipGetLastError
#define cudaGraphDestroy         hipGraphDestroy
#define cudaGraphExecDestroy     hipGraphExecDestroy
#define cudaGraphInstantiate     hipGraphInstantiate
#define cudaGraphLaunch          hipGraphLaunch
#define cudaMalloc               hipMalloc
/* hipHostMalloc's flags parameter defaults to 0 in C++, matching
 * cudaMallocHost's 2-arg form. */
#define cudaMallocHost           hipHostMalloc
#define cudaMemcpy               hipMemcpy
#define cudaMemcpyAsync          hipMemcpyAsync
#define cudaMemset               hipMemset
#define cudaStreamBeginCapture   hipStreamBeginCapture
#define cudaStreamCreate         hipStreamCreate
#define cudaStreamDestroy        hipStreamDestroy
#define cudaStreamEndCapture     hipStreamEndCapture
#define cudaStreamSynchronize    hipStreamSynchronize
#define cudaStreamWaitEvent      hipStreamWaitEvent

/* ----- cub::DeviceRadixSort shim backed by rocPRIM -----
 *
 * Keeps the two SortPairs call sites in nbody_cuda.cu byte-identical
 * between the CUDA and HIP builds. rocPRIM's decomposer overload has
 * the same argument order as CUB's:
 *   (temp, bytes, keys_in, keys_out, vals_in, vals_out, n,
 *    decomposer, begin_bit, end_bit, stream)
 * and the same tuple convention (leftmost element = most significant).
 * rocPRIM's radix sort is stable, like CUB's — required for the
 * deterministic Morton tree build. */
namespace cub
{
struct DeviceRadixSort
{
    template <class K, class V, class Dec>
    static hipError_t SortPairs(void*        d_temp_storage,
                                size_t&      temp_storage_bytes,
                                const K*     d_keys_in,
                                K*           d_keys_out,
                                const V*     d_values_in,
                                V*           d_values_out,
                                int          num_items,
                                Dec          decomposer,
                                unsigned int begin_bit,
                                unsigned int end_bit,
                                hipStream_t  stream = 0)
    {
        return ::rocprim::radix_sort_pairs(d_temp_storage,
                                           temp_storage_bytes,
                                           d_keys_in,
                                           d_keys_out,
                                           d_values_in,
                                           d_values_out,
                                           num_items,
                                           decomposer,
                                           begin_bit,
                                           end_bit,
                                           stream);
    }
};
} /* namespace cub */

#endif /* _NBODY_HIP_COMPAT_H_ */
