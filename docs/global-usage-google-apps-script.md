# Global Usage With Google Apps Script

Dataiku Chirp can report opt-in aggregate counters to a Google Apps Script web app. The app never sends audio, transcript text, active window titles, clipboard contents, or per-dictation rows.

## Recommended Pilot Design

Use a cumulative upsert model:

1. Each laptop gets one random `installationId`.
2. The user chooses a broad team from the app dropdown.
3. The app sends cumulative totals for that install: team, sessions, total words, total local transcription minutes, estimated typing time saved, and estimated vendor spend avoided.
4. Apps Script stores one row per install in a Google Sheet.
5. The dashboard sums the rows.

This is intentionally different from event logging. With 1,000 employees, event logging can become a noisy append-only analytics pipeline. Cumulative upsert keeps the sheet around 1,000 rows and makes retrying safe because the latest row replaces the previous row for the same install.

## Why Apps Script Is Fine For A Pilot

The current Google Apps Script Workspace quotas list 100,000 URL Fetch calls per day, 6 minutes per execution, and 1,000 simultaneous executions per script. Google Sheets supports up to 10 million cells per spreadsheet. Those limits are enough for a pilot when clients sync cumulative totals every 15 minutes or less.

Use a real service and database when you need SSO-backed device identity, audit logs, admin controls, stronger secret management, high-frequency analytics, or production SLAs.

Sources:

- Google Apps Script quotas: https://developers.google.com/apps-script/guides/services/quotas
- Google Sheets 10 million cell limit: https://workspaceupdates.googleblog.com/2022/03/ten-million-cells-google-sheets.html

## Setup

1. Create a Google Sheet named `Dataiku Chirp Usage`.
2. Create a standalone Apps Script project.
3. Paste `integrations/google-apps-script/global_usage.gs`.
4. In Apps Script, open `Project Settings > Script properties`.
5. Add `SPREADSHEET_ID` with the Google Sheet ID.
6. Add `TEAM_KEY` with a long random value.
7. Run `setup` once.
8. Deploy as a web app with execute-as `Me` and access `Anyone`.
9. Build Dataiku Chirp with `DATAIKU_CHIRP_USAGE_ENDPOINT` and `DATAIKU_CHIRP_USAGE_TEAM_KEY` set.

The app UI does not expose the endpoint URL or team key. Users only choose their team and toggle aggregate sharing.

For the native Mac app to POST without Google OAuth, the Apps Script web app needs link-level access. The `TEAM_KEY` check prevents accidental public reads and writes, but it is shared-secret security rather than enterprise auth.

## Payload Shape

The app posts this kind of JSON:

```json
{
  "teamKey": "shared-secret",
  "installationId": "0F89C8A8-9F4E-4F1F-9E66-B6DA9B9963E2",
  "teamName": "Engineering",
  "appVersion": "0.2.0",
  "modelName": "Whisper large-v3 turbo",
  "sessions": 42,
  "totalWords": 9120,
  "totalTranscriptionMinutes": 73.4,
  "totalTypingHoursSaved": 6.1,
  "totalVendorCostAvoidedUSD": 0.44,
  "reportedAt": "2026-06-21T12:00:00Z"
}
```

The Apps Script response returns global totals:

```json
{
  "ok": true,
  "stats": {
    "activeInstallations": 120,
    "totalSessions": 4311,
    "totalWords": 902104,
    "totalTranscriptionMinutes": 8842.7,
    "totalTypingHoursSaved": 602.4,
    "totalVendorCostAvoidedUSD": 53.06,
    "updatedAt": "2026-06-21T12:00:00Z"
  }
}
```

## Privacy Properties

- No transcript text leaves the laptop.
- No audio leaves the laptop.
- No per-dictation event log is created.
- The team dashboard is useful without identifying the employee.
- Uninstalling or clearing app preferences can create a new install row; this is acceptable for pilot analytics.
