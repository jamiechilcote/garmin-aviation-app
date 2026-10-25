# Aviation Navlog

Native Monkey C / Connect IQ watch application for **Garmin Forerunner 965 (454 × 454)**. It provides manual VFR planning references, acknowledgement-based CLEAROFF reminders, independent flight timers, and a GPS-enabled flying FIT activity. It runs offline.

**Development build. All sample headings, altitudes, distances, groundspeeds and frequencies are invented dummy data. Do not use them for flight.** The sample route is Camden (YSCN) → Shellharbour (YSHL) → Goulburn (YGLB) → Mittagong → Camden. There is no validated flight plan or GPS navigation.

## Build and run

Verified environment: Connect IQ SDK 9.3.0, installed `fr965` device package (simulated API 5.2.0), Eclipse Adoptium Java 25, PowerShell 7, Windows. Scripts read the active SDK path from `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg`. Java must be on PATH or installed under `C:\Program Files\Eclipse Adoptium`.

From this repository:

```powershell
./scripts/build.ps1
# Open the installed Garmin Connect IQ Simulator, then:
./scripts/run.ps1

# Stop the running app with the simulator File > Kill App command before tests.
./scripts/build.ps1 -Tests
./scripts/run.ps1 -Tests

# Signed development PRG for the physical device:
./scripts/build.ps1 -Release
```

Outputs: `bin/navlog.prg`, `bin/navlog-tests.prg`, `bin/navlog-device.prg`. The build script generates a local RSA signing key in `.private/developer_key.der` when absent. Keep it private; it is excluded from Git. Generated files and compiler/test logs are under `bin/` and excluded from Git.

Connect your FR965 by USB and copy **only** `bin/navlog-device.prg` into the watch's `GARMIN/APPS` folder, then safely disconnect. Look for Aviation Navlog in the applications/activity list. This follows Garmin's [sideloading instructions](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/). Physical installation and Garmin Connect sync still require verification on a real device. Nothing has been published to the Store.

## Controls

| Button | Navigation screen | Actions / confirmation |
|---|---|---|
| LIGHT, upper left | Standard system light/control behaviour | Standard system behaviour |
| UP, middle left | Open flight actions | Previous action |
| DOWN, lower left | Open session/airborne/leg timer page | Next action |
| START/STOP, upper right | Begin session; thereafter start a CLEAROFF sequence or acknowledge a due check | Select action; press again on confirmation to execute |
| BACK/LAP, lower right | Stay on navigation | Cancel and return immediately to navigation |

Holding UP also opens actions. Touch has no dedicated flight controls. A 450 ms input guard rejects rapid duplicate presses. Advancing, undoing, takeoff/landing and finishing require a separate confirmation screen. START never stops the activity directly. New flight and Exit are available only after finishing (Exit also works before starting).

1. START begins the session, navigation leg and GPS/FIT recording. It does **not** start airborne time or CLEAROFF.
2. Use UP → Confirm radio to dismiss the frequency reminder after checking the aircraft radio. This changes only the reminder on the watch.
3. START on navigation manually starts CLEAROFF. Press START when CHECK DUE appears to acknowledge it. Acknowledgement while a countdown is running is ignored.
4. Use UP → Takeoff / landing, then START to confirm each takeoff or landing. The session timer and FIT recording continue during ground stops.
5. Use Advance waypoint to record actual arrival and activate the next leg. A planned arrival alert never advances automatically. Every new leg requires a fresh manual CLEAROFF start and displays a radio reminder.
6. Undo advancement restores the previous leg and its running timing baseline. One advancement can be undone, including completion of the final leg. Intervening check records are marked corrected; the correction timestamp is retained.
7. Finish and save ends the session only after the FIT save API reports success. Read recording/GPS status on DOWN's timer page. A save error leaves the session open for retry.

## Timing decisions

CLEAROFF intervals use `ceil(min(10, remainingPlannedNm) * 3600 / plannedKnots)`. Thus 100 kt gives 06:00 per 10 NM, and the last 5 NM of a 25 NM leg gives 03:00. Planned distance is consumed **only when a check is acknowledged**; no actual distance or GPS speed is used. Late acknowledgement shifts the entire next interval. At the end of the planned segments, checks stop while manual leg navigation continues.

The main screen shows local device time including seconds, heading, countdown or overdue duration, active/standby references and waypoint. It never shows a future CLEAROFF clock time. Live durations accumulate monotonic milliseconds with rollover handling and fractional remainder; screen refreshes do not determine timing. Wall-clock timestamps are stored independently for history.

Alerts can be vibration, audible, both, or disabled via Change alert mode. Each due transition alerts once and remains visibly overdue until acknowledged. The FR965 device API lists `Attention.vibrate` and `Attention.playTone`; actual audibility, vibration strength, sound settings and DND interaction need hardware testing.

## Recording, storage and recovery

`GpsRecorder` enables continuous location events only to support track recording and report fix quality. It never passes coordinates, speed or heading to `Navigation`. `Recording` uses `ActivityRecording` with `Activity.SPORT_FLYING` (20), and stores total airborne seconds in a session FIT developer field. Garmin records the standard position/altitude data when available; no altitude is fabricated by the app. Normal operation saves one activity including ground stops and all airborne periods.

Full event history is stored separately as versioned dictionaries: flight name, UTC start/finish, airborne periods, leg planned/actual arrival times and durations, planned heading/groundspeed, check due/acknowledgement times, corrections and interruptions. This is suitable for later serialization/export. No phone sync or export UI is implemented yet. See [storage and import proposal](docs/IMPORT.md).

Two alternating checkpoints are written every 15 seconds and after controls/events. On launch, an unfinished checkpoint displays a recovery screen. START explicitly resumes, adding the nonnegative wall-clock gap to timers and any open airborne period. That gap is an estimate: manual clock changes while closed can affect it. The app logs the interruption. The SDK can return an existing unsaved activity session, but survival across crashes/reboots and uninterrupted FIT continuity are **not guaranteed**; GPS gaps cannot be reconstructed. On normal app stop, a checkpoint is written and recording is stopped without deliberately discarding it.

The current/latest session remains in checkpoints. Starting a new flight archives the previous session into a three-flight rolling history. Older archived history is overwritten cyclically. SDK storage values have a 32 KB limit, so exceptionally long sessions with repeated corrections/takeoffs can exceed it. Storage failures are displayed, never reported as successful saves. Last valid checkpoint remains in the alternate slot. Uninstalling the app can remove its history.

## Verification and limits

See [test results](docs/TESTING.md), [API references and constraints](docs/API-NOTES.md), and [progress log](PROGRESS.md). The local simulator has compiled and run the app and saved a decoded flying activity. This is a working development application, not an operationally validated aviation instrument. Hardware GPS tracks, altitude, battery life, background interruptions and Garmin Connect presentation need device acceptance testing. Custom FIT field visibility in Garmin Connect is not promised for a sideloaded app.

## Source layout

`App.mc` owns lifecycle, input flow and monotonic time; `FlightPlan.mc` contains dummy data; `Navigation.mc`, `Clearoff.mc`, and `FlightTimers.mc` own independent state; `GpsRecorder.mc` and `Recording.mc` handle sensors/FIT; `Alerts.mc`, `Persistence.mc`, and `Ui.mc` handle alerts, durable state and display. Tests exercise the actual Monkey C implementation in Garmin's simulator, not a translated model.
