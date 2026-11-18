# GNUstep for GFOS — verified build gates and next engineering tasks

**Verified on daletop (18 November 2026):** host GNUstep Make 2.9.3 configured, built and installed; GNUstep Base 1.31.1 configured for `m68k-amigaos` with feature reductions; **native GNUstep Base compilation did not pass**.

## Baseline and reproducibility

Pin `gnustep/tools-make` to tag SHA `9f277f8f9eb04c77dfa3a2ea8dabb9d51f34a0c8` and `gnustep/libs-base` to tag SHA `b1bfc5bbb404769e95db6944ec0ccfe59c24f3b5`.

Host build: configure tools-make in a separate prefix (`./configure --prefix=/tmp/gnustep-host`), run `make -j4 && make install`. For Base, set `PATH=/tmp/gnustep-host/bin:$PATH` and `GNUSTEP_MAKEFILES=/tmp/gnustep-host/share/GNUstep/Makefiles`, and use cross compiler `CC`, `OBJC`, `CXX` from the isolated OpenAmigaGCC16 prefix.

Exploratory Base configure arguments: `--host=m68k-amigaos --build=x86_64-pc-linux-gnu --enable-nxconstantstring --disable-invocations --disable-iconv --disable-libffi --disable-xml --disable-tls --disable-icu --disable-libdispatch`. These options are **not** the intended production features. They were used to isolate the next compile problems. `--disable-native-objc-exceptions` is a tools-make option, not recognized by Base configure.

## Work gates

1. **Fix native GNUstep make configuration.** The host make package currently chooses host `gcc` by default even when Base configure used target `CC`. Pass explicit `CC=... OBJC=... CXX=...` (and correct `GNUSTEP_MAKEFILES`) to all recursive make invocations. Target should use Amiga-supported static linking and baserel or non-PIC flags, **not** Linux/ELF `@GOT(a4)` code generation. Reconfigure `gnustep-make` for a cross target or supply GFOS-specific make rules, with a native object test.
2. **Align GNUstep's ObjC2 compatibility layer to GCC16 libobjc.** Source `Source/ObjectiveC2/runtime.c` and `sync.m` include `objc/objc-api.h`, which is absent in GCC16. The GNUstep-provided `Headers/ObjectiveC2/objc/runtime.h` conflicts with GCC16's `objc/runtime.h` (objc_property_t, class_copyMethodList etc.). Investigate configuring the correct GNUstep runtime family, and disable/rework only incompatible redundant compatibility shims. Never invent obsolete runtime structs without ABI validation.
3. **Cross-build target libffi**, or an equivalent reviewed m68k libobjc forwarding backend. The configure explicitly rejects missing FFI unless `--disable-invocations`; full `NSInvocation` and reflection need real support.
4. **Cross-build iconv or bridge GFOpenUnicode** for Foundation encodings, `NSString` etc. Configure refuses absent character conversion unless `--disable-iconv`. Verify Unicode conversions on actual AmigaOS.
5. **Re-enable Foundation XML, TLS, ICU** using OpenXML/OpenTLS/GFOpenUnicode only after interfaces and licences are reviewed. Do not package incomplete Foundation as a full system library.
6. **Produce native `libgnustep-base.a`, then guest probes** (`NSObject` lifetime, `NSString`, `NSArray`, `NSDictionary`, `NSData`, `NSLock`, path/NSBundle/filesystem, property lists, ObjC exceptions and method invocation). Check both 68040/68060 and Oolite actual resource load, save/quit.
7. **After Base**, start GNUstep GUI/Back using Intuition/OpenGadTools/OpenRTG/OpenGPU; do not depend on X11 or a second SDL/GL implementation.

The relevant C runtime is already in [GFOpenGCC patches/libnix](https://github.com/DalsinAI/gfopengcc/tree/main/patches/libnix): 11 patches for stack swaps, FPCR, C++ destructors, thread-safe locale, socket calls, usergroup and other correctness bugs. Reuse and test, not rewrite. The canonical overarching repo is [DalsinAI/gfopengnustep](https://github.com/DalsinAI/gfopengnustep); [gfopenfoundation](https://github.com/DalsinAI/gfopenfoundation) tracks Base-specific work.
