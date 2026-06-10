#!/usr/bin/env bash
# Build helper for the HIP/AMD milkyway_nbody app.
# Mirrors build_cuda.sh but configures the HIP backend. Uses a separate
# build directory (build_hip/) so the CUDA build is never disturbed.
# After a successful build, assembles build_hip/dist/ containing the
# binary plus the ROCm runtime libraries it must ship with.
#
# Usage:
#   ./build_hip.sh [-b BOINC_ROOT] [-r ROCM_PATH] [-a GFX_ARCHS]
#                  [-d BUILD_DIR] [-j N] [-h]
#
# Examples:
#   ./build_hip.sh                       # all defaults (16-arch list)
#   ./build_hip.sh -a "gfx1030"          # quick single-arch dev build
#   ./build_hip.sh -d build_hip_test -j 16

set -euo pipefail

# ------------------------- defaults (override via flags) ---------------------
BOINC_ROOT="${BOINC_ROOT:-/home/ian/builds/boinc}"
ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
# Default arch list: the 15 arches shipped by Einstein@home's
# eah_HierarchSearchGCT_hip app, plus gfx90a (CDNA2 / MI200-series).
# wave64 arches (gfx906, gfx908, gfx90a) are compile-verified but not
# yet validated on wave64 silicon.
GFX_ARCHS="${GFX_ARCHS:-gfx906;gfx908;gfx90a;gfx1010;gfx1012;gfx1030;gfx1031;gfx1032;gfx1034;gfx1035;gfx1100;gfx1101;gfx1102;gfx1103;gfx1200;gfx1201}"
BUILD_DIR="${BUILD_DIR:-build_hip}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
# -----------------------------------------------------------------------------

usage() {
    cat <<USAGE
Usage: $0 [options]

Options:
  -b BOINC_ROOT  Path to BOINC source tree (default: $BOINC_ROOT)
  -r ROCM_PATH   ROCm install prefix (default: $ROCM_PATH)
  -a GFX_ARCHS   Semicolon-separated AMD gfx archs (default: 16-arch list
                 matching Einstein's HIP app + gfx90a/CDNA2)
  -d BUILD_DIR   Build directory (default: $BUILD_DIR)
  -j N           Parallel make jobs (default: $JOBS)
  -h             Show this help

Common gfx archs:
  gfx906   Radeon VII / MI50          (Vega20, wave64)
  gfx908   MI100                      (CDNA1,  wave64)
  gfx90a   MI210/MI250                (CDNA2,  wave64)
  gfx1030  RX 6800/6800XT/6900XT      (RDNA2,  wave32)
  gfx1100  RX 7900XTX/XT              (RDNA3,  wave32)
  gfx1200  RX 9070 series             (RDNA4,  wave32)
USAGE
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

cat <<INFO
===== Build configuration (HIP) =====
  Source:        $SOURCE_DIR
  Build dir:     $BUILD_DIR
  BOINC root:    $BOINC_ROOT
  ROCm:          $ROCM_PATH
  gfx archs:     $GFX_ARCHS
  Parallel jobs: $JOBS
=====================================

INFO

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

# ---- dist/: binary + the ROCm runtime libs that must ship with it ----
# No static HIP runtime exists (unlike CUDA's cudart_static), so the
# app depends on libamdhip64 & friends. Resolve the binary's actual
# /opt/rocm-owned dependencies via ldd and copy them (versioned file +
# SONAME symlink) next to the binary. The binary is linked with
# -rpath \$ORIGIN, so it prefers these bundled copies and falls back
# to a host ROCm install when absent. libdrm*/libelf/libnuma come from
# the host's GPU driver / distro and are intentionally NOT bundled.
# Selective refresh: remove only the files this script manages, so
# user-added deployment files (wrapper script, app_info.xml, conf,
# renamed binary copies) survive rebuilds.
DIST_DIR="$BUILD_DIR/dist"
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/milkyway_nbody" "$DIST_DIR"/lib*.so* "$DIST_DIR/README.txt"
cp -f "$BIN_PATH" "$DIST_DIR/"

# Warn about stale renamed binary copies the user may be deploying.
for f in "$DIST_DIR"/milkyway_nbody_*; do
    [ -f "$f" ] && [ -x "$f" ] && \
        echo "NOTE: $f is from a previous build — re-copy from $DIST_DIR/milkyway_nbody if you deploy under that name."
done

# Copy each ROCm lib under its SONAME directly (the only name the
# loader asks for). No symlinks — BOINC file distribution doesn't
# preserve them and the versioned filename is never looked up.
ldd "$BIN_PATH" | awk '$3 ~ /^\/opt\/rocm/ { print $3 }' | while read -r lib; do
    cp -f "$(realpath "$lib")" "$DIST_DIR/$(basename "$lib")"
done

cat > "$DIST_DIR/README.txt" <<'RDME'
milkyway_nbody HIP/AMD app + bundled ROCm runtime libraries.

Deploy all files in this directory together (BOINC app version dir or
anonymous-platform project dir). The binary's rpath is $ORIGIN, so it
loads the bundled libs from its own directory first.

Host requirements: amdgpu kernel driver with ROCm/KFD compute support
and the usual GPU userspace (libdrm). No ROCm installation needed.
RDME

cat <<DONE

===== Build complete (HIP) =====
Binary: $BIN_PATH
Dist:   $DIST_DIR
DONE
ls -la "$DIST_DIR"
