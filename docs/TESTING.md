# Verification — 2026-10-26

## Automated tests

Connect IQ 9.3.0 compiler, Garmin FR965 simulator API 5.2.0. The suite runs production Monkey C classes with controlled elapsed/UTC inputs. Final result: **14 passed, 0 failed, 0 errors**. Full output is in `bin/test-results.log` and a committed copy in `docs/test-results.txt`.

| Requirement | Evidence |
|---|---|
| 10 NM interval | `clearoffInterval`: 100 kt → 360 s, 60 s elapsed → 300 s remaining |
| Acknowledgement anchor | `acknowledgementAnchor`: due 360, acknowledgement 400 → next due 760 |
| Overdue | Countdown clamps to zero, due state persists, history stores original scheduled due and actual acknowledgement |
| Different groundspeeds | `manualWaypoints`: second leg 120 kt → 300 s |
| Short final segment | `shortenedFinal`: 25 NM → 360 + 360 + 180 s, then complete |
| Manual advancement | Planned arrival raises a flag without changing index; confirmed advancement and undo tested |
| Radio confirmation | `radioAndConfirmation`: physical-input controller dismisses radio reminder; advancement still needs confirmation |
| Airborne periods | `independentAirborne`: two periods 100 + 50 s, with a ground stop excluded |
| Session through stops | Same test: session and leg remain 250 s while airborne total is 150 s |
| Hour boundaries | `hourBoundary`: MM:SS formatting at 3600 and a countdown crossing hour boundary |
| Accidental presses | Pre-start advance ignored; repeated starts ignored; early acknowledgement ignored; confirmation cancellation and rapid duplicate press tested |
| Restart recovery | `restartRecovery`: UTC gap estimate makes the check overdue without advancing the waypoint |
| Real persistence | `persistentRoundTrip`: serialize/read/restore via simulator Storage; malformed newer slot falls back to surviving checkpoint |
| Monotonic rollover | Signed 32-bit wrap gives correct 96 ms difference |
| Final leg undo | Completed final leg timer freezes; undo resumes original elapsed baseline |
| Unacknowledged due event | Due history recorded exactly once before acknowledgement; no duplicate event on acknowledgement |

## Simulator interaction

- Compiled, loaded and displayed the native FR965 watch app, not a web mockup.
- Inspected circular screen and corrected oversized time/header clipping and clock/heading spacing.
- Used simulated physical START, UP and DOWN buttons; opened actions and confirmed Finish and save.
- Main navigation remains available via BACK. UI-controller tests verify cancelling a pending advancement does not change the leg.
- Initial screen approximately 25 KB application memory in simulator (not a memory stress test).
- No injected GPS location or valid GPS fix was used in the recorded sample. Track coordinates and recorded altitude therefore remain unverified.

## FIT save and decode

Saved simulator activity `2026-10-26-09-33-20.fit` (synthetic simulator data). Decoded with Garmin's bundled `fit-graph.jar`, class `com.garmin.fit.csv.CSVTool`:

- One activity and one session.
- Sport `20` (flying), sub-sport `0` (generic).
- Activity name `Aviation Navlog`.
- Session elapsed and timer time `139.422` seconds.
- Custom SESSION developer field `Airborne seconds = 0` (no takeoff was recorded in this UI smoke test).
- No GPS position fix; zero recorded distance. This verifies the FIT save pipeline and custom field, **not** GPS track accuracy or Garmin Connect presentation.

The raw `.fit` remains in the simulator's `%LOCALAPPDATA%\Temp\com.garmin.connectiq\GARMIN\Activities` directory. Decoded CSV is in `bin/simulator-flight.csv`; it is not tracked by Git. Simulator heart rate values are synthetic and not evidence of real sensor performance.

## Build notes

Debug, test and release/device builds compile against the installed FR965 package. The compiler emits gradual-type warnings around heterogeneous persisted dictionaries and dynamic view/controller members; no compiler errors remain. Tests use the same dictionaries after serialization. No third-party package installation was necessary.

## Hardware / service acceptance still required

1. Sideload on a physical FR965, launch from its app list, verify local time, all five buttons, touch behaviour and sleep/display lifecycle.
2. Obtain a GPS fix outdoors and record a short ground walk solely as a development test; save and inspect position and altitude in the resulting flying FIT.
3. Test multiple manual airborne periods and stops; compare local history with known durations and FIT summary.
4. Test each alert mode, DND/silent settings and in-cockpit visibility/audibility.
5. Interrupt with a system screen, terminate/reopen the app, then reboot the watch in a separate test. Verify checkpoint recovery and determine whether FIT is continuous or split; do not assume reboot continuity.
6. Exercise a long session for battery, storage and memory bounds, and test save failure behaviour with a controlled full-storage scenario.
7. Sync a test activity to Garmin Connect and inspect category, map, altitude and duration. Sideloaded custom-field visibility is not guaranteed. Do not publish the app merely to test visibility.

No physical-device deployment, flight test, Garmin Connect login/upload, or Store publication was performed.
