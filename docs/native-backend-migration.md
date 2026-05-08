# Rust Native Backend Migration

## Goal

Move the local API engine from Node.js to a small Rust sidecar so the desktop app can ship as a cleaner portable package.

## Current Stage

Stage 1 is a runnable compatibility skeleton. Stage 2 has moved Outlook live fetch into Rust. Stage 3 has moved the Claw Dashboard control plane into Rust:

- WinUI launches `runtime/native/outlook-mail-native.exe` first.
- Node remains a fallback if the Rust sidecar is missing.
- The Rust API opens the same SQLite database path supplied by WinUI through `DB_PATH`.
- The Rust API runs schema migrations for Outlook accounts, cached mails, tags, database maintenance tables, and Claw cache tables.

Implemented Rust endpoints:

- `GET /api/auth/check`
- `GET /api/dashboard/stats`
- `GET /api/accounts`
- `POST /api/accounts/import`
- `POST /api/accounts/import-preview`
- `POST /api/accounts/batch-delete`
- `DELETE /api/accounts/:id`
- `GET /api/tags`
- `POST /api/tags`
- `POST /api/accounts/:id/tags`
- `GET /api/mails/cached`
- `POST /api/mails/fetch` with Outlook Graph token refresh, Graph mail fetch, IMAP XOAUTH2 fallback, MIME parsing, cache writeback, and cache fallback on failure
- `POST /api/oauth/browser/start`
- `GET /api/oauth/browser/callback`
- `POST /api/oauth/browser/poll`
- `POST /api/oauth/device/start`
- `POST /api/oauth/device/poll`
- `GET /api/database/health`
- `POST /api/database/repair`
- `POST /api/database/optimize`
- `GET /api/claw/status`
- `GET /api/claw/stats`
- `POST /api/claw/auth/send-code`
- `POST /api/claw/auth/verify-code`
- `POST /api/claw/auth/refresh`
- `POST /api/claw/auth/logout`
- `GET /api/claw/mailboxes` with optional Dashboard sync
- `POST /api/claw/mailboxes`
- `POST /api/claw/mailboxes/:id/comm-settings`
- `DELETE /api/claw/mailboxes/:id`
- cached `GET /api/claw/mails`
- explicit no-op listener endpoints while the Claw Node SDK realtime layer is still unmigrated

## Package Baseline

`outlook-mail-native.exe` was about 2.8 MB before HTTP/TLS. After adding Graph OAuth/fetch, IMAP fallback, browser/device login, and Claw Dashboard operations it is about 6.5 MB.

The first Rust-sidecar preview package excludes Node and duplicate publish folders:

- folder: `dist/OutlookMailManager-RustSidecar-Preview-20260507`
- zip: `dist/OutlookMailManager-RustSidecar-Preview-20260507.zip`
- zip size during verification: about 51.5 MB

## Next Migration Steps

1. Test Outlook Graph and IMAP against real token accounts, including `outlook.com.ar` style domains.
2. Test Claw login and mailbox sync against a real Claw account.
3. Port the Claw mail transport layer. The old Node backend uses `@clawemail/node-sdk` for live mail sync, sending, reply, attachment download, and websocket listeners; Rust now returns a clear compatibility message for those paths instead of pretending they are live.
3. Remove Node fallback only after all WinUI flows work against Rust.
4. Replace remaining temporary cache-only Claw mail responses with real protocol results.
5. Keep the green package free of `node.exe`, `node_modules`, frontend source, and duplicate `publish` folders.
