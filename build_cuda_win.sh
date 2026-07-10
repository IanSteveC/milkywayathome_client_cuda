#!/usr/bin/env bash
# Cross-build the CUDA milkyway_nbody app for Windows x64 from Linux.
#
# Pattern follows PrimeGrid ap27's build_win.sh:
#  - kernels: built on Linux by nvcc into ONE multi-arch fatbin (the
#    exact device code the Linux app uses), embedded via bin2c
#  - host: plain C++ over the CUDA *driver* API, compiled by
#    x86_64-w64-mingw32-g++ (NBODY_CUDA_DRIVER_API pass)
#  - nvcuda.dll import lib generated with dlltool -- no Windows CUDA
#    toolkit needed anywhere
#  - BOINC libs cross-built once via BOINC's lib/Makefile.mingw
#
# Usage: ./build_cuda_win.sh [-a SM_ARCHS] [-d BUILD_DIR] [-j N]
set -euo pipefail
cd "$(dirname "$0")"
SOURCE_DIR="$(pwd)"

CUDA="${CUDA:-/usr/local/cuda-12.9}"
BOINC_DIR="${BOINC_DIR:-/home/ian/builds/boinc}"
MINGW="${MINGW:-x86_64-w64-mingw32}"
SM_ARCHS="${SM_ARCHS:-60;61;70;75;80;86;89;90;100f;120f}"
BUILD_DIR="${BUILD_DIR:-build_win_cuda}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

while getopts "a:d:j:h" opt; do
    case "$opt" in
        a) SM_ARCHS="$OPTARG" ;;
        d) BUILD_DIR="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        h) echo "usage: $0 [-a SM_ARCHS] [-d BUILD_DIR] [-j N]"; exit 0 ;;
        *) exit 1 ;;
    esac
done

B="$SOURCE_DIR/$BUILD_DIR"
mkdir -p "$B"

# ---------- 0. BOINC Windows libs (cross-built once, cached) ----------
W="$B/winlibs"
if [ ! -f "$W/libboinc.a" ] || [ ! -f "$W/libboinc_api.a" ]; then
    echo "[boinc] cross-building BOINC libs into $W/"
    mkdir -p "$W/shim"
    cat > "$W/shim/config.h" <<'EOF'
#ifndef BOINC_MINGW_CONFIG_H
#define BOINC_MINGW_CONFIG_H
#define HAVE_STRCASECMP 1
#define HAVE__STRICMP 1
#define HAVE_STRDUP 1
#endif
EOF
    printf '#include <stddef.h>\n#include <string.h>\n#include "%s/lib/str_replace.h"\n' "$BOINC_DIR" > "$W/shim/force.h"
    ( cd "$W" && MINGW="$MINGW" BOINC_SRC="$BOINC_DIR" \
        make -f "$BOINC_DIR/lib/Makefile.mingw" \
          INCS="-I$(pwd)/shim -I$BOINC_DIR -I$BOINC_DIR/db -I$BOINC_DIR/lib -I$BOINC_DIR/api -I$BOINC_DIR/zip -I$BOINC_DIR/win_build" \
          OPTFLAGS="-O3 -include $(pwd)/shim/force.h" \
          libboinc.a libboinc_api.a )
fi

# ---------- 1. nvcuda.dll import library ----------
# Symbol list = every driver-API entry the compat layer uses (versioned
# names as exported by nvcuda.dll). Regenerate with:
#   x86_64-w64-mingw32-nm -u <objs> | grep -oE '\bcu[A-Za-z_0-9]+' | sort -u
cat > "$B/nvcuda.def" <<'EOF'
LIBRARY nvcuda.dll
EXPORTS
cuCtxSetCurrent
cuCtxSynchronize
cuDeviceGet
cuDeviceGetAttribute
cuDeviceGetCount
cuDeviceGetName
cuDevicePrimaryCtxRetain
cuEventCreate
cuEventDestroy_v2
cuEventRecord
cuEventSynchronize
cuGetErrorString
cuGraphDestroy
cuGraphExecDestroy
cuGraphInstantiateWithFlags
cuGraphLaunch
cuInit
cuLaunchKernel
cuMemAllocHost_v2
cuMemAlloc_v2
cuMemFreeHost
cuMemFree_v2
cuMemcpyDtoDAsync_v2
cuMemcpyDtoD_v2
cuMemcpyDtoHAsync_v2
cuMemcpyDtoH_v2
cuMemcpyHtoDAsync_v2
cuMemcpyHtoD_v2
cuMemsetD8_v2
cuModuleGetFunction
cuModuleLoadData
cuStreamBeginCapture_v2
cuStreamCreate
cuStreamDestroy_v2
cuStreamEndCapture
cuStreamSynchronize
cuStreamWaitEvent
EOF
"$MINGW-dlltool" -d "$B/nvcuda.def" -l "$B/libnvcuda.a"
echo "[nvcuda] import library: $B/libnvcuda.a"

# ---------- 2. CMake configure (MinGW toolchain, driver-API host) ----------
cmake -S "$SOURCE_DIR" -B "$B" \
    -DCMAKE_TOOLCHAIN_FILE="$SOURCE_DIR/mingw64-toolchain.cmake" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBOINC_APPLICATION=ON \
    -DBOINC_INCLUDE_DIR="$BOINC_DIR;$BOINC_DIR/api;$BOINC_DIR/lib;$BOINC_DIR/win_build" \
    -DBOINC_LIBRARY="$W/libboinc.a" \
    -DBOINC_API_LIBRARY="$W/libboinc_api.a" \
    -DSEPARATION=OFF -DNBODY=ON -DNBODY_GL=OFF \
    -DNBODY_OPENMP=ON -DNBODY_OPENCL=OFF -DNBODY_CRLIBM=ON \
    -DDOUBLEPREC=ON -DNBODY_STATIC=OFF \
    -DNBODY_CUDA_WIN=ON \
    -DNBODY_CUDA_WIN_INCLUDE="$CUDA/include;$B/gen" \
    -DNBODY_CUDA_WIN_NVCUDA="$B/libnvcuda.a" \
    -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -static-libstdc++"

# ---------- 3. kernels -> multi-arch fatbin -> embedded C array ----------
mkdir -p "$B/gen"
GENCODE=""
IFS=';' read -ra ARCHS <<< "$SM_ARCHS"
LAST="${ARCHS[${#ARCHS[@]}-1]}"
for a in "${ARCHS[@]}"; do
    GENCODE="$GENCODE -gencode=arch=compute_${a},code=sm_${a}"
done
GENCODE="$GENCODE -gencode=arch=compute_${LAST},code=compute_${LAST}"

echo "[fatbin] nvcc -fatbin (archs: $SM_ARCHS)"
"$CUDA/bin/nvcc" -fatbin $GENCODE \
    --fmad=false -Xptxas -dlcm=cv -O3 \
    -DNBODY_CUDA=1 \
    -I "$SOURCE_DIR/nbody/include" -I "$B/include" \
    -o "$B/gen/nbody_cuda.fatbin" \
    "$SOURCE_DIR/nbody/src/nbody_cuda.cu"
"$CUDA/bin/bin2c" --const --type char --name nb_cuda_fatbin \
    "$B/gen/nbody_cuda.fatbin" > "$B/gen/nbody_cuda_fatbin.h"
echo "[bin2c] embedded: $(stat -c%s "$B/gen/nbody_cuda.fatbin") bytes"

# ---------- 4. build ----------
cmake --build "$B" -j "$JOBS" --target milkyway_nbody

EXE="$B/bin/milkyway_nbody.exe"
[ -f "$EXE" ] || EXE="$B/bin/milkyway_nbody"
echo
echo "===== Build complete ====="
ls -la "$EXE"
file "$EXE"
