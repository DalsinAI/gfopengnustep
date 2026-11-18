# GFOpenGNUstep / Oolite integration contract — GFOS, GFOpenUp and Team 4 multicore

Checked against live repositories on 18 November 2026:
- `DalsinAI/gfopenmulticore` main `f2bcd5688f9e2bad3377149a32387f5da0d9c1c9`, Team 4 / AmiCradle `gfopenmulticore.library` 0.6 design, 0.5 published header (version 0, revisions for feature gates)
- `DalsinAI/gfopenup` main `2814a78d51a4c2dd4b5d4df870e9de5de5b7bc69`, package/Part manager, `parts.lock`
- `DalsinAI/gfopensdk` main `a2d9fbc17a9b6b09d406d01612071b4e9c52c46a`, common Open SDK
- `DalsinAI/gfopengnustep` core v0.1.1-rc1, seven native 68040 guest smokes PASS
- `DalsinAI/amigaoolite` pinned upstream `21978c37b2f11c8664adf3e2062efc1d0c875979`, Oolite engine integration lane

## Ownership / nonduplication rules

1. **GFOS/Exec owns the OS.** CPU0 owns Exec tasks, `NSRunLoop`, ports, DOS, Objective-C Foundation objects, event dispatch, GUI and Oolite's world/AI object graph. Use native `gfopenmulticore.library` for accelerator jobs, not a second GFOS thread pool, own core board protocol, private host worker protocol or ad hoc pthread offload.
2. **Team 4 owns multicore card and ABI.** Include canonical `<libraries/gfopenmulticore.h>` / `<proto/gfopenmulticore.h>` from `gfopenmulticore` or GFOpenSDK, not a copied ABI. `OMC_Run68k`/`OMC_Submit` + `OMC_Wait`/`OMC_Check` / `OMC_Abort`; for batches, gated `OMC_SubmitRange` / `OMC_RunRange` with `OMC_HAS_RANGE(base)`. Feature-test revision for `OMC_JobInit` / grants / signals with `OMC_HAS_JOBCALLS(base)`. No assumption that 0.6 implies a changed call table; check version/revision at runtime. 
3. **Core workers must be pure computation.** Avoid Exec, DOS, `NS*` Objective-C object methods, direct Chip RAM or graphics context calls from an offloaded worker; run maths / vertex transformation / procedural textures / geometry preprocessing on board cores, using properly granted Fast RAM memory and explicit CPU0 commit. `OMC_GrantSeg` for strict code; `OMC_AddGrant` / `OMC_AllocGrant` for data. Write grants are cache-line-aligned (16 bytes); board workers have a cap of 2 write grants and no Chip RAM. Observe timeouts and return fault/status; leave shared object mutation and GPU submission to CPU0.
4. **CPU0 fallback is mandatory.** An ordinary A1200/AmigaOS with no multicore card must still boot and run Oolite's compatible code path. Prefer `OMC_ANY`, and fall back to CPU0 on `OMCERR_NOCORE`, `OMCERR_BUSY`, unsupported revision or absent library, without changing game semantics. A job may use `OMCF_STRICT` and `OMCF_PAGES` only when the board advertises support; do not require them for normal CPU0 operation.
5. **Completion integrates into NSRunLoop without duplication.** Team 4 already exposes `OMC_SetSignal` for a job-completion signal on the caller task. The future GFOS `NSRunLoop` should multiplex Exec port signals, timer/cancel wakeups and this *same* completion bit, then deliver callbacks to CPU0. Foundation scheduling is not a substitute for `gfopenmulticore.library`, and GPU/OS calls are not permitted from worker code.
6. **GFOpenUp owns packaging.** Build/ship GFOpenGNUstep Foundation and AmigaOolite as properly versioned OpenUp Parts and GFOpenSDK additions, declare versioned library dependencies (GNUstep Base, GFOpenGPU, GFOpenAudio, GFOpenMulticore optional, scripting runtime as required), preserve upstream licences, install headers/link archives and avoid editing `parts.lock` until a real Part manifest/archive and install verification exist. No duplicate installation system in Oolite or GNUstep.
7. **Other OpenUp libraries are dependencies, not forks.** Rendering through GFOpenGPU/GFOpenGfx, fonts through GFOpenFont, input through GFOpenInput, sound through GFOpenAudio, TLS through GFOpenTLS, and filesystem via GFOS DOS/metadata abstraction as applicable. Where the real API is not implemented/verified yet, document it as blocked; no fabricated headers or silent SDL3/OpenGL fallbacks that bypass OpenUp.

## Oolite first offload targets (ordered)

- 1: Procedural galaxy/planet generation and numeric kernels (guest-proven scalar RNG and Objective-C parser baselines). Verify deterministic parity CPU0 vs core board with seeded inputs before changing ownership.
- 2: Icosphere mesh and planet terrain generation, batching per-index work via `OMC_RunRange` if revision >= 0.3; outputs go to Fast RAM grants, then CPU0 invokes GFOpenGPU. The existing OOPlanetData object is *cross-compiled*, not guest-rendered.
- 3: Image decoding, procedural textures and sound preprocessing where GFOpenUp codec/sound interfaces support offload; no OS/GPU calls inside cores.
- Avoid offloading script engines or Objective-C object graphs until lifecycle, heaps, stack and cross-core ABI are explicitly proven.

## Acceptance tests and coordination gates

- Compile-only ABI probe against *Team 4 canonical headers* and native GCC16. Cross-built is **not** multicore runtime proof.
- Guest test on CPU0/no card, then AC090 cores-card mode (`a1200native -C` with board model), and run the same workloads with 1, 2 and N cores. Capture `OMC_CoreCount`, job placement (`omj_Where`), status, output hash, latency and CPU0 responsiveness. Do not infer a card was present from the emulator's AC090 name.
- Race/timeout/cancel and grants: ownership, memory alignment, cache coherence, lost board and completion signals must be proven in native guest tests. Oolite gameplay tests come only after render/input/JS and game startup.
- Ask Team 4 to confirm the latest `gfopenmulticore.library` 0.6 binary/SDK packaging, completion signal semantics and benchmark traces before coupling to an application release. Record their exact tested card revisions; update this document if ABI differs.

**Current truth:** GFOpenGNUstep single-task smoke 7/7; native Oolite RNG and Foundation parser/NSNumber category guest tested; no offload job has been submitted by Oolite, and no full game binary has started. This document is the agreed design target for integration, not evidence that the Team 4 multicore card is working with Oolite yet.
