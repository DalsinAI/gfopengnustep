# GFOpenGNUstep v0.1.1-rc1 — real AmigaChrome guest qualification

**18 November 2026 (UTC)**. Native GCC 16.2 m68k AmigaOS 68040 build, installed in a **separate dedicated AmiCradle/AmigaChrome AC090 guest instance** named `gfos-foundation-rc1-lab-20261118`. We cloned the bootable System/DH0 volume independently on DevDrive; other teams' running emulators and the historical RC1 ZIP were left unchanged. The isolated guest uses an AC090 68040 with FPU, Exec and native message ports. Guest `Version` command reports **Kickstart 47.2, Workbench 47.100** (not independently confirmed as AmigaOS 3.2.3). `Info` confirms a booted writable System/DH0 volume. Both guest identity command exit codes are zero. Actual command output in `tests/guest-evidence/gfos-rc11-guest-identity.log`.

## All seven native guest smoke tests — PASS, rc0

The same `S:ACAgent` guest shell executed all seven production binaries *in one batch*, not Linux simulations. Its script printed the return code after each executable. The runner completed `run.done` and removed `run.running`. Exact stdout archived unedited as `tests/guest-evidence/gfos-rc11-full-suite-7of7-pass.log`.

| Native 68040 test | Observed guest output | Guest return |
| --- | --- | --- |
| `gfos_exec_port_probe_68040` | `GFOS_EXEC_PORT_PROBE_PASS` | **0** |
| `gfos_sync_selftest_68040` | `GFOS_SYNC_SINGLE_TASK_PASS` | **0** |
| `gfos_transport_selftest_68040` | `GFOS_TRANSPORT_ROUNDTRIP_PASS` | **0** |
| `ffi_smoke_68040` | `GFOS_FFI_PASS int=20 double=4.375` | **0** |
| `foundation_smoke_68040` | `FOUNDATION_CORE_PASS len=4 items=1 dict=1` | **0** |
| `foundation_date_probe_68040` | `DATE_PROBE_PASS` after testing NSDate/NSData/NSMutableArray | **0** |
| `foundation_ipc_smoke_68040` | `GFOS_FOUNDATION_IPC_PASS` | **0** |

## What fixed the last guest failure

The previous Objective-C IPC smoke intermittently failed or stalled during one complex, nested message-expression send call. The clean guest diagnostic separated **construction of NSDate, creation of NSMutableArray, Objective-C method existence/IMP resolution, and actual send**. It then executed native `NSMessagePort` creation, named registration and lookup, send, receive, reply acknowledgement and cleanup, returning rc0. The diagnostic log showed `gfosStatus=0` and `GFOS_FOUNDATION_IPC_PASS`. The **production test** (`tests/foundation/foundation_ipc_smoke.m`) now pre-constructs and validates arguments before the `sendBeforeDate:msgid:components:from:reserved:` call. It was rebuilt *without temporary debug printing* using the existing native GFOS NSMessagePort class source and passed in the same guest suite. Rebuilt binary SHA-256: `e9f9cc3dcf8f6d2ea71ba97b93355ded66b4c1417d46938cc4c4d6ddbeb2922c`.

Other corrected build dependencies: libffi must compile m68k `sysv.S` with `-m68040 -m68881` for double return in fp0; GNUstep Base must use `--enable-pass-arguments --disable-fake-main` and applications explicitly call `GSInitializeProcess` before Foundation. The GFOS `NSPort +initialize` bypasses unsupported Unix default transport lookup; `NSMessagePortNameServer +sharedInstance` constructs its singleton with `NSAllocateObject` rather than forbidden `[self new]`. Patched source and repro instructions are in the repository; see `docs/RC1-MERGE-STATUS.md`, `docs/LIBFFI.md`, `patches/gnustep-base/0004-gfos-nsport-exec-default.patch` and the Makefile.

## Limits: not a complete Foundation API release

**This is a verified single-guest smoke-test prerelease, not full GNUstep Foundation conformance.** In particular:

- `NSMessagePort` currently handles local, one-NSData-component messages with explicit polling. Complete `NSRunLoop` integration with Exec signals and `NSConnection` / distributed objects remain unimplemented.
- The current smoke is **one guest task**, not concurrent multi-task IPC. Port lifetime, timeout/cancellation, run-loop dispatch, thread contention, remote sessions and in-flight teardown are not qualified.
- Exec semaphore `GFOSFoundationLock` has recursive semantics and is **not** asserted to be a drop-in nonrecursive `NSLock` implementation.
- GNUstep Base is still the selective static core archive. Build flags disable some iconv/Unicode, XML, TLS and other optional features pending OpenUp native integration. No final installer/SDK interoperability, Oolite app run, real 68060 hardware or AROS result yet.
- The linker currently uses `--whole-archive` for Foundation class registration; a normal static-link consumer qualification remains open.

Release label should remain **developer RC1.1 prerelease** until full interfaces and broader runtime tests pass. The original `v0.1.0-rc1` ZIP had known libffi and startup failures and must not be silently overwritten. This new release contains the *corrected* binaries and their guest evidence.
