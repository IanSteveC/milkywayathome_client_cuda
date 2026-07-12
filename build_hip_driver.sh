#!/usr/bin/env bash
# Native-Linux HIP module-API validation harness.
#
# Proves the whole Windows-HIP pipeline except the Windows PAL runtime:
# the device code object is built by hipcc --genco (exactly what the
# Windows app embeds), and the host is the driver-API path (the same
# code the MinGW build uses) compiled with native gcc and linked against
# libamdhip64.so. A bit-exact gate against the normal HIP app on real
# AMD hardware validates the code object + module-API host together.
#
# Usage: ./build_hip_driver.sh [-a GFX] [-d BUILD_DIR] [-j N]
set -euo pipefail

BOINC_ROOT="${BOINC_ROOT:-/home/ian/builds/boinc}"
ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
GFX="${GFX:-gfx1030}"
BUILD_DIR="${BUILD_DIR:-build_hip_driver}"
JOBS="${JOBS:-$(nproc)}"

while getopts "a:d:j:h" o; do case "$o" in
    a) GFX="$OPTARG" ;;
    d) BUILD_DIR="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    h) echo "usage: $0 [-a GFX] [-d BUILD_DIR] [-j N]"; exit 0 ;;
esac; done

SRC="$(cd "$(dirname "$0")" && pwd)"
B="$SRC/$BUILD_DIR"
HIPCC="$ROCM_PATH/bin/hipcc"
HIPLIB="$ROCM_PATH/lib/libamdhip64.so"
mkdir -p "$B/gen"

INCS="-I$B/include -I$BOINC_ROOT -I$BOINC_ROOT/api -I$BOINC_ROOT/lib \
 -I$SRC/popt/include -I$SRC/lua/include -I$SRC/milkyway/include \
 -I$SRC/dSFMT -I$SRC/nbody/include -I$SRC/crlibm -I$SRC/openpa/include"

# ---------- 1. configure (native gcc host, HIP module-API path) ----------
# NBODY_HIP_WIN -> NBODY_CUDA_WIN + NBODY_HIP_DRIVER_API. The gen dir must
# exist at configure time (fatbin header is #included by the host TU).
if [ ! -f "$B/gen/nbody_cuda_fatbin.h" ]; then
    echo 'const unsigned char nb_cuda_fatbin[1] = {0};' > "$B/gen/nbody_cuda_fatbin.h"
fi
if [ ! -f "$B/CMakeCache.txt" ]; then
  cmake -S "$SRC" -B "$B" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=/usr/bin/cc -DCMAKE_CXX_COMPILER=/usr/bin/c++ \
    -DBOINC_APPLICATION=ON -DBOINC_ROOT="$BOINC_ROOT" \
    -DSEPARATION=OFF -DNBODY=ON -DNBODY_GL=OFF \
    -DNBODY_OPENMP=ON -DNBODY_OPENCL=OFF -DNBODY_CRLIBM=ON \
    -DDOUBLEPREC=ON -DNBODY_STATIC=OFF \
    -DNBODY_HIP_WIN=ON \
    -DNBODY_CUDA_WIN_INCLUDE="$B/gen" \
    -DNBODY_CUDA_WIN_NVCUDA="dl"
fi

# ---------- 2. device code object via hipcc --genco ----------
echo "[genco] hipcc --genco --offload-arch=$GFX (-DNBODY_HIP_GENCO)"
"$HIPCC" --genco --offload-arch="$GFX" \
    -ffp-contract=off -O3 -DNDEBUG -std=gnu++17 -fPIC \
    -DDOUBLEPREC=1 -DDSFMT_MEXP=19937 -D__HIP_ROCclr__=1 -DNBODY_HIP_GENCO \
    $INCS \
    -o "$B/gen/nbody_hip.co" "$SRC/nbody/src/nbody_cuda.cu"
python3 "$SRC/tools/bin2c.py" "$B/gen/nbody_hip.co" nb_cuda_fatbin > "$B/gen/nbody_cuda_fatbin.h"
echo "[bin2c] embedded $(stat -c%s "$B/gen/nbody_hip.co") bytes"

# ---------- 3. build host ----------
cmake --build "$B" -j "$JOBS" --target milkyway_nbody
echo "==== built: $B/bin/milkyway_nbody ===="
