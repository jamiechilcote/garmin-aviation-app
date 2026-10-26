# Actual simulator screenshots — 27 October 2026

[Verified capture matrix and visual findings](2026-10-27/REPORT.md#actual-screenshots-and-visual-review).

Production `navlog.prg` navigation was captured directly. Running, overdue, radio, waypoint confirmation, timers, recovery, finish, finished and pending-FIT states were captured in Garmin's real FR965 simulator using an isolated fixture app with the unchanged production renderer. The fixture distinction matters: these prove actual rendered appearance, not end-to-end control/lifecycle acceptance. All listed images were inspected; no clipping or overlaps appeared. Small labels/footer still require physical outdoor readability testing. No historic pre-remediation baseline image was recreated.

Capture was native Windows PrintWindow restricted to Garmin, explicitly authorized by the user when Computer Use's runtime was unavailable. No generated screenshots were used. [Driver and capture instructions](../acceptance/README.md).

Native GPS playback also produced actual coordinate-bearing FIT records; see the report for the unresolved altitude offset and pending-save restart limitations.
