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
| FIT contribution | One UINT32 SESSION field, ID 0, airborne seconds. XML metadata included. The standard contributor supports RECORD, LAP and SESSION messages, not arbitrary aviation event records. Full events stay in app storage. |
| Storage | `Application.Storage` supports nested arrays/dictionaries of primitive values, but no symbols for durable keys/values. 32 KB limit per value; total limit varies. |

Official references:

- [ActivityRecording](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html)
- [Session](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html)
- [Position](https://developer.garmin.com/connect-iq/api-docs/Toybox/Position.html)
- [System](https://developer.garmin.com/connect-iq/api-docs/Toybox/System.html)
- [FitContributor](https://developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor.html)
- [Storage](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html)
- [Garmin's developer workshop](https://developer.garmin.com/downloads/connect-iq/wearable-programming-for-the-active-lifestyle.pdf) explains that Garmin Connect custom field presentation requires app publication/approval. This project is not published, and decoding the raw FIT does not verify Connect display.

Garmin Connect acceptance, the final user-facing activity category, map/altitude display, and custom summary presentation have **not** been tested. No account was accessed or data uploaded. Physical-device deployment remains a separate acceptance step.
