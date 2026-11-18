# GNUstep Base core-only native archive — 18 November 2026

**Verified new result:** The pinned GNUstep Base 1.31.1 source can now successfully run a **GNUstep Base Source-level static archive build** for `m68k-amigaos` GCC 16.2, producing a 16 MB native `Source/obj/libgnustep-base.a` (240 archive members). Source `make -C Source ... shared=no GFOS_FOUNDATION_CORE_ONLY=yes -j6` exits **0**. Archive SHA-256: `b2b4deb2a7ecd47ffc20a87cf44f26730cdb501089f8185442bf62fc1dc5d1d1`. This is a **diagnostic core-only archive**, not fully linked, guest-running Foundation or an RC.

## How to reproduce

Start with pinned upstream GNUstep Make 2.9.3 and Base 1.31.1 as in `docs/NATIVE-BASE-PROGRESS.md`. Apply `patches/gnustep-base/0002-gfos-base-objc-libnix-sockets.patch` and `patches/gnustep-base/0003-gfos-native-foundation-core-portability.patch` in that order (`patch -p1`). Both patches were verified against an upstream pristine Base tree. Configure with `config/gfos-cross.config`, native libffi and the documented discovery-only build flags. Set PATH/GNUSTEP_MAKEFILES for host-built `gnustep-make`; add native NDK include path via CPATH. Run:

```
make -C Source CC=<m68k-amigaos-gcc> OBJC=<m68k-amigaos-gcc> CXX=<m68k-amigaos-g++> shared=no GFOS_FOUNDATION_CORE_ONLY=yes -j6
```

The `GFOS_FOUNDATION_CORE_ONLY=yes` build flag **excludes unported `NSMessagePort.m` and `NSMessagePortNameServer.m`**. It is NOT permission to ship Foundation claiming standard messaging support. Native `NSPort`, `NSConnection`, and other classes still reference those omitted classes, so a full link remains blocked. This is intended to qualify other Foundation APIs while completing proper Exec IPC integration.

## GFOS portability fixes from patch 0003

- `GSArray.m`: avoid GNU/ELF-style optional LeakSanitizer weak-symbol introspection on AmigaOS a.out, which was otherwise an unresolved link dependency.
- `NSData.m`: use existing libnix `chmod(path)` on the existing temporary filename instead of unavailable `fchmod(fd)`; validate Amiga filesystem protection semantics in guest.
- `GSFileHandle.m`: synchronize this file using existing libnix `fsync(descriptor)`, not the Unix-global `sync()` that is absent on target.
- `NSPage.m`: use an explicitly documented **4096-byte compatibility alignment granule**, not an asserted physical MMU page size, overallocate with `malloc` and store the base allocation pointer to free later; guard against allocation overflow. Physical memory / MMU page operations require a separate properly defined native interface.
- `Source/GNUmakefile`: conditional core-only lane without Unix-domain message port sources; retain the standard build when that flag is not set.

## Link smoke and exact remaining blockers

A native Objective-C smoke program (`tests/foundation/foundation_smoke.m`) uses real Foundation `NSAutoreleasePool`, `NSString`, `NSArray` and `NSDictionary` classes. The 68040 smoke object **compiles**. Linking using GCC 16.2 against the core archive, libobjc, target libffi, libpthread, libnix, zlib and socket archives was tried.

- Normal archive link currently does not resolve all ObjC class references from the target GNUmake-generated archive, requiring further static archive/index/build-flag audit.
- A diagnostic `--whole-archive` link, with the system and third-party libraries grouped, narrows **all remaining unresolved symbols to precisely two classes**: `__objc_class_name_NSMessagePort` and `__objc_class_name_NSMessagePortNameServer`. Neither has been replaced with a fake class. This demonstrates progress, **not a valid linked executable**.
- The top-level `make` also attempts GNUstep command-line tools (`gdnc`, `gspath`, etc.) using unsupported Unix `syslog` priorities and `-rdynamic`. Those belong in a separate GFOS-native tool/build-rules track; only Source archive build is reported as passing.
- No runtime AmigaOS/Foundation guest result exists yet. The optional ARexx bridge is still design-only.

## Next priorities

1. Implement real Foundation `NSMessagePort` and `NSMessagePortNameServer` using native `libgfosfoundationipc.a` and complete `NSRunLoop` event dispatch; test concurrency, cancellation and shutdown rather than injecting dummy class symbols.
2. Audit archive symbol table / automatic class retention to enable ordinary static linking without `--whole-archive`.
3. Link the actual Foundation smoke program, run on AmigaOS 3.2.3 / AROS, then restore Unicode/iconv, XML and TLS dependencies and integrate Oolite.
