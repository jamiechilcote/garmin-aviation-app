# V3 physical-watch UI acceptance — 27 October 2026

Starting commit: `eb7523336f0af45e33e9101d129d7450789433bd`. The photograph and hand-drawn reference were not available in this task's context; the written V3 arrangement was followed. This update changes production rendering in `source/Ui.mc` only. Flight/controller, planned calculations, GPS, recording, persistence, history, manifest/app ID and signing key are retained.

## Before/after: measured values, not requested font sizes

The unchanged V2 renderer was compiled and measured in the actual Garmin FR965 simulator before editing it. The same frozen running scene was then measured in V3. The font is Garmin's `RobotoCondensedRegular`; equal-width numeric samples were measured and tested. Local time still comes directly from `System.getClockTime()` and updates on the existing one-second pulse.

| Element | V2 measured width × height | V3 measured width × height | Height growth |
|---|---:|---:|---:|
| Clock | 250 × 84 px | 306 × 104 px | 23.8% |
| Heading | 102 × 64 px | 135 × 86 px | 34.4% |
| Running CLEAROFF | 116 × 62 px | 161 × 86 px | 38.7% |
| Each radio frequency | 92 × 34 px | 150 × 54 px | 58.8% |
| HEADING label | 71 × 22 px | 90 × 28 px | 27.3% |
| ACTIVE label | 59 × 23 px | 80 × 32 px | 39.1% |
| Selected action (shortened to ADVANCE) | 222 × 36 px | 285 × 84 px | 133.3% |
| Selected plan | 220 × 36 px | 305 × 50 px | 38.9% |

V2 requested 38 px radio text but actually fitted it down to 34 px. V3 allocates the radio regions first and renders at 54 px. Clock/heading/countdown/radio use independent role sizes and readable floors, not a shared minimum. Tabular-digit reference strings reserve the longest tested numeric widths; clock and countdown sizes do not change with their digits.

Running navigation has **9 text elements versus 15** (10 when START/CLEAROFF uses two lines). Sum of measured text rectangles increases **62,312 → 83,240 px²**. Relative to the full 454-pixel circular display, that is **38.49% → 51.42%**, a 33.6% increase in rectangle area. This metric includes font line-height space; it is not lit-pixel coverage or a physical-readability score.

Console measurements are emitted once per scene, so clock seconds may differ from a later capture. The console may replace the degree character in its text encoding; literal rendering tests and the screenshots verify the actual degree glyph.

[Raw V2 metrics](before-metrics.txt), [raw V3 metrics](after-metrics.txt), [all measured rectangles](text-bounds.csv), [size comparison CSV](size-comparison.csv), [V2 capture](before-running.png), [V3 capture](03-running.png).

### Region limits

Coordinates below are relative to the actual 454 × 454 display; all text rectangles remain inside the existing **217-pixel safe radius**, not merely inside a square. Smaller drawable sizes are scaled around the actual display centre and tested too.

| Navigation element | Actual V3 x / y / width / height |
|---|---|
| Clock | 74 / 76 / 306 / 104 |
| HEADING label | 81 / 182 / 90 / 28 |
| Heading value | 58.5 / 211 / 135 / 86 |
| CLEAROFF label | 277 / 182 / 102 / 28 |
| Running countdown | 247.5 / 211 / 161 / 86 |
| ACTIVE label | 100 / 309 / 80 / 32 |
| Active frequency | 198 / 298 / 150 / 54 |
| STBY label | 100 / 363 / 57 / 32 |
| Standby frequency | 198 / 352 / 150 / 54 |

The clock is limited by the circle's narrower upper chord and the middle-section boundary. Heading/countdown are limited by their 86-pixel vertical region while retaining two large radio rows. START/CLEAROFF uses two 42-pixel lines within that same region; longer single action words are fitted independently (TAKEOFF 60 px, COMPLETE 50 px). Flight Timers retains a concise FIT/GPS status line in addition to its three large timers and state, so a pilot can still check recording and GPS fix without adding any navigation clutter. That line distinguishes native recording, fix acquisition, GPS error and unresolved native state.

The lower radio row limits the shared left/right alignment to the circle's lower chord. Enlarging these further requires moving or reducing another essential role. No additional footer is used to make room.

The screen contains only local clock, heading/CLEAROFF labels and values, and ACTIVE/STBY references. Demo/route/leg/progress/status/button-instruction rows are removed from navigation. Demo warnings remain in selection/summary. Current state and pending radio/recording warnings remain in secondary screens. ADVANCE/UNDO show route context and the correct target leg; ordinary menus show one large selected command. Finish/discard still require explicit START confirmation and allow BACK cancellation.

## Actual-size approximation and visual inspection

[Physical-size review HTML](physical-size-review.html) displays genuine cropped screenshots at **35.4 mm diameter**, matching [Garmin's display specification](https://www.garmin.com.sg/products/wearables/forerunner-965-black/). Print at 100% and verify the included 50 mm ruler. On-screen CSS millimetres depend on monitor/OS/browser scaling. [V2 134 px](v2-134px.png), [V3 134 px](v3-134px.png), [V2 menu](v2-menu-134px.png), [V3 menu](v3-menu-134px.png) approximate the diameter at 96 CSS pixels/inch.

The 134 × 134 previews were visually inspected as well as every full capture. The written reference's clock → equal heading/CLEAROFF columns → two radio rows is preserved. The larger white radio values and single large menu command remain distinguishable at the reduced size, whereas V2's labels/footer and menu neighbours are much smaller. This is a screenshot/print approximation, **not a physical FR965 readability test**. No statement of daylight, wrist-distance, viewing-angle or eyesight acceptance follows. The absent drawing/photo cannot be claimed as visually compared.

`acceptance/Make-V3-Review.ps1` reproduces the exports and crops/downscales actual simulator pixels only. The observed native display origin is checked against the 698 × 995 capture geometry; nothing is reconstructed as a mockup. Full captures retain the simulator skin; crops mask only corners outside the circular display in the preview.

## Screenshot matrix

The ordinary final production application was also launched against the preserved checkpoint without starting a flight: [production selection](production-selection.png). [Scope/test-retention check](scope-check.txt) verifies unchanged controller/recording modules and all 82 baseline test functions.

All PNGs are actual FR965 simulator captures, inspected for clipping, overlap, alignment and word legibility. No generated mockups. `01`–`17` use explicit frozen appearance fixtures with unchanged production view code; the fixture only isolates state/storage and records bounds. The live captures use actual production button handling, timers, checkpoints and native recording through a separate app/store identity.

| Required state | Frozen appearance capture | Real button evidence |
|---|---|---|
| Ground / TAKEOFF | [01](01-ground.png) | [live ground](live-ground.png) |
| Airborne / START CLEAROFF | [02](02-airborne-start.png) | [live airborne](live-airborne.png) |
| Running CLEAROFF | [03](03-running.png) | [live running](live-running.png), [early ack](live-early-ack.png) |
| Overdue | [04](04-overdue.png) | Automated acknowledgement regression; no six-minute button wait claimed |
| Complete | [05](05-complete.png) | Controller/rendering regressions; no live full-cycle completion claimed in this V3 smoke |
| Flight Timers | [06](06-timers.png) | BACK/timers/action ring exercised in live trace |
| Flight Actions | [07](07-actions.png) | ADVANCE and DISCARD confirmations opened/cancelled in live trace |
| Flight selection | [08](08-selection.png) | Selection/summary/start confirmation exercised in live trace |
| Radio prompt | [09](09-radio.png) | Preserved radio/controller tests; no live radio-change claim in V3 smoke |
| Finish confirmation | [10](10-finish-confirmation.png) | [live airborne warning](live-finish-confirmation.png) |
| Discard confirmation | [11](11-discard-confirmation.png) | [live opened/cancelled](live-discard-cancel.png) |
| Alerts | [12](12-alerts.png) | Preserved alert tests and new large-selection regression |
| Recovery | [13](13-recovery.png), [review](17-review.png) | Pending/error regression tests; no native reboot-rebinding claim |
| Summary/start | [14](14-summary.png), [15](15-start-confirmation.png) | Live trace |
| Saved status | [16](16-saved.png) | [real native saved](live-saved.png) |

No clipping or text overlap was found in final reviewed images. Frequencies share a common right edge (x=348); ACTIVE/STBY labels share a left edge (x=100). Two-line actions are fully visible. Menus are shortened to ADVANCE, UNDO, LAND/TAKEOFF, ALERTS, FINISH, DISCARD and RADIO; important recovery consequences remain explicit.

## Tests, builds and recording evidence

Before modification: **82 tests passed**, [baseline output](baseline-tests.txt). The initial attempt could not connect while the simulator was closed; opening it allowed the unchanged suite to complete.

Final: **92 passed, zero failures/errors**, [full output](final-tests.txt). All original 82 test functions remain. Added tests cover exact minimal navigation content, contextual START consistency, early/overdue/complete states, pending/ground override, 23:59:59 / 360° / 00:00 / 59:59, maximum bundled/realistic 7-character frequencies, aligned labels/right edges, responsive circular bounds, large menus, confirmations, timers/alerts, accurate secondary FIT/GPS status and the UNDO target-leg label. One old index-based radio-clock assertion was updated because the simplified radio prompt deliberately removes that secondary clock; its circular bounds and reference tests remain. A timing-sensitive test assertion was corrected to measure a fresh interval from the controller's actual elapsed time, rather than assuming drawing consumed no time. Production timing code was not changed.

Simulator/debug, test and signed development device builds reported **BUILD SUCCESSFUL**. [Build results and SHA256 hashes](build-results.txt). Existing dynamic dictionary warnings remain. The signed artifact is `bin/navlog-device.prg`; generated output and signing keys stay outside Git.

[Real button trace](button-flight.txt): plan selection, separate start confirmation, takeoff, start CLEAROFF, early acknowledgement, BACK timers, ADVANCE confirmation/cancellation, wrap to DISCARD and cancel, FINISH/save and normal exit. [Native file identification](button-fit.txt), [decoded FIT](button-fit-decoded.csv). The session closed with a real native save, an unconfirmed airborne period, no fabricated landing and no waypoint arrival. The early acknowledgement retains separate scheduled due and actual timestamps. This smoke ran without a GPS fix; it does not replace the existing V2 GPS evidence or resolve its altitude discrepancy.

## Restored .gitignore

The user explicitly authorised replacing local `.gitignore` edits. The tracked HEAD baseline was inspected, then retained with necessary generated-directory, key/credential and temporary/editor rules. `bin/`, `.private/`, generated PRG/IQ/MIR/debug output, FIT/log files, loose signing keys and local environment credentials are ignored. PNG/CSV/HTML acceptance evidence, source/tests/resources/docs and `.env.example` are not hidden. **29 positive/negative `git check-ignore --no-index` checks passed**: [results](gitignore-checks.txt). No unrelated changes were discarded.

## Limits and next physical test

- No physical-watch test was performed. The requested layout is based on the written brief because the drawing and photograph were unavailable here.
- Unknown native FIT identity after restart remains guarded; no rebinding, save/discard workaround or retry-loop changes were introduced. Existing pending-FIT protections remain intact.
- The V2 altitude-offset issue, physical launcher compositing, device DND/alerts, battery, reboot continuity and Garmin Connect presentation are unchanged/unverified in this UI phase.
- Navigation intentionally omits warnings/state/radio-pending footers. Use BACK for timers/state and UP/DOWN for contextual actions/recovery. Do not infer recording success from a running countdown.
- Seven-character numeric radio references are the supported bundled format; values with units or additional annotations are not part of the plan model/UI contract.

Rebuild with `scripts/build.ps1 -Release`. Preserve unresolved recordings, USB-copy only `bin/navlog-device.prg` into FR965 `GARMIN/APPS`, disconnect safely and launch. Review the new layout on the actual watch at wrist distance and in daylight. Check TAKEOFF → START CLEAROFF → countdown/early ack → DUE → COMPLETE, two radio rows, timers/actions/wrap, radio prompts and finish/discard cancellations. Compare with the user's drawing/photo on the physical device. Use a separate disposable flight for actual discard or interruption testing; normal finish should save and return to Garmin. [User instructions](../../docs/USER-GUIDE.md).

Modified production file: `source/Ui.mc`. Also changed `.gitignore`, focused UI tests, simulator measurement/button entry points, screenshot-review tooling, current documentation and this evidence. No flight-engine, GPS, recording, persistence, alert-setting or controller source changed.


### File inventory

- Production view: `source/Ui.mc`; project ignore policy: `.gitignore`.
- Tests: updated `tests/UiTests.mc`, added `tests/V3UiTests.mc`. All original test functions retained.
- Acceptance support: `acceptance/source/V3MeasureApp.mc`, `acceptance/v3*.jungle`, `acceptance/v3*-manifest.xml`, `acceptance/Make-V3-Review.ps1`, and `acceptance/README.md`.
- Current documentation: `README.md`, `PROGRESS.md`, `docs/USER-GUIDE.md`, `docs/TESTING.md`, `docs/API-NOTES.md`, `docs/AUDIT.md`, `evidence/SCREENSHOTS.md`, `evidence/FIT-VERIFICATION.md`.
- All V3 screenshots, text bounds/comparisons, native FIT decode, test/build/ignore results and physical-size artifacts are under `evidence/v3/`.
