# V2 changelog

- Added plan selection, summary and separate Start Flight confirmation before recording.
- Added derived flight state and contextual START: Takeoff → Start checks → Complete check, with another takeoff after landing.
- Enlarged Garmin-measured clock (84 px requested), heading (64) and countdown (62), from 72/48/48; retained circular bounds, high contrast, radio references and explicit state/action.
- Mapped navigation BACK to timers, UP to last action and DOWN to first. Actions wrap through timers; confirmation BACK cancels safely.
- Allowed early checks while preserving 10/10/5 NM planned intervals, due/actual UTC history and anti-double-press protection. Expanded undo regressions.
- Replaced ordinary Confirm radio with change-only prompts and a pending contextual reminder; unchanged frequencies do not prompt.
- Added cancellable four-mode alert selection with compatible persisted IDs.
- Moved retry/recovery/local-only operations to dedicated contextual recovery screens; retained unknown-native-session protections and no uncontrolled retries.
- Added verified finish/local-save completion and automatic safe exit. Failed finish freezes local end for retry. Added guarded native discard and a local tombstone.
- Removed embedded black icon rectangle; compiled transparency verified separately from physical launcher behaviour.
- Retained continuous flying FIT, GPS/altitude recording, lap/developer fields, manual events, independent timers, history and conservative legacy recovery. No Sheets integration.
- Baseline 54 tests; final 82 passing tests, three successful builds, real button-flight and GPS FIT evidence. Hardware and native-restart limitations remain documented.
