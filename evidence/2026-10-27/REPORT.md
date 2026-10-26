# Acceptance verification — 27 October 2026

Reviewed `main` at `f3f38a5cd529d85ed93c73a18a0dc49cd5b3a923` against the requested remaining acceptance gaps. Environment: Windows, Connect IQ SDK 9.3.0, actual Forerunner 965 simulator/API 5.2.0. No redesign, UI changes, spreadsheet integration, physical watch deployment or Garmin Connect upload.

## Tests and builds

The original 53-test suite passed again. One targeted defect was found: explicit **Exit app** could abandon a finished local-only flight's pending native FIT. Commit `4971b80` blocks Exit when either the pending flag or native session handle remains. Its regression covers both cases.

After that change, the **complete suite passed 54 tests, zero failures/errors**, in Garmin's FR965 simulator. See [full output](tests-after-exit-guard.txt). Debug simulator, test and signed development device builds all reported **BUILD SUCCESSFUL**. Existing dynamic dictionary type warnings remain. The screen/GPS/lifecycle probes below are separate acceptance experiments, not additional passing unit tests.

[Build evidence](build-results.txt) records successful compiler output and binary hashes. Signing keys, binaries and raw FIT files remain outside Git. Production source did not change after these checks.

## Actual screenshots and visual review

Captured directly from the native simulator window using Win32 PrintWindow, after the user explicitly authorized a Garmin-only fallback because Computer Use's required runtime was unavailable. These are real simulator pixels, not generated images or mathematical-layout-test exports.

[Production navigation](01-production-navigation.png) was captured from the ordinary `navlog.prg`. The remaining screenshots use the isolated `VisualAcceptanceApp`: unchanged production `NavView`, real Garmin fonts and local clock, deterministic navigation/timer fixtures, physical simulated START to change scenes. Recovery uses the production snapshot validation/restoration path with a 30-second gap. These fixtures verify displayed states; they do not establish a complete button-driven flight or native recovery after reboot. Timer values are frozen deliberately while the local clock updates. [Scene log](visual-scenes.txt).

| Screen | Capture | Inspection |
|---|---|---|
| Navigation | [idle](02-navigation-fixture.png) | Clock largest; heading/CLEAROFF beneath; active and standby, route and progress aligned. |
| CLEAROFF running | [03:42](03-clearoff-running.png) | Green countdown balances heading; labels and values remain separate. |
| Overdue | [CHECK DUE +00:40](04-overdue.png) | Amber due/overrun visible; clock remains largest. |
| Radio confirmation | [radio](05-radio-confirmation.png) | Clock/countdown and both frequencies remain visible; amber verification label and confirmation hint fit. |
| Waypoint confirmation | [advance](06-waypoint-confirmation.png) | Action centred; confirm/cancel distinct; no clipping. |
| Timers | [timers](07-timers.png) | Three independent values and planned GS/altitude aligned; fixture explicitly says no native FIT. |
| Recovery | [recovery](08-recovery.png) | Estimated offline time and FIT/GPS gap warnings readable; retry/manual/timer actions fit. |
| Finish | [confirmation](09-finish-confirmation.png), [finished](10-finished.png) | Unconfirmed landing/unreached waypoint/no-FIT statements fit; finished footer shown. |
| Pending FIT | [pending](11-pending-fit.png) | Amber unsaved-FIT warning fits. |

All listed images were visually inspected. No text overlaps, truncation or circular-edge clipping appeared in these captured states. Primary navigation values have clear hierarchy. The radio verification label and bottom hints are relatively small and need outdoor wrist-size readability assessment. A finished screen retains the last CLEAROFF value above its finished footer. No cosmetic change is justified by clipping evidence. Historical pre-remediation screenshots and exhaustive hardware/button/readability checks are not claimed.

## GPS injection and recorded FIT

Verified native **Simulation > Activity Data > FIT/GPX Playable File**. Select/load the file after launching the app but before recording: starting a new app resets the source to Data Simulation, and recording locks source selection. Set GPS quality to Good, press playback Play, then watch START. [Actual configured playback panel](gps-playback-configured.png).

The separate GPS driver calls production recording/navigation code, records takeoff and landing, then finishes/saves after about 29 seconds. [Actual console output](gps-playback-result.txt): `GPS fix / recording`, accuracy enum 4, position `[-34.037100, 150.692900]`, `saved=true`, `FIT saved`.

Garmin's bundled FIT CSV decoder successfully decoded native `2026-10-27-08-18-55.fit`. It contains **nine record messages with valid changing coordinates** (native sample cadence), from latitude -34.04000001959503 / longitude 150.68999997340143 to -34.03719996102154 / 150.6928000319749. Both match the synthetic input path within semicircle rounding. [Extracted decoded records](gps-records.csv), [full decoder output](decoded-fit.csv).

Altitude/enhanced-altitude values are finite and change from **28 to 56 metres**. Input altitude at matching coordinates is 150 to 178 metres: a consistent **-122 m offset** occurred. Cause/calibration was not established. Thus location recording and changing altitude records are verified; accurate altitude reproduction is **not**. Earlier attempts without actual playback produced no coordinates and are not passes. This synthetic track proves neither physical GPS accuracy nor Connect map/altitude presentation. GPS quality was returned to Not Available after testing.

## Finished activity with a pending FIT after restart

The isolated lifecycle probe used a real native session, explicit local-only finish and persisted pending flag. [Before exit](pending-before-exit.txt) records `finished=true pending=true` and the original native start/timer identity. During exit/relaunch investigation the simulator itself crashed: [Windows Application Error](simulator-crash.txt), 07:48:36, `simulator.exe`, `c0000005`, offset `00570cf0`.

After simulator restart, [the local checkpoint recovered](pending-after-simulator-restart.txt) with `finished=true pending=true sessionNull=true`; production refused blind saving with `FIT recovery needs review`. An experimental native `createSession` returned a non-recording candidate with null start time/zero elapsed. Calling its `save()` returned true, but no matching original pending activity appeared in Activities. This is **not recovered FIT proof**, and the experimental code is excluded from production.

Safe automatic rebinding is still blocked by lack of verified original-session identity/continuity. The local checkpoint and pending warning remain; New flight and explicit Exit now refuse abandonment. Same-app late save is covered by existing tests, but completed native pending-save recovery across app restart/reboot has **not passed**. The native crash also prevents claiming an uninterrupted simulator-process app-restart experiment. Preserve any unresolved native data for review; do not reset storage or assume an API success boolean recovered the activity.

## Next physical Forerunner 965 test

1. Build `scripts/build.ps1 -Release`; USB-copy only `bin/navlog-device.prg` into `GARMIN/APPS`, safely disconnect and launch. Use disposable development/demo data.
2. Inspect every screen above outdoors at wrist size, especially the radio label/footer. Check all physical buttons, touch rejection, display wake, DND/alert modes and battery behaviour.
3. Obtain an outdoor GPS fix; record a short safe walking development track. DOWN must show recording/fix status. Verify decoded changing coordinates and compare recorded altitude with a known reference; investigate the simulator offset separately.
4. Start CLEAROFF manually: first interval 06:00 at 100 kt; acknowledge late, confirm a fresh full interval, then shortened final segment. Confirm waypoints advance only manually and radio references stay visible during confirmation.
5. Record two takeoff/landing pairs separated by a ground stop, finish/save, and inspect session duration, phase laps, UTC fields and airborne total. In a separate run finish while airborne: no fabricated landing or waypoint arrival.
6. First verify ordinary saved-flight close/reopen. Then use a separate disposable run for interruption/reboot and pending-save failure testing; preserve raw FIT/checkpoints and compare native identity/continuity. Do not intentionally create an unresolved pending activity in valuable data. Save in the same app instance when possible.
7. Sync only the development activity to Garmin Connect; verify category, map, altitude, laps and custom-field display. Physical recovery, alerts, battery, altitude accuracy and Connect presentation remain open until observed there.
