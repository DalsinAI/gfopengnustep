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
