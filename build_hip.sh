#!/usr/bin/env bash
# Build helper for the HIP/AMD milkyway_nbody app.
# Mirrors build_cuda.sh but configures the HIP backend. Uses a separate
# build directory (build_hip/) so the CUDA build is never disturbed.
#
# Usage:
#   ./build_hip.sh [-b BOINC_ROOT] [-r ROCM_PATH] [-a GFX_ARCHS]
#                  [-d BUILD_DIR] [-j N] [-h]
#
# Examples:
#   ./build_hip.sh                       # all defaults (gfx1030 = RDNA2)
#   ./build_hip.sh -a "gfx1030;gfx1100"  # RDNA2 + RDNA3
#   ./build_hip.sh -d build_hip_test -j 16

set -euo pipefail

# ------------------------- defaults (override via flags) ---------------------
BOINC_ROOT="${BOINC_ROOT:-/home/ian/builds/boinc}"
ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
GFX_ARCHS="${GFX_ARCHS:-gfx1030}"
BUILD_DIR="${BUILD_DIR:-build_hip}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -b BOINC_ROOT  Path to BOINC source tree (default: $BOINC_ROOT)
  -r ROCM_PATH   ROCm install prefix (default: $ROCM_PATH)
  -a GFX_ARCHS   Semicolon-separated AMD gfx archs (default: "$GFX_ARCHS")
                 wave32 (RDNA, gfx10xx/gfx11xx) only — CDNA (gfx90a etc.)
                 is wave64 and is rejected at runtime.
  -d BUILD_DIR   Build directory (default: $BUILD_DIR)
  -j N           Parallel make jobs (default: $JOBS)
  -h             Show this help

Common gfx archs:
  gfx1030  RX 6800/6800XT/6900XT     (RDNA2)
  gfx1031  RX 6700XT                 (RDNA2)
  gfx1100  RX 7900XTX/XT             (RDNA3)
  gfx1101  RX 7800XT/7700XT          (RDNA3)
EOF
    exit 0
}

while getopts "b:r:a:d:j:h" opt; do
    case "$opt" in
        b) BOINC_ROOT="$OPTARG" ;;
        r) ROCM_PATH="$OPTARG" ;;
        a) GFX_ARCHS="$OPTARG" ;;
        d) BUILD_DIR="$OPTARG" ;;
        j) JOBS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SOURCE_DIR/$BUILD_DIR"
mkdir -p "$BUILD_DIR"

HIPCC_CLANG="$ROCM_PATH/llvm/bin/clang++"
if [ ! -x "$HIPCC_CLANG" ]; then
    echo "error: $HIPCC_CLANG not found — is ROCm installed at $ROCM_PATH?" >&2
    exit 1
fi

cat <<EOF
===== Build configuration (HIP) =====
  Source:        $SOURCE_DIR
  Build dir:     $BUILD_DIR
  BOINC root:    $BOINC_ROOT
  ROCm:          $ROCM_PATH
  gfx archs:     $GFX_ARCHS
  Parallel jobs: $JOBS
=====================================

EOF

cd "$BUILD_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBOINC_APPLICATION=ON \
    -DBOINC_ROOT="$BOINC_ROOT" \
    -DSEPARATION=OFF \
    -DNBODY=ON \
    -DNBODY_GL=OFF \
    -DNBODY_OPENMP=ON \
    -DNBODY_OPENCL=OFF \
    -DNBODY_CRLIBM=ON \
    -DNBODY_CUDA=OFF \
    -DNBODY_HIP=ON \
    -DNBODY_STATIC=OFF \
    -DCMAKE_HIP_COMPILER="$HIPCC_CLANG" \
    -DCMAKE_HIP_ARCHITECTURES="$GFX_ARCHS" \
    -DCMAKE_PREFIX_PATH="$ROCM_PATH"

echo
echo "===== Configure done — building ====="
echo

cmake --build . -j "$JOBS" --target milkyway_nbody

BIN_PATH="$(realpath "$BUILD_DIR/bin/milkyway_nbody" 2>/dev/null || echo "$PWD/bin/milkyway_nbody")"
cat <<EOF

===== Build complete (HIP) =====
Binary: $BIN_PATH
EOF
ls -la "$BIN_PATH"
