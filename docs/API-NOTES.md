> Latest V3 UI acceptance: [92 passing tests, three builds, actual simulator screenshots, measured size/space comparison and physical-size preview](../evidence/v3/REPORT.md). Flight/recording/controller logic is retained; earlier version reports below are historical.

> V2 (27 October 2026): [82 passing tests, three builds, button-flight/FIT evidence, screenshots and exact remaining limits](../evidence/v2/REPORT.md). V2 changes and controls are described in [the user guide](USER-GUIDE.md); earlier sections below describe previous versions.

> Acceptance follow-up (27 October 2026): [verified screenshots, GPS/FIT evidence, 54 tests, three builds and remaining physical/lifecycle limitations](../evidence/2026-10-27/REPORT.md). The earlier findings below are historical; the follow-up supersedes their screenshot/GPS status.

# API evidence and platform constraints

Reviewed 2026-10-26 against installed SDK 9.3.0 `bin/api.mir`, `doc/Toybox`, `samples/RecordSample`, `samples/MoxyField`, and device package `fr965/fr965.api.debug.xml`.

| Concern | Verified API / decision |
|---|---|
| Classification | `Activity.SPORT_FLYING = 20`, `SUB_SPORT_GENERIC = 0`. Simulator FIT decoded with sport 20. No substitution of running/cycling. |
| Session | `ActivityRecording.createSession`, `start`, `stop`, `save`, `isRecording`. Return values checked; save failure does not mark navigation finished. |
| Recovery | `createSession` documents returning an existing active unsaved session. This is not a guarantee of persistence through device reboot or process failure. |
| GPS | `Position.enableLocationEvents(LOCATION_CONTINUOUS, callback)` as in SDK RecordSample; disabled on suspend/save. Callback accepts `Position.Info`. GPS quality is the only datum exposed to UI. |
| Clocks | `System.getTimer()` returns milliseconds and periodically wraps. Difference uses Long and a 2^32 correction. `Time.now().value()` records UTC history; `System.getClockTime()` renders local time. |
| Refresh | Foreground `Timer.Timer` at one second; no GPS polling loop. Full screen updates are appropriate for seconds, but AMOLED battery use needs hardware measurement. |
| Alerts | FR965 symbols include `Attention.vibrate`, `VibeProfile`, `playTone`, `TONE_ALERT_HI`; guarded at runtime. OS/device settings may suppress alerts. |
| FIT contribution | UINT32 SESSION field 0 stores total airborne seconds; LAP fields 1–4 encode phase, period seconds and takeoff/confirmed landing UTC. XML metadata included. Native simulator output verifies these fields. Connect display is unverified. The standard contributor supports RECORD, LAP and SESSION messages, not arbitrary aviation event records. Full events stay in app storage. |
| Storage | `Application.Storage` supports nested arrays/dictionaries of primitive values, but no symbols for durable keys/values. 32 KB limit per value; total limit varies. |

Official references:

- [ActivityRecording](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html)
- [Session](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html)
- [Position](https://developer.garmin.com/connect-iq/api-docs/Toybox/Position.html)
- [System](https://developer.garmin.com/connect-iq/api-docs/Toybox/System.html)
- [FitContributor](https://developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor.html)
- [Storage](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html)
- [Garmin's developer workshop](https://developer.garmin.com/downloads/connect-iq/wearable-programming-for-the-active-lifestyle.pdf) explains that Garmin Connect custom field presentation requires app publication/approval. This project is not published, and decoding the raw FIT does not verify Connect display.

Measured UI fonts use `Graphics.getVectorFont({:face=>"RobotoCondensedRegular",:size=>...})`, verified against the installed FR965 simulator font definitions and SDK TrueTypeFonts sample. API 4.2.1 is required. Real `getFontHeight`, `getTextWidthInPixels` and buffered-bitmap drawing are used in screen-state tests. See [Garmin Graphics documentation](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html).

`Session.addLap()` is supported and its raw output has been decoded. The simulator rejected immediate consecutive boundaries without elapsed time; production warns on failure and retains canonical local timestamps. Phase 2 explicitly indicates an incomplete airborne period, with landing UTC 0 rather than a fabricated landing. Unix UTC custom fields are distinct from FIT epoch timestamps. Raw lap fields do not guarantee Garmin Connect display for a sideloaded app.

`createSession` can return an existing unsaved session, but has no verified identity/continuity query in this integration. Active-flight recovery retries recording with a gap warning. Finished local-only sessions whose native FIT is still pending cannot be safely rebound after restart; the warning/pending flag is preserved and new-flight creation is blocked instead of discarding data.

Garmin Connect acceptance, the final user-facing activity category, map/altitude display, and custom summary presentation have **not** been tested. No account was accessed or data uploaded. Physical-device deployment remains a separate acceptance step.
