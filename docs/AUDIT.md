> Latest V3 UI acceptance: [92 passing tests, three builds, actual simulator screenshots, measured size/space comparison and physical-size preview](../evidence/v3/REPORT.md). Flight/recording/controller logic is retained; earlier version reports below are historical.

> V2 (27 October 2026): [82 passing tests, three builds, button-flight/FIT evidence, screenshots and exact remaining limits](../evidence/v2/REPORT.md). V2 changes and controls are described in [the user guide](USER-GUIDE.md); earlier sections below describe previous versions.

> Acceptance follow-up (27 October 2026): [verified screenshots, GPS/FIT evidence, 54 tests, three builds and remaining physical/lifecycle limitations](../evidence/2026-10-27/REPORT.md). The earlier findings below are historical; the follow-up supersedes their screenshot/GPS status.

# Remediation status — 2026-10-26

The historical audit below was the input to this remediation. Its five concrete findings have been addressed in code and focused regression tests: confirmed vs unconfirmed history, queued/central alerts, recoverable recording/save/cleanup failure states, manual navigation independent of FIT, and validated independent checkpoint fallback. The original report is retained for traceability.

The UI now uses a measured two-column heading/CLEAROFF layout, conditional demo banner, radio confirmation preserving time/countdown, acknowledgement-based check progress, and explicit recording status. Individual airborne FIT lap/developer fields are implemented and decoded from a native simulator test. All existing tests remain, and the expanded suite passes 53 tests. Debug, test and signed-device builds compile.

## Still open

- Actual baseline/after screenshots and visual acceptance are pending: this session did not expose desktop capture/input tools. Real Garmin rendering/bounds/overlap tests pass, but are not substituted for screenshot review.
- Simulated GPS coordinate injection/playback was not performed. The new saved FIT has synthetic altitude samples but no coordinates; GPS-track acceptance is still open.
- Physical FR965 deployment, outdoor GPS/altitude, battery, display lifecycle, sound/vibration/DND, full kill/relaunch/reboot recovery and Garmin Connect compatibility remain unverified.
- Explicit local-only finish preserves unsaved native FIT. Late saving works within the same app instance; safely identifying/rebinding that finished native session after restart is unsupported in the current integration. Its persistent pending flag blocks silent abandonment by New flight.
- SDK storage limits and three-flight rolling retention remain. A crash between physical alert delivery and durable checkpoint can cause a repeated alert; the watch does not provide an atomic alert-and-storage transaction.
- Dynamic persisted-dictionary/compiler warnings remain. No compiler errors or failing automated tests remain in the verified builds.

See [testing](TESTING.md), [screen capture checklist](../evidence/SCREENSHOTS.md) and [FIT evidence](../evidence/FIT-VERIFICATION.md). The task is closer to hardware acceptance, but visual/GPS/device/service acceptance is not declared complete.

---
# Original-request alignment audit — 2026-10-26

Audited commit `3b8da45` against the original attached request, all production source, tests, manifest, resources, scripts, build logs, recorded test output and project documentation. This was a source/evidence review: no application code changed, builds repeated, simulator sessions restarted, or hardware/Connect tests performed. Findings below are code-path findings unless explicitly described as prior test evidence.

## Conclusion

The native watch foundation and normal navigation/timing workflow substantially match the request. The project is not fully complete against the original acceptance criteria. Recording/recovery error paths need targeted fixes, and GPS/altitude, hardware deployment and Garmin Connect compatibility remain unverified. Four phase commits exist; their titles should not be interpreted as proof that every phase acceptance check passed.

## Concrete discrepancies, in priority order

1. **Finishing creates unconfirmed flight events.** `Navigation.finish()` calls `timers.land(utc)` even when the pilot never confirmed landing. It also fills the current leg's `finishUtc` using the same field that manual advancement uses for actual waypoint arrival. Ending a session early is therefore indistinguishable from reaching the destination in that record. Original sections 5, 6 and 10 require manual landing and actual waypoint times. Require explicit landing confirmation, or distinguish an incomplete/closed period from a confirmed landing; similarly distinguish session termination from waypoint arrival.

2. **Recovery and undo can consume alerts without delivering them.** `Persistence.restore()` and `Navigation.undo()` call `nav.tick()`/`tick()` and discard its return value. If a check or planned arrival becomes due during the gap, those calls mark it due/alerted. The next application tick sees no new transition and does not call `Alerts.fire()`. The overdue display survives, but the configured alert may be missed. Return/queue these events to the application and test that they alert exactly once.

3. **Save failures can separate recorded time from app time.** `Recording.save()` stops the FIT session before trying `session.save()`. If save fails, application timers continue but the FIT session is not restarted. Also, GPS cleanup occurs inside the same success/failure block: if `gps.stop()` throws after a successful save, the method reports failure after clearing the session reference, leaving navigation unfinished with no session to retry. Track FIT save completion independently from cleanup and define a consistent retry state. Failed starts can also leave GPS enabled.

4. **Recovery navigation is coupled to recording success.** `App.input()` only restores navigation when `recording.start()` succeeds. On failure it stays on the recovery page, and BACK/UP/DOWN are ignored by that branch. An unavailable recording service can therefore block access to the existing manual plan and timers. Restore navigation independently and expose an explicit recording failure/retry status.

5. **Checkpoint fallback is only partially defensive.** `Persistence.valid()` checks many key names but not all nested values, arrays, state strings or undo records. A malformed checkpoint can pass validation and fail during restore/use. Both slot reads share one try/catch, so an exception reading one slot can prevent consideration of the other. The existing corrupt-slot test covers a missing-key dictionary, not these failure modes. Archive errors may also be cleared by the unconditional subsequent checkpoint save. Strengthen only these boundaries and add focused failure tests.

## Requirement coverage

| Original area | Audit result |
|---|---|
| Native Monkey C watch app / FR965 | Aligned: watch-app manifest, FR965 target, modular source, debug/test/device PRGs, previous successful compiler logs and simulator interaction. Physical app-list launch not yet tested. |
| Offline operation | Aligned in code: hardcoded plan and local storage, no phone/network dependency. |
| Sample route and dummy values | Correct four legs; per-leg speed, heading, altitude, distance and frequencies; visible DUMMY DATA label. Name uses an ASCII hyphen instead of the requested typographic dash, a cosmetic difference only. |
| Navigation display | Normal screen matches requested order, prominent local seconds, MM:SS countdown and no next-check clock time. Previous visual checks cover normal screen; overdue/recovery and all long text variants lack equivalent visual evidence. |
| CLEAROFF normal operation | Aligned: planned-speed calculation, shortened last segment, manual start, acknowledgement-based restart, due/ack history, no GPS distance input, monotonic live timing. Recovery/undo alert exception above. |
| Separate states | Running/due/complete states exist. `acknowledged` is transient within a call, with durable acknowledgement timestamps; previous-leg completion is represented by history timestamps, and final-leg completion by `legCompleted`. This is a representation choice rather than a missing normal workflow. |
| Session / airborne / leg timers | Separate state and normal-operation tests; multiple airborne periods and ground stops supported. Finish-event semantics above require correction. |
| Manual waypoints and undo | Aligned normally; no automatic progression. One-step undo provided. Undo removes the accidental new-leg record and retains a correction timestamp, rather than preserving a complete immutable audit trail of every discarded visit. |
| Radio | Per-leg active/standby references, nonmodal confirmation reminder, no aircraft-radio control. Optional station labels are not populated/rendered, which is acceptable for optional data. |
| Alerts | Four configurable modes implemented, device API support checked previously. Hardware sound/vibration/DND behaviour untested; recovery/undo delivery gap above. |
| GPS only for recording | Separation is correct: only fix quality reaches UI; position/speed/heading never drive navigation. Actual coordinates/altitude have not been verified in output. |
| Activity classification / FIT | Prior decoded sample confirms flying sport 20, one session and airborne-total field. No inappropriate sport substitution. |
| Outbound/return periods in activity | Partial: continuous FIT session spans the flight, but individual takeoff/landing periods are only in app storage; FIT contains total airborne seconds, not explicit per-period boundaries. This is weaker than the requested single activity containing those periods. Investigate supported lap/developer-field encoding before deciding it is unavailable. |
| Waypoint / CLEAROFF FIT events | Stored locally, as permitted when FIT cannot represent arbitrary events. Existing documentation explains RECORD/LAP/SESSION contributor limits; no bespoke aviation event support is claimed. |
| Flight history | Requested fields largely present, subject to finish-event semantics. Versioned primitive dictionaries suit later export. No export UI was required at this phase. |
| Five-button controls | Documented mapping with standard LIGHT behaviour, quick BACK, contextual START, confirmation screens and debounce. Only part of the mapping has simulator interaction evidence; hardware remains pending. |
| Interruptions / efficiency | Monotonic timers, 15-second checkpoints, no GPS polling loop, explicit restart fallback implemented. Lifecycle/crash/reboot and battery testing incomplete. |
| Google Sheets future phase | Aligned: import proposal only, no integration implemented prematurely. |
| Deliverables / Git / publishing | Source, resources, manifest, three builds, README, controls, test report, constraints and progress log exist. Four commits present. No Store publication. Device build compilation is not proof of successful device installation. |

## Existing tests: what they actually establish

The recorded suite reports **14 passed, 0 failed, 0 errors**. It verifies the main timer calculations, acknowledgement anchor, shortened final segment, different speeds, manual advancement/undo, radio-controller state, independent timers, duplicate presses, monotonic rollover, and a real simulator Storage round trip.

Two original testing requirements are only partially covered:

- **Clock across hour boundaries:** the test checks duration formatting and countdown arithmetic. It does not exercise the displayed local clock crossing an hour/midnight or a device clock adjustment.
- **Application restart:** tests reconstruct navigation from a snapshot and use the object store. They do not test a complete app kill/relaunch with active FIT, reattachment, recording failure, or device reboot. They also do not observe alert delivery after recovery.

The saved FIT smoke test had **no GPS fix**, **zero distance**, and **no recorded takeoff**. It proves basic saving, flying classification and the presence of the custom field, not GPS track recording, altitude, multiple airborne periods in FIT, or Garmin Connect compatibility. Those distinctions are already mostly documented in TESTING.md.

## Documented choices to retain or revisit deliberately

- CLEAROFF must be manually started on **every** new leg. The prompt specifies manual start of the first countdown but does not fully define cross-leg behaviour. Current behaviour is documented, not necessarily a defect.
- Durations are rounded up to whole seconds; shortened segments consume planned distance on acknowledgement, not GPS distance.
- Recovery adds an estimated wall-clock gap to session, leg and any open airborne period. It cannot know whether an unlogged landing occurred while the app was closed.
- History retains three archived flights plus the current/latest checkpoint, overwriting older archives. This retention limit was not specified by the user and there is no export UI yet; it is a material storage compromise, not unlimited flight history.
- Heterogeneous dictionary compiler warnings remain. Compilation succeeds, but those warnings help explain why stronger persisted-state boundary checks matter.

## Minimal next work

Fix the five concrete code-path issues above with focused regression tests; decide how to represent individual airborne periods in FIT. Then verify a GPS-enabled simulator track and actual lifecycle recovery. Finish with physical FR965 deployment and Garmin Connect acceptance testing. Do not rebuild the project, redesign the working navigation screen, or add spreadsheet integration for this remediation.
