# Milkyway@Home N-body — CUDA GPU port (faithful)

A CUDA port of the [Milkyway@Home](https://github.com/Milkyway-at-home/milkywayathome_client)
N-body client. The simulation runs entirely on an NVIDIA GPU (Barnes–Hut
tree with quadrupole moments) and produces results **bit-identical to the
CPU reference**, so they validate against the project.

This is the **`cuda-port`** branch — a **direct, faithful translation** of
the existing OpenCL/CPU N-body code to CUDA. The goal here is fidelity,
not speed: the kernels mirror the structure of the original
`nbody_kernels.cl`, the tree is built with the same legacy
allocation-order algorithm, and every stage is kept as close to the CPU
math as possible so the GPU reproduces the CPU result exactly.

> Want the faster, portable version? See the
> **[`cuda-port-optimization`](../../tree/cuda-port-optimization)** branch.
> It starts from this port and adds a deterministic Morton tree builder,
> a re-optimized force walk, CUDA graphs, and an **AMD/HIP** backend —
> while keeping the same bit-identical-to-CPU result. That branch's
> `CUDA_OPTIMIZATIONS.md` documents every change.

---

## Design — a faithful port

- **One GPU translation unit** (`nbody_cuda.cu`) implements the full
  per-step pipeline: bounding box → tree build → summarization →
  quadrupole moments → Barnes–Hut force walk → leapfrog integration,
  plus the external potential (bulge / disk / halo / LMC + dynamical
  friction). The host marshals bodies AoS↔SoA and drives the loop; the
  GPU does the physics.
- **Legacy tree builder.** The tree is built with the original
  `atomicCAS` cell-allocation kernel, mirroring the OpenCL code — not a
  reworked algorithm.
- **CPU-matched floating point.** Built with NVCC `--fmad=false` to
  match the CPU's `-ffp-contract=off`, and transcendentals use vendored
  correctly-rounded `crlibm` routines (`pow`, `log`, cube) so the GPU
  rounds the same way the CPU does. This matters because N-body
  integration is chaotic — a single differently-rounded operation
  amplifies into an O(1) result difference over a full run, so faithful
  rounding is what makes the GPU result valid.
- **Deep-tree correctness.** `NBODY_CUDA_MAXDEPTH` is 41 (raised from the
  OpenCL default of 26, which silently dropped a body on deep trees — the
  long-workunit divergence root cause). Trees shallower than 26 are
  unaffected.

CUDA only — no AMD/HIP backend on this branch.

---

## Building

Requirements: CMake (**< 4.0**), a BOINC source tree or system install,
and a CUDA toolkit (≥ 12.2).

```bash
./build_cuda.sh                      # all defaults → build/bin/milkyway_nbody
./build_cuda.sh -a "70;80;90"        # V100 + A100 + H100 only
./build_cuda.sh -c /opt/cuda         # custom CUDA toolkit path
./build_cuda.sh -d build_v100 -j 16  # named build dir, 16 jobs
./build_cuda.sh -h                   # all options
```

Defaults: BOINC app, double precision, crlibm on, OpenMP on, OpenCL off.
`-b` overrides the BOINC root, `-a` the embedded SM architectures, `-c`
the CUDA toolkit.

## Running on the GPU

Add `--use-cuda` to a normal N-body invocation:

```bash
./bin/milkyway_nbody \
    -f nbody_parameters.lua -h histogram.txt \
    --seed <seed> -np 12 -p <12 params> \
    --nthreads 4 --use-cuda
```

`--use-cuda` selects the GPU backend. `--nthreads` still controls the CPU
threads used for the reverse-orbit setup and the likelihood/histogram
stages.

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
| `--use-cuda` | Run the simulation on the GPU |

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
