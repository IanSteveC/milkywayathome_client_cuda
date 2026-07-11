/* nbody_cuda_crlibm_atan.cuh — device port of crlibm atan_rn FAST PHASE.
 * MACHINE-GENERATED from crlibm/atan_fast.c via `gcc -E` with the exact
 * build configuration (non-FMA macro variants). The rare accurate-phase
 * fallback (SCS multiprecision on the CPU) is NOT ported: when the
 * rounding test fails — the same test the CPU uses to decide SCS — the
 * kernel sets *uncertain and the HOST recomputes that entire node with
 * the normal CPU path. Bit-exact hybrid by construction. */
#ifndef NBODY_CUDA_CRLIBM_ATAN_CUH
#define NBODY_CUDA_CRLIBM_ATAN_CUH
namespace nb_crlibm_atan {
extern unsigned long long crlibm_init(void);
extern void crlibm_exit(unsigned long long);
extern double exp_rn(double);
extern double exp_rd(double);
extern double exp_ru(double);
extern double log_rn(double);
extern double log_rd(double);
extern double log_ru(double);
extern double log_rz(double);
extern double cos_rn(double);
extern double cos_rd(double);
extern double cos_ru(double);
extern double cos_rz(double);
extern double sin_rn(double);
extern double sin_rd(double);
extern double sin_ru(double);
extern double sin_rz(double);
extern double tan_rn(double);
extern double tan_rd(double);
extern double tan_ru(double);
extern double tan_rz(double);
extern double cospi_rn(double);
extern double cospi_rd(double);
extern double cospi_ru(double);
extern double cospi_rz(double);
extern double sinpi_rn(double);
extern double sinpi_rd(double);
extern double sinpi_ru(double);
extern double sinpi_rz(double);
extern double tanpi_rn(double);
extern double tanpi_rd(double);
extern double tanpi_ru(double);
extern double tanpi_rz(double);

extern double atan_rd(double);
extern double atan_ru(double);
extern double atan_rz(double);
extern double atanpi_rn(double);
extern double atanpi_rd(double);
extern double atanpi_ru(double);
extern double atanpi_rz(double);
extern double cosh_rn(double);
extern double cosh_rd(double);
extern double cosh_ru(double);
extern double cosh_rz(double);
extern double sinh_rn(double);
extern double sinh_rd(double);
extern double sinh_ru(double);
extern double sinh_rz(double);
extern double log2_rn(double);
extern double log2_rd(double);
extern double log2_ru(double);
extern double log2_rz(double);
extern double log10_rn(double);
extern double log10_rd(double);
extern double log10_ru(double);
extern double log10_rz(double);
extern double asin_rn(double);
extern double asin_rd(double);
extern double asin_ru(double);
extern double asin_rz(double);
extern double acos_rn(double);
extern double acos_rd(double);
extern double acos_ru(double);
extern double asinpi_rn(double);
extern double asinpi_rd(double);
extern double asinpi_ru(double);
extern double asinpi_rz(double);
extern double acospi_rn(double);
extern double acospi_rd(double);
extern double acospi_ru(double);
extern double expm1_rn(double);
extern double expm1_rd(double);
extern double expm1_ru(double);
extern double expm1_rz(double);
extern double log1p_rn(double);
extern double log1p_rd(double);
extern double log1p_ru(double);
extern double log1p_rz(double);
extern double exp2_rn(double);
extern double exp2_rd(double);
extern double exp2_ru(double);
extern double pow_rn(double, double);
typedef unsigned long long uint64_t;
typedef long long int64_t;
typedef unsigned int uint32_t;
typedef int int32_t;
typedef union {
  int32_t i[2];
  int64_t l;
  double d;
} db_number;
 extern const db_number radix_one_double ;
 extern const db_number radix_two_double ;
 extern const db_number radix_mone_double;
 extern const db_number radix_mtwo_double;
 extern const db_number radix_rng_double ;
 extern const db_number radix_mrng_double;
 extern const db_number max_double ;
 extern const db_number min_double ;
typedef unsigned long long uint64_t;
typedef long long int64_t;
typedef unsigned int uint32_t;
typedef int int32_t;
extern int crlibm_second_step_taken;
void printHexa(char* s, double x);
static __device__ const db_number HALFPI = {{0x54442D18,0x3FF921FB}};static __device__ const db_number HALFPI_TO_PLUS_INFINITY = {{0x54442D19,0x3FF921FB}};
static __device__ const double rncst[4] ={
1.00108178765940960655050071055243374002677613873338 ,
1.00005232457100223306383112145248847898875939835839 ,
1.00177430465884899885886845639867196876576265849646 ,
1.00001038174963923723172604569348623337721036178939 ,
 };
static __device__ const double epsilon[4] ={
5.98811545469121308132334292226294391299405661608483e-20 ,
2.85148356343799927177205125935801754271662806490715e-21 ,
9.82484875894815915914535124879847312836985338769278e-20 ,
5.23355329168770007392834621113547073694289911517614e-22 ,
 };
static __device__ double const coef_poly[4] =
{
                        0.11111111111111110494320541874913033097982406616211,
                        -0.14285714285714284921269268124888185411691665649414,
                        0.20000000000000001110223024625156540423631668090820,
                        -0.33333333333333331482961625624739099293947219848633,
 };
static __device__ db_number const arctan_table[62][4] =
{
{
              {{(int)0xBCCE533D,0x3F89FDF8}} ,
              {{0x27760007,0x3F99FF0B}} ,
              {{0x4969F96C,0x3F99FD9D}} ,{{0x750685EA,(int)0xBC301997}} ,
}
,{
              {{(int)0x90CEBC31,0x3FA3809F}} ,
              {{(int)0xE3547CC2,0x3FAA0355}} ,
              {{0x4936262D,0x3FA9FD9D}} ,{{0x3A2D0F59,(int)0xBC4C1F96}} ,
}
,{
              {{0x68FBA526,0x3FB04419}} ,
              {{(int)0xABF7BFB9,0x3FB387E0}} ,
              {{(int)0xF6C1E06C,0x3FB37E35}} ,{{(int)0x8378E024,(int)0xBC556710}} ,
}
,{
              {{(int)0xABCDFA25,0x3FB6CD46}} ,
              {{(int)0xE265B8AB,0x3FBA1491}} ,
              {{0x48CF1996,0x3FB9FD9D}} ,{{(int)0xB73BED3C,(int)0xBC4360DC}} ,
}
,{
              {{0x6D2EA546,0x3FBD5E09}} ,
              {{(int)0x9124D46B,0x3FC054FA}} ,
              {{0x4D618156,0x3FC03E82}} ,{{0x49A86344,0x3C62604E}} ,
}
,{
              {{(int)0xD691E891,0x3FC1FC4E}} ,
              {{0x51F57043,0x3FC3A526}} ,
              {{(int)0xF64EF83E,0x3FC37E35}} ,{{(int)0xB4A55EA6,0x3C5F2B13}} ,
}
,{
              {{0x531F610B,0x3FC54FA6}} ,
              {{(int)0xB99F2601,0x3FC6FBF4}} ,
              {{(int)0x9F302425,0x3FC6BDE9}} ,{{(int)0xC4D330CE,(int)0xBC23B62A}} ,
}
,{
              {{0x0550EAF1,0x3FC8AA38}} ,
              {{0x61D9D63D,0x3FCA5A97}} ,
              {{0x48053FC8,0x3FC9FD9D}} ,{{(int)0x98474AF1,(int)0xBC67A12C}} ,
}
,{
              {{(int)0xB8975BD9,0x3FCC0D3A}} ,
              {{(int)0xBCBF6ABC,0x3FCDC24A}} ,
              {{(int)0xF0CE8DD9,0x3FCD3D50}} ,{{0x3A31D353,0x3C6EF257}} ,
}
,{
              {{(int)0xFEE46885,0x3FCF79F0}} ,
              {{(int)0xFCF66B85,0x3FD09A2B}} ,
              {{0x4CC62C6B,0x3FD03E82}} ,{{(int)0x95C6E482,0x3C5DA594}} ,
}
,{
               {{(int)0x943274CA,0x3FD178D5}} ,
               {{(int)0x8943E603,0x3FD2590B}} ,
               {{0x211F7969,0x3FD1DE5C}} ,{{0x0B01EF44,0x3C3C4E87}} ,
}
,{
               {{(int)0xB2CFB5F7,0x3FD33AE4}} ,
               {{(int)0x81B0D1DF,0x3FD41E78}} ,
               {{(int)0xF5735AA1,0x3FD37E35}} ,{{(int)0x8D437AE9,(int)0xBC772D05}} ,
}
,{
               {{0x0DD40A5B,0x3FD503DF}} ,
               {{0x1EB6A659,0x3FD5EB31}} ,
               {{(int)0xC9C20060,0x3FD51E0F}} ,{{0x20BA7A7B,(int)0xBC6C0F53}} ,
}
,{
               {{0x3998DD14,0x3FD6D488}} ,
               {{(int)0xAAF865B1,0x3FD7BFFE}} ,
               {{(int)0x9E0B9E67,0x3FD6BDE9}} ,{{(int)0x870D5E8E,0x3C797792}} ,
}
,{
               {{(int)0x964ABFA5,0x3FD8ADAF}} ,
               {{0x00A6F44E,0x3FD99DB7}} ,
               {{0x72506BCA,0x3FD85DC3}} ,{{0x43A1CBA3,0x3C720BD1}} ,
}
,{
               {{(int)0xE241114E,0x3FDA9031}} ,
               {{0x327F0E90,0x3FDB853E}} ,
               {{0x4690A2C8,0x3FD9FD9D}} ,{{(int)0xEFB73034,(int)0xBC6A048E}} ,
}
,{
               {{(int)0xFB78B41D,0x3FDC7CFA}} ,
               {{0x67BE333A,0x3FDD7788}} ,
               {{0x1ACC80A6,0x3FDB9D77}} ,{{(int)0xE8FB154D,0x3C6A9BD7}} ,
}
,{
               {{(int)0xD82B9DC6,0x3FDE7507}} ,
               {{(int)0xF3B4AACC,0x3FDF759B}} ,
               {{(int)0xEF044589,0x3FDD3D50}} ,{{0x09E8652E,0x3C575857}} ,
}
,{
               {{0x5FF4B2AB,0x3FE03CB4}} ,
               {{(int)0xD9952BEF,0x3FE0C049}} ,
               {{(int)0xC338344A,0x3FDEDD2A}} ,{{(int)0x81513292,0x3C23C787}} ,
}
,{
               {{(int)0xE826E4EA,0x3FE145A1}} ,
               {{(int)0xDDD96DE0,0x3FE1CCD0}} ,
               {{0x4BB44923,0x3FE03E82}} ,{{0x49DF0A58,0x3C8CAF01}} ,
}
,{
               {{(int)0xED462BAC,0x3FE255EB}} ,
               {{0x35B0819C,0x3FE2E109}} ,
               {{0x35CAD39D,0x3FE10E6F}} ,{{0x0D1EB36B,0x3C45DB33}} ,
}
,{
               {{(int)0xD4CDD9AC,0x3FE36E3F}} ,
               {{(int)0xF51235D9,0x3FE3FDA7}} ,
               {{0x1FDFDE84,0x3FE1DE5C}} ,{{(int)0xD3921CA6,0x3C86FBEF}} ,
}
,{
               {{(int)0xE1FB2991,0x3FE48F5A}} ,
               {{0x18D0CCB0,0x3FE52373}} ,
               {{0x09F38FC9,0x3FE2AE49}} ,{{0x058084C6,(int)0xBC84BBB5}} ,
}
,{
               {{0x5FE86E27,0x3FE5BA0C}} ,
               {{(int)0xDA588D41,0x3FE65343}} ,
               {{(int)0xF4060E3D,0x3FE37E35}} ,{{(int)0xAE25B9B7,0x3BF6235C}} ,
}
,{
               {{0x22C19A5D,0x3FE6EF38}} ,
               {{0x629002BC,0x3FE78E09}} ,
               {{(int)0xDE17817F,0x3FE44E22}} ,{{0x1A6D25E3,(int)0xBC85F46E}} ,
}
,{
               {{0x70F967BD,0x3FE82FD9}} ,
               {{(int)0xEE8B9555,0x3FE8D4CB}} ,
               {{(int)0xC82811DC,0x3FE51E0F}} ,{{(int)0xFCB9720C,(int)0xBC81CCF7}} ,
}
,{
               {{0x69351A0D,0x3FE97D06}} ,
               {{0x7D0D616A,0x3FEA28B0}} ,
               {{(int)0xB237E838,0x3FE5EDFC}} ,{{(int)0xF8F29048,(int)0xBC833EA8}} ,
}
,{
               {{(int)0xFE730FCD,0x3FEAD7F3}} ,
               {{0x21335E3D,0x3FEB8AFD}} ,
               {{(int)0x9C472DF1,0x3FE6BDE9}} ,{{(int)0x80DED249,0x3C5E8127}} ,
}
,{
               {{(int)0xAA0A733E,0x3FEC41FA}} ,
               {{0x1D9A7669,0x3FECFD1E}} ,
               {{(int)0x86560CC5,0x3FE78DD6}} ,{{(int)0x9396D511,(int)0xBC7E962F}} ,
}
,{
               {{(int)0xFAEEEADF,0x3FEDBC9B}} ,
               {{(int)0xF41419E7,0x3FEE80AB}} ,
               {{0x7064AEB4,0x3FE85DC3}} ,{{0x5225ACD1,0x3C77C0FC}} ,
}
,{
               {{0x33AC790A,0x3FEF4989}} ,
               {{0x50BB2D02,0x3FF00BB9}} ,
               {{0x5A733DE9,0x3FE92DB0}} ,{{(int)0xA318D041,(int)0xBC6598C9}} ,
}
,{
               {{(int)0x9AC922B4,0x3FF07555}} ,
               {{0x25F4BC57,0x3FF0E1BD}} ,
               {{0x4481E499,0x3FE9FD9D}} ,{{(int)0x9464A40D,(int)0xBC82E89F}} ,
}
,{
               {{0x0440E8D3,0x3FF15116}} ,
               {{(int)0xDEC8DA1A,0x3FF1C388}} ,
               {{0x2E90CCEA,0x3FEACD8A}} ,{{(int)0xFE4AC33B,0x3C60B8DB}} ,
}
,{
               {{0x329D3DD8,0x3FF23941}} ,
               {{(int)0x8F9CF3AD,0x3FF2B26D}} ,
               {{0x18A020D8,0x3FEB9D77}} ,{{0x43DDC7EE,0x3C714EA3}} ,
}
,{
               {{(int)0xE2DB7094,0x3FF32F3F}} ,
               {{(int)0xC485093A,0x3FF3AFED}} ,
               {{0x02B00A17,0x3FEC6D64}} ,{{(int)0xC1E56981,0x3C5CF722}} ,
}
,{
               {{(int)0xD38A35D7,0x3FF434B0}} ,
               {{0x16D89BC7,0x3FF4BDC7}} ,
               {{(int)0xECC0B1F8,0x3FED3D50}} ,{{(int)0xC689AE1B,0x3C8FFD9A}} ,
}
,{
               {{0x6F41F96D,0x3FF54B73}} ,
               {{0x11C53212,0x3FF5DDFE}} ,
               {{(int)0xD6D24151,0x3FEE0D3D}} ,{{(int)0xC830B564,(int)0xBC654F0F}} ,
}
,{
               {{0x165CA5E1,0x3FF675B5}} ,
               {{0x13170C5B,0x3FF712ED}} ,
               {{(int)0xC0E4E05B,0x3FEEDD2A}} ,{{(int)0xBF676FFE,(int)0xBC8FEAC3}} ,
}
,{
               {{(int)0xD0DEA3C6,0x3FF7B601}} ,
               {{0x11FBEA40,0x3FF85F57}} ,
               {{(int)0xAAF8B69E,0x3FEFAD17}} ,{{(int)0xE69F3AF7,0x3C8B8DA3}} ,
}
,{
               {{0x79506F51,0x3FF90F59}} ,
               {{(int)0x8AF460DF,0x3FF9C67F}} ,
               {{0x4A86F56B,0x3FF03E82}} ,{{(int)0xDE1DF40B,0x3C8C4641}} ,
}
,{
               {{(int)0xD74CF791,0x3FFA854A}} ,
               {{0x4A696F14,0x3FFB4C49}} ,
               {{(int)0xBF92516C,0x3FF0A678}} ,{{0x6A0966AF,(int)0xBC9194FF}} ,
}
,{
               {{(int)0xB3972246,0x3FFC1C16}} ,
               {{(int)0x80F0B83E,0x3FFCF55E}} ,
               {{0x349E81BA,0x3FF10E6F}} ,{{0x3CD05C13,0x3C9C7D12}} ,
}
,{
               {{(int)0xC6DB1831,0x3FFDD8DD}} ,
               {{(int)0x927D039C,0x3FFEC765}} ,
               {{(int)0xA9AB9836,0x3FF17665}} ,{{0x7B9C115B,(int)0xBC924DFA}} ,
}
,{
               {{(int)0xA4F6D032,0x3FFFC1DD}} ,
               {{(int)0xCDEC630C,0x400064A3}} ,
               {{0x1EB9A624,0x3FF1DE5C}} ,{{0x595EC15D,(int)0xBC7002F6}} ,
}
,{
               {{0x56AEFAF2,0x4000EF61}} ,
               {{0x02FA3F97,0x400181C8}} ,
               {{(int)0x93C8BC28,0x3FF24652}} ,{{(int)0xC61E8575,(int)0xBC8FE336}} ,
}
,{
               {{(int)0xFD9A80C1,0x40021C8B}} ,
               {{0x188015C0,0x4002C078}} ,
               {{0x08D8EA37,0x3FF2AE49}} ,{{0x56281657,(int)0xBC99C943}} ,
}
,{
               {{0x7D67269C,0x40036E71}} ,
               {{0x17EDBBF3,0x4004277C}} ,
               {{0x7DEA3F8C,0x3FF3163F}} ,{{(int)0x90EB721B,0x3C9AD329}} ,
}
,{
               {{(int)0xF069F1E4,0x4004ECBF}} ,
               {{(int)0xA99113B9,0x4005BF8F}} ,
               {{(int)0xF2FCCAA3,0x3FF37E35}} ,{{(int)0x8B3674F4,(int)0xBC96C4D7}} ,
}
,{
               {{0x780169B7,0x4006A170}} ,
               {{(int)0xEECFDE39,0x40079423}} ,
               {{0x68109926,0x3FF3E62C}} ,{{0x46562D7D,0x3C9D395E}} ,
}
,{
               {{0x319C3F02,0x400899B4}} ,
               {{0x34491C9A,0x4009B483}} ,
               {{(int)0xDD25B7F0,0x3FF44E22}} ,{{(int)0x96299AC9,(int)0xBC9AC408}} ,
}
,{
               {{0x05B0834A,0x400AE75E}} ,
               {{0x6451B6E9,0x400C3595}} ,
               {{0x523C32F8,0x3FF4B619}} ,{{(int)0x9A6CF82B,0x3C98372D}} ,
}
,{
               {{0x739BD0E3,0x400DA31D}} ,
               {{0x088B2A13,0x400F34B7}} ,
               {{(int)0xC7541555,0x3FF51E0F}} ,{{(int)0xD97CC177,(int)0xBC4DA0E1}} ,
}
,{
               {{0x1886BC57,0x40107813}} ,
               {{(int)0x8D819944,0x40116E3D}} ,
               {{0x3C6D692D,0x3FF58606}} ,{{(int)0xD9D13C46,(int)0xBC7DAB9D}} ,
}
,{
               {{(int)0x8BCE2241,0x4012813A}} ,
               {{(int)0x9F0E4EBF,0x4013B685}} ,
               {{(int)0xB18837B4,0x3FF5EDFC}} ,{{(int)0xBC854F71,(int)0xBC858200}} ,
}
,{
               {{0x4ACECE78,0x40151516}} ,
               {{(int)0xF3CD0189,0x4016A5E9}} ,
               {{0x26A48924,0x3FF655F3}} ,{{0x0EF07703,(int)0xBC95DCD4}} ,
}
,{
               {{(int)0x9526FAB9,0x401874CE}} ,
               {{(int)0xBA057809,0x401A9194}} ,
               {{(int)0x9BC264B7,0x3FF6BDE9}} ,{{0x555821B5,0x3C839FB7}} ,
}
,{
               {{(int)0xE094C913,0x401D11EB}} ,
               {{(int)0xA01EFACA,0x40200A31}} ,
               {{0x10E1D0A5,0x3FF725E0}} ,{{0x56DADB03,0x3C86B63B}} ,
}
,{
               {{0x220DFA19,0x4021E2BC}} ,
               {{(int)0xFBA72898,0x40243445}} ,
               {{(int)0x8602D21D,0x3FF78DD6}} ,{{0x4D2EA6E0,(int)0xBC9FD7D6}} ,
}
,{
               {{(int)0xD0337C49,0x40273463}} ,
               {{0x4A4A5A1D,0x402B3DC7}} ,
               {{(int)0xFB256D40,0x3FF7F5CC}} ,{{(int)0xA28CF77C,0x3C954E9E}} ,
}
,{
               {{0x26350916,0x40307B8E}} ,
               {{0x24D415BF,0x4034DBD6}} ,
               {{0x7049A526,0x3FF85DC3}} ,{{(int)0xE9374500,(int)0xBC8424E5}} ,
}
,{
               {{0x497BF2F2,0x403C62CF}} ,
               {{0x6C3EC43C,0x40463208}} ,
               {{(int)0xE56F7BD2,0x3FF8C5B9}} ,{{0x2F7EC153,(int)0xBC81D57A}} ,
}
,{
               {{(int)0xFA9E0EF4,0x40596CC3}} ,
               {{0x7BFF8329,0x4054B2C4}} ,
               {{(int)0xF333CBBA,0x3FF8F082}} ,{{0x3909BC3A,0x3C952577}} ,
}
,
};
static __device__ void atan_quick(double *atanhi,double *atanlo, int *index_of_e, double x) {
  double tmphi,tmplo, x0hi,x0lo;
  double q,Xred2,x2;
  double Xredhi,Xredlo;
  double xmBihi, xmBilo, tmphi2, tmplo2, atanlolo;
  int i;
  if (x > 0.01269144369306618004077670910586377580133132772550)
    {
      if (x > arctan_table[61][1].d) {
        i=61;
        {double _z, _a=x, _b=-arctan_table[61][1].d; xmBihi = _a + _b; _z = xmBihi - _a; xmBilo = _b - _z; };
      }
      else
        {
          i=31;
          if (x < arctan_table[i][0].d) i-= 16;
          else i+=16;
          if (x < arctan_table[i][0].d) i-= 8;
          else i+= 8;
          if (x < arctan_table[i][0].d) i-= 4;
          else i+= 4;
          if (x < arctan_table[i][0].d) i-= 2;
          else i+= 2;
          if (x < arctan_table[i][0].d) i-= 1;
          else i+= 1;
          if (x < arctan_table[i][0].d) i-= 1;
          xmBihi = x-arctan_table[i][1].d;
          xmBilo = 0.0;
        }
      { const double c = 134217729.; double up, u1, u2, vp, v1, v2; double _u=x, _v=arctan_table[i][1].d; up = _u*c; vp = _v*c; u1 = (_u-up)+up; v1 = (_v-vp)+vp; u2 = _u-u1; v2 = _v-v1; *&tmphi = _u*_v; *&tmplo = (((u1*v1-*&tmphi)+(u1*v2))+(u2*v1))+(u2*v2);};
      if (x > 1)
        do { double _r,_s; _r = (tmphi)+(1.0); _s = ((((tmphi)-_r) +(1.0)) + (0.0)) + (tmplo); *&x0hi = _r+_s; *&x0lo = (_r - (*&x0hi)) + _s; } while(0);
      else {do { double _r,_s; _r = (1.0)+(tmphi); _s = ((((1.0)-_r) +(tmphi)) + (tmplo)) + (0.0); *&x0hi = _r+_s; *&x0lo = (_r - (*&x0hi)) + _s; } while(0);}
      { double _ch,_cl,_uh,_ul; _ch=(xmBihi)/(x0hi); { const double c = 134217729.; double up, u1, u2, vp, v1, v2; double _u=_ch, _v=(x0hi); up = _u*c; vp = _v*c; u1 = (_u-up)+up; v1 = (_v-vp)+vp; u2 = _u-u1; v2 = _v-v1; *&_uh = _u*_v; *&_ul = (((u1*v1-*&_uh)+(u1*v2))+(u2*v1))+(u2*v2);}; _cl=((xmBihi)-_uh); _cl -= _ul; _cl += (xmBilo); _cl -= _ch*(x0lo); _cl /= (x0hi); *&Xredhi=_ch+_cl; *&Xredlo=(_ch-(*&Xredhi))+_cl; };
      Xred2 = Xredhi*Xredhi;
      q = Xred2*(coef_poly[3]+Xred2*
                 (coef_poly[2]+Xred2*
                  (coef_poly[1]+Xred2*
                   coef_poly[0]))) ;
      atanlolo = (Xredlo + arctan_table[i][3].d);
      atanlolo += Xredhi*q;
      {double _z, _a=arctan_table[i][2].d, _b=Xredhi; tmphi2 = _a + _b; _z = tmphi2 - _a; tmplo2 = _b - _z; };
      {double _z, _a=tmphi2, _b=(tmplo2+atanlolo); *atanhi = _a + _b; _z = *atanhi - _a; *atanlo = _b - _z; };
      if (i<10)
        *index_of_e = 0;
      else
        *index_of_e = 1;
    }
  else
    {
      x2 = x*x;
      q = x2*(coef_poly[3]+x2*
              (coef_poly[2]+x2*
               (coef_poly[1]+x2*
                coef_poly[0]))) ;
      {double _z, _a=x, _b=x*q; *atanhi = _a + _b; _z = *atanhi - _a; *atanlo = _b - _z; };
      *index_of_e = 2;
    }
}
__device__ double cuda_crlibm_atan_rn_impl(double x, int* uncertain) {
  double atanhi,atanlo;
  int index_of_e;
  double sign;
  db_number x_db;
  int absxhi;
  x_db.d = x;
  absxhi = x_db.i[1] & 0x7fffffff;
  if(x_db.i[1] & (int)0x80000000){
    x_db.i[1] = absxhi;
    sign =-1;
  }
  else
    sign=1;
  if ( absxhi >= 0x43500000)
    {
      if ((absxhi > 0x7ff00000) || ((absxhi == 0x7ff00000) && (x_db.i[0] != 0)))
        return x+x;
      else
        return sign*HALFPI.d;
    }
  if ( absxhi < 0x3E400000 )
      return x;
  atan_quick(&atanhi, &atanlo,&index_of_e , x_db.d);
  if (atanhi == (atanhi + (atanlo*rncst[index_of_e])))
    return sign*atanhi;
  else
    {
      { *uncertain = 1; return 0.0; } /* accurate phase: host recomputes */
    }
}
} /* namespace */
static __device__ __forceinline__ double cuda_crlibm_atan_rn(double x, int* uncertain)
{ return nb_crlibm_atan::cuda_crlibm_atan_rn_impl(x, uncertain); }
#endif
