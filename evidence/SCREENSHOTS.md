# Simulator capture checklist

No screenshot files were generated in this remediation session. Desktop screenshot/input tools were not available, and plugin discovery did not return a usable replacement. The installed Garmin simulator was used for all tests. The SDK's font and bitmap renderer was exercised directly, but that is **not a screenshot review**.

| Required capture | Renderer coverage | Screenshot |
|---|---|---|
| Baseline navigation | Previous UI launched before changes | Pending |
| Updated navigation before start | `idle` | Pending |
| CLEAROFF running | `running` | Pending |
| Due / overdue | `due` | Pending |
| Radio confirmation | `radio` | Pending |
| Waypoint confirmation | `advance` | Pending |
| Timer page | `timers` | Pending |
| Recovery | `recovery` | Pending |
| Recording warning | `error` | Pending |
| Finish confirmation | `finish` | Pending |

The renderer test uses a real 454 × 454 Garmin buffered bitmap, FR965 vector fonts, `getFontHeight` and `getTextWidthInPixels`. It checks every text rectangle's four corners against a 217-pixel-radius safe circle, checks text-to-text overlap, and checks clock prominence. It also covers completed checks and the longest sample waypoint name. This establishes geometric bounds for the tested strings, not outdoor readability or pixel-level visual acceptance.

When desktop control is available, capture the actual simulator through **File > Save Screen Capture** and save PNGs here with these names: `00-baseline.png`, `01-idle.png`, `02-running.png`, `03-overdue.png`, `04-radio.png`, `05-advance.png`, `06-timers.png`, `07-recovery.png`, `08-recording-error.png`, `09-finish.png`. The baseline must be generated from the pre-remediation commit in a separate checkout; do not overwrite current source to recreate it.

A supported simulator GPS injection/playback control has not been verified in this session. A saved FIT with altitude values but no coordinate fields does not satisfy the GPS-track acceptance check.
