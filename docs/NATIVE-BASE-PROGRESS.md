# GNUstep Base 1.31.1 — GFOS native cross-build evidence (18 November 2026)

**Cross-built 241 `.o` files so far, including actual Foundation `NSString`, `NSArray`, `NSDictionary`, `NSFileManager`, `NSThread`, `NSTimeZone`, `NSLog` and `NSHost`.** This is not a complete GNUstep Base library or a guest-validated release; final `make` stops in `NSMessagePortNameServer.m` because GNUstep assumes AF_UNIX/PF_UNIX socket IPC while the inspected GFOS SDK does not provide a working Unix-domain sockets interface. Do NOT define fake AF_UNIX values to suppress the failure.

## Proven steps

- Host `gnustep/tools-make` 2.9.3 (`9f277f8f9eb04c77dfa3a2ea8dabb9d51f34a0c8`) built and installed successfully in isolated host prefix.
- `gnustep/libs-base` 1.31.1 (`b1bfc5bbb404769e95db6944ec0ccfe59c24f3b5`) configures for `--host=m68k-amigaos` with existing native libffi installed; `ffi.h... yes`, `FFI library usage... libffi`.
- **Objective-C runtime compatibility fix:** GCC16 `libobjc.a` actually exports `_objc_getProperty`, `_objc_setProperty`, `_objc_sync_enter`, `_class_copyMethodList`. GNUstep Base's stock `cross.config` erroneously says `cross_objc2_runtime=0`; use the new `config/gfos-cross.config` with `cross_objc2_runtime=1`. This skips an obsolete ObjectiveC2 shim requiring nonexistent `objc/objc-api.h`, and unlocks compiling current Foundation classes.
- **Static build**: pass explicit cross `CC`, `OBJC`, `CXX` to make, plus `shared=no`. This avoids earlier unsupported PIC/GOT style and accidental host-gcc compilation.
- **SDK limitation:** some header symlinks in the isolated GCC16 prefix point at a missing old installation root. `CPATH=/path/to/ndk-include.vendor` exposed the real headers without modifying the shared stove. It also revealed a separate ABI type difference: Amiga Exec's 16-bit BOOL conflicts with GCC libobjc's 8-bit BOOL. `patches/gnustep-base/0002...patch` isolates affected Roadshow header imports to prevent the collision (do not redefine the Objective-C runtime BOOL globally).
- **Native libnix adjustments:** `NSLog.m` selects its native file-descriptor/stderr path when `syslog.h` is absent (despite configure reporting a libc syslog symbol); `NSTimeZone.m` uses existing libnix `_daylight`; `NSPathUtilities.m` explicitly includes existing NDK `pwd.h` when a broken symlink made configure miss it; `NSThread.m` makes empty `_POSIX_THREAD_PRIORITY_SCHEDULING` macros safe for preprocessor expressions; `NSException.m` avoids `dladdr` when `Dl_info` API is absent.
- **Patch quality:** full 10-file patch dry-run succeeds (`patch -p1 --dry-run`) on a separate *unmodified* GNUstep Base 1.31.1 tarball. No silent external modifications, and no changes to the shared GCC/libnix stove.

## Reproducing the current source compile

Fetch the pinned GNUstep Make and Base tags from official upstream. Install host tools-make with standard `./configure --prefix=<host-prefix> && make && make install`. Download the already ported and installed native libffi from the GFOpenGNUstep libffi patch, or build it in an isolated target prefix.

Apply `patches/gnustep-base/0002-gfos-...patch` to GNUstep Base (`patch -p1`). Configure Base with your cross compiler in `CC`, `OBJC` and `CXX`, `PATH` containing host gnustep-config, `GNUSTEP_MAKEFILES=<host-prefix>/share/GNUstep/Makefiles`, and the flags below:

```
--host=m68k-amigaos --build=x86_64-pc-linux-gnu
--with-cross-compilation-info=/path/to/config/gfos-cross.config
--enable-nxconstantstring
--with-ffi-include=/path/to/target-libffi/include
--with-ffi-library=/path/to/target-libffi/lib
--disable-iconv --disable-xml --disable-tls --disable-icu --disable-libdispatch
```

The disabled optional features are discovery-only; **not an RC specification**. Character conversion must be restored via GFOpenUnicode/native iconv, XML via OpenXML, TLS via OpenTLS, and all Oolite-relevant Foundation APIs must be tested.

Make invocation: `make CC=<m68k-amigaos-gcc> OBJC=<m68k-amigaos-gcc> CXX=<m68k-amigaos-g++> shared=no -j6` with `CPATH` pointed to the NDK headers. No native Base archive has passed full `make` yet.

## Next required GFOS implementation work

1. Native `NSMessagePort` / `NSMessagePortNameServer` transport and name lookup via Exec messaging / GFOS services; preserve Foundation's `NSPort` semantics. Unix `AF_UNIX`/`PF_UNIX` socket assumptions are not portable to this target. Implement and test—not stub.
2. Finish remaining native Base compile errors after replacing the Unix-domain port transport, complete static `libgnustep-base.a`, and resolve target link symbols.
3. Guest-run real Foundation class tests (`NSString`, collections, plists, NSFileManager, NSThread, NSLock, NSInvocation, logging, locale). Guest-run native libffi integer/double call and closure trampoline tests before RC.
4. Restore iconv/Unicode, XML and TLS capabilities through GFOS/OpenUp facilities; evaluate AROS and 68060 builds; integrate real Oolite source.

Gating issue: https://github.com/DalsinAI/gfopengnustep/issues/1 . GNUstep Base subproject https://github.com/DalsinAI/gfopenfoundation .
