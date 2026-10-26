# Aviation Navlog

Native Monkey C / Connect IQ watch app for **Garmin Forerunner 965, 454 × 454**. Manual VFR references, planned-speed CLEAROFF reminders, three independent timers, GPS-enabled flying activity recording, and local history. No phone or network dependency.

**The bundled Camden – Goulburn Return plan is demonstration data. Every heading, altitude, distance, groundspeed and frequency is invented.** The conditional `DEMO PLAN` banner follows `FlightPlan.DEMO` / persisted plan metadata; future validated plans need not display it.

## Build and install

Verified environment: Connect IQ SDK 9.3.0, FR965 package/API 5.2.0, Eclipse Adoptium Java 25, PowerShell 7 on Windows. Minimum app API is 4.2.1 for measured vector fonts. Scripts read `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg`; Java must be on PATH or under `C:\Program Files\Eclipse Adoptium`.

From `C:\Development\garmin-aviation-app`:

```powershell
./scripts/build.ps1
# Open Garmin's installed Connect IQ Simulator before running:
./scripts/run.ps1

# Stop the running app through simulator File > Kill App before tests:
./scripts/build.ps1 -Tests
./scripts/run.ps1 -Tests

./scripts/build.ps1 -Release
```

Outputs are `bin/navlog.prg`, `bin/navlog-tests.prg`, and signed `bin/navlog-device.prg`. The local signing key is `.private/developer_key.der`; it and generated binaries/FIT files are excluded from Git. The test suite runs production Monkey C in the actual simulator, including a native synthetic FIT recording test.

For physical-device testing:

1. Build with `-Release`, connect the FR965 by USB, and copy **only** `bin/navlog-device.prg` to `GARMIN/APPS`.
2. Safely disconnect and select Aviation Navlog from the watch's applications/activity list.
3. Check the demo banner, local clock, display boundaries, and buttons before starting.
4. START begins the session. DOWN shows GPS/FIT status. Wait for a real outdoor GPS fix before testing a recorded track.
5. Use the actions below to exercise manual checks, takeoff/landing, waypoints, and ground stops.
6. Finish and save. Confirm status and inspect the generated flying activity after syncing a development test to Garmin Connect. Map, altitude and custom-field presentation require verification; they are not assumed to work merely because the FIT saves.

This follows Garmin's [sideloading instructions](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/). Physical deployment has not been performed in this session. Do not publish to the Store for testing.

## Display and controls

Local `HH:MM:SS` is the largest element. Balanced HEADING and CLEAROFF groups sit below it, followed by active/standby frequencies, route, leg number, and acknowledgement-based check progress. White primary values, grey labels, green countdowns, amber due/warning states, black background. No scheduled CLEAROFF clock time is displayed. Text uses Garmin-measured font dimensions and an inset circular safe area.

| Button | Navigation | Other screens |
|---|---|---|
| LIGHT | Standard system behaviour | Standard system behaviour |
| UP / hold UP | Flight actions | Previous action |
| DOWN | Flight timers | Next action in actions menu |
| START | Begin session; start idle checks; acknowledge due checks | Select, then confirm actions |
| BACK | Stay on navigation | Return to navigation / cancel |

Touch taps are consumed without starting or acknowledging actions. A 450 ms guard rejects rapid duplicates. Waypoint, undo, takeoff/landing and finish actions have confirmation pages. BACK and DOWN remain available after recording failures and from recovery. The radio confirmation page preserves the clock and countdown.

- START begins session/leg timing and attempts recording. Failure shows a warning and manual navigation continues.
- UP → Confirm radio → START opens the reference confirmation; START confirms, BACK leaves the reminder pending. This only acknowledges the watch display; it does not change an aircraft radio.
- START from navigation starts CLEAROFF manually on each leg. While running, additional START presses do not reset it. CHECK DUE waits for manual acknowledgement.
- UP → Takeoff / landing → START records the explicit pilot-confirmed event. Ground stops do not stop session timing or FIT recording.
- Advance waypoint records `waypointReachedUtc`, closes the leg, activates the next leg, resets checks to idle, and prompts for radio confirmation. Planned arrival alerts never advance automatically.
- Undo advancement restores one previous leg and its original timing baseline. Discarded visits and corrected checks remain identifiable in history.
- Finish and save distinguishes session closure from arrival. An active airborne period closes as **unconfirmed**, with no invented landing. An unreached waypoint remains unreached. The confirmation page explains this.
- Retry recording attempts GPS/FIT recovery where supported. After finishing, it retries GPS cleanup. Retry recovery re-reads preserved checkpoints.
- If no FIT session could be created, Finish saves local history and explicitly reports no FIT. If a session object exists but saving keeps failing, choose **Finish local only** and confirm: local timers/history close, the native FIT remains pending, and no landing or arrival is invented. Use Finish and save again to retry that retained FIT before exiting. New flight cannot silently abandon it.

## Timing and history

The sample route remains YSCN → YSHL → YGLB → Mittagong → YSCN. Each leg has its own planned heading, groundspeed, altitude and radio references.

CLEAROFF uses `ceil(min(10, remainingPlannedNm) * 3600 / plannedKnots)`. It consumes planned segment distance only on acknowledgement and starts the next interval from that acknowledgement. A 25 NM leg at 100 kt gives 360, 360 and 180 seconds. Late acknowledgements shift subsequent reminders; completing planned checks does not advance the leg. Progress shows the current check number, with completed count when all segments are acknowledged. GPS never proves a segment was travelled.

Live elapsed time uses monotonic milliseconds with rollover correction and fractional remainder. UTC is stored separately for history. Session, airborne and leg timers remain independent. The timer page also shows planned groundspeed/altitude and explicit GPS/FIT status.

History schema 2 distinguishes `waypointReachedUtc`, `legClosedUtc`, confirmed `landingUtc`, unconfirmed period `closedUtc`, durations, due/ack timestamps and recording boundaries. Version-1 data is migrated conservatively as `legacyUnknown`; old automatic closures are not relabelled as confirmed arrivals/landings. See [import/export proposal](docs/IMPORT.md).

## Recording and recovery

GPS is enabled by default when recording is attempted. Only fix quality reaches the UI. No coordinates, speed, heading or altitude drive navigation, CLEAROFF, radio, takeoff or landing decisions.

FIT uses `Activity.SPORT_FLYING` (20). One normal continuous activity includes ground stops and multiple airborne periods. Supported lap developer fields encode phase (`0` ground, `1` confirmed airborne period, `2` incomplete), period seconds, takeoff UTC and confirmed landing UTC; the session field stores total airborne seconds. The raw simulator FIT contains these fields, but Garmin Connect presentation is unverified. Failed/too-fast lap writes warn and leave local history authoritative.

Save failure attempts to resume native recording. If that fails, status explicitly says recording is stopped and offers retry; manual timers continue with a recorded boundary/gap warning. A successful FIT save stays successful even if GPS cleanup fails. App closure and recovery never claim uninterrupted recording through a crash/reboot.

Alternating checkpoints are written every 15 seconds and after actions/delivered events. Each slot is independently read and validated. A corrupt slot cannot hide a valid older one; errors remain visible. If neither slot is valid, raw data is retained and checkpoint writes are blocked until recovery is resolved. Recovered timers add a nonnegative wall-clock gap estimate, including any open airborne period. They are available immediately; START retries recording, BACK continues manual navigation. Clock changes while closed can affect the gap estimate. Due events are queued through recovery and undo, delivered centrally and removed once handled. A crash between physical alert delivery and its durable checkpoint can cause a repeated alert on restart; atomic hardware alert delivery is unavailable.

If the app exits after an explicit local-only finish while FIT is still pending, the pending flag survives. The current SDK integration cannot safely identify/rebind that finished native recording after restart; New flight remains blocked for review rather than overwriting it. Resolve pending FIT saves in the same app session where possible. This remains a known recovery limitation.

The current/latest session and three rotating archived flights are retained. Starting a new flight overwrites the oldest archive. Each storage value remains subject to the SDK's 32 KB limit; long histories can exceed it. Errors are shown, not silently treated as successful persistence. Export UI and Google Sheets integration remain deferred.

## Acceptance status

The expanded simulator suite passes; all three builds compile. Geometry/overlap tests render the requested screens with Garmin's actual fonts, and native FIT saving/lap fields are decoded. **Actual before/after screenshots and injected GPS coordinates were not obtained because desktop control/capture tools were unavailable. UI visual acceptance is still pending.** The saved FIT contains synthetic altitude values, which do not establish physical altitude accuracy.

See [testing](docs/TESTING.md), [capture checklist](evidence/SCREENSHOTS.md), [FIT evidence](evidence/FIT-VERIFICATION.md), [audit status](docs/AUDIT.md), [API notes](docs/API-NOTES.md) and [progress](PROGRESS.md). Physical FR965 GPS, battery, display lifecycle, sound/vibration/DND, reboot recovery and Garmin Connect acceptance still require testing.
