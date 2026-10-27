> Latest V3 UI acceptance: [92 passing tests, three builds, actual simulator screenshots, measured size/space comparison and physical-size preview](../evidence/v3/REPORT.md). Flight/recording/controller logic is retained; earlier version reports below are historical.

> V2 (27 October 2026): [82 passing tests, three builds, button-flight/FIT evidence, screenshots and exact remaining limits](../evidence/v2/REPORT.md). V2 changes and controls are described in [the user guide](USER-GUIDE.md); earlier sections below describe previous versions.

> Acceptance follow-up (27 October 2026): [verified screenshots, GPS/FIT evidence, 54 tests, three builds and remaining physical/lifecycle limitations](../evidence/2026-10-27/REPORT.md). The earlier findings below are historical; the follow-up supersedes their screenshot/GPS status.

# Remediation verification — 2026-10-26

## Baseline and reproduction

Starting commit `a6ea793` on main. Existing `.gitignore` edits preserved. Required documents, all source, scripts and tests inspected. Debug/test builds compiled, and **14 baseline tests passed** in Garmin's actual FR965 simulator. Two added regressions reproduced false landing history and missing recovery-event delivery support before changes. Baseline evidence is under `evidence/`.

## Final automated result

**53 tests passed, zero failures/errors**, using Connect IQ 9.3.0 / FR965 API 5.2.0. Full output: `docs/test-results.txt` and `evidence/final-tests.txt`. No existing test was removed. The radio test was updated to exercise the new explicit reference confirmation page.

Coverage includes:

- Original CLEAROFF interval/anchor/overdue/short-final/different-speed tests, independent timers, manual waypoints, final-leg undo, duplicate buttons and monotonic rollover.
- Finishing while airborne records an unconfirmed closure; finishing before a waypoint leaves arrival null; normal landing followed by save preserves the actual landing timestamp.
- Recovery and undo queue due events; repeated ticks/acknowledgements do not duplicate them; central delivery drains them once.
- Injected GPS start, FIT create/start/stop/save/restart and GPS cleanup failures. Successful save remains successful after cleanup failure; failed save resumes recording or exposes a stopped/retry state.
- Initial/recovered manual navigation and timer access without FIT; local-only finish; recording retry and post-save GPS cleanup retry.
- Explicit local-only completion retains an unsaved FIT, supports same-session late saving, preserves the original local end time, and persists a warning that blocks silent abandonment after restart.
- Actual object-store round trip, malformed newer-slot fallback, unreadable independent slot fallback, nested corruption, invalid undo, conservative legacy migration, inconsistent legacy totals and sticky deduplicated errors.
- Clock formatter inputs across 12:59:59 → 13:00:00 and 23:59:59 → 00:00:00. These exercise the formatter used by live `System.getClockTime`; they do not simulate hardware timezone/DST changes.
- Persisted alert mode round trip and actual simulator Attention calls in vibration, tone, combined and disabled modes. No physical-device audibility or vibration claim follows.
- Real Garmin buffered-bitmap rendering of idle, running, overdue, radio confirmation, waypoint confirmation, timers, recovery, recording warning, finish, complete and long-waypoint scenes. Every measured text rectangle fits an inset 217-pixel safe circle; text rectangles do not overlap; clock is largest. Demo warning is conditional. Touch taps do not start/acknowledge.
- Native simulator FIT integration with four real elapsed lap boundaries and two synthetic airborne periods. Production Recording/FitContributor code is used; failures are injected only in isolated test classes elsewhere.

The native integration test waits about 4.4 seconds in its isolated test method to give Garmin lap records distinct timestamps. It is not part of the production app or physical-device acceptance workflow.

## Builds

Debug simulator application, unit-test application and signed development device application compile successfully. Logs: `bin/final-build.log`, `bin/final-test-build.log`, `bin/final-device-build.log`. Dynamic dictionary/controller type warnings remain; no compiler errors. Signing keys and binaries are excluded from Git.

## FIT output

Garmin's bundled decoder confirms one flying session (sport 20), four lap messages, two airborne laps, period seconds and UTC fields, plus the airborne-total session field. Four synthetic altitude samples were present. **No coordinate samples were present.** See `evidence/FIT-VERIFICATION.md`. This does not verify a GPS flight track, altitude accuracy, Garmin Connect import/display, or continuity after reboot.

## Visual / lifecycle checks still pending

Desktop screenshot/input tools were unavailable. Plugin discovery found no usable replacement. No screenshots were fabricated, and mathematical bounds tests are not described as screenshot review. Required capture names and scene coverage are in `evidence/SCREENSHOTS.md`. The original app was launched before changes; the final app is also launched after building, but screen appearance has not been inspected in this session.

A finished local-only session with pending FIT cannot yet be safely rebound after app restart. Its pending flag remains visible and prevents silent New flight abandonment; resolve it within the same app session or preserve data for development review. Full native app kill/relaunch with an unsaved FIT session, real device reboot, and GPS injection/playback remain pending. State reconstruction and queued-event recovery tests do not replace those lifecycle checks.

## Physical-device acceptance procedure

1. Build `./scripts/build.ps1 -Release`; USB-copy `bin/navlog-device.prg` into FR965 `GARMIN/APPS`, then disconnect and launch Aviation Navlog.
2. Inspect the demo banner, local seconds, heading/countdown grouping, radio values, longest waypoint, warnings and circular edges. Exercise every physical button and verify touches cannot trigger critical actions.
3. Begin an outdoor development session; inspect DOWN's GPS/FIT status. Obtain a valid fix and record a short development track, then decode its FIT for changing coordinates and altitude. Treat it as a development flying activity, not an operational flight plan.
4. Manually start checks. At 100 kt the first leg uses 06:00. Acknowledge late and verify the next full interval starts at acknowledgement. Complete the shortened final segment without automatic waypoint advancement.
5. Use takeoff/landing twice with a ground stop; session continues throughout. Compare period history, total airborne time and lap fields. Test an early finish while airborne: landing and destination arrival must remain unconfirmed/unreached.
6. Check all four alert modes, silent/DND settings, outdoor readability, display timeout/wake and battery use. Do not infer these from simulator sound.
7. In a separate development run, interrupt/close/reopen and then reboot. Verify local recovery, pending alerts and recording status; inspect whether raw FIT is continuous or split. Do not assume GPS data can be reconstructed across a gap.
8. Sync a development activity to Garmin Connect and inspect category, map, altitude, duration, laps and custom fields. Sideloaded custom fields may not be shown. Do not publish to the Store solely to test presentation.
9. Stress-test history limits, storage failures and native save retries on controlled development data before operational use.

No physical watch, Garmin Connect account/upload, Store publication, actual flight, or GPS track acceptance was performed here.
