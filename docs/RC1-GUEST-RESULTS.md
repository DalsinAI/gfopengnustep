# GFOpenGNUstep RC1 — first real AmigaChrome guest qualification

**Date:** 2026-11-18 UTC. **Build machine:** daletop, GFOpenGCC 16.2 cross m68k-amigaos (`-m68040 -m68881 -noixemul`). **Guest:** active AmigaChrome/AmiCradle AC090 native A1200 instance using guest-visible `DH1:GFOpenGNUstep-RC1/`, with guest shell agent `SYS:ACAgent/run.script` triggered by `S:ACAgent`. The agent's `run.out` contains actual guest stdout and shell `$RC`, not Linux host simulation. Guest OS minor version has **not** been independently verified here; don't claim AmigaOS 3.2.3 from these results alone.

**Result:** 5/6 RC1 categories PASS after diagnostic rebuilds. The initial published v0.1.0-rc1 ZIP is **not** 5/6 passing as distributed, because libffi floating-point and Foundation process initialisation required rebuilds. Do not overwrite release evidence or describe RC1 as accepted. The sixth test, full Foundation IPC, is still failing/hanging under guest. Leave GitHub prerelease status enabled.

## Guest execution facts

| Probe | Guest stdout / behaviour | Exit | Verdict |
| --- | --- | --- | --- |
| `gfos_exec_port_probe_68040` | `GFOS_EXEC_PORT_PROBE_PASS` | 0 | PASS (published RC1) |
| `gfos_sync_selftest_68040` | `GFOS_SYNC_SINGLE_TASK_PASS` | 0 | PASS (published RC1; not multicore test) |
| `gfos_transport_selftest_68040` | `GFOS_TRANSPORT_ROUNDTRIP_PASS` | 0 | PASS (published RC1; not multi-task test) |
| `ffi_smoke_68040` **original** | `FFI_DOUBLE_FAIL 0.00000000` | 5 | FAIL, original published build |
| `ffi_smoke_fpu_68040` **rebuilt** | `GFOS_FFI_PASS int=20 double=4.375` | 0 | PASS, fix not yet in RC1 ZIP |
| `foundation_smoke_68040` **original** | `GNUSTEP Internal Error: ... could not find the main function ...` | 1 | FAIL, original published build |
| `foundation_smoke_explicit_68040` **rebuilt** | `FOUNDATION_CORE_PASS len=4 items=1 dict=1` | 0 | PASS, fix not yet in RC1 ZIP |
| `foundation_ipc_smoke_68040` **original** | guest shell stuck after launch (`run.running`) | not captured | FAIL / HANG |
| Traced Foundation IPC after GFOS `NSPort`/name-server singleton fixes | reaches registered name and lookup, then `GFOS_FOUNDATION_IPC_FAIL` | 2 | FAIL, no runtime PASS |
| Latest instrumented IPC | prints through `TRACE_11_BEFORE_SEND`, then hangs without entering the annotated send method | not captured | FAIL / HANG; likely method argument preparation or related Foundation dependency, **not yet proven** |

## Root cause fixes verified by guest

1. **libffi 68k floating-point ABI:** upstream `sysv.S` checks `__HAVE_68881__` and reads double results from `fp0`. The initial isolated libffi build assembled without `-m68040 -m68881`, so it followed its integer register return path, returning 0.0 for a function producing 4.375. Rebuilding libffi with `CFLAGS` containing `-m68040 -m68881` and relinking smoke passed in the guest. Corrected static libffi SHA-256 `e00ba19d98ec24e706fab478a880b05ddab10f0c4bf5789950554870bb347df8`; rebuilt FFI smoke `c69fcd2b754f78e2ab8ca58eba7fbc572422da5b78fb37fb6f9601cb3410d133`.
2. **GNUstep fake-main ABI:** GNUstep Base 1.31.1 generated both `Headers/GNUstepBase/GSConfig.h` and `Source/GNUstepBase/GSConfig.h`, initially with `GS_FAKE_MAIN=1`. On AmigaOS target a.out, weak `gnustep_base_user_main` fallback was selected, aborting before the application. For diagnostic rebuild both generated configs were changed to `GS_FAKE_MAIN=0`, `GS_PASS_ARGUMENTS=1`, and test application `main(argc,argv)` calls `GSInitializeProcess(argc, argv, gfos_environment)` before any other Foundation call, with an empty environment array (the existing C runtime does not export Unix `environ`). The GNUstep Base core archive and Foundation smoke executable relinked and the guest returned PASS. **Reproducible production configure should use `--enable-pass-arguments --disable-fake-main` and verify BOTH generated GSConfig.h files.** Proper enumeration of Amiga environment variables is still future work.
3. **Native NSPort class init:** `NSPort +initialize` queried `NSUserDefaults` to choose between `NSMessagePort` and `NSSocketPort`. GFOS supports Exec native ports and not the Unix socket default; a GFOS-only conditional avoids this early defaults dependency. With this and the next fix, the message port instance creates successfully in guest.
4. **Name-server singleton construction:** GNUstep's base class rejects normal `+alloc` for singleton name servers. The GFOS `NSMessagePortNameServer` initially called `[self new]`, causing guest abort. Updated to `NSAllocateObject(self, 0, NSDefaultMallocZone())`, matching upstream's construction. Guest trace subsequently created the name server and registered an Exec port successfully.

## Outstanding real IPC blocker

The current `src/foundation/GFOSNSMessagePort.m` prototype supports one local NSData component and explicit polling, not full `NSRunLoop`, distributed objects, thread cancellation or concurrent close. After latest trace, named port registration and lookup pass, but sending still fails/hangs before method-internal instrumentation is reached. Distinguish `[NSDate dateWithTimeIntervalSinceNow:5]`, `NSMutableArray arrayWithObject:` and Objective-C method dispatch via separately marked argument construction. Do not bypass, stub, or claim success.

**Caution:** `ACAgent` renames `run.script` to `run.running`. A hung guest command leaves `run.running`; do not overwrite it, restart another team's instance, or claim a timed-out run passed. We used only previously idle agent targets and did not restart emulators. The first results' raw logs are recorded in `tests/guest-evidence/`.

Next release must be a **new prerelease** containing the fixed libffi + GNUstep process startup and actual test evidence. Existing `v0.1.0-rc1` ZIP remains a historical diagnostic candidate.
