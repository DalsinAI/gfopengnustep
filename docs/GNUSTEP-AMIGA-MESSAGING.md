# GFOpenGNUstep: native AmigaOS messaging, locking and ARexx integration

## Architectural decision — 18 November 2026

GNUstep must expose its *normal Foundation APIs* to applications, but the implementation on GFOS / AmigaOS 3.x should use native Exec facilities rather than pretending the guest is Unix. The three related but distinct mechanisms are:

| GFOS mechanism | What it does | GNUstep interface | Implemented today |
| --- | --- | --- | --- |
| `exec.library` message ports (`MsgPort`, `Message`, `PutMsg`, `GetMsg`, `ReplyMsg`, `WaitPort`, `FindPort`) | Request/reply and asynchronous delivery between tasks | `NSMessagePort`, `NSPortMessage`, `NSPortNameServer`, `NSRunLoop` integration | **C substrate plus Objective-C receive adapter**, but not a completed Foundation messaging backend |
| Exec `SignalSemaphore` (`InitSemaphore`, `ObtainSemaphore`, `AttemptSemaphore`, `ReleaseSemaphore`) | Synchronises access to shared resources and data across tasks | `NSLock`, `NSRecursiveLock` / threading support | **C static library and Objective-C wrapper compiled**; guest concurrency and correct NSLock semantics remain |
| ARexx | Application scripting and command exchange over Exec ports with the Rexx protocol | Optional ARexx gateway to selected Foundation objects / `NSInvocation` methods | **Design only**; no Rexx protocol adapter yet |

**Do not conflate these.** A semaphore is not a message transport; ARexx uses Exec ports but has a Rexx-specific message format and language runtime; a Foundation `NSPortMessage` is not an ARexx `RexxMsg`. Passing arbitrary Foundation payloads directly to an ARexx port is incorrect. Native Exec ports are the base IPC primitive.

## Runtime architecture

```
Oolite / Objective-C applications       Classic Amiga applications and scripts
               |                                     |
      Foundation-compatible API                   ARexx commands
     NSMessagePort / NSRunLoop                      (optional)
     NSLock / NSRecursiveLock                          |
               |                                 ARexx gateway
               v                                     v
       GFOS Foundation adapters <----------> GFOS service dispatcher
                  |                                  |
      +-----------+-----------------+----------------+
      |                             |
  Exec MsgPort                   Exec SignalSemaphore
  (PutMsg/ReplyMsg)              (Obtain/Release)
      |                             |
                AmigaOS Exec / GFOS
```

### 1. Native messaging

- Use Exec public named ports for local service discovery and private reply ports for requests and replies. Enforce bounded payload sizes, ownership, request IDs, explicit errors and protocol version.
- `Forbid`/`Permit` may protect the short lookup-plus-queue action; **never wait, allocate, perform long callbacks or call blocking semaphores while tasks are forbidden**.
- A queued Exec `Message` is owned by the protocol until replied. Caller must not free or reuse an in-flight envelope, and must keep its reply port alive until completion. Avoid sending to a removed port by holding the appropriate list protection during lookup and `PutMsg`.
- The initial `libgfosfoundationipc.a` implements bounded async delivery, acknowledgement and single-owner lifetime counters. Full concurrency needs proper locks, timer/cancel logic, active-callback tracking, and atomic invalidation.
- Preserve GNUstep's `NSMessagePort` public protocol and delegate semantics. `NSRunLoop` must wait on Exec task signal bits and handle nested event loops, callbacks, cancellation and wakeups; do not merely rename a C `MsgPort` type.
- Distributed-object IPC beyond the local host may eventually use the wider GFOS/Cradle remote session transport, but that is not a prerequisite for local Foundation compatibility.

### 2. Native synchronisation

- `libgfosfoundationsync.a` wraps Exec `SignalSemaphore` using C `GFOSMutex` functions. A native single-task qualification executable checks initialisation, nested acquisition, release and reacquisition. It **cross-compiles and links** with GCC 16; it has **not been run in a guest**.
- `GFOSFoundationLock` is an Objective-C bridge compiled against the real GNUstep Base headers. The initial Exec `SignalSemaphore` is recursively owned; this prototype is therefore **not an ABI-compatible drop-in implementation of nonrecursive `NSLock`**. Correct `NSLock`/`NSRecursiveLock` ownership rules, task contention, try-lock, timeouts, wakeups and destruction must be qualified before substituting it in Base.
- Existing pthread/OpenMulticore support remains the Foundation threads interface; native semaphores may underpin it, rather than creating an independent threading stack.

### 3. Optional ARexx gateway (separate from the IPC core)

Expose selected Foundation services to classic Amiga applications as a distinct ARexx command interface, e.g., application status, resource query, and requested actions. Use the Amiga `rexxsyslib.library` protocol and `RexxMsg` structures, safe argument/result memory, and explicit command permissions. Bridge to Foundation objects via vetted selectors or service registry; never accept arbitrary selector invocation or treat incoming payloads as trusted Objective-C object pointers. Guard against reentrancy, dead scripts, and stale target objects. ARexx is an **interoperability adapter**, not the Foundation runtime transport.

No native ARexx adapter has been built or tested yet; it should follow a working Exec/NSRunLoop implementation. The ARexx command surface should be versioned and independently optional.

## Reproducible build evidence

The top-level `Makefile` targets `native-probes` and `foundation-bridge` produce native 68040 objects and executables with OpenAmigaGCC 16. Native test sources are in `tests/ipc/`, `tests/sync/` and `tests/ffi_smoke.c`. Object and archive file type verification is separate from **guest execution**; tests may be labeled passed only after an actual AmigaOS runtime log and exit code are captured.

We now cross-build the following pieces:

- `libgfosfoundationipc.a`: native message-port transport with bounded envelopes and send/reply ownership rules
- `GFOSFoundationEndpoint.o`: Foundation `NSData` receive-side bridge
- `libgfosfoundationsync.a`: native Exec SignalSemaphore wrapper
- `GFOSFoundationLock.o`: Foundation-facing semaphore wrapper, currently recursive semantics
- `gfos_transport_selftest_68040`, `gfos_exec_port_probe_68040`, `gfos_sync_selftest_68040`, `ffi_smoke_68040`: linked native tests, **not guest-validated**

## Gates to GFOpenGNUstep RC1

1. Integrate native transport as the real GNUstep `NSMessagePort`/name server implementation and deliver messages through `NSRunLoop`.
2. Qualify concurrency, in-flight close/cancel, port registration collision, memory release, task termination and timeouts under actual AmigaOS; verify the lock interfaces' semantic equivalence.
3. Finish building and linking real native `libgnustep-base.a`; restore required Unicode, XML, TLS; test Oolite Foundation API use.
4. Run on AmigaOS 3.2.3, AROS where applicable, and qualify 68040/68060. Package SDK, headers, examples, licences, logs and release artifact. Optional ARexx gateway is **not required** for first Base RC unless explicitly designated.

## Guest qualification update: 18 November 2026

Actual AmigaChrome guest execution now confirms the C Exec port, semaphore and transport tests all return PASS with exit code 0, plus a corrected native libffi floating-point call test and GNUstep Foundation strings/collections smoke. The full Objective-C `NSMessagePort` test remains **failed/hung**, even though native port creation, name-server creation, registration and lookup have been traced in guest. The singleton was corrected to use `NSAllocateObject()` rather than forbidden `[self new]`. See [RC1 Guest Results](RC1-GUEST-RESULTS.md) for unambiguous original-RC-versus-rebuilt test versions, raw evidence and remaining gate. `NSRunLoop` and thread safety are not qualified.
