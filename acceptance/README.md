# Simulator acceptance drivers

These independent app IDs compile unchanged production sources plus `acceptance/source`. They are excluded from `monkey.jungle` and signed device output. They are development probes, not extra production features or passing unit tests.

From repository root with Garmin SDK and Java on PATH:

```powershell
$sdk=(Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
& "$sdk\bin\monkeyc.bat" -f acceptance/visual.jungle -d fr965 -o bin/visual-acceptance.prg -y .private/developer_key.der -w
& "$sdk\bin\monkeydo.bat" bin/visual-acceptance.prg fr965
```

Visual driver: physical watch START advances navigation/running/overdue/radio/waypoint/timers/recovery/finish/finished/pending scenes. It freezes fixture elapsed values, uses actual clock/fonts/production view and writes no checkpoints or native FIT. Recovery passes through production snapshot/restore. Capture via Garmin's Save Screen Capture or the explicitly approved fallback.

`Simulator-Window.ps1` is a bounded Windows fallback: exact installed Garmin simulator executable and owned windows only. It captures with PrintWindow and supports observed Garmin menu/control actions. Use only with user authorization when normal Computer Use is unavailable. Coordinates are simulator client coordinates, specific to the current 698 x 995 window; inspect a fresh capture before clicking. Never use it for other applications or delete/reset/discard data.

GPS driver: replace `visual.jungle`/`visual-acceptance.prg` above with `acceptance.jungle`/`gps-acceptance.prg`. It waits for START. Before START, set GPS quality Good and open Simulation > Activity Data; choose FIT/GPX Playable File and load `bin/gps-input.fit`. Press Play and then the simulated watch START. Driver uses production recording, starts checks after 2 seconds, takeoff after 4, landing after 24, saves/exits after 28 seconds. Watch the console; inspect actual output FIT, not only the save result.

Build the synthetic input using Garmin's bundled encoder:

```powershell
java -cp "$sdk\bin\fit-graph.jar" com.garmin.fit.csv.CSVTool -c acceptance/gps-input.csv bin/gps-input.fit
# Decode the actual saved activity (substitute its real path):
java -cp "$sdk\bin\fit-graph.jar" com.garmin.fit.csv.CSVTool -i -b 'C:\path\to\saved.fit' bin/decoded.csv
```

Input: 45 seconds/samples on a synthetic path (-34.04 + i*0.0001, 150.69 + i*0.0001), altitude 150+i metres. Native simulator Activities directory: `%LOCALAPPDATA%\Temp\com.garmin.connectiq\GARMIN\Activities`. App reload resets playback source; configure after loading. Restore GPS quality after testing. Current findings, including altitude offset, are in `evidence/2026-10-27/REPORT.md`.

Pending driver: `pending.jungle` / `pending-acceptance.prg`. On its first run it starts a real disposable native recording, locally finishes at 8 seconds, persists identity and exits at 9 seconds. On relaunch it logs restored local state, production refusal, and an experimental unstarted candidate save. It persists phase in its own app ID. It bypasses the explicit Exit action intentionally to probe external termination; it does not prove production Exit allowed abandonment. It caused a native simulator crash during this investigation. Run only with disposable simulator data and preserve evidence; no automatic reset/discard is supplied. A true save boolean is not proof the original activity was recovered.

## V2 acceptance entry points

Use `v2.jungle` / `bin/v2-button.prg` to compile `V2ButtonApp`. Its only changes are a separate app/store identity and console evidence. Drive the physical simulator buttons normally; source controller/recording/view behaviour is production. Final traces and screenshot matrix are in `evidence/v2/REPORT.md`.

Use `v2-proof.jungle` / `bin/v2-proof.prg` for labelled frozen fixtures. START cycles overdue, recording failure, unresolved review, compiled icon transparency and airborne checks-idle. It writes no checkpoints and creates no native recording. The extra bitmap resource compiles the same icon SVG separately from the launcher reference, to inspect transparency on coloured backgrounds.

The GPS driver's V2 entry starts at a selected summary: configure native FIT playback first, then press START twice for the separate confirmation. It records takeoff after two seconds, starts checks after four, lands after 24 and attempts Finish & Save after 28. It exits directly only after native state is saved; failed saves remain protected. See current V2 GPS evidence rather than assuming the previous altitude offset is fixed. Restore GPS quality afterwards.

`VisualAcceptanceApp` and `PendingAcceptanceApp` are historical investigation helpers. For exact pre-V2 reproduction use commit a2c71f8 and its report. Do not interpret their old interaction fixtures as current end-to-end V2 acceptance.
