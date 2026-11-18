# Canonical GFOpenMulticore Team 4 header compatibility check

18 November 2026. Retrieved `include/libraries/gfopenmulticore.h` unmodified from `DalsinAI/gfopenmulticore` main at `f2bcd5688f9e2bad3377149a32387f5da0d9c1c9`.

`tests/gfos_omc_abi_probe.c` includes the **real** Team 4 header and directly accesses `OMCJob`, `OMCGrant`, `OMC_ANY`, `OMCF_STRICT`, `OMCG_READ`, `OMCG_WRITE`, `OMC_HAS_JOBCALLS`, `OMC_HAS_RANGE`, `OMC_DEFAULTTIMEOUT`, `OMC_RANGEMAXARGS`, and `OMC_GRANTSIZE`. Cross-compiled with GCC 16.2 `-m68040 -m68881 -noixemul -O2 -Wall -Wextra` plus vendor NDK. **Compile PASS, zero warnings**; output is AmigaOS object data. Object SHA-256 `199d9063f55ce854436c7248064ad923814942e1caa5bda6b6c9195049abb8ce`.

To reproduce, retrieve the current canonical Team 4 header into an SDK include directory then compile:

```
m68k-amigaos-gcc -std=gnu11 -m68040 -m68881 -noixemul -O2 -Wall -Wextra -I <team4-SDK-include-root> -I <ndk-include-root> -c tests/gfos_omc_abi_probe.c -o gfos_omc_abi_probe.o
```

This is **compile-only**. It does not link `gfopenmulticore.library`, use its function table, test board discovery or submit a job. The next real gate is a CPU0 fallback versus **confirmed cores-card** guest run via Team 4's library, using `OMC_RunRange` and checked grants/statuses. The integration contract lives at `docs/GFOS-OPENUP-MULTICORE-INTEGRATION.md`.
