# Remediation baseline — 2026-10-26

- Branch: main; starting commit a6ea793. Existing staged/unstaged .gitignore edits preserved.
- Required documents, every production source file, tests and build scripts inspected.
- Baseline debug/test compilation succeeded with existing dynamic-type warnings.
- Actual FR965 simulator: 14/14 existing tests passed; output in baseline-tests.txt.
- Original app launched through Garmin monkeydo.
- Two focused regressions reproduced false landing and missing recovery-event interface (reproduced-defects.txt).
- Desktop-control and screenshot tools are unavailable in this session. The computer-use skill was inspected; its required node_repl runtime is not available. SDK shell exposes app/device commands but no verified screenshot or location-injection command was found. Baseline screenshot could not be captured. This is a verification limitation, not fabricated evidence.
