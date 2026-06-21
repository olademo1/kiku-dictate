const SHEET_NAME = 'Installations';
const ACTIVE_WINDOW_DAYS = 30;
const HEADERS = [
  'installationId',
  'teamName',
  'lastSeenAt',
  'appVersion',
  'modelName',
  'sessions',
  'totalWords',
  'totalTranscriptionMinutes',
  'totalTypingHoursSaved',
  'totalVendorCostAvoidedUSD'
];

function setup() {
  ensureSheet_();
}

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents || '{}');
    authorize_(payload.teamKey);

    const stats = withLock_(() => {
      const sheet = ensureSheet_();
      upsertInstallation_(sheet, payload);
      return summarize_(sheet);
    });

    return json_({ ok: true, stats });
  } catch (error) {
    return json_({ ok: false, error: String(error.message || error) });
  }
}

function doGet(e) {
  try {
    authorize_(e.parameter.teamKey);
    const stats = withLock_(() => summarize_(ensureSheet_()));

    if (e.parameter.format === 'json') {
      return json_({ ok: true, stats });
    }

    return HtmlService
      .createHtmlOutput(renderDashboard_(stats))
      .setTitle('Dataiku Chirp Global Usage');
  } catch (error) {
    return json_({ ok: false, error: String(error.message || error) });
  }
}

function authorize_(provided) {
  const expected = PropertiesService.getScriptProperties().getProperty('TEAM_KEY');
  if (!expected) {
    throw new Error('Set script property TEAM_KEY before deploying.');
  }
  if (!provided || String(provided) !== expected) {
    throw new Error('Invalid team key.');
  }
}

function spreadsheet_() {
  const spreadsheetId = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!spreadsheetId) {
    throw new Error('Set script property SPREADSHEET_ID before deploying.');
  }
  return SpreadsheetApp.openById(spreadsheetId);
}

function ensureSheet_() {
  const spreadsheet = spreadsheet_();
  let sheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(SHEET_NAME);
  }

  const current = sheet.getRange(1, 1, 1, HEADERS.length).getValues()[0];
  const needsHeader = HEADERS.some((header, index) => current[index] !== header);
  if (needsHeader) {
    sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
    sheet.setFrozenRows(1);
  }

  return sheet;
}

function upsertInstallation_(sheet, payload) {
  const installationId = String(payload.installationId || '').trim();
  if (!installationId) {
    throw new Error('Missing installationId.');
  }

  const row = [
    installationId,
    String(payload.teamName || 'Other'),
    new Date(),
    String(payload.appVersion || ''),
    String(payload.modelName || ''),
    toNumber_(payload.sessions),
    toNumber_(payload.totalWords),
    toNumber_(payload.totalTranscriptionMinutes),
    toNumber_(payload.totalTypingHoursSaved),
    toNumber_(payload.totalVendorCostAvoidedUSD)
  ];

  const values = sheet.getDataRange().getValues();
  for (let index = 1; index < values.length; index += 1) {
    if (values[index][0] === installationId) {
      sheet.getRange(index + 1, 1, 1, HEADERS.length).setValues([row]);
      return;
    }
  }

  sheet.appendRow(row);
}

function summarize_(sheet) {
  const values = sheet.getDataRange().getValues().slice(1);
  const now = Date.now();
  const activeCutoffMs = ACTIVE_WINDOW_DAYS * 24 * 60 * 60 * 1000;

  const stats = values.reduce((acc, row) => {
    if (!row[0]) return acc;

    const lastSeenAt = new Date(row[2]).getTime();
    if (!Number.isNaN(lastSeenAt) && now - lastSeenAt <= activeCutoffMs) {
      acc.activeInstallations += 1;
    }

    acc.totalSessions += toNumber_(row[5]);
    acc.totalWords += toNumber_(row[6]);
    acc.totalTranscriptionMinutes += toNumber_(row[7]);
    acc.totalTypingHoursSaved += toNumber_(row[8]);
    acc.totalVendorCostAvoidedUSD += toNumber_(row[9]);
    return acc;
  }, {
    activeInstallations: 0,
    totalSessions: 0,
    totalWords: 0,
    totalTranscriptionMinutes: 0,
    totalTypingHoursSaved: 0,
    totalVendorCostAvoidedUSD: 0,
    updatedAt: new Date().toISOString()
  });

  stats.totalSessions = Math.round(stats.totalSessions);
  stats.totalWords = Math.round(stats.totalWords);
  stats.totalTranscriptionMinutes = round_(stats.totalTranscriptionMinutes);
  stats.totalTypingHoursSaved = round_(stats.totalTypingHoursSaved);
  stats.totalVendorCostAvoidedUSD = round_(stats.totalVendorCostAvoidedUSD);
  return stats;
}

function withLock_(callback) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    return callback();
  } finally {
    lock.releaseLock();
  }
}

function toNumber_(value) {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : 0;
}

function round_(value) {
  return Math.round(value * 100) / 100;
}

function json_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}

function renderDashboard_(stats) {
  return `
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body {
        margin: 0;
        font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #f6f5ef;
        color: #111827;
      }
      main {
        max-width: 860px;
        margin: 0 auto;
        padding: 40px 24px;
      }
      h1 {
        margin: 0 0 6px;
        font-size: 32px;
      }
      p {
        margin: 0 0 24px;
        color: #5f6670;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
      }
      .card {
        background: #fffef8;
        border: 1px solid #d6d9cf;
        border-radius: 8px;
        padding: 16px;
      }
      .label {
        color: #5f6670;
        font-size: 12px;
        font-weight: 700;
      }
      .value {
        font-size: 30px;
        font-weight: 800;
        margin-top: 6px;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Dataiku Chirp Global Usage</h1>
      <p>Aggregate counters only. No transcripts or audio are collected.</p>
      <section class="grid">
        ${card_('Team words', stats.totalWords)}
        ${card_('Active installs', stats.activeInstallations)}
        ${card_('Team time saved', `${stats.totalTypingHoursSaved} hr`)}
        ${card_('Spend avoided', `$${stats.totalVendorCostAvoidedUSD.toFixed(2)}`)}
      </section>
    </main>
  </body>
</html>`;
}

function card_(label, value) {
  return `<div class="card"><div class="label">${escapeHtml_(label)}</div><div class="value">${escapeHtml_(String(value))}</div></div>`;
}

function escapeHtml_(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
