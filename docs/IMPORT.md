# Future spreadsheet import and history export

Proposal only. No Google Sheets integration or network permission is included.

Export a single UTF-8 JSON document from a future trusted companion/importer:

```json
{
  "schemaVersion": 1,
  "flightId": "camden-return-demo",
  "name": "Camden - Goulburn Return",
  "dummyData": true,
  "legs": [
    {
      "from": "YSCN",
      "to": "YSHL",
      "headingMagneticDegrees": 135,
      "plannedAltitudeFeet": 3500,
      "plannedDistanceNm": 25.0,
      "plannedGroundspeedKnots": 100.0,
      "activeFrequencyMHz": "123.450",
      "standbyFrequencyMHz": "124.550",
      "activeStation": "Dummy active",
      "standbyStation": "Dummy standby"
    }
  ]
}
```

Use one spreadsheet row per leg, with these column names. Frequencies remain strings to preserve trailing zeros. Heading is explicitly magnetic; distance is NM; speed is knots; altitude is feet. Validate positive finite speed/distance, heading 0–359, frequency formatting, string lengths, maximum leg count, schema version and payload size. Reject missing fields and mismatched units. Do not infer operational accuracy from a syntactically valid plan. Display source/revision and require plan review before activation. Replace plans atomically only outside an active session. Keep the last known valid plan if import fails. Credentials belong in a companion service, never in watch source.

Current storage export shape is a snapshot containing `version`, `generation`, `savedUtc`, `navigation`, `timers`, `clearoff`, and `undo`. Timestamps use Unix UTC seconds, elapsed durations use seconds, groundspeeds knots, and distances NM. `navigation.checks[].ackUtc = null` represents an unacknowledged due check; `corrected = true` marks a record from an undone leg. `timers.periods` records each takeoff, landing, and elapsed airborne duration. Open periods have null landing timestamps. `navigation.corrections` records advancement corrections and estimated interruption gaps.

Future export should include the full immutable plan, device/app version, interruption uncertainty and unique event/visit IDs. It should stream or chunk long histories rather than exceed the SDK's 32 KB storage-value limit. Implement only after physical standalone testing is stable.
