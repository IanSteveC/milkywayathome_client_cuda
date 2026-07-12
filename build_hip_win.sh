#!/usr/bin/env bash
# Cross-build the HIP (AMD) milkyway_nbody app for Windows x64 from Linux.
#
# Same structure as build_cuda_win.sh, HIP backend:
#  - device kernels: hipcc --genco on Linux into ONE multi-arch code
#    object (the exact GPU code the Linux HIP app runs), embedded via
#    tools/bin2c.py
#  - host: the driver-API host path compiled by x86_64-w64-mingw32-g++,
#    with the CUDA driver API mapped to the HIP module API via
#    nbody_hip_shim.h (NBODY_HIP_DRIVER_API)
#  - amdhip64 resolved at runtime (LoadLibrary + GetProcAddress,
#    NBODY_HIP_DYNLOAD) -- no import lib, binds whatever the installed
#    AMD driver names its HIP runtime, and runs CPU-only without one
#  - BOINC winlibs cross-built once via BOINC's lib/Makefile.mingw
#
# Usage: ./build_hip_win.sh [-a "gfxA;gfxB"] [-d BUILD_DIR] [-j N]
set -euo pipefail
cd "$(dirname "$0")"
SOURCE_DIR="$(pwd)"

ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
BOINC_DIR="${BOINC_DIR:-/home/ian/builds/boinc}"
MINGW="${MINGW:-x86_64-w64-mingw32}"
GFX_ARCHS="${GFX_ARCHS:-gfx906;gfx908;gfx90a;gfx1010;gfx1012;gfx1030;gfx1031;gfx1032;gfx1034;gfx1035;gfx1100;gfx1101;gfx1102;gfx1103;gfx1200;gfx1201}"
BUILD_DIR="${BUILD_DIR:-build_win_hip}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

while getopts "a:d:j:h" opt; do
    case "$opt" in
        a) GFX_ARCHS="$OPTARG" ;;
        d) BUILD_DIR="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        h) echo "usage: $0 [-a GFX_ARCHS] [-d BUILD_DIR] [-j N]"; exit 0 ;;
        *) exit 1 ;;
    esac
done

B="$SOURCE_DIR/$BUILD_DIR"
HIPCC="$ROCM_PATH/bin/hipcc"
mkdir -p "$B/gen"

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

# ---------- 1. CMake configure (MinGW toolchain, HIP module-API host) ----------
# NBODY_HIP_WIN -> NBODY_CUDA_WIN + NBODY_HIP_DRIVER_API + NBODY_HIP_DYNLOAD.
# No import lib: LoadLibrary/GetProcAddress live in kernel32 (auto-linked).
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
    -DNBODY_HIP_WIN=ON \
    -DNBODY_CUDA_WIN_INCLUDE="$B/gen" \
    -DNBODY_CUDA_WIN_NVCUDA="" \
    -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -static-libstdc++"

# ---------- 2. device kernels -> multi-arch HIP code object -> C array ----------
# Same device translation unit and flags as the validated Linux build
# (build_hip_driver.sh); the code object is GPU ISA and host-OS neutral,
# so the Windows exe runs bit-identical device code. -DNBODY_HIP_GENCO
# compiles the wavefront-agnostic WinSort kernels (the MinGW host cannot
# orchestrate rocPRIM).
OFFLOAD=""
IFS=';' read -ra ARCHS <<< "$GFX_ARCHS"
for a in "${ARCHS[@]}"; do OFFLOAD="$OFFLOAD --offload-arch=$a"; done
INCS="-I$B/include -I$BOINC_DIR -I$BOINC_DIR/api -I$BOINC_DIR/lib \
 -I$SOURCE_DIR/popt/include -I$SOURCE_DIR/lua/include -I$SOURCE_DIR/milkyway/include \
 -I$SOURCE_DIR/dSFMT -I$SOURCE_DIR/nbody/include -I$SOURCE_DIR/crlibm -I$SOURCE_DIR/openpa/include"
echo "[genco] hipcc --genco (arches: $GFX_ARCHS)"
"$HIPCC" --genco $OFFLOAD \
    -ffp-contract=off -O3 -DNDEBUG -std=gnu++17 -fPIC \
    -DDOUBLEPREC=1 -DDSFMT_MEXP=19937 -D__HIP_ROCclr__=1 -DNBODY_HIP_GENCO \
    $INCS \
    -o "$B/gen/nbody_hip.co" "$SOURCE_DIR/nbody/src/nbody_cuda.cu"
python3 "$SOURCE_DIR/tools/bin2c.py" "$B/gen/nbody_hip.co" nb_cuda_fatbin > "$B/gen/nbody_cuda_fatbin.h"
echo "[bin2c] embedded: $(stat -c%s "$B/gen/nbody_hip.co") bytes"

# ---------- 3. build ----------
cmake --build "$B" -j "$JOBS" --target milkyway_nbody

EXE="$B/bin/milkyway_nbody.exe"
[ -f "$EXE" ] || EXE="$B/bin/milkyway_nbody"
echo
echo "===== Build complete ====="
ls -la "$EXE"
file "$EXE"
