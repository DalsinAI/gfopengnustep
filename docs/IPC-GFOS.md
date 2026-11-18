# GNUstep Foundation IPC: replace Unix sockets with Exec message ports

## Why this is mandatory

GNUstep Base 1.31.1's `NSMessagePort.m` and `NSMessagePortNameServer.m` use Unix-domain sockets (`AF_UNIX`, `PF_UNIX`, `sockaddr_un`) and filesystem socket pathnames, an assumption not provided by GFOS/AmigaOS 3.x. `NSPort` public API must keep standard Foundation semantics, but its IPC backend must use native Exec and OpenUp services. Inventing AF_UNIX constant values would compile the wrong transport and is not acceptable.

The existing AmigaOS NDK provides `CreateMsgPort`, `DeleteMsgPort`, `AddPort`, `RemPort`, `FindPort`, `PutMsg`, `GetMsg`, `ReplyMsg`, `WaitPort`, `Forbid`, `Permit`. The executable `tests/ipc/gfos_exec_port_probe.c` tests the real *single-task* named-port and request/reply API sequence. It cross-compiles **successfully** to a native GCC16 68040 AmigaOS loadseg executable. SHA256 `4e811f06a52d07ce244c9b05d3cde34aaa71e15a4573edace401090182f09ddb`. Actual guest execution has NOT yet been performed.

## Production design gates

1. Define a stable `NSPortMessage` envelope (protocol/version, byte length and bounded payload, message IDs, sender identity, optional shared-buffer ownership). Exec Message pointers work only within one address space; define explicit copy/ownership semantics for remote Cradle/external GFOS expansions later.
2. Implement name registration and lookup with `FindPort`/`AddPort`/`RemPort`, global/public port lifetime and collision control, plus process/task termination cleanups. The Exec list lock (`Forbid`/`Permit`) must span the actual Send `PutMsg` operation to avoid a use-after-remove race.
3. Map Foundation run-loop scheduling to task signals/message availability, with timeouts and cancellations. A synchronous reply port is not sufficient for real `NSMessagePort` when callbacks and nested event loops occur.
4. Implement remote transport and name-server cross-process semantics if required for distributed objects. Handle errors on dead tasks, resource exhaustion, oversize sends, registration collisions and concurrent close/send. No unbounded waiting.
5. Preserve Foundation `NSMessagePort`/`NSPortNameServer` APIs and types (not an Amiga-only application API). Validate two-task concurrent sending, multiple requesters, timeout, cleanup, object retain/release, and shutdown under guest AmigaOS.

Do not promote the single-task compile probe to a production transport. Existing [GFOpenMulticore](https://github.com/DalsinAI/gfopenmulticore) may provide scheduling assistance, but the actual Exec IPC ownership needs runtime testing first.

The current GNUstep Base source build stops in `NSMessagePortNameServer.m` because of AF_UNIX/PF_UNIX assumptions, after 241 native AmigaOS object modules had already been built. The existing Foundation symbols cannot be declared complete until this is integrated and tested.

## First reusable transport implementation (new)

`src/ipc/gfos_transport.{h,c}` now implements a **native static GFOS transport**, `libgfosfoundationipc.a`, with:

- Named public port registration and collision protection under `Forbid/Permit`, plus an unnamed private reply-port option
- Bounded (32 KiB) public-memory envelopes that respect Exec's 16-bit `mn_Length` with a magic/version field, request ID, status, payload length and send state
- Race-safe lookup + `PutMsg` under the same `Forbid/Permit` critical section; never waits with multitasking disabled
- Nonblocking receive/reply queue polling and `ReplyMsg` handback; the sending task owns its allocated envelope until a reply arrives
- Duplicate-send refusal on already-sent envelopes, and a single-process roundtrip self-test checking payload integrity, request ID and status

`Makefile` builds `libgfosfoundationipc.a` and a native `gfos_transport_selftest_68040` along with the earlier libffi and Exec probes. The cross-build and native link both passed with OpenAmigaGCC16 and no compiler diagnostics. The produced files have been verified to be AmigaOS object/library data and loadseg executable format. **Guest execution is still outstanding.**

Important: this is an **IPC substrate**, not yet a GNUstep `NSMessagePort` subclass or a completed Foundation run-loop integration. Production integration must address concurrent receive/close, dead-client handling, reply port lifetime, timer-based cancellation without use-after-free, message dispatch and cross-task/multicore tests. Until those semantics are proven, do not mark the Foundation IPC gate closed or publish RC.

## Objective-C Foundation bridge compilation

`src/foundation/GFOSFoundationEndpoint.{h,m}` provides a first **real Foundation-facing** class: a named `GFOSPort` backed by Exec and `-receiveNextPayloadWithRequestId:` producing an `NSData` copy *before* calling `ReplyMsg`. This keeps payload ownership correct when the sending task reclaims the envelope. It safely scopes Amiga Exec's 16-bit BOOL under `GFOS_ExecBOOL` rather than polluting the GCC16 Objective-C BOOL type. An actual `GFOSFoundationEndpoint.m` Objective-C module cross-compiled as an AmigaOS object against the GNUstep Base 1.31.1 headers with GCC16, and is reproducible via `make foundation-bridge GNUSTEP_BASE_DIR=<patched-gnustep-base>`.

This bridge is presently a **nonblocking single-task prototype**, not a production-complete `NSMessagePort` or `NSRunLoop` source; it deliberately has no sent-message lifetime management or concurrent `invalidate` semantics. A real run-loop adapter must use Exec task signals and handle invalidation while callbacks are active. No guest execution or native Foundation linkage has passed yet.

## Message ownership hardening

Native transport has been tightened so `gfos_message_free()` refuses an in-flight message, a reply port refuses `gfos_port_close()` while its outbound counter is nonzero, and polling an acknowledgement decrements that counter and marks the envelope replied. The self-test checks duplicate-send rejection, premature-free rejection and premature reply-port closure. Public receive-port cleanup replies queued requests; private acknowledgement ports do not erroneously `ReplyMsg()` responses a second time. GCC16 native static archive, test executable and Objective-C object recompile successfully with the stronger checks.

Remaining concurrency caveat: send/receive/close APIs currently expect their owning task to serialize operations. The outbound counter is not yet an intertask atomic lifetime protocol; a production Foundation object needs an Exec semaphore/lock and active-callback tracking. No timeout/cancel handling or guest runtime result exists yet.
