# Development progress

## 2026-10-26 — Foundation
- Empty workspace; installed SDK 9.3.0 and fr965 device package located in AppData/Roaming/Garmin/ConnectIQ.
- Java 25 found under Eclipse Adoptium (not initially on PATH).
- Created watch-app manifest, resources, navigation view, physical button delegate and repeatable build script.
- SDK API declarations and RecordSample inspected; no phone/network dependency.

## Phase 2 — Navigation
- Implemented four dummy legs, independent session/airborne/leg timers, acknowledgement-anchored CLEAROFF, short final segments, manual arrival and one-step undo.
- Seven Monkey C tests passed in the fr965 simulator. Tests caught and resolved string reference comparisons.
- Simulator screen inspection found oversized clock and edge clipping; layout refinement is next.


## Phase 3 — Recording
- Implemented Position continuous recording and ActivityRecording SPORT_FLYING, with a custom airborne-seconds session field.
- Saved a simulator activity and decoded it using Garmin's bundled FIT CSV tool: one session, sport 20, 139.422 seconds, custom field present.
- No simulator GPS fix in that sample; coordinate/altitude and Garmin Connect checks remain outstanding.

## Phase 4 — Polish and recovery
- Added four alert modes, protected termination, explicit recovery, alternating storage checkpoints, and three-flight rolling archive.
- Refined round-screen layout from actual simulator screenshots.
- Fourteen tests now pass, including real Storage round trip, corrupt-slot fallback, monotonic rollover and duplicate-button rejection.
- Signed device build prepared; physical-device acceptance remains outstanding.

## Phase 5 — Proposal only
- Documented future spreadsheet JSON import and history export. No Google Sheets/network integration implemented.


## Remediation — reliability
- Reproduced both false landing and missing recovery events before fixing them; baseline 14 tests passed.
- Separate waypointReachedUtc and legClosedUtc; finishing an active airborne period now marks it unconfirmed without inventing a landing.
- Navigation transitions queue explicit events; central application delivery retains recovery/undo notifications and drains them once.
- Manual navigation/timers remain accessible after GPS/FIT failures. Added recording retry and explicit local-only finish when no FIT session exists.
- FIT save success is independent of GPS cleanup; unsuccessful saves attempt to resume recording, or show an explicit stopped/retry state.
- Alternating checkpoints retained; nested validation, independent reads, sticky errors and conservative version-1 migration added.
- Entire expanded suite: 35 passed, zero failures/errors in FR965 simulator.
- Capture and GPS injection cannot yet be verified because the required desktop-control tools are unavailable in this session.

## Remediation — interface and acceptance
- Implemented the requested clock-first display with measured circular bounds, balanced heading/CLEAROFF groups, green/amber timing states, radio references, route, leg and reliable check progress.
- Demo warning follows plan metadata. Added a radio confirmation page preserving clock/countdown, refined timers/recovery/confirmation screens, and consumed touch taps to protect physical-button actions.
- Added raw FIT lap fields for manual airborne periods, including explicitly incomplete phase 2. Native output decoded: one flying session, four laps, two synthetic airborne periods, airborne total 2 seconds. Synthetic altitude present; no coordinates.
- Explicit local-only finish retains pending native FIT, supports same-instance save retry and preserves the original local end. A pending flag survives restart and blocks silent abandonment; finished pending-native-session rebinding remains unsupported.
- Expanded suite: 53 passed. Real Garmin renderer tests cover all requested states plus complete/long-waypoint/local-only variants, validate circle bounds and text overlap, and check clock prominence.
- Debug, test and signed-device development builds succeed. Existing .gitignore edits remain separate.
- Actual PNG screenshot review, GPS injection, full native app restart/reboot, physical FR965 and Garmin Connect acceptance are still pending. Evidence documents these gaps rather than claiming them complete.

## Acceptance follow-up — 27 October 2026
- Reverified latest remote main f3f38a5: original 53 tests passed again; three builds succeeded.
- Found and fixed explicit Exit abandoning a pending FIT after local finish; regression added. Complete suite now 54 passed, zero failures/errors; all three versions rebuilt successfully (4971b80).
- Captured and visually inspected actual production navigation and isolated production-renderer scenes in native FR965 simulator. No clipping/overlap observed; no cosmetic source changes made.
- Native FIT playback verified changing coordinates in nine recorded samples and altitude 28–56 m; altitude is 122 m below matching synthetic input, so accuracy remains unresolved.
- Pending-native-save probe persisted finished/pending state, but simulator crashed during restart investigation. After restart, candidate native save returned true without a matching recovered FIT. Conservative production guard retained; physical continuity/rebinding remains blocked.
- Report and physical FR965 instructions: evidence/2026-10-27/REPORT.md. No physical deployment, account upload or Google Sheets integration.

## V2 — physical-use workflow improvements, 27 October 2026
- Inspected current main a2c71f8 and prior evidence; unchanged 54-test baseline passed before edits.
- Added two bundled demo plans, persisted IDs/revisions, selection, summary and separate Start Flight confirmation.
- Added derived flight states and contextual START: Takeoff, Start checks, Complete check. BACK opens timers; UP/DOWN opens last/first contextual action. Actions wrap through timers.
- Enlarged measured navigation values, retained high-contrast state/action/radio/route information, and removed the icon's embedded opaque background.
- Enabled early acknowledgement with unchanged fixed planned intervals, original due/actual history and a two-second new-interval guard. Expanded undo coverage.
- Added change-only radio prompts/pending retention and cancellable four-mode alert selection. Maintenance options moved to contextual recovery screens.
- Added local-end freeze on failed finish, verified native/local completion before exit, safe native discard/tombstones and continued unknown-session safeguards.
- Final suite: 82 passed, zero failures/errors; debug/test/signed-device builds successful. Existing dictionary type warnings remain.
- Actual button flight saved one flying FIT with two airborne periods; separate V2 GPS playback saved nine changing coordinate samples and changing altitude with unresolved -19.8 m offset (earlier -122 m).
- Real screenshots inspected; fixtures and real button evidence distinguished. Compiled icon alpha verified; physical launcher/readability/reboot/Connect acceptance remains open. See evidence/v2/REPORT.md and docs/USER-GUIDE.md.

## V3 — physical-watch UI refinement, 27 October 2026
- Used the precise written layout because the user photograph/drawing was not available in this task context.
- Baseline: unchanged V2 suite 82 passed. Production changes confined to source/Ui.mc; all controller/flight/GPS/recording/persistence logic retained.
- Removed navigation route/leg/progress/state/demo/button footers. CLEAROFF field now holds TAKEOFF, two-line START CLEAROFF, countdown, amber DUE or COMPLETE, matching the contextual START action.
- Allocated circular-safe regions and measured independently: clock 104, heading/countdown 86, radio 54 px (V2 measured 84/64/62/34). Labels left-align and frequency values right-align. Selected action uses 84 px instead of 36.
- Reworked secondary screens to one large selected command and concise labels while retaining explicit confirmation, cancel and recovery consequences. Corrected UNDO's displayed target-leg number without changing undo logic.
- All required real simulator captures inspected. Added cropped/downscaled genuine 35.4 mm/134 px review artifacts; no physical readability claim.
- Real buttons exercised selection/start, takeoff/checks/early ack, menus/confirmation cancellations, native save and normal exit. Native FIT decoded; no new GPS-track accuracy claim.
- Final 92 tests pass; debug/test/signed-device builds succeed. Restored .gitignore with authorised local edits discarded; 29 positive/negative ignore checks pass. See evidence/v3/REPORT.md.
