# GFOpenGNUstep native defaults + filesystem UAT — 19 November 2026

## Scope and environment

Pinned GNUstep Base `gnustep-libs-base-b1bfc5b` in the persistent Oolite/GFOS DevDrive workspace; GCC 16.2 native `m68k-amigaos`, A1200/AC090 68040 running AmigaOS 3.2.3 in isolated cloned guest at `/mnt/xs1000/oolite-sdl3-input-uat-20261118` (ports 9240/9241). Original historical guest/other teams' labs untouched. Tests use native `loadseg()` executables, not host simulations. Patch `0005-gfos-native-userdefaults-filesystem-bootstrap.patch` changes only GNUstep Base `Source/NSUserDefaults.m`, `NSFileManager.m`, `NSDistributedLock.m` behind AmigaOS preprocessor guards. No shared runtime binaries were replaced.

## Verified defects

1. `NSUserDefaults +initialize` recurses at `GSPrivateInfoDictionary(nil)` during bundle identifier lookup. GFOS fallback uses existing `processName` as defaults domain.
2. `NSUserDefaults -initWithUser:` recurses through `GSDefaultsRootForUser` / `NSPathUtilities`. GFOS native directory `SYS:Prefs/Env-Archive/GNUstep/.GNUstepDefaults` avoids the recursive startup path.
3. `NSUserDefaults +standardUserDefaults` recurses in locale configuration. Initial native bootstrap registers `_unlocalizedDefaults`, updates cache and unlocks. Other platform logic remains unchanged. Language-specific domains remain a follow-on compatibility concern.
4. `NSFileManager -createDirectoryAtPath:attributes:` returns false *despite successful native mkdir*, because it synthesizes a Unix owner and `chown` fails on AmigaDOS. Guard Unix root-owner assignment only for GFOS. Before: both API creations returned 0 though directories physically existed; after: both return 1 in guest and directories exist.
5. `NSDistributedLock -initWithPath:` attempts POSIX `isWritableFileAtPath`/`isExecutableFileAtPath` preflight that hangs or gives misleading results with AmigaDOS protections. GFOS skips those preflight checks, preserving actual lock acquisition and release, filesystem enforcement and concurrency locking.
6. After successfully serializing a defaults plist, GNUstep `setPermissions()` applies Unix mode rewriting. On native GFOS it reenters standard defaults/filename metadata while the defaults lock is held. GFOS skips that POSIX adjustment. Native AmigaDOS protection semantics need a separate dedicated implementation.

## Native guest evidence

- `filemanager-mkdir-v2-guest-pass.log`: real native test shows `plain-created=1`, `perms-created=1`, both exist, RC 0.
- `distributed-lock-fresh-68040-guest-pass.log`: two consecutive real lock acquire/release cycles, first=1, second=1, RC 0. Fresh test name required because an earlier unsuccessful host-side change retained stale `.amigachrome-meta.json` entries in a disposable guest folder. That metadata issue remains a separate ACFS investigation.
- `defaults-clean-patch0005-first-guest-pass.log`: patched uninstrumented GNUstep Base native executable opens defaults, sets and reads key, reports `synchronize=1`, exit RC 0; actual XML plist physically present on DH0 in `Prefs/Env-Archive/GNUstep/`.
- `defaults-clean-patch0005-reload-guest-pass.log`: **separate invocation** of the same executable reads saved key *before writing*: `GFOS_DEFAULTS_RW before=roundtrip-68040`, then `synchronize=1`, RC 0.
- Original untouched native preferences probe independently stalls before return from `[NSUserDefaults standardUserDefaults]`. Earlier diagnostic-only workarounds passed in-memory but failed persistence; only final clean patch 0005 was promoted.

## Reproducible build / replay

Apply the patch to the pinned GNUstep Base source using `patch -p1`; replay was dry-run tested and the three resulting sources byte-for-byte matched the isolated source copies. Cross-compile the three `.m` files with GCC 16.2, GNUstep Base headers, `-DGNUSTEP_BASE_LIBRARY=1`, `-m68040 -m68881 -noixemul`, replace archive members `NSUserDefaults.m.o`, `NSFileManager.m.o`, `NSDistributedLock.m.o` **in a private copy** of `Source/obj/libgnustep-base.a` with `m68k-amigaos-ar r`, run `m68k-amigaos-ranlib`. Link `tests/foundation/gfos_defaults_native_68040.m` against this archive plus GFOS ports, IPC, libffi, libobjc, libpthread, libm, libz, libsocket (link examples in `gfopengnustep/ci-check/Makefile`). Do not embed an entire GNUstep Base archive into unrelated common libraries.

## Remaining release gates

This qualifies the bootstrap and basic single-application durable preferences round trip on **one AC090 68040 isolated guest**; it does not validate multi-process concurrent lock contention, stale lock recovery, permissions/hardening, language/locale preference domains, alternate AmigaDOS volumes or AROS, or all Foundation APIs. It is not evidence the whole original Oolite game reaches its title screen: the existing Oolite executable still stalls in `MyOpenGLView -init` and must be relinked with patched GNUstep Base for a valid retest. No general GFOS UAT or Oolite RC1 release should be declared from this probe alone.

## Additional isolated guest regression (verified after initial patch publication)

The published GNUstep private archive was relinked into three existing Foundation 68040 tests, rather than using old guest binaries. Each was executed in the same independent AmigaOS 3.2.3 AC090 guest:
- `foundation_smoke-patched-defaults-68040`: `FOUNDATION_CORE_PASS len=4 items=1 dict=1`, RC0
- `foundation_date_probe-patched-defaults-68040`: `DATE_PROBE_PASS`, RC0
- `foundation_ipc_smoke-patched-defaults-68040`: `GFOS_FOUNDATION_IPC_PASS`, RC0

`tests/evidence/gfos-foundation-patch0005-regression-3of3-68040-guest-pass.log` records all three in one ordered ACAgent command. This is a regression smoke gate, not comprehensive thread/contention/locale qualification.

The reproducible `make native-defaults-68040` target was subsequently added to GFOpenGNUstep Makefile. It applies patch 0005 to **private source copies**, assembles a private archive with original Base `.a` preserved, links an original GNUstep Base program, and the resulting guest executable passed `NSUserDefaults` set/get/save with `synchronize=1`, RC0; evidence `tests/evidence/defaults-make-target-68040-guest-pass.log`.
