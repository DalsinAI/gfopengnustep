# GFOpenGNUstep — native GNUstep for AmigaOS 3.x / GFOS

**Platform repository for GNUstep on GFOS and AmigaOS 3.2.3, initially 68040/68881 and then 68060.** Keep upstream GNUstep APIs compatible but replace unsupported operating-system assumptions with the existing OpenUp stack, repaired **libnix**, **OpenAmigaGCC 16**, Objective-C `libobjc`, pthreads/OpenMulticore, AmigaDOS, GFOpenUnicode and GFOpenGPU/OpenGadTools as appropriate. This is not a Linux distribution or a second graphics stack. All compiled targets must be native AmigaOS executable/object/library files.

## Modules and priorities

| Upstream component | GFOS target | Priority / state |
| --- | --- | --- |
| GNUstep Make (`gnustep/tools-make`) | Cross-build host tools + AmigaOS-target build rules; native install/packaging paths | Host make 2.9.3 configured, built and installed locally on daletop |
| GNUstep Base (`gnustep/libs-base`) | Foundation classes, initially `libgnustep-base.a`, later stable `foundation.library` if practical | 1.31.1 cross-configures and 241 native AmigaOS object files compile; full archive still blocked on native Foundation messaging / remaining integration |
| GNU Objective-C runtime | Existing GCC 16 `libobjc.a` | Present; Objective-C test class cross-compiled; GNUstep ABI/header adaptation needed |
| POSIX C/runtime | Existing repaired [GFOpenGCC libnix](https://github.com/DalsinAI/gfopengcc/tree/main/patches/libnix) | Existing 11 upstream patch fixes; must not reimplement |
| Threads and events | Existing pthreads / OpenMulticore / Exec | Target `libpthread.a` and headers exist; guest concurrency tests required |
| Foundation character conversion | GFOpenUnicode / GFOpenBrowser ICU or a native iconv bridge | **Missing from this build**, required for complete functionality |
| Foundation method invocation | Native GFOS-patched libffi 3.8.1 | **Cross-built and links into 68040 test executable**; method invocation and closure runtime guest tests still outstanding |
| Plists, XML, TLS | OpenXML, OpenTLS/OpenCrypto, GFOS services | Integration to be designed and verified; exploratory configure disabled XML/TLS |
| GNUstep GUI | OpenGadTools / OpenRTG / OpenGPU / OpenFont bridges | After Base. Avoid X11, cairo/pixman, a duplicate desktop compositor |
| GNUstep Back | Native GFOS backend to Intuition/OpenGadTools/OpenRTG/OpenGPU | After GUI; not yet started |

First demanding consumer: [AmigaOolite](https://github.com/DalsinAI/amigaoolite), which already builds two genuine upstream source modules for AmigaOS (galaxy RNG and planet mesh). Foundation needs to run Oolite, rather than becoming an incomplete private Oolite shim.

## Current native build receipt (daletop, 18 November 2026)

Pinned releases: `gnustep/tools-make` **make-2_9_3**, tag SHA `9f277f8f9eb04c77dfa3a2ea8dabb9d51f34a0c8`; `gnustep/libs-base` **base-1_31_1**, tag SHA `b1bfc5bbb404769e95db6944ec0ccfe59c24f3b5`.

- Downloaded and unpacked upstream source in `/tmp/gfopenfoundation-build-20261118/`, with no local commits. Host `gnustep-make` configure, make and install **passed** into an isolated `/tmp` prefix.
- Native GCC16 configure found working Objective-C runtime and target pthreads, `-m68040/-m68881` targets available. Initial Foundation `./configure --host=m68k-amigaos --build=x86_64-pc-linux-gnu` failed on constant-string support until `--enable-nxconstantstring` was applied. The next hard gate was missing target libffi. Temporarily using `--disable-invocations` exposed missing iconv; temporarily `--disable-iconv` then gave **configure exit 0**. These disabled features are for discovery **only**, not acceptable for an RC.
- First `make` used the host GNUstep-make default `gcc`, failing at missing host Objective-C compiler (`cc1obj`). Retrying with explicit GCC16 cross `CC`, `CXX` and `OBJC` exposed **real ABI/target issues**: legacy ObjectiveC2 GNUstep compatibility layer includes removed `objc/objc-api.h`; GNUStep's generated ObjectiveC2 runtime symbols/properties conflict with the GCC16 `objc/runtime.h`; generated code also uses `@GOT(a4)` relocations unsupported by the chosen m68k-amigaos assembler/linker path. No native Foundation archive yet.

See [docs/BUILD-GATES.md](docs/BUILD-GATES.md) for the precise stop points and next fixes. **Never describe a successful configure as a successful build or guest test.**

## Native AmigaOS messaging and synchronisation

The [GFOS-native GNUstep messaging architecture](docs/GNUSTEP-AMIGA-MESSAGING.md) is now documented and has initial buildable components. Foundation `NSMessagePort` uses **Exec message ports** as its intended transport; `NSLock`/`NSRecursiveLock` integration uses **Exec SignalSemaphore** and existing pthread/OpenMulticore; **ARexx** is a separate optional command bridge, not a replacement for message payloads. Native source builds now include `libgfosfoundationipc.a`, `libgfosfoundationsync.a`, an `NSData` receive adapter, a semaphore adapter and 68040 smoke-test executables. Full Foundation IPC event-loop integration, guest tests and RC remain pending.

See [IPC implementation and limitations](docs/IPC-GFOS.md), [native GNUstep Base build receipts](docs/NATIVE-BASE-PROGRESS.md) and [libffi port instructions](docs/LIBFFI.md).

## GFOS integration rules

The build should eventually install standard GNUstep headers and native libraries into the GFOS SDK, using Amiga-native assigns and library lookup paths in runtime code, not Linux `/usr`, `/proc`, X11 or generic Unix DLL assumptions. Preserve ObjC method dispatch, retain/release, exception/forwarding semantics, resource bundles and multithreaded safety. Native GUI/back libraries are an additional programme, not prerequisites for Oolite's nongraphical Foundation classes.

The GNUstep components have upstream licensing conditions that must be carried individually; do not assume every GNUstep component shares a single licence. The base release's Foundation implementation is LGPL-family; read and retain upstream files when redistributing. The `libobjc` and libnix licensing remains independent.
