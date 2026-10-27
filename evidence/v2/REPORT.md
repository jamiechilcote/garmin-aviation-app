# V2 acceptance report — 27 October 2026

Starting main: `a2c71f83baaf92d1d1e1f3881b51553c5a722715`. Existing architecture, all source/tests/resources and prior simulator/FIT/recovery evidence were inspected. This is an update to the application, with no Sheets integration or operational navigation data. Unrelated staged/unstaged `.gitignore` edits were preserved.

## Automated tests and builds

The first baseline attempt could not connect because the simulator was closed. After opening Garmin's actual FR965 simulator, the unchanged **54-test baseline passed**, before source edits: [output](baseline-tests.txt).

Final **82 passed, zero failed, zero errors** in Connect IQ SDK 9.3.0 / FR965 API 5.2.0: [full output](final-tests.txt). All original 54 test functions remain. Expectations were updated for explicitly replaced startup/button/radio/alert flows; native save, pending protection, migration, storage, event/undo and geometry coverage remains. Added 28 regressions include state/startup, exactly-once recording, fixed early/late intervals, two-second protection, final checks, multiple airborne periods, all requested undo states, GPS independence, menus/back/confirmations, radio changes and pending retention, alert cancellation, failed local/native save, discard guards, plan identity/revision and real long-name truncation.

A native simulator start/discard test passed using production `Recording.discard()`. Known false-return failures were injected; physical discard is not claimed. Geometry tests cover 22 V2 scenes using real vector font measurements and a 217-pixel safe circle, asserting no overlap and larger clock/heading/countdown values. Existing renderer coverage remains too.

Debug simulator, test and signed development device builds all reported **BUILD SUCCESSFUL**. [Compiler success results and SHA256 binary hashes](build-results.txt). Existing dynamic dictionary/container warnings remain. Keys, raw FIT and binaries remain excluded from Git. Only whitespace normalization followed final verification; production logic remained unchanged.

## Button-driven simulator flight

`V2ButtonApp` changes only app/storage identity and console evidence; inputs, navigation, rendering, recording, history and exit use production behaviour. Real Win32 button input was restricted to Garmin's installed simulator under the user's existing explicit fallback authorization. No generated mockups were used.

[Full flight trace](button-flight.txt): selection → summary → separate Start confirmation → ground → takeoff → checks → early acknowledgements → checks complete → BACK timers → DOWN first action → UP through timers to last → cancel discard/finish → alert selection/save → confirmed landing → second takeoff → confirmed waypoint → radio prompt → dismiss/retain → acknowledge → finish/save → exit. A just-started check press was ignored, then later deliberate presses completed fixed planned intervals. A separate [final-source button smoke](final-button-flight.txt) rechecked corrected idle/radio labels and native save/exit. The first flight had two airborne periods; the final shorter smoke had one unconfirmed period.

[Decoded first native FIT](button-fit-decoded.csv), [file identification](button-fit.txt): one flying session (sport 20), elapsed 148.688 seconds, four phase lap messages, confirmed airborne period 110 seconds and incomplete phase-2 period 36 seconds, airborne-total field 146 seconds. Local history shows manual first-waypoint arrival, no arrival for the final unfinished leg, and no invented landing for the second period. No GPS track is claimed from this button flight; it ran without a fix. Normal completion showed saved status and returned the simulator to idle through `System.exit()`.

## Screenshot matrix and visual review

The ordinary final production `navlog.prg` was also launched against the preserved checkpoint and correctly opened [flight selection](00-production-startup.png) without starting a recording. All PNGs below are actual simulator-window captures. The final list was inspected visually. No clipping, overlaps or out-of-circle text appeared. A duplicated START label and an overly long recovery notice were corrected from actual capture evidence. A partial-frame capture was replaced by a complete, explicitly labelled fixture frame. Pixel capture is not proof of physical daylight readability.

| Brief requirement | Screenshot | Evidence type |
|---|---|---|
| Flight selection | [01](01-selection.png) | Real button flight |
| Selected summary | [02](02-summary.png) | Real button flight |
| Start Flight confirmation | [03](03-start-confirmation.png) | Real button flight |
| Ground / TAKEOFF | [04](04-ground-takeoff.png) | Real button flight |
| Airborne / START CHECKS | [05](05-airborne-idle.png) | Final-source appearance fixture; transition also verified in both button traces |
| Running countdown | [06](06-running.png) | Real button flight |
| Early acknowledgement | [07](07-early-ack.png), [guarded press](07-guarded-press.png) | Real button flight; next interval remains six minutes |
| Overdue | [21](21-overdue-fixture.png) | Frozen elapsed-time fixture; no six-minute physical wait claimed |
| Completed checks | [09](09-complete.png) | Real button flight |
| Radio change | [19 prompt](19-radio-change.png), [pending](19-radio-pending.png) | Real button flights |
| Flight Timers | [10](10-timers.png) | Real button flight |
| Actions first / last | [11](11-actions-first.png), [12](12-actions-last.png) | Real button flight |
| Alert selection | [15](15-alert-settings.png) | Real button flight |
| Landing confirmation | [16](16-landing-confirmation.png), [landed](17-landed.png) | Real button flight |
| Finish confirmation | [14](14-finish-confirmation.png) | Real button flight |
| Discard confirmation | [13](13-discard-confirmation.png) | Opened and cancelled; no button-driven destructive discard claimed |
| Successful finish | [20](20-finished.png) | Final-source real button flight, real native save |
| Failure / recovery | [22](22-recording-error-fixture.png), [23](23-unresolved-review-fixture.png) | Explicit appearance fixtures; failure guards separately exercised by tests |
| Waypoint confirmation | [18](18-waypoint-confirmation.png) | Real button flight |
| Compiled icon transparency | [24](24-icon-transparency.png) | Actual compiled duplicate SVG bitmap on two coloured backgrounds; launcher itself untested |

The production navigation clock requests 84 px versus 72 previously; heading 64 versus 48; running countdown 62 versus 48. Measurements verify actual rendered heights of at least 72/56/56 respectively and clock dominance. Radio values request 38 rather than 32. Labels, state and START action are stronger and the display area is used more fully. Text fitting may reduce sizes for longer strings; plan names truncate with an ellipsis. Physical wrist-distance, daylight, screen-wake and battery acceptance remains necessary.

## V2 GPS/FIT playback

The separate GPS driver uses production start/recording/phase/save operations, with controlled event timing after manual Start Flight confirmation. It is not presented as a button-driven full flight. Native Activity Data FIT/GPX playback was configured before starting recording; [panel](gps-playback.png), [console](gps-result.txt), [full decoded FIT](gps-fit-decoded.csv), [coordinate extract](gps-records.csv).

Native `2026-10-27-17-07-17.fit` decoded successfully. Nine location records match synthetic fixture indexes 0,1,4,8,12,16,20,24,26 within semicircle rounding. Latitude changes from -34.04000001959503 to -34.03740003705025 and longitude from 150.68999997340143 to 150.69260003976524. Altitude changes **130.2 → 156.2 m** against matching synthetic input **150 → 176 m**: a consistent **-19.8 m** discrepancy in this run. Earlier evidence had -122 m. The varying offset is unresolved; no correction or accuracy claim is made. GPS quality was restored to Not Available after testing.

## Remaining limits and specification differences

- Automatic local restoration is implemented; automatic unknown-native-FIT rebinding is deliberately withheld. Prior restart investigation crashed the simulator and a new candidate save did not prove original-session recovery. V2 therefore blocks new recording, blind discard and unsafe exit when identity is unresolved. No experimental rebinding was added. Real reboot/native continuity remains unverified.
- A known same-instance native recording can retry; recording that never created a session can retry once on request. No retry loop exists. After failed Finish, local end/timers remain frozen at the first finish command; native recording may resume after a save failure, so raw FIT duration needs separate review.
- Native and local save/discard cannot be atomic. Local storage failure after native success remains pending and retry does not create/save another FIT. An interruption between native completion and durable local bookkeeping may still require review.
- Icon asset transparency is verified in the real simulator, not merely inferred from SVG editing. System launcher compositing and return-to-activity-list behaviour require physical-device checking.
- Only two demo plans are bundled, using existing data. Names/IDs/revisions/date are separate and persisted; no operationally validated routes or import transport are supplied. Four-leg maximum and existing bounded history/checkpoint storage remain.
- Timers is the wrap position in the vertical action interface. START there has no action highlighted and does nothing. BACK never saves/discards. Radio prompts preserve access to actions; a pending contextual reminder replaces the ordinary Confirm radio action.
- Overdue, failure/review and the final idle appearance screenshot are fixtures, clearly separated from the real button-flight evidence. No full hardware acceptance, physical install, actual flight, Garmin Connect upload, alert audibility/DND, battery or altitude-accuracy test was performed here.

## Rebuild and next physical test

Use `scripts/build.ps1 -Release`, then USB-copy only `bin/navlog-device.prg` into FR965 `GARMIN/APPS`, preserving the existing app ID/key and any pending recording. Safely disconnect and launch. Follow the [physical acceptance checklist](../../docs/USER-GUIDE.md#next-physical-fr965-acceptance): inspect launcher/readability/buttons, test the full contextual START and BACK/timers/action workflow, obtain outdoor GPS, verify fixed early/late intervals, two airborne periods and safe finish, then use separate disposable data for discard/interruption/reboot and Garmin Connect presentation. The app is ready for that next development acceptance test; it is not operationally validated or production-certified.

## Modified files

- Production: `source/App.mc`, `Clearoff.mc`, `FlightPlan.mc`, `Navigation.mc`, `Persistence.mc`, `Recording.mc`, `Ui.mc`; `resources/drawables/icon.svg`. The existing `GpsRecorder`, `FlightTimers` and `Alerts` implementations, manifest permissions/app ID and FIT field metadata are retained.
- Tests: preserved/updated `tests/NavigationTests.mc`, `ReliabilityTests.mc`, `UiTests.mc`; added `V2Tests.mc`.
- Simulator helpers: `acceptance/source/V2ButtonApp.mc`, `V2ProofApp.mc`, updated `GpsAcceptanceApp.mc`, V2 manifests/jungles and the duplicate icon proof resource. Existing acceptance jungles include the proof resource because their shared acceptance source directory compiles together. Production source paths do not include these helpers/resources.
- Documentation: `README.md`, `PROGRESS.md`, `docs/USER-GUIDE.md`, `V2-ARCHITECTURE.md`, `V2-CHANGELOG.md`; current-version notices in `TESTING.md`, `API-NOTES.md`, `AUDIT.md`, `evidence/SCREENSHOTS.md` and `FIT-VERIFICATION.md`; `acceptance/README.md` and all evidence under `evidence/v2/`.
