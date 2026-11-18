# GFOpenGNUstep — integrated RC1 guest evidence and next gates

18 November 2026 UTC. `main` is the only branch in DalsinAI/gfopengnustep, and GitHub reports no open pull requests or unmerged branches. All verified source fixes are therefore consolidated by direct GitHub commits, as required by the project workflow; no local Git commit is made.

## Actual RC1 guest status

**Five of six original categories have achieved guest PASS with corrected diagnostic builds**: Exec MsgPort, SignalSemaphore, native Exec transport, native libffi integer/double calls, and GNUstep Base NSString/NSArray/NSDictionary/autorelease-pool. The first three work in the original RC1 ZIP; the FPU and Foundation startup fixes are only in corrected local builds, not in the historical `v0.1.0-rc1` release asset. Do not mark that ZIP as acceptance-tested.

**Additional guest PASS:** A separate native Foundation `NSDate`, `NSData`, `NSMutableArray` probe returned `DATE_PROBE_PASS`, shell exit code **0**, on the running AmigaChrome AC090 guest on 18 November 2026. Exact output in `tests/guest-evidence/gfos-rc1-guest-08-date-array-pass.log`. Test source: `tests/foundation/foundation_date_probe.m`.

**Still failing:** Objective-C `NSMessagePort`/`NSMessagePortNameServer` end-to-end round trip. After fixing the singleton with GNUstep's `NSAllocateObject()` and avoiding Unix socket defaults in `NSPort +initialize`, guest tests create both ports and successfully register/lookup a named port; one trace exits rc2 on attempted send, another hangs after `TRACE_11_BEFORE_SEND`. The date/array probe rules out a general failure of those classes, but not the exact evaluation or selector path in the IPC caller. No guest IPC pass is claimed. See `docs/RC1-GUEST-RESULTS.md` and issue #2.

## Corrected reproducible build options

GNUstep Base `configure` explicitly supports `--enable-pass-arguments` and `--disable-fake-main`. Use **both** for native AmigaOS rather than manually editing generated `GSConfig.h` files. Verify generated copies under both `Headers/GNUstepBase/GSConfig.h` and `Source/GNUstepBase/GSConfig.h` show `GS_PASS_ARGUMENTS=1`, `GS_FAKE_MAIN=0`. Each user executable must call `GSInitializeProcess(argc, argv, env)` before Foundation calls, passing a valid null-terminated environment array until native process environment integration is implemented.

Native m68k libffi's assembly must be built with **`-m68040 -m68881`** so the target selects 68881 floating-point register return handling. Use `CFLAGS='-O2 -m68040 -m68881'` at **libffi configure time**, confirm the generated Makefile and `sysv.S` compilation command, and rebuild/install before linking the final executable. This is not optional: the first prerelease's double-return test failed with 0.0; the corrected guest test returned 4.375 and rc0.

`NSPort` GFOS initialization patch `patches/gnustep-base/0004-gfos-nsport-exec-default.patch` avoids querying `NSUserDefaults` while choosing a transport class, since Unix socket selection is unsupported. `src/foundation/GFOSNSMessagePortNameServer.m` now uses `NSAllocateObject` for its singleton to avoid GNUstep's superclass +alloc prohibition. Both steps were validated as progress by actual guest traces but have not produced a complete IPC pass.

## RC1.1 gate

Do not merge temporary `SEND_DBG` instrumentation from `/tmp` into production source. Next step is an isolated guest test that constructs the date, `NSMutableArray` and receiver **as separate expressions** before calling `sendBeforeDate:msgid:components:from:reserved:`. Trace Objective-C selector lookup and actual entry to the send method. Fix the underlying failure, then run the native six-category guest suite and preserve stdout + exit codes. Build and publish a corrected RC1.1 prerelease only after the test results have been honestly recorded. Full `NSRunLoop`, concurrency and distributed-object semantics remain larger RC acceptance gates.

## References

- [RC1 guest test results](RC1-GUEST-RESULTS.md)
- [GNUstep Amiga messaging architecture](GNUSTEP-AMIGA-MESSAGING.md)
- [libffi build and guest FPU fix](LIBFFI.md)
- [Foundation Exec-port integration](FOUNDATION-EXEC-PORTS.md)
- https://github.com/DalsinAI/gfopengnustep/issues/1
- https://github.com/DalsinAI/gfopengnustep/issues/2
