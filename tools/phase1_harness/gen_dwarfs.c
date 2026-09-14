#include <stdio.h>
#include <string.h>
#include "nbody_types.h"
#include "nbody_potential_types.h"
#include "nbody_mixeddwarf.h"
static void put(FILE* f, Dwarf d){ set_model_params(&d); fwrite(&d,sizeof(Dwarf),1,f); }
int main(void){
    FILE* f=fopen("dwarfs.bin","wb");
    Dwarf d;
    /* Plummer light + Plummer dark (classic) */
    d=(Dwarf)EMPTY_DWARF; d.type=Plummer; d.mass=12.0; d.scaleLength=0.2; put(f,d);
    d=(Dwarf)EMPTY_DWARF; d.type=Plummer; d.mass=100.0; d.scaleLength=0.8; put(f,d);
    /* NFW no cutoff / with cutoff */
    d=(Dwarf)EMPTY_DWARF; d.type=NFW; d.mass=344764.0; d.scaleLength=11.8119; put(f,d);
    d=(Dwarf)EMPTY_DWARF; d.type=NFW; d.mass=344764.0; d.scaleLength=11.8119; d.rcut=44.4656; d.rdecay=31.3375; put(f,d);
    /* Cored (the 40k WU family): mass, scale, rcut, rdecay, rc via r1/rc fields as the lua sets them */
    d=(Dwarf)EMPTY_DWARF; d.type=Cored; d.mass=344764.0; d.scaleLength=11.8119; d.rcut=44.4656; d.rdecay=31.3375; d.rc=0.196879*11.8119; d.r1=0.950312*11.8119; put(f,d);
    d=(Dwarf)EMPTY_DWARF; d.type=Cored; d.mass=5000.0; d.scaleLength=1.5; d.rc=0.3; d.r1=1.0; put(f,d);
    /* General Hernquist */
    d=(Dwarf)EMPTY_DWARF; d.type=General_Hernquist; d.mass=50.0; d.scaleLength=0.5; put(f,d);
    /* Einasto n>1 and n<1 (new v1.97 formulas) */
    d=(Dwarf)EMPTY_DWARF; d.type=Einasto; d.mass=2000.0; d.scaleLength=3.0; d.n=4.0; put(f,d);
    d=(Dwarf)EMPTY_DWARF; d.type=Einasto; d.mass=800.0; d.scaleLength=1.2; d.n=0.7; put(f,d);
    fclose(f); printf("sizeof(Dwarf)=%zu, wrote 9\n", sizeof(Dwarf)); return 0;
}
