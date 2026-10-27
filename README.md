# Aviation Navlog V2

Native Connect IQ / Monkey C flight activity for the **Garmin Forerunner 965 (454 × 454)**. This updates the existing navigation, timing, FIT and checkpoint architecture.

**Every bundled heading, altitude, distance, speed and frequency is invented demo data. The plans are not operationally validated.** No Google Sheets or network integration is included.

## Build and install

Requires Connect IQ SDK 9.3.0, FR965/API 5.2.0, Java and PowerShell. Scripts read `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg` and find the installed Adoptium JDK when needed.

```powershell
./scripts/build.ps1             # bin/navlog.prg: simulator
./scripts/build.ps1 -Tests      # bin/navlog-tests.prg
# Open Garmin's Connect IQ Simulator, then:
./scripts/run.ps1 -Tests
./scripts/build.ps1 -Release    # bin/navlog-device.prg: signed development build
```

To reinstall on your physical FR965, preserve any unresolved recording first. USB-copy **only `bin/navlog-device.prg`** to `GARMIN/APPS`, safely disconnect, then open Aviation Navlog. Keep the existing app ID and signing key; do not copy private keys, test applications or simulator probes to the watch. This session built the device artifact but did not reinstall it on hardware.

## Flight workflow

1. UP/DOWN chooses one of two preloaded demo plans: `YSCN-YGLB-YSCN` (original four-leg return route) or `YSCN-YGLB` (its first two legs). START opens its summary. START then opens a separate **START FLIGHT** confirmation; another deliberate START begins session timing and one native FIT recording. BACK cancels without recording.
2. On the ground, START means **TAKEOFF**. It records a pilot-confirmed takeoff and opens an airborne period.
3. Airborne with checks idle, START means **START CHECKS**. While running or overdue, START means **COMPLETE CHECK**. Early acknowledgements are supported. Inputs within the first two elapsed seconds of a newly started interval are ignored, protecting against repeated presses.
4. BACK opens Flight Timers. DOWN opens the first action; UP opens the last. The timers page is the wrap position between the ends of the actions list. BACK from actions returns to timers; BACK from timers returns to navigation. Navigation UP opens the last action and DOWN opens the first. LIGHT keeps normal Garmin behaviour; touch cannot trigger flight actions.
5. Flight Actions offers applicable waypoint advancement/undo, Land or Takeoff, alert settings, Finish & Save and Discard Flight. Destructive actions stay at the end and require confirmation. Landing closes the airborne period but keeps the session recording; START can take off again.
6. Manual waypoint advancement resets that leg's checks to idle. Changed radio references open **RADIO CHANGE**. START acknowledges; BACK dismisses while retaining the visible reminder. Identical frequencies do not prompt. The contextual Radio change action remains only while a reminder is pending. The app never changes an aircraft radio.
7. Finish & Save closes the local flight without fabricating a landing or waypoint arrival. Only a successful native FIT save **and** local checkpoint save produce completion and automatic exit after three seconds. Failed saving freezes the local end time and keeps recovery/pending protections. Discard removes the native recording only after `Session.discard()` succeeds, then replaces the current local log with an empty tombstone and exits. Existing archived flights remain.

See the [full user guide](docs/USER-GUIDE.md) for recording recovery, alert selection and physical acceptance steps.

## Timing and safeguards

CLEAROFF is entirely planned: `ceil(min(10, remainingPlannedNm) * 3600 / plannedGroundspeedKt)`. A 25 NM leg at 100 kt gives **06:00, 06:00, 03:00**, even when checks are acknowledged early. The next interval starts at the actual acknowledgement. Scheduled due UTC and actual acknowledgement UTC are both logged. These are planned intervals, not proof of distance flown. GPS never drives checks, heading or waypoint advancement.

Session, airborne and leg timers remain independent. A single FIT activity spans ground stops and multiple manually confirmed airborne periods. Existing flying sport classification and developer lap/session fields remain. An incomplete airborne period has no confirmed landing timestamp.

State is derived from canonical navigation, timer, recording and recovery data. No separately persisted competing flight state is introduced. Version-2 checkpoints remain readable; missing plan metadata migrates conservatively to the original demo route. Plan IDs/revisions are validated before recovery. Current/latest flight plus three rotating archives remain the storage limit.

Unknown native recording identity after restart remains a limitation. Local checkpoints restore automatically; the app does not invent native continuity or blindly create another activity. Dedicated recovery screens retain the log, explain gaps and offer only safe retry/manual/local-log/review choices. Pending native FIT blocks unsafe exit, new flight and blind discard. Resolve save failures in the same app instance where possible; preserve unresolved data for review.

## Verification

Baseline: **54/54 tests passed before source edits**. Final: **82/82 passed, zero failures/errors**, in the actual FR965 simulator. Debug, test and signed development device builds succeeded. Existing dictionary type warnings remain.

A real button-driven flight exercised selection, confirmations, takeoff, early checks/completion, timers/actions, alerts, landing, second takeoff, waypoint/radio prompts and native save/exit. The decoded FIT contains one flying session, four phase laps and two airborne periods. A separate V2 GPS playback run recorded changing coordinates and altitude. This V2 run produced an unexplained **−19.8 m altitude offset** from the synthetic input; earlier playback showed −122 m. Altitude accuracy remains unverified.

Real screenshots were captured and inspected. Overdue/error/review screens and compiled icon transparency are explicitly identified as fixtures. The icon's opaque SVG rectangle is removed and compiled transparency is visible on a coloured simulator background; physical launcher background behaviour is unverified. Hardware daylight readability, alerts/DND, reboot continuity, battery and Garmin Connect presentation remain to be tested.

[Acceptance report and screenshots](evidence/v2/REPORT.md) · [User guide](docs/USER-GUIDE.md) · [Architecture and SDK limits](docs/V2-ARCHITECTURE.md) · [Tests](docs/TESTING.md) · [Changelog](docs/V2-CHANGELOG.md)
