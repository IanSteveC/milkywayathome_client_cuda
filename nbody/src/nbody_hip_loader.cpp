/*
 * nbody_hip_loader.cpp
 *
 * NBODY_HIP_DYNLOAD only. Resolves the amdhip64 module/driver API at
 * runtime instead of hard-linking an import library. This lets one exe
 * bind whatever the installed AMD stack names its HIP runtime
 * (amdhip64.dll, amdhip64_6.dll, ... on Windows; libamdhip64.so[.N] on
 * Linux), and lets the app run CPU-only when no HIP runtime is present
 * rather than failing to start.
 *
 * The function-pointer set and their signatures come from the single
 * NB_HIP_API list in nbody_hip_shim.h, so this stays in lock-step with
 * the host call sites.
 */

#if defined(NBODY_HIP_DRIVER_API) && defined(NBODY_HIP_DYNLOAD)

#include "nbody_hip_shim.h"
#include <stdio.h>

/* one definition per API entry, initialized null until resolved */
#define NB_HIP_DEF_PTR(ret, name, params) extern "C" ret (*name) params = 0;
NB_HIP_API(NB_HIP_DEF_PTR)
#undef NB_HIP_DEF_PTR

#if defined(_WIN32)
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
   typedef HMODULE nb_dl_t;
   static nb_dl_t nb_dlopen_any(const char* const* names) {
       for (const char* const* n = names; *n; ++n) {
           nb_dl_t h = LoadLibraryA(*n);
           if (h) { fprintf(stderr, "[nbody_hip] loaded runtime: %s\n", *n); return h; }
       }
       return (nb_dl_t)0;
   }
   static void* nb_dlsym(nb_dl_t h, const char* s) { return (void*)GetProcAddress(h, s); }
   static const char* const NB_HIP_DLLS[] = {
       "amdhip64.dll", "amdhip64_6.dll", "amdhip64_7.dll", "amdhip64_5.dll", 0
   };
#else
#  include <dlfcn.h>
   typedef void* nb_dl_t;
   static nb_dl_t nb_dlopen_any(const char* const* names) {
       for (const char* const* n = names; *n; ++n) {
           nb_dl_t h = dlopen(*n, RTLD_NOW | RTLD_GLOBAL);
           if (h) { fprintf(stderr, "[nbody_hip] loaded runtime: %s\n", *n); return h; }
       }
       return (nb_dl_t)0;
   }
   static void* nb_dlsym(nb_dl_t h, const char* s) { return dlsym(h, s); }
   static const char* const NB_HIP_DLLS[] = {
       "libamdhip64.so", "libamdhip64.so.7", "libamdhip64.so.6", 0
   };
#endif

int nbHipLoadRuntime(void) {
    static int state = -1;   /* -1 untried, 0 ok, 1 failed */
    if (state >= 0) return state ? -1 : 0;

    nb_dl_t h = nb_dlopen_any(NB_HIP_DLLS);
    if (!h) {
        fprintf(stderr, "[nbody_hip] no HIP runtime found (amdhip64) - GPU unavailable\n");
        state = 1;
        return -1;
    }

    int missing = 0;
#define NB_HIP_RESOLVE(ret, name, params)                                   \
    name = (ret (*) params) nb_dlsym(h, #name);                             \
    if (!name) { fprintf(stderr, "[nbody_hip] missing symbol: %s\n", #name); missing++; }
    NB_HIP_API(NB_HIP_RESOLVE)
#undef NB_HIP_RESOLVE

    if (missing) {
        fprintf(stderr, "[nbody_hip] %d HIP symbol(s) unresolved\n", missing);
        state = 1;
        return -1;
    }
    state = 0;
    return 0;
}

#endif /* NBODY_HIP_DRIVER_API && NBODY_HIP_DYNLOAD */
