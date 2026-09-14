# Phase-1 device integrand harness

Bit-compares the GPU port of the dwarf distribution-function integrand
(`nbody/include/nbody_cuda_phase1_integrand.h`, both the block-per-node
kernel and the per-thread kernel) against the same header compiled as host
C++ over crlibm, for every supported dwarf type pair (Plummer, NFW with and
without cutoff, Cored with and without cutoff, General Hernquist, Einasto
n>1 and n<1), both isDark values, ~3.2M nodes including 15% below 2h to
exercise the forward stencil branch. Expected result: 0 mismatches
(NaN-flagged nodes are the atan accurate-phase fallback and are recomputed
on the CPU in production).

Run after any change to the integrand header or to the CPU functions it
mirrors (nbody_dwarf_potential.c, nbody_math_funcs.c, nbody_mixeddwarf.c fun()).

```
B=build_cm197_cuda   # any configured CUDA build dir
INC="-I $B/include -I /home/ian/builds/boinc -I /home/ian/builds/boinc/api -I /home/ian/builds/boinc/lib -I popt/include -I lua/include -I milkyway/include -I dSFMT -I nbody/include -I crlibm -I $B/crlibm -I openpa/include"
gcc -O2 -std=gnu99 -DDOUBLEPREC=1 -DDSFMT_MEXP=19937 -fopenmp $INC -c tools/phase1_harness/gen_dwarfs.c -o /tmp/gen_dwarfs.o
# link with the app's own link line (see $B/nbody/CMakeFiles/milkyway_nbody.dir/link.txt), replacing main.c.o
c++ -pthread -fopenmp /tmp/gen_dwarfs.o $B/nbody/CMakeFiles/milkyway_nbody.dir/cmake_device_link.o -o /tmp/gen_dwarfs \
    -Wl,--start-group $B/lib/libnbody.a $B/lib/libnbody_lua.a $B/lib/libmilkyway_lua.a $B/lib/libnbody.a $B/lib/libmilkyway.a $B/lib/libpopt.a $B/lib/liblua51.a -lm \
    /usr/local/cuda-12.9/targets/x86_64-linux/lib/libcudart_static.a -ldl -lrt -lpthread $B/lib/libcrlibm.a -Wl,--end-group \
    /home/ian/builds/boinc/api/libboinc_api.a /home/ian/builds/boinc/lib/libboinc.a $B/lib/libdsfmt.a -lrt -lcudadevrt -lcudart_static
/usr/local/cuda-12.9/bin/nvcc -O2 -arch=sm_70 --fmad=false -Xptxas -dlcm=cv -std=c++17 -I nbody/include -I crlibm -I $B/crlibm -I milkyway/include -I $B/include -DDOUBLEPREC=1 \
    tools/phase1_harness/test_fun.cu -o /tmp/test_fun $B/lib/libcrlibm.a
cd /tmp && ./gen_dwarfs && ./test_fun 20000
```

The harness embeds the kernels by slicing them out of nbody_cuda.cu at
generation time; regenerate test_fun.cu if the kernel boundaries move.
