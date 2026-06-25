# Milkyway@Home N-body — CUDA / HIP GPU port (optimized)

A GPU port of the [Milkyway@Home](https://github.com/Milkyway-at-home/milkywayathome_client)
N-body client. The simulation runs entirely on the GPU (Barnes–Hut tree
with quadrupole moments), producing results **bit-identical to the CPU
reference** so they validate against the project.

This is the **`cuda-port-optimization`** branch — the optimized,
production-oriented version. It targets NVIDIA GPUs via **CUDA** and AMD
GPUs via **HIP** from a single source tree.

> Looking for the simplest, most faithful version? See the
> **[`cuda-port`](../../tree/cuda-port)** branch — a direct,
> minimally-modified CUDA translation of the OpenCL/CPU code (CUDA only,
> legacy tree builder). This branch starts from that port and adds the
> performance, determinism, and portability work summarized below.

---

## What's in this branch

Everything in the faithful `cuda-port`, plus:

- **NVIDIA (CUDA)** and **AMD (HIP)** backends from one `nbody_cuda.cu`
  source. The CUDA build is never disturbed by the HIP build (separate
  build dirs, all HIP code behind `__HIP__` / `NBODY_HIP` gates).
- A **deterministic** GPU tree builder (Morton) — same result every run.
- A **faster** force walk — ~8% off the long-workunit wall time on a V100.
- All of it **bit-identical to the CPU reference** and to the legacy tree
  path; that invariant is enforced on every change (see
  [`CUDA_OPTIMIZATIONS.md`](CUDA_OPTIMIZATIONS.md)).

## Optimization summary

High-level overview. Full per-commit detail, benchmarks, and the list of
ideas that were tried and reverted is in
[`CUDA_OPTIMIZATIONS.md`](CUDA_OPTIMIZATIONS.md).

| Area | What changed | Effect |
|------|--------------|--------|
| **Deterministic tree build (Morton)** | Replaced the legacy `atomicCAS` buildTree (whose cell-allocation order depended on warp scheduling) with a Sort → level-by-level fused-kernel build using a 128-bit Morton key and CUB radix sort. Default on; set `NBODY_BUILDTREE_MORTON=0` to fall back to legacy. | Bit-identical to legacy **and deterministic across runs**; slightly faster. |
| **forceTree memory layout** | forceTree is ~92% of GPU time. Mega-packed each cell's `pos+mass+critRadii+quad` into one 128-byte/cell array so every per-cell read hits a single cache line; `__ldg` body reads; warp-shuffle leader broadcast; removed dead shared-memory quad stacks (–9.7 KB shared/block). | Biggest perf bucket; long-WU walk ~8% faster, lower register & shared-mem pressure. |
| **CUDA graphs** | Captured the full Morton tree-build pipeline (~50 launches) into a single replayed graph. | Removes per-step launch overhead on the build phase. |
| **Fewer syncs / checkpoints** | Dropped per-kernel `cudaDeviceSynchronize` (rely on stream ordering); raised CUDA checkpoint cadence 50 → 500 steps. | Less host/device round-tripping. |
| **HIP / AMD backend** | Single-source port compiling under `hipcc`; `nbody_hip_compat.h` maps the CUDA host API to HIP and shims `cub::DeviceRadixSort` onto rocPRIM. 16-arch fat binary (RDNA wave32 + CDNA/Vega wave64), `dist/` packaging that bundles the ROCm runtime libs with an `$ORIGIN` rpath. | Runs on AMD GPUs; verified bit-identical on RX 6800 XT (gfx1030). |
| **Deep-tree correctness** | Raised `NBODY_CUDA_MAXDEPTH` 26 → 41 (the old cap silently dropped a body on deep trees, the long-WU divergence root cause); surfaced the device `errorCode`; added `--abort-nsteps`. | Long workunits now bit-identical to CPU. |
| **Multi-GPU + broad arch coverage** | Multi-GPU dispatch wrapper; default CUDA fatbin spans SM 6.0–9.0/100/120 and HIP spans 16 gfx archs. | One binary runs across the fleet. |

### Determinism & precision invariants

Every optimization here preserves two hard rules: **bit-identical to the
legacy CUDA tree path** on the reference workunits, and **deterministic
across runs**. Anything that breaks either is reverted.

N-body integration is chaotic (Lyapunov amplification ~`exp(170)` over a
full run), so *any* change to floating-point semantics in the force/
integration loop blows up to an O(1) result difference. That rules out
FMA fusion (`--fmad=true`), fewer-division rewrites, and per-lane tree
walks — all tried, all reverted. The GPU is therefore built with
`--fmad=false` (and `-ffp-contract=off` under HIP), and transcendentals
use vendored correctly-rounded `crlibm` routines to match the CPU. See
the "Tried-and-reverted" and "Phase 1" sections of
[`CUDA_OPTIMIZATIONS.md`](CUDA_OPTIMIZATIONS.md).

---

## Building

Requirements: CMake (**< 4.0**), a BOINC source tree or system install,
and CUDA ≥ 12.2 (CUDA) or ROCm ≥ 6.2 (HIP).

### NVIDIA (CUDA)

```bash
./build_cuda.sh                      # all defaults → build/bin/milkyway_nbody
./build_cuda.sh -a "70;80;90"        # V100 + A100 + H100 only
./build_cuda.sh -d build_v100 -j 16  # named build dir, 16 jobs
./build_cuda.sh -h                   # all options
```

Defaults: BOINC app, double precision, crlibm on, OpenMP on, OpenCL off.
`-c` overrides the CUDA toolkit path, `-b` the BOINC root, `-a` the
embedded SM architectures.

### AMD (HIP)

```bash
./build_hip.sh                       # 16-arch fat binary → build_hip/bin/milkyway_nbody
./build_hip.sh -a "gfx1030"          # single-arch dev build
./build_hip.sh -h                    # all options
```

A successful HIP build also assembles `build_hip/dist/` — the binary plus
the ROCm runtime libraries it must ship with (named by SONAME, `$ORIGIN`
rpath) for BOINC deployment. The CUDA build is left completely untouched.

> `NBODY_CUDA` and `NBODY_HIP` are mutually exclusive — use separate
> build directories (the two scripts already do).

## Running on the GPU

Add `--use-gpu` to a normal N-body invocation:

```bash
./bin/milkyway_nbody \
    -f nbody_parameters.lua -h histogram.txt \
    --seed <seed> -np 12 -p <12 params> \
    --nthreads 4 --use-gpu
```

- `--use-gpu` selects the GPU backend (CUDA or HIP, whichever this binary
  was built with). `--use-cuda` is kept as a deprecated alias so existing
  BOINC `app_info.xml` / `app_config.xml` files keep working.
- `--nthreads` still controls the CPU threads used for the
  reverse-orbit setup and likelihood/histogram stages.
- `--abort-nsteps=N` (default 0 = off) voluntarily finishes a workunit
  exceeding N steps.

Diagnostic environment variables:

| Var | Effect |
|-----|--------|
| `NBODY_BUILDTREE_MORTON=0` | Force the legacy `atomicCAS` tree builder (debug only; Morton is default). |
| `NBODY_CUDA_STEP_HEARTBEAT=N` | Print steps/second every N steps. |
| `NBODY_BUILDTREE_MORTON_PROFILE=1` | Per-phase timing for the first few Morton builds. |

---

## N-body usage reference

The options below are inherited from the upstream client and apply
whether you run on CPU or GPU.

### Command-line options

| Option | Description |
|--------|-------------|
| `-f` | Path to input Lua file |
| `-o` | Path to bodies output file |
| `-z` | Path to histogram output file |
| `-h` | Path to histogram input file (comparison runs) |
| `-e` / `--seed` | RNG seed |
| `-n` / `--nthreads` | CPU threads for setup / likelihood |
| `-P` | Print progress percentage |
| `-u` | Run the visualizer (needs an OpenGL build) |
| `-p` | Simulation parameter list (6, 7, 8, 12, 13 or 14 args) |
| `--use-gpu` | Run the simulation on the GPU |

#### `-p` parameters

- **6 (required):** `Forward Time, Time Ratio, Baryon Scale Radius, Radius Ratio, Baryon Mass, Mass Ratio`
- **7:** `LMC_mass` (or `Manual Bodies Input File` if `manual_bodies = true`)
- **8:** `LMC Mass, Manual Bodies Input File`
- **12:** adds `l, b, r, vx, vy, vz`
- **13:** as 12 plus `LMC_mass` (or manual-bodies file)
- **14:** as 12 plus `LMC Mass, Manual Bodies Input File`

#### Likelihood comparison flags

`-s` histogram to compare (EMD + cost by default); `-S` beta dispersion;
`-V` velocity dispersion; `-B` beta average; `-Q` line-of-sight velocity;
`-U` proper motions; `-L` momentum.

### Input Lua dwarf models

- **Double component (mixed):** Plummer / NFW / General Hernquist
  `{mass, scaleLength}`, Cored `{mass, scaleLength, r1, rc}`. Set baryons
  = total bodies and mass ratio = 1.0 to use it as a single-component
  generator.
- **Single component:** Plummer `{nbody, mass, scaleRadius, position, velocity, ignore, prng}`
  (NFW and Hernquist also available; only Plummer is analytic).

### Units

| Quantity | Unit |
|----------|------|
| Mass | Structure Mass Units (SMU); 1 SMU = 222288.47 M☉ |
| Distance | kiloparsec (kpc) |
| Time | Gigayear (Gyr) |
| Velocity | kpc/Gyr; 1 kpc/Gyr = 0.97789439 km/s |
| Acceleration | kpc/Gyr² |

Chosen so that G = 1 kpc³·SMU⁻¹·Gyr⁻².

### Tests

`make test` runs everything (slow); `make check` runs core functionality;
`make test_${n}` for n = 100, 1024, 10000; `ctest -R <name> [-VV]` for a
single test.

---

For the original CPU/OpenCL client, separation code, TAO, and the
visualizer, see the upstream
[milkywayathome_client](https://github.com/Milkyway-at-home/milkywayathome_client).
