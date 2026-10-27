# Aviation Navlog V3 user guide

## Buttons

| Screen | START | BACK | UP / DOWN |
|---|---|---|---|
| Flight selection | Select highlighted plan | Exit safely | Previous / next plan, wrapping |
| Flight summary | Open Start Flight confirmation | Selection | No flight action |
| Start confirmation | Begin session and recording | Summary | No flight action |
| Navigation | Takeoff, start checks or complete check according to state | Flight Timers | Last / first Flight Action |
| Flight Timers | No action is highlighted | Navigation | Last / first action |
| Flight Actions | Open highlighted action | Flight Timers | Previous / next; wraps through timers |
| Confirmation | Confirm the displayed operation | Cancel to previous menu | No operation |
| Radio change | Acknowledge reference values | Navigation, reminder stays pending | Open actions |
| Alert settings | Save highlighted mode | Cancel without changing | Highlight previous / next mode |
| Recovery | Select highlighted safe option | Manual navigation with warning | Choose available option |
| Completion | Safe exit | Safe exit | No new flight action |

LIGHT retains system behaviour. Touch taps are consumed. Select has a 450 ms debounce, other navigation 180 ms; a new CLEAROFF interval additionally rejects acknowledgements for two elapsed seconds. Wait briefly if a press is ignored. The CLEAROFF area names the action: TAKEOFF, START CLEAROFF, a countdown, DUE or COMPLETE. No separate action footer is shown.

## Start, fly and finish

Choose a clearly labelled demo plan, review its departure/destination, leg count and revision, then confirm Start Flight. Until confirmation there is no FIT activity or running session timer. Wait for an outdoor GPS fix before testing a physical track. BACK exposes GPS/FIT status on Flight Timers.

START on the ground marks takeoff. START after takeoff starts that leg's checks. START during the countdown acknowledges early; START after DUE acknowledges late. Either consumes exactly one fixed planned segment and starts the next full planned interval. Final acknowledgement shows COMPLETE. Neither check completion nor arrival alerts advance a waypoint.

Advance waypoint and Undo are confirmed actions. A changed active or standby frequency prompts; unchanged values do not. Dismissed reminders remain pending in Flight Timers and accessible through the contextual RADIO action. Navigation intentionally has no reminder footer. Frequencies are reference information only.

Land is a separate confirmed action. The session/FIT keeps running on the ground. START can open a second airborne period. Existing checks remain on the session elapsed-time basis during a ground stop; landing does not reset the planned check schedule. Starting a new leg requires starting its checks manually.

Finish & Save requires confirmation. Finishing while airborne records an unconfirmed closure, not a landing. Finishing before a waypoint leaves it unreached. Completion shows FIT + LOG SAVED only after both writes succeed, then exits to Garmin through `System.exit()`. The simulator returns to its idle Garmin screen; the physical launcher destination must be checked on your watch.

Discard requires confirmation and warns that the flight will not be saved. A failed native discard leaves the recording protected. Successful discard clears only the current flight log, not prior archives. It is not available for a saved activity or an unidentified old native recording.

## Alerts and problems

Alert settings offers Vibration + sound, Vibration only, Sound only and Off. UP/DOWN highlights; START saves; BACK cancels. Existing mode IDs remain compatible and persist across flights/restarts. Device/DND settings may suppress sound or vibration.

Recording failures retain manual navigation. Recovery offers a single deliberate retry only where the current native handle is known or no prior native recording could exist. Return to flight keeps a warning. Save local log only is a confirmed fallback: the log closes, but an unresolved FIT stays pending and blocks new flight/exit. Review explains why a previous recording cannot be safely identified. There is no retry loop or experimental native rebinding.

If native saving fails, the local end/landing/waypoint semantics stay frozen at the original Finish command. A later save does not invent extra airborne time in local history. Native recording may have resumed after its save failure, so inspect its duration/continuity separately. If FIT succeeds but the local log write fails, completion remains pending and retry does not save a second FIT.

Do not reset app data or start another flight over an unresolved recording. Preserve the device data for review. The app cannot prove recovery of an old finished FIT from a fresh session object.

## Next physical FR965 acceptance

1. Preserve pending data; rebuild with `scripts/build.ps1 -Release`. USB-copy only `bin/navlog-device.prg` into `GARMIN/APPS`, disconnect safely and launch.
2. Inspect the launcher icon, every screen at wrist distance/daylight and all five buttons. Confirm the larger clock/heading/countdown and radio values fit. Check touch rejection and display wake.
3. Select/cancel a plan, then confirm Start Flight once. Observe ground state and outdoor GPS fix. Record a short safe development track; inspect decoded coordinates and altitude against a known reference. Do not infer accuracy from simulator playback.
4. Test takeoff, start checks, one early and one late acknowledgement, 06:00/06:00/03:00 fixed segments, waypoint/undo and changed/unchanged radio references.
5. Land, wait on the ground, take off again and finish while airborne. Verify one activity, two airborne periods, ground time retained, no invented second landing and no invented unreached waypoint.
6. Verify alert selection, cancellation, persistence, DND effects and battery. Use a separate disposable run to confirm discard and return to the launcher.
7. Verify saved-flight reopen first. Use disposable development data for interruption/reboot/failure tests. Preserve raw FIT/checkpoints and assess continuity without assuming rebinding works.
8. Sync only a development activity to Garmin Connect; inspect sport/category, map, altitude, laps and custom fields. None of that presentation is certified by the simulator results.

## V3 display and short labels

The main display follows clock → HEADING/CLEAROFF → ACTIVE/STBY. State, route, check progress, demo warnings and button instructions are removed from navigation. Review recording/state on Flight Timers and contextual recovery screens; a running timer is not proof FIT/GPS recording succeeded. Route context is shown with ADVANCE/UNDO actions, where the target matters.

Flight Actions now displays one large selected label: ADVANCE, UNDO, LAND/TAKEOFF, ALERTS, FINISH, DISCARD or RADIO. UP/DOWN/BACK/START behaviour is unchanged. Alert selection shows one large mode at a time. Confirmation screens spell out START SAVE or START DISCARD and BACK CANCEL, and retain important landing/arrival or unsaved-FIT consequences.

Build `scripts/build.ps1 -Release`; copy only `bin/navlog-device.prg` to the watch's `GARMIN/APPS`, then disconnect safely. The existing app ID and signing key remain. Preserve pending native data before reinstalling. [V3 captures, measurement comparison and limitations](../evidence/v3/REPORT.md).
