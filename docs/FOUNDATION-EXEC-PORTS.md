# GFOpenGNUstep — native Foundation Exec ports and RC1 test candidate

18 November 2026, daletop. **Native GNUstep Base 1.31.1 core archive cross-builds, and two real Foundation smoke executables cross-link successfully. No AmigaOS guest execution has been completed.** The RC1 candidate is a pre-release developer qualification pack, not a stable or production-complete GNUstep/Base release.

## Implementation

- `src/foundation/GFOSNSMessagePort.m`: real partial Foundation NSMessagePort class based on the existing GFOS/Exec message transport. Supports local private ports; one NSData payload component per message; named public registration; async send; explicit receive/poll; real `NSPortMessage` with request ID; delegate call and reply-envelope handback. Other component forms and distributed objects are not supported.
- `src/foundation/GFOSNSMessagePortNameServer.m`: local NSMessagePortNameServer using Exec public named ports with collision control and local lookup. Remote hosts are deliberately unsupported; only one public alias per port. Full concurrency/lifetime handling remains outstanding.
- `src/foundation/GFOSNSMessagePort.h`: GFOS-specific extension API for polling and name publication.
- `src/ipc/gfos_transport.{c,h}`: public publish/unpublish/existence operations now supplement existing bounded native Exec messaging and acknowledgement safety. Real Exec services are called; no fake AF_UNIX compatibility.

## Confirmed build output

- Native GNUstep Base core-only archive `libgnustep-base.a`: 16 MB, 240 archive members; GNUstep Source `make` exit 0 after GFOS patches 0002 and 0003. It excludes Unix-domain socket message-port sources and is NOT the complete Foundation implementation.
- Native `libgfosfoundationports.a`, `libgfosfoundationipc.a`, `libgfosfoundationsync.a`, and patched `libffi.a` are compiled and archived as native m68k AmigaOS objects.
- `make foundation-core-link` exits 0 and produces native AmigaOS loadseg executables `foundation_smoke_68040` and `foundation_ipc_smoke_68040`, verified by `file`. The Foundation smoke tests use real Foundation collection APIs and named-port send/receive/reply APIs respectively.
- `foundation_smoke_68040` SHA-256: `8b1f175426a29c10134e2a3831e5179de5a7aef5cbbf152c795da1377e5bdafa`.
- `foundation_ipc_smoke_68040` SHA-256: `4f0d27a1952751e27871abf3aa2c6f19e8390963dc615f2792298b86a156307e`.

## Limitations and RC gate

`NSRunLoop` integration with Exec task signals, cancellation/deadlines, multiple message components, `NSConnection`/distributed objects, native locking correctness (recursive vs nonrecursive semantics), public-port lifecycle across tasks, concurrency, full Objective-C class registration and autorelease behaviour, Unicode/iconv, XML/TLS and actual AmigaOS runtime operation remain outstanding. The link currently uses `--whole-archive` for the Foundation core; ordinary archive-index class loading needs qualification.

This package is published as a **prerelease RC1 developer candidate**, for guest testing and defect discovery only. It does **not** pass the final RC1 acceptance gate. Do not promote it to stable until real AmigaOS guest test logs and exit codes are collected, run-loop and port lifetime semantics are corrected, and Foundation functionality required by the first customer (Oolite) is proven.

## Licence and provenance

GNUstep Base upstream `gnustep/libs-base` tag `base-1_31_1` (`b1bfc5bbb404769e95db6944ec0ccfe59c24f3b5`). GNUstep Make upstream `gnustep/tools-make` tag `make-2_9_3` (`9f277f8f9eb04c77dfa3a2ea8dabb9d51f34a0c8`). libffi upstream v3.8.1 (`a09b362a01e17842184732223184253986c2cc4e`). Binary GNUstep Base must be accompanied by proper LGPL compliance, upstream source location, upstream licences and patch series; these are included as references and patches in the project. This development pack does not replace the upstream source or licensing obligations.
