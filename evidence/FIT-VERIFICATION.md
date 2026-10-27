> Latest V3 evidence: [minimal navigation, large menus, real-button native save and exact limits](v3/REPORT.md). Earlier results remain historical evidence.

> Latest V2 evidence: [actual screenshots, real button flights and decoded GPS/native FIT](v2/REPORT.md). Earlier results below are historical.

> 27 October 2026 follow-up: [actual injected coordinate records, altitude offset and pending-save probe](2026-10-27/REPORT.md). The earlier no-coordinate result below remains historical evidence.

# FIT acceptance evidence — remediation

The native integration test calls the production `Recording` class, Garmin ActivityRecording and FitContributor APIs in the FR965 simulator. It creates a continuous flying session with four boundaries: ground, airborne, ground, airborne. The two airborne periods are deliberately synthetic one-second test periods, not detected flights.

Decoded with the installed SDK's `fit-graph.jar` / `com.garmin.fit.csv.CSVTool -i -b`:

- One session, sport 20 (flying), sub-sport 0 (generic).
- Four lap messages; two have `Air phase = 1` and one-second `Air period seconds` values.
- Lap developer fields contain Unix UTC takeoff/confirmed-landing timestamps.
- Session developer field `Airborne seconds = 2`.
- Session elapsed duration about 4.44 seconds, including the two ground periods.
- Four synthetic simulator altitude samples were present, with value -122 m.
- **Zero coordinate samples**. No GPS fix or real track was verified.

Files are deliberately excluded from Git: raw `.fit` under `%LOCALAPPDATA%\Temp\com.garmin.connectiq\GARMIN\Activities`, decoded output under `bin/final-fit.csv`. Keep any future real tracks private.

The simulator rejected back-to-back zero-duration lap boundaries in the first attempt. The test now waits for distinct actual elapsed timestamps and always saves before asserting lap results. Production lap failure is explicit and leaves local history intact. Rapid genuine takeoff/landing confirmations can still exceed the recording API's accepted boundary rate; local history is authoritative in that case.

Garmin Connect display, native watch lap presentation, physical altitude accuracy, and GPS recording remain unverified. Encoding a FIT developer field does not prove Connect will show it for a sideloaded application.
