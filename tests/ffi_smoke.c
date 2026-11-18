/* GFOS native libffi ABI qualifier. Real execution required in AmigaOS guest. */
#include <ffi.h>
#include <stdio.h>
static int add3(int a, int b, int c) { return a + b + c; }
static double mul2(double a, double b) { return a * b; }
int main(void)
{
  ffi_cif cif;
  ffi_type *ints[3] = { &ffi_type_sint32, &ffi_type_sint32, &ffi_type_sint32 };
  ffi_type *dbls[2] = { &ffi_type_double, &ffi_type_double };
  int a=4,b=7,c=9, result=0;
  double x=1.25,y=3.5, answer=0;
  void *argv[3] = { &a,&b,&c };
  void *dargv[2] = { &x,&y };
  if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 3, &ffi_type_sint32, ints) != FFI_OK) return 2;
  ffi_call(&cif, FFI_FN(add3), &result, argv);
  if (result!=20) { printf("FFI_INT_FAIL %d\n",result);return 3; }
  if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_double, dbls) != FFI_OK) return 4;
  ffi_call(&cif, FFI_FN(mul2), &answer, dargv);
  if (answer!=4.375) { printf("FFI_DOUBLE_FAIL %.8f\n",answer);return 5; }
  printf("GFOS_FFI_PASS int=%d double=%.3f\n",result,answer);
  return 0;
}
