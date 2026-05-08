#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use mailparse::MailHeaderMap;
use reqwest::header::{ACCEPT, AUTHORIZATION, CONTENT_TYPE, COOKIE, REFERER, SET_COOKIE};
use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process;
use std::sync::{Arc, LazyLock, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use tiny_http::{Header, Method, Request, Response, Server};
use url::Url;
#[cfg(windows)]
use windows_sys::Win32::Foundation::{CloseHandle, WAIT_OBJECT_0};
#[cfg(windows)]
use windows_sys::Win32::System::Threading::{OpenProcess, WaitForSingleObject};

#[cfg(windows)]
const SYNCHRONIZE_ACCESS: u32 = 0x0010_0000;

type SharedDb = Arc<Mutex<Connection>>;

static BROWSER_SESSIONS: LazyLock<Mutex<HashMap<String, BrowserSession>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

const DEFAULT_SCOPES: &str = "offline_access https://graph.microsoft.com/User.Read https://graph.microsoft.com/Mail.Read https://outlook.office.com/IMAP.AccessAsUser.All";
const CLAW_DASHBOARD_ORIGIN: &str = "https://claw.163.com";
const CLAW_BASE_URL: &str = "https://claw.163.com/mailserv-claw-dashboard/api/v1";
const CLAW_PUBLIC_BASE_URL: &str = "https://claw.163.com/mailserv-claw-dashboard/p/v1";
const CLAW_TOKEN_URL: &str = "https://claw.163.com/claw-api-gateway/open/v1/mail/auth/token";
const CLAW_COREMAIL_PROXY_URL: &str = "https://claw.163.com/claw-api-gateway/api/coremail/proxy";

#[derive(Clone)]
struct BrowserSession {
    client_id: String,
    verifier: String,
    redirect_uri: String,
    status: BrowserSessionStatus,
    account: Option<Value>,
    error: Option<String>,
    created_at: Instant,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum BrowserSessionStatus {
    Pending,
    Authorized,
    Error,
}

fn main() {
    let port = env::var("PORT")
        .ok()
        .and_then(|v| v.parse::<u16>().ok())
        .unwrap_or(3000);
    let db_path = resolve_db_path();
    if let Some(parent) = db_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let conn = Connection::open(&db_path).expect("open sqlite database");
    configure_database(&conn).expect("configure database");
    run_migrations(&conn).expect("run migrations");
    migrate_legacy_if_needed(&conn, &db_path);

    watch_parent_process();

    let bind = format!("127.0.0.1:{port}");
    let server = Server::http(&bind).expect("bind native api server");
    eprintln!("[READY] Rust native API running on http://{bind}");

    let db = Arc::new(Mutex::new(conn));
    for request in server.incoming_requests() {
        let db = db.clone();
        if let Err(err) = handle_request(request, db) {
            eprintln!("[ERROR] {err}");
        }
    }
}

fn resolve_db_path() -> PathBuf {
    if let Ok(raw) = env::var("DB_PATH") {
        if !raw.trim().is_empty() {
            return PathBuf::from(raw);
        }
    }

    env::current_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .join("server")
        .join("data")
        .join("outlook.db")
}

fn configure_database(conn: &Connection) -> rusqlite::Result<()> {
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "foreign_keys", "ON")?;
    Ok(())
}

fn run_migrations(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL,
          password TEXT DEFAULT '',
          client_id TEXT NOT NULL,
          refresh_token TEXT NOT NULL,
          status TEXT DEFAULT 'active' CHECK(status IN ('active','inactive','error')),
          last_synced_at DATETIME,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_email ON accounts(email);

        CREATE TABLE IF NOT EXISTS proxies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL CHECK(type IN ('socks5','http')),
          host TEXT NOT NULL,
          port INTEGER NOT NULL,
          username TEXT DEFAULT '',
          password TEXT DEFAULT '',
          is_default INTEGER DEFAULT 0,
          last_tested_at DATETIME,
          last_test_ip TEXT DEFAULT '',
          status TEXT DEFAULT 'untested' CHECK(status IN ('untested','active','failed')),
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS mail_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          mailbox TEXT NOT NULL DEFAULT 'INBOX' CHECK(mailbox IN ('INBOX','Junk')),
          mail_id TEXT DEFAULT '',
          sender TEXT DEFAULT '',
          sender_name TEXT DEFAULT '',
          subject TEXT DEFAULT '',
          text_content TEXT DEFAULT '',
          html_content TEXT DEFAULT '',
          mail_date DATETIME,
          is_read INTEGER DEFAULT 0,
          cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_mail_cache_account ON mail_cache(account_id, mailbox);
        CREATE INDEX IF NOT EXISTS idx_mail_cache_date ON mail_cache(mail_date DESC);

        CREATE TABLE IF NOT EXISTS tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          color TEXT NOT NULL DEFAULT '#3B82F6',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS account_tags (
          account_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL,
          PRIMARY KEY (account_id, tag_id),
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS claw_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL DEFAULT '',
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS claw_mailboxes (
          id TEXT PRIMARY KEY,
          email TEXT NOT NULL UNIQUE,
          prefix TEXT DEFAULT '',
          display_name TEXT DEFAULT '',
          mailbox_type TEXT DEFAULT '',
          status TEXT DEFAULT 'active',
          openclaw_status TEXT DEFAULT '',
          install_command TEXT DEFAULT '',
          auth_url TEXT DEFAULT '',
          comm_level INTEGER,
          ext_receive_type INTEGER,
          ext_send_type INTEGER,
          created_at_remote DATETIME,
          synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_claw_mailboxes_email ON claw_mailboxes(email);
        CREATE INDEX IF NOT EXISTS idx_claw_mailboxes_status ON claw_mailboxes(status);

        CREATE TABLE IF NOT EXISTS claw_mail_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          provider_mail_id TEXT NOT NULL,
          mailbox_email TEXT NOT NULL,
          sender TEXT DEFAULT '',
          sender_name TEXT DEFAULT '',
          recipients TEXT DEFAULT '',
          subject TEXT DEFAULT '',
          text_content TEXT DEFAULT '',
          html_content TEXT DEFAULT '',
          raw_json TEXT DEFAULT '',
          header_raw TEXT DEFAULT '',
          has_attachments INTEGER DEFAULT 0,
          received_at DATETIME,
          cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(mailbox_email, provider_mail_id)
        );
        CREATE INDEX IF NOT EXISTS idx_claw_mail_cache_mailbox ON claw_mail_cache(mailbox_email);
        CREATE INDEX IF NOT EXISTS idx_claw_mail_cache_date ON claw_mail_cache(received_at DESC);

        CREATE TABLE IF NOT EXISTS database_maintenance_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          details TEXT DEFAULT '',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        "#,
    )?;

    add_column_if_missing(conn, "accounts", "token_refreshed_at", "DATETIME")?;
    add_column_if_missing(conn, "accounts", "remark", "TEXT DEFAULT ''")?;
    add_column_if_missing(conn, "accounts", "marker_color", "TEXT DEFAULT ''")?;
    let _ = conn.execute_batch(
        r#"
        CREATE UNIQUE INDEX IF NOT EXISTS idx_mail_cache_identity
          ON mail_cache(account_id, mailbox, mail_id)
          WHERE mail_id IS NOT NULL AND mail_id != '';
        "#,
    );
    Ok(())
}

fn add_column_if_missing(
    conn: &Connection,
    table: &str,
    column: &str,
    definition: &str,
) -> rusqlite::Result<()> {
    let exists = table_columns(conn, table)?
        .iter()
        .any(|name| name == column);
    if !exists {
        conn.execute_batch(&format!(
            "ALTER TABLE {table} ADD COLUMN {column} {definition}"
        ))?;
    }
    Ok(())
}

fn table_columns(conn: &Connection, table: &str) -> rusqlite::Result<Vec<String>> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let columns = stmt.query_map([], |row| row.get::<_, String>(1))?.collect();
    columns
}

fn migrate_legacy_if_needed(conn: &Connection, current_db_path: &Path) {
    let current_count = count_i64(conn, "SELECT COUNT(*) FROM accounts", &[]).unwrap_or(0);
    if current_count > 0 {
        return;
    }

    let raw = env::var("LEGACY_DB_PATHS").unwrap_or_default();
    for candidate in env::split_paths(&raw) {
        if !candidate.exists() || same_path(&candidate, current_db_path) {
            continue;
        }

        let Ok(legacy) =
            Connection::open_with_flags(&candidate, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
        else {
            continue;
        };
        let Ok(legacy_count) = count_i64(&legacy, "SELECT COUNT(*) FROM accounts", &[]) else {
            continue;
        };
        if legacy_count == 0 {
            continue;
        }

        for table in ["accounts", "tags", "account_tags", "mail_cache", "proxies"] {
            let _ = copy_table(conn, &legacy, table);
        }
        eprintln!(
            "[MIGRATE] Imported {legacy_count} accounts from legacy database: {}",
            candidate.display()
        );
        break;
    }
}

fn same_path(left: &Path, right: &Path) -> bool {
    match (fs::canonicalize(left), fs::canonicalize(right)) {
        (Ok(a), Ok(b)) => a == b,
        _ => left == right,
    }
}

fn copy_table(target: &Connection, source: &Connection, table: &str) -> rusqlite::Result<()> {
    let target_columns = table_columns(target, table)?;
    let source_columns = table_columns(source, table)?;
    let columns: Vec<String> = target_columns
        .into_iter()
        .filter(|column| source_columns.contains(column))
        .collect();
    if columns.is_empty() {
        return Ok(());
    }

    let quoted = columns
        .iter()
        .map(|c| format!("\"{}\"", c.replace('"', "\"\"")))
        .collect::<Vec<_>>();
    let select_sql = format!("SELECT {} FROM {table}", quoted.join(", "));
    let insert_sql = format!(
        "INSERT OR IGNORE INTO {table} ({}) VALUES ({})",
        quoted.join(", "),
        (0..columns.len())
            .map(|_| "?")
            .collect::<Vec<_>>()
            .join(", ")
    );
    let mut select = source.prepare(&select_sql)?;
    let mut rows = select.query([])?;
    while let Some(row) = rows.next()? {
        let mut values = Vec::with_capacity(columns.len());
        for i in 0..columns.len() {
            values.push(row.get::<_, rusqlite::types::Value>(i)?);
        }
        let params = rusqlite::params_from_iter(values);
        let _ = target.execute(&insert_sql, params);
    }
    Ok(())
}

fn watch_parent_process() {
    let parent_pid = env::var("OUTLOOK_MANAGER_PARENT_PID")
        .ok()
        .and_then(|v| v.parse::<u32>().ok());
    if let Some(pid) = parent_pid {
        watch_parent_process_impl(pid);
    }
}

#[cfg(windows)]
fn watch_parent_process_impl(pid: u32) {
    thread::spawn(move || unsafe {
        let handle = OpenProcess(SYNCHRONIZE_ACCESS, 0, pid);
        if handle.is_null() {
            return;
        }
        let wait_result = WaitForSingleObject(handle, u32::MAX);
        CloseHandle(handle);
        if wait_result == WAIT_OBJECT_0 {
            process::exit(0);
        }
    });
}

#[cfg(not(windows))]
fn watch_parent_process_impl(_pid: u32) {}

fn handle_request(mut request: Request, db: SharedDb) -> Result<(), String> {
    let method = request.method().clone();
    let full_url = request.url().to_string();
    let (path, query) = parse_url(&full_url);
    let mut body = String::new();
    let _ = request.as_reader().read_to_string(&mut body);
    let json_body = if body.trim().is_empty() {
        Value::Null
    } else {
        serde_json::from_str(&body).unwrap_or(Value::Null)
    };

    if method == Method::Get && path == "/api/oauth/browser/callback" {
        let result = complete_browser_login(&db, &query);
        return respond_html(request, result.title, result.message);
    }

    let result = {
        let conn = db
            .lock()
            .map_err(|_| "database lock poisoned".to_string())?;
        dispatch(&conn, &method, &path, &query, json_body)
    };

    match result {
        Ok(data) => respond_json(
            request,
            200,
            json!({ "code": 200, "data": data, "message": "ok" }),
        ),
        Err(ApiError { code, message }) => respond_json(
            request,
            200,
            json!({ "code": code, "data": Value::Null, "message": message }),
        ),
    }
}

fn parse_url(raw: &str) -> (String, HashMap<String, String>) {
    let url = Url::parse(&format!("http://localhost{raw}")).expect("local url");
    let path = url.path().to_string();
    let query = url
        .query_pairs()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect();
    (path, query)
}

fn dispatch(
    conn: &Connection,
    method: &Method,
    path: &str,
    query: &HashMap<String, String>,
    body: Value,
) -> Result<Value, ApiError> {
    match (method, path) {
        (&Method::Get, "/api/auth/check") => Ok(json!({ "authenticated": true, "native": true })),
        (&Method::Get, "/api/dashboard/stats") => dashboard_stats(conn),
        (&Method::Get, "/api/accounts") => list_accounts(conn, query),
        (&Method::Post, "/api/accounts/import") => import_accounts(conn, body, false),
        (&Method::Post, "/api/accounts/import-preview") => import_accounts(conn, body, true),
        (&Method::Post, "/api/accounts/batch-delete") => batch_delete_accounts(conn, body),
        (&Method::Get, "/api/tags") => list_tags(conn),
        (&Method::Post, "/api/tags") => create_tag(conn, body),
        (&Method::Get, "/api/mails/cached") => cached_mails(conn, query),
        (&Method::Post, "/api/mails/fetch") => fetch_mails_live(conn, body),
        (&Method::Get, "/api/database/health") => database_health(conn),
        (&Method::Post, "/api/database/repair") => database_repair(conn, body),
        (&Method::Post, "/api/database/optimize") => database_optimize(conn),
        (&Method::Post, "/api/oauth/browser/start") => start_browser_login(body),
        (&Method::Post, "/api/oauth/browser/poll") => poll_browser_login(conn, body),
        (&Method::Post, "/api/oauth/device/start") => start_device_login(body),
        (&Method::Post, "/api/oauth/device/poll") => poll_device_login(conn, body),
        (&Method::Get, "/api/claw/status") => claw_status(conn),
        (&Method::Get, "/api/claw/stats") => claw_stats(conn),
        (&Method::Post, "/api/claw/auth/send-code") => claw_send_code(body),
        (&Method::Post, "/api/claw/auth/verify-code") => claw_verify_code(conn, body),
        (&Method::Post, "/api/claw/auth/refresh") => claw_refresh_auth(conn),
        (&Method::Post, "/api/claw/auth/logout") => claw_logout(conn),
        (&Method::Get, "/api/claw/listeners") => Ok(json!({ "items": [], "native": true })),
        (&Method::Get, "/api/claw/events") => Ok(
            json!({ "events": [], "native": true, "message": "Rust native API does not keep Claw realtime listeners yet." }),
        ),
        (&Method::Post, "/api/claw/listeners/start") => Ok(
            json!({ "started": false, "native": true, "message": "Claw realtime listener requires the Node SDK and is not migrated to Rust yet." }),
        ),
        (&Method::Post, "/api/claw/listeners/start-all") => Ok(
            json!({ "started": false, "native": true, "message": "Claw realtime listeners require the Node SDK and are not migrated to Rust yet." }),
        ),
        (&Method::Delete, "/api/claw/listeners") => Ok(json!({ "stopped": true, "native": true })),
        (&Method::Get, "/api/claw/mailboxes") => claw_mailboxes(conn, query),
        (&Method::Post, "/api/claw/mailboxes") => claw_create_mailbox(conn, body),
        (&Method::Get, "/api/claw/mails") => claw_mails(conn, query),
        _ if method == &Method::Delete && path.starts_with("/api/accounts/") => {
            delete_account(conn, path.trim_start_matches("/api/accounts/"))
        }
        _ if method == &Method::Post
            && path.starts_with("/api/accounts/")
            && path.ends_with("/tags") =>
        {
            let id = path
                .trim_start_matches("/api/accounts/")
                .trim_end_matches("/tags")
                .trim_matches('/');
            set_account_tags(conn, id, body)
        }
        _ if method == &Method::Post
            && path.starts_with("/api/accounts/")
            && path.ends_with("/marker") =>
        {
            let id = path
                .trim_start_matches("/api/accounts/")
                .trim_end_matches("/marker")
                .trim_matches('/');
            set_account_marker(conn, id, body)
        }
        _ if method == &Method::Post
            && path.starts_with("/api/claw/mailboxes/")
            && path.ends_with("/comm-settings") =>
        {
            let id = path
                .trim_start_matches("/api/claw/mailboxes/")
                .trim_end_matches("/comm-settings")
                .trim_matches('/');
            claw_update_comm_settings(conn, id, body)
        }
        _ if method == &Method::Delete && path.starts_with("/api/claw/mailboxes/") => {
            claw_delete_mailbox(conn, path.trim_start_matches("/api/claw/mailboxes/"))
        }
        _ if method == &Method::Delete && path.starts_with("/api/claw/listeners/") => {
            Ok(json!({ "stopped": true, "native": true }))
        }
        _ if method == &Method::Delete && path.starts_with("/api/claw/mails/") => {
            Ok(json!({ "deleted": false }))
        }
        _ => Err(ApiError::new(
            404,
            format!("Native API route not implemented: {method} {path}"),
        )),
    }
}

fn list_accounts(conn: &Connection, query: &HashMap<String, String>) -> Result<Value, ApiError> {
    let page = parse_query_i64(query, "page", 1).max(1);
    let page_size = parse_query_i64(query, "pageSize", 20).clamp(1, 500);
    let search = query.get("search").map(String::as_str).unwrap_or("").trim();
    let offset = (page - 1) * page_size;

    let (total, accounts) = if search.is_empty() {
        let total = count_i64(conn, "SELECT COUNT(*) FROM accounts", &[])?;
        let accounts = query_accounts(
            conn,
            "SELECT * FROM accounts ORDER BY id DESC LIMIT ? OFFSET ?",
            &[&page_size, &offset],
        )?;
        (total, accounts)
    } else {
        let pattern = format!("%{search}%");
        let total = count_i64(
            conn,
            "SELECT COUNT(*) FROM accounts WHERE email LIKE ?",
            &[&pattern],
        )?;
        let accounts = query_accounts(
            conn,
            "SELECT * FROM accounts WHERE email LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?",
            &[&pattern, &page_size, &offset],
        )?;
        (total, accounts)
    };

    Ok(json!({ "list": accounts, "total": total, "page": page, "pageSize": page_size }))
}

fn query_accounts(
    conn: &Connection,
    sql: &str,
    params: &[&dyn rusqlite::ToSql],
) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn.prepare(sql)?;
    let rows = stmt.query_map(params, |row| {
        let id: i64 = row.get("id")?;
        Ok(json!({
            "id": id,
            "email": row.get::<_, String>("email")?,
            "password": row.get::<_, Option<String>>("password")?.unwrap_or_default(),
            "client_id": row.get::<_, String>("client_id")?,
            "refresh_token": row.get::<_, String>("refresh_token")?,
            "remark": row.get::<_, Option<String>>("remark")?.unwrap_or_default(),
            "marker_color": row.get::<_, Option<String>>("marker_color")?.unwrap_or_default(),
            "status": row.get::<_, Option<String>>("status")?.unwrap_or_else(|| "active".to_string()),
            "last_synced_at": row.get::<_, Option<String>>("last_synced_at")?,
            "token_refreshed_at": row.get::<_, Option<String>>("token_refreshed_at")?,
            "created_at": row.get::<_, Option<String>>("created_at")?.unwrap_or_default(),
            "updated_at": row.get::<_, Option<String>>("updated_at")?.unwrap_or_default(),
            "tags": load_tags_for_account(conn, id).unwrap_or_default(),
        }))
    })?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)
}

fn load_tags_for_account(conn: &Connection, account_id: i64) -> rusqlite::Result<Vec<Value>> {
    let mut stmt = conn.prepare(
        "SELECT t.id, t.name, t.color, t.created_at FROM tags t JOIN account_tags at ON at.tag_id = t.id WHERE at.account_id = ? ORDER BY t.name",
    )?;
    let tags = stmt
        .query_map([account_id], |row| {
            Ok(json!({
                "id": row.get::<_, i64>(0)?,
                "name": row.get::<_, String>(1)?,
                "color": row.get::<_, String>(2)?,
                "created_at": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
            }))
        })?
        .collect();
    tags
}

fn import_accounts(conn: &Connection, body: Value, preview: bool) -> Result<Value, ApiError> {
    let content = body.get("content").and_then(Value::as_str).unwrap_or("");
    if content.trim().is_empty() {
        return Err(ApiError::new(400, "content is required"));
    }
    let separator = body
        .get("separator")
        .and_then(Value::as_str)
        .unwrap_or("----");
    let format = body
        .get("format")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect::<Vec<_>>()
        })
        .filter(|items| !items.is_empty())
        .unwrap_or_else(|| {
            vec![
                "email".into(),
                "password".into(),
                "client_id".into(),
                "refresh_token".into(),
            ]
        });

    let mut imported = 0;
    let mut skipped = 0;
    let mut errors = Vec::new();
    let mut new_items = Vec::new();
    let mut duplicates = Vec::new();

    for (index, line) in content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .enumerate()
    {
        let record = parse_account_record(line, separator, &format);
        if let Some(error) = validate_account_record(&record, index + 1) {
            errors.push(error);
            continue;
        }
        let email = record.get("email").cloned().unwrap_or_default();
        let exists = conn
            .query_row(
                "SELECT id FROM accounts WHERE email = ?",
                [email.as_str()],
                |row| row.get::<_, i64>(0),
            )
            .optional()?
            .is_some();
        if preview {
            let item = json!({
                "line": index + 1,
                "email": email,
                "password": record.get("password").cloned().unwrap_or_default(),
                "client_id": record.get("client_id").cloned().unwrap_or_default(),
                "refresh_token": record.get("refresh_token").cloned().unwrap_or_default(),
            });
            if exists {
                duplicates.push(item);
            } else {
                new_items.push(item);
            }
            continue;
        }
        if exists {
            skipped += 1;
            continue;
        }
        conn.execute(
            "INSERT OR IGNORE INTO accounts (email, password, client_id, refresh_token) VALUES (?, ?, ?, ?)",
            params![
                email,
                record.get("password").cloned().unwrap_or_default(),
                record.get("client_id").cloned().unwrap_or_default(),
                record.get("refresh_token").cloned().unwrap_or_default()
            ],
        )?;
        imported += 1;
    }

    if preview {
        Ok(json!({ "newItems": new_items, "duplicates": duplicates, "errors": errors }))
    } else {
        Ok(json!({ "imported": imported, "skipped": skipped, "errors": errors }))
    }
}

fn parse_account_record(line: &str, separator: &str, format: &[String]) -> HashMap<String, String> {
    let parts: Vec<&str> = line.split(separator).collect();
    let mut record = HashMap::new();
    for (index, field) in format.iter().enumerate() {
        record.insert(
            field.to_string(),
            parts.get(index).copied().unwrap_or("").trim().to_string(),
        );
    }

    let client_id_looks_like_token = record
        .get("client_id")
        .map(|v| v.starts_with("M."))
        .unwrap_or(false);
    let refresh_looks_like_client_id = record
        .get("refresh_token")
        .map(|v| is_client_id(v))
        .unwrap_or(false);
    if client_id_looks_like_token && refresh_looks_like_client_id {
        let original = record.get("client_id").cloned().unwrap_or_default();
        let refresh = record.get("refresh_token").cloned().unwrap_or_default();
        record.insert("client_id".into(), refresh);
        record.insert("refresh_token".into(), original);
    }
    record
}

fn validate_account_record(record: &HashMap<String, String>, line: usize) -> Option<String> {
    let email = record.get("email").map(String::as_str).unwrap_or("");
    let client_id = record.get("client_id").map(String::as_str).unwrap_or("");
    let refresh_token = record
        .get("refresh_token")
        .map(String::as_str)
        .unwrap_or("");
    if email.is_empty() || client_id.is_empty() || refresh_token.is_empty() {
        return Some(format!("Line {line}: missing required fields"));
    }
    if !email.contains('@')
        || !email
            .rsplit_once('.')
            .map(|(_, tld)| !tld.is_empty())
            .unwrap_or(false)
    {
        return Some(format!("Line {line}: invalid email"));
    }
    if !is_client_id(client_id) {
        return Some(format!("Line {line}: invalid client_id"));
    }
    if !refresh_token.starts_with("M.") {
        return Some(format!("Line {line}: invalid refresh_token"));
    }
    None
}

fn is_client_id(value: &str) -> bool {
    value.len() == 36 && value.chars().all(|ch| ch.is_ascii_hexdigit() || ch == '-')
}

fn delete_account(conn: &Connection, id_raw: &str) -> Result<Value, ApiError> {
    let id = id_raw
        .parse::<i64>()
        .map_err(|_| ApiError::new(400, "invalid account id"))?;
    let changes = conn.execute("DELETE FROM accounts WHERE id = ?", [id])?;
    if changes == 0 {
        Err(ApiError::new(404, "Account not found"))
    } else {
        Ok(json!({ "deleted": true }))
    }
}

fn batch_delete_accounts(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let ids: Vec<i64> = body
        .get("ids")
        .and_then(Value::as_array)
        .map(|items| items.iter().filter_map(Value::as_i64).collect())
        .unwrap_or_default();
    if ids.is_empty() {
        return Err(ApiError::new(400, "ids must be a non-empty array"));
    }
    let placeholders = ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
    let sql = format!("DELETE FROM accounts WHERE id IN ({placeholders})");
    let deleted = conn.execute(&sql, rusqlite::params_from_iter(ids))?;
    Ok(json!({ "deleted": deleted }))
}

fn list_tags(conn: &Connection) -> Result<Value, ApiError> {
    let mut stmt = conn.prepare("SELECT id, name, color, created_at FROM tags ORDER BY name")?;
    let tags = stmt
        .query_map([], |row| {
            Ok(json!({
                "id": row.get::<_, i64>(0)?,
                "name": row.get::<_, String>(1)?,
                "color": row.get::<_, String>(2)?,
                "created_at": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
            }))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(json!(tags))
}

fn create_tag(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let name = body
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    if name.is_empty() {
        return Err(ApiError::new(400, "name is required"));
    }
    let color = body
        .get("color")
        .and_then(Value::as_str)
        .unwrap_or("#292827");
    conn.execute(
        "INSERT OR IGNORE INTO tags (name, color) VALUES (?, ?)",
        params![name, color],
    )?;
    let tag = conn.query_row(
        "SELECT id, name, color, created_at FROM tags WHERE name = ?",
        [name],
        |row| {
            Ok(json!({
                "id": row.get::<_, i64>(0)?,
                "name": row.get::<_, String>(1)?,
                "color": row.get::<_, String>(2)?,
                "created_at": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
            }))
        },
    )?;
    Ok(tag)
}

fn set_account_tags(conn: &Connection, id_raw: &str, body: Value) -> Result<Value, ApiError> {
    let account_id = id_raw
        .parse::<i64>()
        .map_err(|_| ApiError::new(400, "invalid account id"))?;
    let tag_ids: Vec<i64> = body
        .get("tag_ids")
        .or_else(|| body.get("tagIds"))
        .and_then(Value::as_array)
        .map(|items| items.iter().filter_map(Value::as_i64).collect())
        .unwrap_or_default();
    conn.execute(
        "DELETE FROM account_tags WHERE account_id = ?",
        [account_id],
    )?;
    for tag_id in &tag_ids {
        conn.execute(
            "INSERT OR IGNORE INTO account_tags (account_id, tag_id) VALUES (?, ?)",
            params![account_id, tag_id],
        )?;
    }
    Ok(json!({ "account_id": account_id, "tag_ids": tag_ids }))
}

fn set_account_marker(conn: &Connection, id_raw: &str, body: Value) -> Result<Value, ApiError> {
    let account_id = id_raw
        .parse::<i64>()
        .map_err(|_| ApiError::new(400, "invalid account id"))?;
    let color = body
        .get("color")
        .or_else(|| body.get("marker_color"))
        .or_else(|| body.get("markerColor"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    if !color.is_empty() && !is_hex_color(color) {
        return Err(ApiError::new(400, "invalid marker color"));
    }

    let changes = conn.execute(
        "UPDATE accounts SET marker_color = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        params![color, account_id],
    )?;
    if changes == 0 {
        return Err(ApiError::new(404, "Account not found"));
    }

    Ok(json!({ "account_id": account_id, "marker_color": color }))
}

fn is_hex_color(value: &str) -> bool {
    let hex = value.strip_prefix('#').unwrap_or(value);
    hex.len() == 6 && hex.chars().all(|ch| ch.is_ascii_hexdigit())
}

fn dashboard_stats(conn: &Connection) -> Result<Value, ApiError> {
    let total_accounts = count_i64(conn, "SELECT COUNT(*) FROM accounts", &[])?;
    let active_accounts = count_i64(
        conn,
        "SELECT COUNT(*) FROM accounts WHERE status = 'active'",
        &[],
    )?;
    let total_inbox_mails = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE mailbox = 'INBOX'",
        &[],
    )?;
    let total_junk_mails = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE mailbox = 'Junk'",
        &[],
    )?;
    let total_proxies = count_i64(conn, "SELECT COUNT(*) FROM proxies", &[]).unwrap_or(0);
    let active_proxies = count_i64(
        conn,
        "SELECT COUNT(*) FROM proxies WHERE status = 'active'",
        &[],
    )
    .unwrap_or(0);
    let error_accounts = count_i64(
        conn,
        "SELECT COUNT(*) FROM accounts WHERE status = 'error'",
        &[],
    )?;
    let unused_accounts = count_i64(
        conn,
        "SELECT COUNT(*) FROM accounts WHERE token_refreshed_at IS NULL",
        &[],
    )?;
    let recent_mails = recent_mails(conn, 10)?;
    let account_stats = account_stats(conn)?;
    Ok(json!({
        "totalAccounts": total_accounts,
        "activeAccounts": active_accounts,
        "totalInboxMails": total_inbox_mails,
        "totalJunkMails": total_junk_mails,
        "totalProxies": total_proxies,
        "activeProxies": active_proxies,
        "recentMails": recent_mails,
        "accountStats": account_stats,
        "expiringTokens": 0,
        "errorAccounts": error_accounts,
        "unusedAccounts": unused_accounts
    }))
}

fn cached_mails(conn: &Connection, query: &HashMap<String, String>) -> Result<Value, ApiError> {
    let account_id = parse_query_i64(query, "account_id", 0);
    if account_id <= 0 {
        return Err(ApiError::new(400, "account_id is required"));
    }
    let mailbox = query.get("mailbox").map(String::as_str).unwrap_or("INBOX");
    let page = parse_query_i64(query, "page", 1).max(1);
    let page_size = parse_query_i64(query, "pageSize", 50).clamp(1, 500);
    let offset = (page - 1) * page_size;
    let total = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE account_id = ? AND mailbox = ?",
        &[&account_id, &mailbox],
    )?;
    let mails = query_mails(
        conn,
        "SELECT * FROM mail_cache WHERE account_id = ? AND mailbox = ? ORDER BY mail_date DESC LIMIT ? OFFSET ?",
        &[&account_id, &mailbox, &page_size, &offset],
    )?;
    Ok(json!({ "list": mails, "total": total, "page": page, "pageSize": page_size }))
}

fn fetch_mails_live(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let account_id = body
        .get("account_id")
        .or_else(|| body.get("accountId"))
        .and_then(Value::as_i64)
        .unwrap_or(0);
    if account_id <= 0 {
        return Err(ApiError::new(400, "account_id is required"));
    }
    let mailbox = body
        .get("mailbox")
        .and_then(Value::as_str)
        .unwrap_or("INBOX");
    let top = body
        .get("top")
        .and_then(Value::as_i64)
        .unwrap_or(50)
        .clamp(1, 200);

    match fetch_graph_for_account(conn, account_id, mailbox, top) {
        Ok(result) => Ok(result),
        Err(graph_err) => match fetch_imap_for_account(conn, account_id, mailbox, top) {
            Ok(mut result) => {
                if let Some(object) = result.as_object_mut() {
                    object.insert(
                        "graphWarning".to_string(),
                        json!(friendly_graph_warning(&graph_err.message)),
                    );
                    let cached = object
                        .get("cached")
                        .and_then(Value::as_bool)
                        .unwrap_or(false);
                    let mail_count = object
                        .get("mails")
                        .and_then(Value::as_array)
                        .map(|items| items.len())
                        .unwrap_or(0);
                    if (cached || mail_count == 0) && !object.contains_key("warning") {
                        object.insert(
                            "warning".to_string(),
                            json!(friendly_graph_warning(&graph_err.message)),
                        );
                    }
                }
                Ok(result)
            }
            Err(imap_err) => {
                let cached = query_mails(
                conn,
                "SELECT * FROM mail_cache WHERE account_id = ? AND mailbox = ? ORDER BY mail_date DESC LIMIT ?",
                &[&account_id, &mailbox, &top],
            )?;
                if !cached.is_empty() {
                    let total = count_i64(
                        conn,
                        "SELECT COUNT(*) FROM mail_cache WHERE account_id = ? AND mailbox = ?",
                        &[&account_id, &mailbox],
                    )?;
                    return Ok(json!({
                        "mails": cached,
                        "total": total,
                        "protocol": "imap",
                        "cached": true,
                        "warning": format!("Rust live fetch failed, served cached mails. Graph: {}; IMAP: {}", graph_err.message, imap_err.message)
                    }));
                }

                let _ = conn.execute("UPDATE accounts SET status = 'error', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [account_id]);
                Err(ApiError::new(
                    500,
                    format!(
                        "Both Rust Graph and IMAP failed. Graph: {}; IMAP: {}",
                        graph_err.message, imap_err.message
                    ),
                ))
            }
        },
    }
}

fn friendly_graph_warning(message: &str) -> String {
    if message.contains("Graph API fetch failed: 401")
        || message.contains("Graph token refresh failed: 401")
        || message.contains("Graph token refresh failed: 400")
    {
        return "Graph 权限不可用，已切换到 IMAP 或本地缓存。若需要 Graph 实时收件，请用浏览器授权重新登录。".to_string();
    }
    format!("Graph 不可用，已切换到 IMAP 或本地缓存：{message}")
}

fn fetch_graph_for_account(
    conn: &Connection,
    account_id: i64,
    mailbox: &str,
    top: i64,
) -> Result<Value, ApiError> {
    let account =
        load_account(conn, account_id)?.ok_or_else(|| ApiError::new(404, "Account not found"))?;
    let token = refresh_graph_token(&account.client_id, &account.refresh_token)?;

    let new_refresh_token = token
        .get("refresh_token")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or(&account.refresh_token);
    conn.execute(
        "UPDATE accounts SET refresh_token = ?, token_refreshed_at = CURRENT_TIMESTAMP, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        params![new_refresh_token, account_id],
    )?;

    let access_token = token
        .get("access_token")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ApiError::new(500, "Microsoft token response did not include access_token")
        })?;
    let mails = fetch_graph_mails(access_token, mailbox, top)?;
    if !mails.is_empty() {
        upsert_mails(conn, account_id, mailbox, &mails)?;
    }
    conn.execute("UPDATE accounts SET last_synced_at = CURRENT_TIMESTAMP, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [account_id])?;

    let cached_after_fetch = query_mails(
        conn,
        "SELECT * FROM mail_cache WHERE account_id = ? AND mailbox = ? ORDER BY mail_date DESC LIMIT ?",
        &[&account_id, &mailbox, &top],
    )?;
    let total_after_fetch = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE account_id = ? AND mailbox = ?",
        &[&account_id, &mailbox],
    )?;

    if mails.is_empty() && !cached_after_fetch.is_empty() {
        return Ok(
            json!({ "mails": cached_after_fetch, "total": total_after_fetch, "protocol": "graph", "cached": true }),
        );
    }

    Ok(
        json!({ "mails": cached_after_fetch, "total": total_after_fetch, "protocol": "graph", "cached": false }),
    )
}

#[derive(Debug)]
struct AccountRecord {
    email: String,
    client_id: String,
    refresh_token: String,
}

fn load_account(conn: &Connection, account_id: i64) -> Result<Option<AccountRecord>, ApiError> {
    conn.query_row(
        "SELECT email, client_id, refresh_token FROM accounts WHERE id = ?",
        [account_id],
        |row| {
            Ok(AccountRecord {
                email: row.get(0)?,
                client_id: row.get(1)?,
                refresh_token: row.get(2)?,
            })
        },
    )
    .optional()
    .map_err(ApiError::from)
}

fn fetch_imap_for_account(
    conn: &Connection,
    account_id: i64,
    mailbox: &str,
    top: i64,
) -> Result<Value, ApiError> {
    let account =
        load_account(conn, account_id)?.ok_or_else(|| ApiError::new(404, "Account not found"))?;
    let mut candidates = vec![account.email.clone()];
    if let Ok(profile) = resolve_profile_email_for_imap(&account) {
        if !candidates
            .iter()
            .any(|item| item.eq_ignore_ascii_case(&profile))
        {
            candidates.insert(0, profile);
        }
    }
    let token = refresh_imap_token(&account.client_id, &account.refresh_token)?;
    let new_refresh_token = token
        .get("refresh_token")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or(&account.refresh_token);
    conn.execute(
        "UPDATE accounts SET refresh_token = ?, token_refreshed_at = CURRENT_TIMESTAMP, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        params![new_refresh_token, account_id],
    )?;

    let access_token = token
        .get("access_token")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ApiError::new(500, "Microsoft token response did not include access_token")
        })?;

    let mut last_error = None;
    let mut used_login = account.email.clone();
    let mut mails = Vec::new();
    for candidate in candidates {
        match fetch_imap_mails(&candidate, access_token, mailbox, top) {
            Ok(next) => {
                used_login = candidate;
                mails = next;
                last_error = None;
                break;
            }
            Err(err) => last_error = Some(err),
        }
    }
    if let Some(err) = last_error {
        return Err(err);
    }
    if !mails.is_empty() {
        upsert_mails(conn, account_id, mailbox, &mails)?;
    }
    conn.execute("UPDATE accounts SET last_synced_at = CURRENT_TIMESTAMP, status = 'active', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [account_id])?;

    let cached_after_fetch = query_mails(
        conn,
        "SELECT * FROM mail_cache WHERE account_id = ? AND mailbox = ? ORDER BY mail_date DESC LIMIT ?",
        &[&account_id, &mailbox, &top],
    )?;
    let total_after_fetch = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE account_id = ? AND mailbox = ?",
        &[&account_id, &mailbox],
    )?;

    if mails.is_empty() && !cached_after_fetch.is_empty() {
        return Ok(json!({
            "mails": cached_after_fetch,
            "total": total_after_fetch,
            "protocol": "imap",
            "cached": true,
            "login": used_login,
            "warning": format!("IMAP 实时收件暂未返回新邮件，已显示 {used_login} 的本地缓存。")
        }));
    }

    Ok(
        json!({ "mails": cached_after_fetch, "total": total_after_fetch, "protocol": "imap", "cached": false, "login": used_login }),
    )
}

fn resolve_profile_email_for_imap(account: &AccountRecord) -> Result<String, ApiError> {
    let token = refresh_graph_token(&account.client_id, &account.refresh_token)?;
    let access_token = token
        .get("access_token")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ApiError::new(500, "Microsoft token response did not include access_token")
        })?;
    get_profile_email(access_token)
}

fn refresh_imap_token(client_id: &str, refresh_token: &str) -> Result<Value, ApiError> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id),
            ("grant_type", "refresh_token"),
            ("refresh_token", refresh_token),
            (
                "scope",
                "offline_access https://outlook.office.com/IMAP.AccessAsUser.All",
            ),
        ])
        .send()
        .map_err(|err| ApiError::new(500, format!("IMAP token refresh failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!("IMAP token refresh failed: {} - {}", status.as_u16(), text),
        ));
    }
    serde_json::from_str(&text)
        .map_err(|err| ApiError::new(500, format!("parse IMAP token response failed: {err}")))
}

fn fetch_imap_mails(
    email: &str,
    access_token: &str,
    mailbox: &str,
    top: i64,
) -> Result<Vec<Value>, ApiError> {
    let tcp = TcpStream::connect(("outlook.office365.com", 993))
        .map_err(|err| ApiError::new(500, format!("IMAP TCP connect failed: {err}")))?;
    tcp.set_read_timeout(Some(Duration::from_secs(45))).ok();
    tcp.set_write_timeout(Some(Duration::from_secs(20))).ok();
    let connector = native_tls::TlsConnector::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .map_err(|err| ApiError::new(500, format!("IMAP TLS connector failed: {err}")))?;
    let tls = connector
        .connect("outlook.office365.com", tcp)
        .map_err(|err| ApiError::new(500, format!("IMAP TLS connect failed: {err}")))?;
    let mut reader = BufReader::new(tls);

    let greeting = read_imap_line(&mut reader)?;
    if !greeting.starts_with("* OK") {
        return Err(ApiError::new(500, format!("IMAP bad greeting: {greeting}")));
    }

    imap_authenticate_xoauth2(&mut reader, email, access_token)?;
    let select_lines = imap_command(
        &mut reader,
        "A002",
        &format!("SELECT {}", quote_imap_mailbox(mailbox)),
    )?;
    if !tag_ok(&select_lines, "A002") {
        return Err(ApiError::new(
            500,
            format!("IMAP SELECT failed: {}", select_lines.join(" | ")),
        ));
    }

    let search_lines = imap_command(&mut reader, "A003", "UID SEARCH ALL")?;
    let uids = parse_search_uids(&search_lines);
    let selected = uids
        .into_iter()
        .rev()
        .take(top.max(0) as usize)
        .collect::<Vec<_>>();

    let mut mails = Vec::new();
    for (index, uid) in selected.into_iter().enumerate() {
        if let Some(raw) = imap_fetch_body(&mut reader, 4 + index, uid)? {
            mails.push(parse_imap_mail(email, mailbox, uid, &raw));
        }
    }

    let _ = imap_command(&mut reader, "AZ99", "LOGOUT");
    Ok(mails)
}

fn imap_authenticate_xoauth2<R>(
    reader: &mut BufReader<R>,
    email: &str,
    access_token: &str,
) -> Result<(), ApiError>
where
    R: Read + Write,
{
    reader
        .get_mut()
        .write_all(b"A001 AUTHENTICATE XOAUTH2\r\n")
        .map_err(|err| ApiError::new(500, format!("IMAP AUTH write failed: {err}")))?;
    reader.get_mut().flush().ok();
    let line = read_imap_line(reader)?;
    if !line.starts_with('+') {
        return Err(ApiError::new(
            500,
            format!("IMAP AUTH did not request XOAUTH2 data: {line}"),
        ));
    }
    let auth = format!("user={email}\x01auth=Bearer {access_token}\x01\x01");
    let encoded = base64_url_standard(auth.as_bytes());
    reader
        .get_mut()
        .write_all(format!("{encoded}\r\n").as_bytes())
        .map_err(|err| ApiError::new(500, format!("IMAP AUTH data write failed: {err}")))?;
    reader.get_mut().flush().ok();
    let lines = read_imap_response(reader, "A001")?;
    if tag_ok(&lines, "A001") {
        Ok(())
    } else {
        Err(ApiError::new(
            500,
            format!("IMAP AUTH failed: {}", lines.join(" | ")),
        ))
    }
}

fn imap_command<R>(
    reader: &mut BufReader<R>,
    tag: &str,
    command: &str,
) -> Result<Vec<String>, ApiError>
where
    R: Read + Write,
{
    reader
        .get_mut()
        .write_all(format!("{tag} {command}\r\n").as_bytes())
        .map_err(|err| ApiError::new(500, format!("IMAP command write failed: {err}")))?;
    reader.get_mut().flush().ok();
    read_imap_response(reader, tag)
}

fn imap_fetch_body<R>(
    reader: &mut BufReader<R>,
    tag_index: usize,
    uid: u64,
) -> Result<Option<Vec<u8>>, ApiError>
where
    R: Read + Write,
{
    let tag = format!("A{tag_index:03}");
    reader
        .get_mut()
        .write_all(format!("{tag} UID FETCH {uid} (BODY.PEEK[])\r\n").as_bytes())
        .map_err(|err| ApiError::new(500, format!("IMAP FETCH write failed: {err}")))?;
    reader.get_mut().flush().ok();

    let mut raw_body = None;
    loop {
        let line = read_imap_line(reader)?;
        if line.starts_with(&tag) {
            if !line.starts_with(&format!("{tag} OK")) {
                return Err(ApiError::new(
                    500,
                    format!("IMAP FETCH failed for UID {uid}: {line}"),
                ));
            }
            break;
        }

        if let Some(size) = parse_imap_literal_size(&line) {
            let mut bytes = vec![0u8; size];
            reader
                .read_exact(&mut bytes)
                .map_err(|err| ApiError::new(500, format!("IMAP literal read failed: {err}")))?;
            raw_body = Some(bytes);
        }
    }
    Ok(raw_body)
}

fn read_imap_response<R>(reader: &mut BufReader<R>, tag: &str) -> Result<Vec<String>, ApiError>
where
    R: Read,
{
    let mut lines = Vec::new();
    loop {
        let line = read_imap_line(reader)?;
        let done = line.starts_with(tag);
        lines.push(line);
        if done {
            return Ok(lines);
        }
    }
}

fn read_imap_line<R>(reader: &mut BufReader<R>) -> Result<String, ApiError>
where
    R: Read,
{
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|err| ApiError::new(500, format!("IMAP read failed: {err}")))?;
    Ok(line.trim_end_matches(['\r', '\n']).to_string())
}

fn tag_ok(lines: &[String], tag: &str) -> bool {
    lines
        .iter()
        .any(|line| line.starts_with(&format!("{tag} OK")))
}

fn parse_search_uids(lines: &[String]) -> Vec<u64> {
    lines
        .iter()
        .find(|line| line.starts_with("* SEARCH"))
        .map(|line| {
            line.split_whitespace()
                .skip(2)
                .filter_map(|part| part.parse::<u64>().ok())
                .collect()
        })
        .unwrap_or_default()
}

fn parse_imap_literal_size(line: &str) -> Option<usize> {
    let start = line.rfind('{')?;
    let end = line[start..].find('}')? + start;
    line[(start + 1)..end].parse::<usize>().ok()
}

fn quote_imap_mailbox(mailbox: &str) -> String {
    let escaped = mailbox.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

fn parse_imap_mail(email: &str, mailbox: &str, uid: u64, raw: &[u8]) -> Value {
    match mailparse::parse_mail(raw) {
        Ok(parsed) => {
            let subject = parsed
                .headers
                .get_first_value("Subject")
                .unwrap_or_default();
            let from = parsed.headers.get_first_value("From").unwrap_or_default();
            let date = parsed.headers.get_first_value("Date").unwrap_or_default();
            let (mut text, html) = collect_mail_bodies(&parsed);
            if text.trim().is_empty() && !html.trim().is_empty() {
                text = html_to_text(&html);
            }
            json!({
                "mail_id": format!("imap:{}:{}:{}", email.to_lowercase(), mailbox, uid),
                "sender": extract_email_address(&from),
                "sender_name": extract_sender_name(&from),
                "subject": subject,
                "text_content": text,
                "html_content": html,
                "mail_date": date,
            })
        }
        Err(_) => json!({
            "mail_id": format!("imap:{}:{}:{}", email.to_lowercase(), mailbox, uid),
            "sender": "",
            "sender_name": "",
            "subject": "(无法解析邮件)",
            "text_content": String::from_utf8_lossy(raw).chars().take(2000).collect::<String>(),
            "html_content": "",
            "mail_date": "",
        }),
    }
}

fn collect_mail_bodies(mail: &mailparse::ParsedMail<'_>) -> (String, String) {
    if mail.subparts.is_empty() {
        let mimetype = mail.ctype.mimetype.to_ascii_lowercase();
        let body = mail.get_body().unwrap_or_default();
        if mimetype == "text/html" {
            return (String::new(), body);
        }
        if mimetype == "text/plain" {
            return (body, String::new());
        }
        return (String::new(), String::new());
    }

    let mut text = String::new();
    let mut html = String::new();
    for part in &mail.subparts {
        let (part_text, part_html) = collect_mail_bodies(part);
        if text.is_empty() && !part_text.is_empty() {
            text = part_text;
        }
        if html.is_empty() && !part_html.is_empty() {
            html = part_html;
        }
    }
    (text, html)
}

fn html_to_text(html: &str) -> String {
    let without_style = remove_html_block(html, "style");
    let sanitized = remove_html_block(&without_style, "script");
    let mut output = String::with_capacity(sanitized.len());
    let mut in_tag = false;
    let mut in_entity = false;
    let mut entity = String::new();
    for ch in sanitized.chars() {
        match ch {
            '<' => {
                in_tag = true;
                output.push(' ');
            }
            '>' => in_tag = false,
            '&' if !in_tag => {
                in_entity = true;
                entity.clear();
            }
            ';' if in_entity => {
                in_entity = false;
                output.push_str(match entity.as_str() {
                    "nbsp" => " ",
                    "amp" => "&",
                    "lt" => "<",
                    "gt" => ">",
                    "quot" => "\"",
                    "#39" => "'",
                    _ => " ",
                });
            }
            _ if in_tag => {}
            _ if in_entity => entity.push(ch),
            _ => output.push(ch),
        }
    }
    output
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(4000)
        .collect()
}

fn remove_html_block(input: &str, tag: &str) -> String {
    let lower = input.to_ascii_lowercase();
    let start_pattern = format!("<{tag}");
    let end_pattern = format!("</{tag}>");
    let mut output = String::with_capacity(input.len());
    let mut pos = 0;

    while let Some(relative_start) = lower[pos..].find(&start_pattern) {
        let start = pos + relative_start;
        output.push_str(&input[pos..start]);
        let Some(relative_end) = lower[start..].find(&end_pattern) else {
            pos = input.len();
            break;
        };
        pos = start + relative_end + end_pattern.len();
    }

    output.push_str(&input[pos..]);
    output
}

fn extract_email_address(from: &str) -> String {
    if let (Some(start), Some(end)) = (from.rfind('<'), from.rfind('>')) {
        if end > start {
            return from[(start + 1)..end].trim().to_string();
        }
    }
    from.trim().trim_matches('"').to_string()
}

fn extract_sender_name(from: &str) -> String {
    if let Some(start) = from.rfind('<') {
        return from[..start].trim().trim_matches('"').to_string();
    }
    String::new()
}

fn base64_url_standard(bytes: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.encode(bytes)
}

fn refresh_graph_token(client_id: &str, refresh_token: &str) -> Result<Value, ApiError> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let scopes = [
        DEFAULT_SCOPES,
        "https://graph.microsoft.com/.default offline_access",
    ];
    let mut last_error = String::new();
    for scope in scopes {
        let response = client
            .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            .form(&[
                ("client_id", client_id),
                ("grant_type", "refresh_token"),
                ("refresh_token", refresh_token),
                ("scope", scope),
            ])
            .send()
            .map_err(|err| ApiError::new(500, format!("OAuth token refresh failed: {err}")))?;
        let status = response.status();
        let text = response.text().unwrap_or_default();
        if status.is_success() {
            return serde_json::from_str(&text)
                .map_err(|err| ApiError::new(500, format!("parse token response failed: {err}")));
        }
        last_error = format!("{} - {}", status.as_u16(), text);
    }
    Err(ApiError::new(
        500,
        format!("OAuth token refresh failed: {last_error}"),
    ))
}

fn fetch_graph_mails(access_token: &str, mailbox: &str, top: i64) -> Result<Vec<Value>, ApiError> {
    let folder = if mailbox.eq_ignore_ascii_case("Junk") {
        "junkemail"
    } else {
        "inbox"
    };
    let url =
        format!("https://graph.microsoft.com/v1.0/me/mailFolders/{folder}/messages?$top={top}");
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(45))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .get(url)
        .bearer_auth(access_token)
        .header("Content-Type", "application/json")
        .send()
        .map_err(|err| ApiError::new(500, format!("Graph API fetch failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!("Graph API fetch failed: {} - {}", status.as_u16(), text),
        ));
    }

    let data: Value = serde_json::from_str(&text)
        .map_err(|err| ApiError::new(500, format!("parse Graph response failed: {err}")))?;
    let mails = data
        .get("value")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|item| {
                    let from = item.get("from").and_then(|v| v.get("emailAddress"));
                    json!({
                        "mail_id": item.get("id").and_then(Value::as_str).unwrap_or_default(),
                        "sender": from.and_then(|v| v.get("address")).and_then(Value::as_str).unwrap_or_default(),
                        "sender_name": from.and_then(|v| v.get("name")).and_then(Value::as_str).unwrap_or_default(),
                        "subject": item.get("subject").and_then(Value::as_str).unwrap_or_default(),
                        "text_content": item.get("bodyPreview").and_then(Value::as_str).unwrap_or_default(),
                        "html_content": item.get("body").and_then(|v| v.get("content")).and_then(Value::as_str).unwrap_or_default(),
                        "mail_date": item
                            .get("createdDateTime")
                            .or_else(|| item.get("receivedDateTime"))
                            .and_then(Value::as_str)
                            .unwrap_or_default(),
                    })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    Ok(mails)
}

fn upsert_mails(
    conn: &Connection,
    account_id: i64,
    mailbox: &str,
    mails: &[Value],
) -> Result<(), ApiError> {
    for mail in mails {
        let mail_id = mail
            .get("mail_id")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim();
        let sender = mail.get("sender").and_then(Value::as_str).unwrap_or("");
        let sender_name = mail
            .get("sender_name")
            .and_then(Value::as_str)
            .unwrap_or("");
        let subject = mail.get("subject").and_then(Value::as_str).unwrap_or("");
        let text_content = mail
            .get("text_content")
            .and_then(Value::as_str)
            .unwrap_or("");
        let html_content = mail
            .get("html_content")
            .and_then(Value::as_str)
            .unwrap_or("");
        let mail_date = mail.get("mail_date").and_then(Value::as_str).unwrap_or("");

        let existing = if mail_id.is_empty() {
            None
        } else {
            conn.query_row(
                "SELECT id FROM mail_cache WHERE account_id = ? AND mailbox = ? AND mail_id = ? LIMIT 1",
                params![account_id, mailbox, mail_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()?
        };

        if let Some(id) = existing {
            conn.execute(
                r#"
                UPDATE mail_cache
                SET sender = ?, sender_name = ?, subject = ?, text_content = ?, html_content = ?, mail_date = ?, cached_at = CURRENT_TIMESTAMP
                WHERE id = ?
                "#,
                params![sender, sender_name, subject, text_content, html_content, mail_date, id],
            )?;
        } else {
            conn.execute(
                r#"
                INSERT INTO mail_cache (account_id, mailbox, mail_id, sender, sender_name, subject, text_content, html_content, mail_date)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                "#,
                params![account_id, mailbox, mail_id, sender, sender_name, subject, text_content, html_content, mail_date],
            )?;
        }
    }
    Ok(())
}

fn start_browser_login(body: Value) -> Result<Value, ApiError> {
    prune_browser_sessions();
    let client_id = body
        .get("client_id")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    let redirect_uri = body
        .get("redirect_uri")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    if !is_client_id(client_id) {
        return Err(ApiError::new(400, "client_id must be a valid UUID"));
    }
    if !is_local_browser_callback(redirect_uri) {
        return Err(ApiError::new(
            400,
            "redirect_uri must be the local browser callback URL",
        ));
    }

    let state = random_url_token(24)?;
    let verifier = random_url_token(48)?;
    let challenge = pkce_challenge(&verifier);
    BROWSER_SESSIONS
        .lock()
        .map_err(|_| ApiError::new(500, "browser session lock poisoned"))?
        .insert(
            state.clone(),
            BrowserSession {
                client_id: client_id.to_string(),
                verifier,
                redirect_uri: redirect_uri.to_string(),
                status: BrowserSessionStatus::Pending,
                account: None,
                error: None,
                created_at: Instant::now(),
            },
        );

    let mut authorize_url =
        Url::parse("https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize")
            .map_err(|err| ApiError::new(500, err.to_string()))?;
    authorize_url
        .query_pairs_mut()
        .append_pair("client_id", client_id)
        .append_pair("response_type", "code")
        .append_pair("redirect_uri", redirect_uri)
        .append_pair("response_mode", "query")
        .append_pair("scope", DEFAULT_SCOPES)
        .append_pair("code_challenge", &challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("state", &state)
        .append_pair("prompt", "select_account");

    Ok(json!({
        "state": state,
        "redirect_uri": redirect_uri,
        "authorization_url": authorize_url.to_string(),
        "expires_in": 600
    }))
}

fn complete_browser_login(db: &SharedDb, query: &HashMap<String, String>) -> CallbackPage {
    prune_browser_sessions();
    let state = query.get("state").cloned().unwrap_or_default();
    let code = query.get("code").cloned().unwrap_or_default();
    let returned_error = query
        .get("error_description")
        .or_else(|| query.get("error"))
        .cloned()
        .unwrap_or_default();

    let session = {
        let sessions = BROWSER_SESSIONS.lock();
        let Ok(sessions) = sessions else {
            return CallbackPage::new("授权失败", "浏览器授权会话锁定失败。");
        };
        sessions.get(&state).cloned()
    };

    let Some(session) = session else {
        return CallbackPage::new("授权已失效", "请回到软件里重新点“浏览器授权”。");
    };

    if !returned_error.is_empty() {
        mark_browser_session_error(&state, returned_error.clone());
        return CallbackPage::new("授权失败", returned_error);
    }
    if code.is_empty() {
        mark_browser_session_error(&state, "Microsoft did not return an authorization code.");
        return CallbackPage::new(
            "授权失败",
            "Microsoft did not return an authorization code.",
        );
    }

    let result = (|| -> Result<Value, ApiError> {
        let token = exchange_authorization_code(
            &session.client_id,
            &code,
            &session.redirect_uri,
            &session.verifier,
        )?;
        let access_token = token
            .get("access_token")
            .and_then(Value::as_str)
            .ok_or_else(|| {
                ApiError::new(500, "Microsoft token response did not include access_token")
            })?;
        let refresh_token = token
            .get("refresh_token")
            .and_then(Value::as_str)
            .ok_or_else(|| {
                ApiError::new(
                    500,
                    "Microsoft token response did not include refresh_token",
                )
            })?;
        let email = get_profile_email(access_token)?;
        let conn = db
            .lock()
            .map_err(|_| ApiError::new(500, "database lock poisoned"))?;
        upsert_oauth_account(&conn, &email, &session.client_id, refresh_token)
    })();

    match result {
        Ok(account) => {
            if let Ok(mut sessions) = BROWSER_SESSIONS.lock() {
                if let Some(session) = sessions.get_mut(&state) {
                    session.status = BrowserSessionStatus::Authorized;
                    session.account = Some(account.clone());
                }
            }
            let email = account
                .get("email")
                .and_then(Value::as_str)
                .unwrap_or("账号");
            CallbackPage::new(
                "授权完成",
                format!("{email} 已写入本地账号库，可以关闭这个页面。"),
            )
        }
        Err(err) => {
            mark_browser_session_error(&state, err.message.clone());
            CallbackPage::new("授权失败", err.message)
        }
    }
}

fn poll_browser_login(_conn: &Connection, body: Value) -> Result<Value, ApiError> {
    prune_browser_sessions();
    let state = body
        .get("state")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    let mut sessions = BROWSER_SESSIONS
        .lock()
        .map_err(|_| ApiError::new(500, "browser session lock poisoned"))?;
    let Some(session) = sessions.get(state).cloned() else {
        return Err(ApiError::new(
            404,
            "browser login session not found or expired",
        ));
    };

    match session.status {
        BrowserSessionStatus::Authorized => {
            sessions.remove(state);
            Ok(json!({ "status": "authorized", "account": session.account }))
        }
        BrowserSessionStatus::Error => {
            sessions.remove(state);
            Ok(
                json!({ "status": "error", "error": session.error.unwrap_or_else(|| "Browser authorization failed".to_string()) }),
            )
        }
        BrowserSessionStatus::Pending => Ok(json!({ "status": "pending" })),
    }
}

fn start_device_login(body: Value) -> Result<Value, ApiError> {
    let client_id = body
        .get("client_id")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    if !is_client_id(client_id) {
        return Err(ApiError::new(400, "client_id must be a valid UUID"));
    }
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")
        .form(&[("client_id", client_id), ("scope", DEFAULT_SCOPES)])
        .send()
        .map_err(|err| ApiError::new(500, format!("Device login start failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!("Device login start failed: {} - {}", status.as_u16(), text),
        ));
    }
    let data: Value = serde_json::from_str(&text)
        .map_err(|err| ApiError::new(500, format!("parse device code response failed: {err}")))?;
    Ok(json!({
        "client_id": client_id,
        "device_code": data.get("device_code").and_then(Value::as_str).unwrap_or_default(),
        "user_code": data.get("user_code").and_then(Value::as_str).unwrap_or_default(),
        "verification_uri": data.get("verification_uri").and_then(Value::as_str).unwrap_or_default(),
        "expires_in": data.get("expires_in").and_then(Value::as_i64).unwrap_or(0),
        "interval": data.get("interval").and_then(Value::as_i64).unwrap_or(5),
        "message": data.get("message").and_then(Value::as_str).unwrap_or_default()
    }))
}

fn poll_device_login(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let client_id = body
        .get("client_id")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    let device_code = body
        .get("device_code")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    if !is_client_id(client_id) {
        return Err(ApiError::new(400, "client_id must be a valid UUID"));
    }
    if device_code.is_empty() {
        return Err(ApiError::new(400, "device_code is required"));
    }

    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id),
            ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
            ("device_code", device_code),
        ])
        .send()
        .map_err(|err| ApiError::new(500, format!("Device login failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    let data: Value = serde_json::from_str(&text).unwrap_or_else(|_| json!({}));
    if !status.is_success() {
        let error = data.get("error").and_then(Value::as_str).unwrap_or("");
        if error == "authorization_pending" || error == "slow_down" {
            return Ok(json!({ "status": "pending" }));
        }
        return Err(ApiError::new(
            500,
            format!("Device login failed: {} - {}", status.as_u16(), text),
        ));
    }

    let access_token = data
        .get("access_token")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ApiError::new(500, "Microsoft token response did not include access_token")
        })?;
    let refresh_token = data
        .get("refresh_token")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ApiError::new(
                500,
                "Microsoft token response did not include refresh_token",
            )
        })?;
    let email = get_profile_email(access_token)?;
    let account = upsert_oauth_account(conn, &email, client_id, refresh_token)?;
    Ok(json!({ "status": "authorized", "account": account }))
}

fn exchange_authorization_code(
    client_id: &str,
    code: &str,
    redirect_uri: &str,
    verifier: &str,
) -> Result<Value, ApiError> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .post("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
        .form(&[
            ("client_id", client_id),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirect_uri),
            ("code_verifier", verifier),
            ("scope", DEFAULT_SCOPES),
        ])
        .send()
        .map_err(|err| ApiError::new(500, format!("Browser login failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!("Browser login failed: {} - {}", status.as_u16(), text),
        ));
    }
    serde_json::from_str(&text)
        .map_err(|err| ApiError::new(500, format!("parse browser token response failed: {err}")))
}

fn get_profile_email(access_token: &str) -> Result<String, ApiError> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(35))
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))?;
    let response = client
        .get("https://graph.microsoft.com/v1.0/me?$select=mail,userPrincipalName")
        .bearer_auth(access_token)
        .send()
        .map_err(|err| ApiError::new(500, format!("Read Microsoft profile failed: {err}")))?;
    let status = response.status();
    let text = response.text().unwrap_or_default();
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!(
                "Read Microsoft profile failed: {} - {}",
                status.as_u16(),
                text
            ),
        ));
    }
    let data: Value = serde_json::from_str(&text)
        .map_err(|err| ApiError::new(500, format!("parse profile response failed: {err}")))?;
    let email = data
        .get("mail")
        .or_else(|| data.get("userPrincipalName"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_string();
    if email.is_empty() {
        Err(ApiError::new(
            500,
            "Microsoft profile did not return an email address.",
        ))
    } else {
        Ok(email)
    }
}

fn upsert_oauth_account(
    conn: &Connection,
    email: &str,
    client_id: &str,
    refresh_token: &str,
) -> Result<Value, ApiError> {
    let existing_id = conn
        .query_row("SELECT id FROM accounts WHERE email = ?", [email], |row| {
            row.get::<_, i64>(0)
        })
        .optional()?;
    let id = if let Some(id) = existing_id {
        conn.execute(
            "UPDATE accounts SET client_id = ?, refresh_token = ?, status = 'active', token_refreshed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            params![client_id, refresh_token, id],
        )?;
        id
    } else {
        conn.execute(
            "INSERT INTO accounts (email, password, client_id, refresh_token, status, token_refreshed_at) VALUES (?, '', ?, ?, 'active', CURRENT_TIMESTAMP)",
            params![email, client_id, refresh_token],
        )?;
        conn.last_insert_rowid()
    };
    let mut accounts = query_accounts(conn, "SELECT * FROM accounts WHERE id = ?", &[&id])?;
    accounts
        .pop()
        .ok_or_else(|| ApiError::new(500, "created account not found"))
}

fn prune_browser_sessions() {
    if let Ok(mut sessions) = BROWSER_SESSIONS.lock() {
        sessions.retain(|_, session| session.created_at.elapsed() < Duration::from_secs(600));
    }
}

fn mark_browser_session_error(state: &str, message: impl Into<String>) {
    if let Ok(mut sessions) = BROWSER_SESSIONS.lock() {
        if let Some(session) = sessions.get_mut(state) {
            session.status = BrowserSessionStatus::Error;
            session.error = Some(message.into());
        }
    }
}

fn random_url_token(len: usize) -> Result<String, ApiError> {
    let mut bytes = vec![0u8; len];
    getrandom::fill(&mut bytes)
        .map_err(|err| ApiError::new(500, format!("random generation failed: {err}")))?;
    Ok(base64_url_encode(&bytes))
}

fn pkce_challenge(verifier: &str) -> String {
    let digest = Sha256::digest(verifier.as_bytes());
    base64_url_encode(&digest)
}

fn base64_url_encode(bytes: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes)
}

fn is_local_browser_callback(value: &str) -> bool {
    let Ok(url) = Url::parse(value) else {
        return false;
    };
    url.scheme() == "http"
        && matches!(url.host_str(), Some("localhost" | "127.0.0.1"))
        && url.path() == "/api/oauth/browser/callback"
        && url.port().is_some()
}

struct CallbackPage {
    title: String,
    message: String,
}

impl CallbackPage {
    fn new(title: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            title: title.into(),
            message: message.into(),
        }
    }
}

#[allow(dead_code)]
fn fetch_mails_from_cache(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let account_id = body
        .get("account_id")
        .or_else(|| body.get("accountId"))
        .and_then(Value::as_i64)
        .unwrap_or(0);
    if account_id <= 0 {
        return Err(ApiError::new(400, "account_id is required"));
    }
    let mailbox = body
        .get("mailbox")
        .and_then(Value::as_str)
        .unwrap_or("INBOX");
    let mails = query_mails(
        conn,
        "SELECT * FROM mail_cache WHERE account_id = ? AND mailbox = ? ORDER BY mail_date DESC LIMIT 100",
        &[&account_id, &mailbox],
    )?;
    Ok(json!({ "mails": mails, "total": mails.len(), "protocol": "native-cache", "cached": true }))
}

fn query_mails(
    conn: &Connection,
    sql: &str,
    params: &[&dyn rusqlite::ToSql],
) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn.prepare(sql)?;
    let rows = stmt.query_map(params, |row| {
        Ok(json!({
            "id": row.get::<_, i64>("id")?,
            "account_id": row.get::<_, i64>("account_id")?,
            "mailbox": row.get::<_, String>("mailbox")?,
            "mail_id": row.get::<_, Option<String>>("mail_id")?.unwrap_or_default(),
            "sender": row.get::<_, Option<String>>("sender")?.unwrap_or_default(),
            "sender_name": row.get::<_, Option<String>>("sender_name")?.unwrap_or_default(),
            "subject": row.get::<_, Option<String>>("subject")?.unwrap_or_default(),
            "text_content": row.get::<_, Option<String>>("text_content")?.unwrap_or_default(),
            "html_content": row.get::<_, Option<String>>("html_content")?.unwrap_or_default(),
            "mail_date": row.get::<_, Option<String>>("mail_date")?.unwrap_or_default(),
            "is_read": row.get::<_, i64>("is_read").unwrap_or(0) != 0,
            "cached_at": row.get::<_, Option<String>>("cached_at")?.unwrap_or_default(),
        }))
    })?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)
}

fn recent_mails(conn: &Connection, limit: i64) -> Result<Vec<Value>, ApiError> {
    query_mails(
        conn,
        "SELECT * FROM mail_cache ORDER BY mail_date DESC LIMIT ?",
        &[&limit],
    )
}

fn account_stats(conn: &Connection) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn.prepare(
        r#"
        SELECT a.id, a.email,
          SUM(CASE WHEN mc.mailbox = 'INBOX' THEN 1 ELSE 0 END) AS inbox_count,
          SUM(CASE WHEN mc.mailbox = 'Junk' THEN 1 ELSE 0 END) AS junk_count
        FROM accounts a
        LEFT JOIN mail_cache mc ON mc.account_id = a.id
        GROUP BY a.id, a.email
        ORDER BY a.id DESC
        "#,
    )?;
    let rows = stmt.query_map([], |row| {
        Ok(json!({
            "account_id": row.get::<_, i64>(0)?,
            "email": row.get::<_, String>(1)?,
            "inbox_count": row.get::<_, Option<i64>>(2)?.unwrap_or(0),
            "junk_count": row.get::<_, Option<i64>>(3)?.unwrap_or(0),
        }))
    })?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)
}

fn database_health(conn: &Connection) -> Result<Value, ApiError> {
    let db_path = resolve_db_path();
    let size = fs::metadata(&db_path).map(|m| m.len()).unwrap_or(0);
    let journal_mode = conn
        .pragma_query_value(None, "journal_mode", |row| row.get::<_, String>(0))
        .unwrap_or_default();
    let foreign_keys = conn
        .pragma_query_value(None, "foreign_keys", |row| row.get::<_, i64>(0))
        .unwrap_or(0)
        != 0;
    Ok(json!({
        "dbPath": db_path.display().to_string(),
        "exists": db_path.exists(),
        "journalMode": journal_mode,
        "foreignKeys": foreign_keys,
        "sizeBytes": size,
        "outlookCache": mail_cache_issues(conn)?,
        "clawCache": claw_cache_summary(conn)?
    }))
}

fn database_repair(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let dry_run = body.get("dryRun").and_then(Value::as_bool).unwrap_or(true);
    let issues = mail_cache_issues(conn)?;
    let normalized = issues
        .get("emptyMailIds")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let duplicate_rows = issues
        .get("duplicateRows")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let orphan_rows = issues
        .get("orphanRows")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    if !dry_run {
        let _ = conn.execute(
            "UPDATE mail_cache SET mail_id = NULL WHERE mail_id = ''",
            [],
        );
        let _ = conn.execute(
            "DELETE FROM mail_cache WHERE account_id NOT IN (SELECT id FROM accounts)",
            [],
        );
        let _ = conn.execute_batch(
            r#"
            DELETE FROM mail_cache
            WHERE id NOT IN (
              SELECT MIN(id)
              FROM mail_cache
              GROUP BY account_id, mailbox, COALESCE(NULLIF(mail_id, ''), id)
            );
            "#,
        );
        let _ = conn.execute(
            "INSERT INTO database_maintenance_log (action, details) VALUES ('repair', ?)",
            [format!("native repair: normalized={normalized}, duplicates={duplicate_rows}, orphans={orphan_rows}")],
        );
    }
    Ok(json!({
        "dryRun": dry_run,
        "normalizedEmptyMailIds": normalized,
        "deletedDuplicateRows": duplicate_rows,
        "deletedOrphanRows": orphan_rows,
        "remainingIssues": if dry_run { issues } else { mail_cache_issues(conn)? }
    }))
}

fn database_optimize(conn: &Connection) -> Result<Value, ApiError> {
    let path = resolve_db_path();
    let before = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    conn.execute_batch("PRAGMA optimize; VACUUM;")?;
    let after = fs::metadata(&path).map(|m| m.len()).unwrap_or(before);
    let journal_mode = conn
        .pragma_query_value(None, "journal_mode", |row| row.get::<_, String>(0))
        .unwrap_or_default();
    Ok(json!({
        "beforeBytes": before,
        "afterBytes": after,
        "savedBytes": before.saturating_sub(after),
        "journalMode": journal_mode
    }))
}

fn mail_cache_issues(conn: &Connection) -> Result<Value, ApiError> {
    let total = count_i64(conn, "SELECT COUNT(*) FROM mail_cache", &[])?;
    let empty = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE mail_id = ''",
        &[],
    )?;
    let orphan = count_i64(
        conn,
        "SELECT COUNT(*) FROM mail_cache WHERE account_id NOT IN (SELECT id FROM accounts)",
        &[],
    )?;
    let duplicate_groups = count_i64(
        conn,
        "SELECT COUNT(*) FROM (SELECT account_id, mailbox, mail_id, COUNT(*) c FROM mail_cache WHERE mail_id IS NOT NULL AND mail_id != '' GROUP BY account_id, mailbox, mail_id HAVING c > 1)",
        &[],
    )?;
    let duplicate_rows = count_i64(
        conn,
        "SELECT COALESCE(SUM(c - 1), 0) FROM (SELECT COUNT(*) c FROM mail_cache WHERE mail_id IS NOT NULL AND mail_id != '' GROUP BY account_id, mailbox, mail_id HAVING c > 1)",
        &[],
    )?;
    Ok(json!({
        "totalRows": total,
        "emptyMailIds": empty,
        "duplicateGroups": duplicate_groups,
        "duplicateRows": duplicate_rows,
        "orphanRows": orphan
    }))
}

fn claw_cache_summary(conn: &Connection) -> Result<Value, ApiError> {
    let total = count_i64(conn, "SELECT COUNT(*) FROM claw_mail_cache", &[]).unwrap_or(0);
    let duplicate_groups = count_i64(
        conn,
        "SELECT COUNT(*) FROM (SELECT mailbox_email, provider_mail_id, COUNT(*) c FROM claw_mail_cache GROUP BY mailbox_email, provider_mail_id HAVING c > 1)",
        &[],
    )
    .unwrap_or(0);
    Ok(json!({ "totalRows": total, "duplicateGroups": duplicate_groups }))
}

fn claw_status(conn: &Connection) -> Result<Value, ApiError> {
    let settings = load_claw_settings(conn);
    let mailboxes = count_i64(
        conn,
        "SELECT COUNT(*) FROM claw_mailboxes WHERE status != 'deleted'",
        &[],
    )
    .unwrap_or(0);
    let mails = count_i64(conn, "SELECT COUNT(*) FROM claw_mail_cache", &[]).unwrap_or(0);
    Ok(json!({
        "connected": settings.get("dashboardCookie").map(|v| !v.is_empty()).unwrap_or(false),
        "userEmail": settings.get("userEmail").cloned().unwrap_or_default(),
        "workspaceName": settings.get("workspaceName").cloned().unwrap_or_default(),
        "domain": settings.get("domain").cloned().unwrap_or_else(|| "claw.163.com".to_string()),
        "mailboxes": mailboxes,
        "mails": mails
    }))
}

fn claw_stats(conn: &Connection) -> Result<Value, ApiError> {
    let mailboxes = count_i64(
        conn,
        "SELECT COUNT(*) FROM claw_mailboxes WHERE status != 'deleted'",
        &[],
    )
    .unwrap_or(0);
    let mails = count_i64(conn, "SELECT COUNT(*) FROM claw_mail_cache", &[]).unwrap_or(0);
    let recent_mails = claw_recent_mails(conn, 10)?;
    Ok(json!({
        "totalAccounts": mailboxes,
        "activeAccounts": mailboxes,
        "totalInboxMails": mails,
        "totalJunkMails": 0,
        "totalProxies": 0,
        "activeProxies": 0,
        "recentMails": recent_mails,
        "accountStats": [],
        "expiringTokens": 0,
        "errorAccounts": 0,
        "unusedAccounts": 0
    }))
}

fn claw_recent_mails(conn: &Connection, limit: i64) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn.prepare(
        "SELECT id, mailbox_email, sender, sender_name, subject, text_content, html_content, received_at
         FROM claw_mail_cache
         ORDER BY COALESCE(received_at, cached_at) DESC
         LIMIT ?",
    )?;
    let rows = stmt.query_map([limit], |row| {
        let mailbox_email = row.get::<_, String>(1)?;
        Ok(json!({
            "id": row.get::<_, i64>(0)?,
            "account_id": 0,
            "mailbox": "INBOX",
            "mailbox_email": mailbox_email,
            "sender": row.get::<_, Option<String>>(2)?.unwrap_or_default(),
            "sender_name": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
            "subject": row.get::<_, Option<String>>(4)?.unwrap_or_default(),
            "text_content": row.get::<_, Option<String>>(5)?.unwrap_or_default(),
            "html_content": row.get::<_, Option<String>>(6)?.unwrap_or_default(),
            "mail_date": row.get::<_, Option<String>>(7)?.unwrap_or_default(),
            "is_read": false
        }))
    })?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)
}

fn claw_send_code(body: Value) -> Result<Value, ApiError> {
    let email = body
        .get("email")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_lowercase();
    if !is_email(&email) {
        return Err(ApiError::new(400, "Claw 登录邮箱格式不正确。"));
    }

    let client = http_client()?;
    let response = client
        .post(format!("{CLAW_PUBLIC_BASE_URL}/auth/email/send-code"))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(CONTENT_TYPE, "application/json")
        .header(
            REFERER,
            format!("{CLAW_DASHBOARD_ORIGIN}/projects/dashboard/"),
        )
        .json(&json!({ "email": email }))
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw send code failed: {err}")))?;
    let _ = parse_claw_dashboard_response(response)?;
    Ok(json!({ "sent": true }))
}

fn claw_verify_code(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let email = body
        .get("email")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_lowercase();
    let code = body
        .get("code")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_string();
    if !is_email(&email) {
        return Err(ApiError::new(400, "Claw 登录邮箱格式不正确。"));
    }
    if code.len() < 4 || code.len() > 8 || !code.chars().all(|c| c.is_ascii_digit()) {
        return Err(ApiError::new(400, "Claw 验证码格式不正确。"));
    }

    let client = http_client()?;
    let response = client
        .post(format!("{CLAW_PUBLIC_BASE_URL}/auth/email/verify-code"))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(CONTENT_TYPE, "application/json")
        .header(
            REFERER,
            format!("{CLAW_DASHBOARD_ORIGIN}/projects/dashboard/"),
        )
        .json(&json!({ "email": email, "code": code }))
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw verify code failed: {err}")))?;
    let cookie = read_set_cookie(response.headers());
    let _ = parse_claw_dashboard_response(response)?;
    if cookie.is_empty() {
        return Err(ApiError::new(500, "Claw 登录成功但没有返回会话 Cookie。"));
    }

    connect_claw_with_cookie(conn, &cookie)
}

fn claw_refresh_auth(conn: &Connection) -> Result<Value, ApiError> {
    let settings = load_claw_settings(conn);
    let cookie = require_claw_setting(&settings, "dashboardCookie")?;
    connect_claw_with_cookie(conn, &cookie)
}

fn claw_logout(conn: &Connection) -> Result<Value, ApiError> {
    conn.execute("DELETE FROM claw_settings", [])?;
    claw_status(conn)
}

fn connect_claw_with_cookie(conn: &Connection, cookie: &str) -> Result<Value, ApiError> {
    let client = http_client()?;
    let me = claw_get(&client, "/auth/me", cookie)?;
    let workspaces = collect_items(
        &claw_get(&client, "/workspaces", cookie)?,
        &["items", "list", "workspaces"],
    );
    let api_keys = collect_items(
        &claw_get(&client, "/api-keys", cookie)?,
        &["items", "list", "apiKeys", "api_keys"],
    );

    let workspace = select_active(workspaces)
        .ok_or_else(|| ApiError::new(500, "Claw Dashboard 没有返回可用 workspace。"))?;
    let workspace_id = value_string_any(&workspace, &["id", "workspaceId"])
        .ok_or_else(|| ApiError::new(500, "Claw workspace 缺少 id。"))?;
    let workspace_name =
        value_string_any(&workspace, &["name", "workspaceName"]).unwrap_or_default();

    let api_key = select_active(api_keys)
        .and_then(|item| value_string_any(&item, &["apiKey", "key", "token", "value"]))
        .unwrap_or_default();

    let remote = fetch_claw_dashboard_mailboxes(&client, cookie, &workspace_id)?;
    let primary = select_primary_mailbox(&remote)
        .ok_or_else(|| ApiError::new(500, "Claw Dashboard 没有返回主邮箱。"))?;
    let parent_mailbox_id = value_string_any(&primary, &["id"]).unwrap_or_default();
    let user_email = value_string_any(&me, &["email", "userEmail"])
        .or_else(|| value_string_any(&primary, &["email"]))
        .unwrap_or_default();
    let root_prefix = mailbox_root_prefix(&primary);
    let domain = value_string_any(&primary, &["email"])
        .and_then(|email| email.split_once('@').map(|(_, domain)| domain.to_string()))
        .unwrap_or_else(|| "claw.163.com".to_string());

    save_claw_settings(
        conn,
        &[
            ("apiKey", api_key.as_str()),
            ("dashboardCookie", cookie),
            ("userEmail", user_email.as_str()),
            ("workspaceId", workspace_id.as_str()),
            ("workspaceName", workspace_name.as_str()),
            ("parentMailboxId", parent_mailbox_id.as_str()),
            ("rootPrefix", root_prefix.as_str()),
            ("domain", domain.as_str()),
        ],
    )?;

    upsert_claw_mailboxes(conn, &remote)?;
    Ok(json!({
        "auth": claw_status(conn)?,
        "syncedMailboxes": remote.len(),
        "listeners": {
            "started": false,
            "native": true,
            "message": "Claw realtime listeners still need the Claw Node SDK compatibility layer."
        }
    }))
}

fn claw_get(
    client: &reqwest::blocking::Client,
    path: &str,
    cookie: &str,
) -> Result<Value, ApiError> {
    let response = client
        .get(format!("{CLAW_BASE_URL}{path}"))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(COOKIE, cookie)
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw Dashboard request failed: {err}")))?;
    parse_claw_dashboard_response(response)
}

fn fetch_claw_dashboard_mailboxes(
    client: &reqwest::blocking::Client,
    cookie: &str,
    workspace_id: &str,
) -> Result<Vec<Value>, ApiError> {
    let response = client
        .get(format!(
            "{CLAW_BASE_URL}/mailboxes?workspaceId={}",
            url_encode(workspace_id)
        ))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(COOKIE, cookie)
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw list mailboxes failed: {err}")))?;
    let data = parse_claw_dashboard_response(response)?;
    let mut items = Vec::new();
    if let Some(mailbox) = data.get("mailbox") {
        items.push(mailbox.clone());
    }
    for item in collect_items(&data, &["subMailboxes", "items", "list", "mailboxes"]) {
        items.push(item);
    }
    if items.is_empty() && data.is_array() {
        items = collect_items(&data, &[]);
    }
    Ok(items)
}

fn claw_sync_mailboxes(conn: &Connection) -> Result<Value, ApiError> {
    let settings = load_claw_settings(conn);
    let cookie = require_claw_setting(&settings, "dashboardCookie")?;
    let workspace_id = require_claw_setting(&settings, "workspaceId")?;
    let client = http_client()?;
    let remote = fetch_claw_dashboard_mailboxes(&client, &cookie, &workspace_id)?;
    upsert_claw_mailboxes(conn, &remote)?;
    claw_mailboxes_from_cache(conn)
}

fn claw_create_mailbox(conn: &Connection, body: Value) -> Result<Value, ApiError> {
    let suffix = body
        .get("suffix")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_lowercase();
    if suffix.is_empty()
        || suffix.len() > 32
        || !suffix
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit())
    {
        return Err(ApiError::new(
            400,
            "Claw 子邮箱后缀只能包含 1-32 位小写字母或数字。",
        ));
    }

    let settings = load_claw_settings(conn);
    let cookie = require_claw_setting(&settings, "dashboardCookie")?;
    let workspace_id = require_claw_setting(&settings, "workspaceId")?;
    let parent_mailbox_id = require_claw_setting(&settings, "parentMailboxId")?;
    let client = http_client()?;
    let response = client
        .post(format!("{CLAW_BASE_URL}/mailboxes"))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(CONTENT_TYPE, "application/json")
        .header(COOKIE, cookie.as_str())
        .json(&json!({
            "prefix": suffix,
            "displayName": suffix,
            "mailboxType": "sub",
            "workspaceId": workspace_id,
            "parentMailboxId": parent_mailbox_id
        }))
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw create mailbox failed: {err}")))?;
    let mut mailbox = parse_claw_dashboard_response(response)?;
    apply_default_comm_fields(&mut mailbox);
    let mailbox_id = value_string_any(&mailbox, &["id"])
        .ok_or_else(|| ApiError::new(500, "Claw create mailbox response missing id"))?;
    let payload = json!({ "commLevel": 2, "extReceiveType": 1, "extSendType": 1 });
    post_claw_comm_settings(&client, &cookie, &mailbox_id, &payload)?;
    upsert_claw_mailbox(conn, &mailbox)?;
    Ok(normalize_claw_mailbox_for_api(&mailbox))
}

fn claw_update_comm_settings(conn: &Connection, id: &str, body: Value) -> Result<Value, ApiError> {
    let payload = normalize_claw_comm_payload(body)?;
    let settings = load_claw_settings(conn);
    let cookie = require_claw_setting(&settings, "dashboardCookie")?;
    let client = http_client()?;
    post_claw_comm_settings(&client, &cookie, id, &payload)?;
    let _ = claw_sync_mailboxes(conn)?;
    get_claw_mailbox_by_id(conn, id)?.ok_or_else(|| ApiError::new(404, "Claw 邮箱不存在。"))
}

fn claw_delete_mailbox(conn: &Connection, id: &str) -> Result<Value, ApiError> {
    let settings = load_claw_settings(conn);
    if settings.get("parentMailboxId").map(String::as_str) == Some(id) {
        return Err(ApiError::new(400, "Claw 主邮箱不能在这里删除。"));
    }
    let cookie = require_claw_setting(&settings, "dashboardCookie")?;
    let client = http_client()?;
    let response = client
        .post(format!(
            "{CLAW_BASE_URL}/mailboxes/delete?id={}",
            url_encode(id)
        ))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(COOKIE, cookie.as_str())
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw delete mailbox failed: {err}")))?;
    let _ = parse_claw_dashboard_response(response)?;
    conn.execute(
        "UPDATE claw_mailboxes SET status = 'deleted', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        [id],
    )?;
    Ok(json!({ "deleted": true }))
}

fn post_claw_comm_settings(
    client: &reqwest::blocking::Client,
    cookie: &str,
    id: &str,
    payload: &Value,
) -> Result<(), ApiError> {
    let response = client
        .post(format!(
            "{CLAW_BASE_URL}/mailboxes/comm-settings?id={}",
            url_encode(id)
        ))
        .header(ACCEPT, "application/json, text/plain, */*")
        .header(CONTENT_TYPE, "application/json")
        .header(COOKIE, cookie)
        .json(payload)
        .send()
        .map_err(|err| {
            ApiError::new(
                500,
                format!("Claw update communication settings failed: {err}"),
            )
        })?;
    let _ = parse_claw_dashboard_response(response)?;
    Ok(())
}

fn load_claw_settings(conn: &Connection) -> HashMap<String, String> {
    let mut map = HashMap::new();
    if let Ok(mut stmt) = conn.prepare("SELECT key, value FROM claw_settings") {
        if let Ok(rows) = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        }) {
            for (key, value) in rows.flatten() {
                map.insert(key, value);
            }
        }
    }
    for (key, env_key, default_value) in [
        ("apiKey", "CLAW_API_KEY", ""),
        ("dashboardCookie", "CLAW_DASHBOARD_COOKIE", ""),
        ("workspaceId", "CLAW_WORKSPACE_ID", ""),
        ("parentMailboxId", "CLAW_PARENT_MAILBOX_ID", ""),
        ("rootPrefix", "CLAW_ROOT_PREFIX", ""),
        ("domain", "CLAW_DOMAIN", "claw.163.com"),
    ] {
        if !map.contains_key(key) {
            let value = env::var(env_key).unwrap_or_else(|_| default_value.to_string());
            if !value.is_empty() {
                map.insert(key.to_string(), value);
            }
        }
    }
    map
}

fn claw_mailboxes(conn: &Connection, query: &HashMap<String, String>) -> Result<Value, ApiError> {
    if query
        .get("sync")
        .map(|v| v.eq_ignore_ascii_case("true"))
        .unwrap_or(false)
    {
        return claw_sync_mailboxes(conn);
    }
    claw_mailboxes_from_cache(conn)
}

fn claw_mailboxes_from_cache(conn: &Connection) -> Result<Value, ApiError> {
    let mut stmt = conn.prepare("SELECT id, email, prefix, display_name, mailbox_type, status, openclaw_status, comm_level, ext_receive_type, ext_send_type, synced_at FROM claw_mailboxes WHERE status != 'deleted' ORDER BY email ASC")?;
    let items = stmt
        .query_map([], |row| {
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "email": row.get::<_, String>(1)?,
                "prefix": row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                "display_name": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                "mailbox_type": row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                "status": row.get::<_, Option<String>>(5)?.unwrap_or_else(|| "active".into()),
                "openclaw_status": row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                "comm_level": row.get::<_, Option<i64>>(7)?,
                "ext_receive_type": row.get::<_, Option<i64>>(8)?,
                "ext_send_type": row.get::<_, Option<i64>>(9)?,
                "synced_at": row.get::<_, Option<String>>(10)?.unwrap_or_default()
            }))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(json!({ "items": items }))
}

fn save_claw_settings(conn: &Connection, settings: &[(&str, &str)]) -> Result<(), ApiError> {
    let mut stmt = conn.prepare(
        "INSERT INTO claw_settings (key, value, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP",
    )?;
    for (key, value) in settings {
        stmt.execute(params![key, value])?;
    }
    Ok(())
}

fn require_claw_setting(settings: &HashMap<String, String>, key: &str) -> Result<String, ApiError> {
    settings
        .get(key)
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::new(400, format!("Claw 配置缺失：{key}。请先绑定 ClawEmail。")))
}

fn upsert_claw_mailboxes(conn: &Connection, remote: &[Value]) -> Result<(), ApiError> {
    for mailbox in remote {
        upsert_claw_mailbox(conn, mailbox)?;
    }

    let emails: Vec<String> = remote
        .iter()
        .filter_map(|item| value_string_any(item, &["email"]))
        .map(|email| email.to_lowercase())
        .collect();
    if emails.is_empty() {
        return Ok(());
    }

    let mut stmt = conn.prepare("SELECT id, email FROM claw_mailboxes")?;
    let rows = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    for (id, email) in rows {
        if !emails.iter().any(|active| active == &email.to_lowercase()) {
            conn.execute("UPDATE claw_mailboxes SET status = 'deleted', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [id])?;
        }
    }
    Ok(())
}

fn upsert_claw_mailbox(conn: &Connection, raw: &Value) -> Result<(), ApiError> {
    let id = value_string_any(raw, &["id"])
        .ok_or_else(|| ApiError::new(500, "Claw mailbox missing id"))?;
    let email = value_string_any(raw, &["email"])
        .ok_or_else(|| ApiError::new(500, "Claw mailbox missing email"))?
        .to_lowercase();
    let prefix = value_string_any(raw, &["prefix"])
        .unwrap_or_else(|| email.split('@').next().unwrap_or("").to_string());
    let display_name = value_string_any(raw, &["displayName", "display_name"]).unwrap_or_default();
    let mailbox_type = value_string_any(raw, &["mailboxType", "mailbox_type"]).unwrap_or_default();
    let status = value_string_any(raw, &["status"]).unwrap_or_else(|| "active".to_string());
    let openclaw_status =
        value_string_any(raw, &["openclawStatus", "openclaw_status"]).unwrap_or_default();
    let install_command =
        value_string_any(raw, &["installCommand", "install_command"]).unwrap_or_default();
    let auth_url = extract_auth_url(&install_command);
    let comm_level = value_i64_any(raw, &["commLevel", "comm_level"]);
    let ext_receive_type = value_i64_any(raw, &["extReceiveType", "ext_receive_type"]);
    let ext_send_type = value_i64_any(raw, &["extSendType", "ext_send_type"]);
    let created_at = value_string_any(raw, &["createdAt", "created_at_remote"]);

    conn.execute(
        "INSERT INTO claw_mailboxes (
            id, email, prefix, display_name, mailbox_type, status, openclaw_status,
            install_command, auth_url, comm_level, ext_receive_type, ext_send_type,
            created_at_remote, synced_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO UPDATE SET
            email = excluded.email,
            prefix = excluded.prefix,
            display_name = excluded.display_name,
            mailbox_type = excluded.mailbox_type,
            status = excluded.status,
            openclaw_status = excluded.openclaw_status,
            install_command = excluded.install_command,
            auth_url = excluded.auth_url,
            comm_level = excluded.comm_level,
            ext_receive_type = excluded.ext_receive_type,
            ext_send_type = excluded.ext_send_type,
            created_at_remote = excluded.created_at_remote,
            synced_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP",
        params![
            id,
            email,
            prefix,
            display_name,
            mailbox_type,
            status,
            openclaw_status,
            install_command,
            auth_url,
            comm_level,
            ext_receive_type,
            ext_send_type,
            created_at
        ],
    )?;
    Ok(())
}

fn get_claw_mailbox_by_id(conn: &Connection, id: &str) -> Result<Option<Value>, ApiError> {
    let mut stmt = conn.prepare("SELECT id, email, prefix, display_name, mailbox_type, status, openclaw_status, comm_level, ext_receive_type, ext_send_type, synced_at FROM claw_mailboxes WHERE id = ?")?;
    let value = stmt
        .query_row([id], |row| {
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "email": row.get::<_, String>(1)?,
                "prefix": row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                "display_name": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                "mailbox_type": row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                "status": row.get::<_, Option<String>>(5)?.unwrap_or_else(|| "active".into()),
                "openclaw_status": row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                "comm_level": row.get::<_, Option<i64>>(7)?,
                "ext_receive_type": row.get::<_, Option<i64>>(8)?,
                "ext_send_type": row.get::<_, Option<i64>>(9)?,
                "synced_at": row.get::<_, Option<String>>(10)?.unwrap_or_default()
            }))
        })
        .optional()?;
    Ok(value)
}

fn normalize_claw_mailbox_for_api(raw: &Value) -> Value {
    json!({
        "id": value_string_any(raw, &["id"]).unwrap_or_default(),
        "email": value_string_any(raw, &["email"]).unwrap_or_default().to_lowercase(),
        "prefix": value_string_any(raw, &["prefix"]).unwrap_or_default(),
        "display_name": value_string_any(raw, &["displayName", "display_name"]).unwrap_or_default(),
        "mailbox_type": value_string_any(raw, &["mailboxType", "mailbox_type"]).unwrap_or_default(),
        "status": value_string_any(raw, &["status"]).unwrap_or_else(|| "active".to_string()),
        "openclaw_status": value_string_any(raw, &["openclawStatus", "openclaw_status"]).unwrap_or_default(),
        "comm_level": value_i64_any(raw, &["commLevel", "comm_level"]),
        "ext_receive_type": value_i64_any(raw, &["extReceiveType", "ext_receive_type"]),
        "ext_send_type": value_i64_any(raw, &["extSendType", "ext_send_type"])
    })
}

fn parse_claw_dashboard_response(response: reqwest::blocking::Response) -> Result<Value, ApiError> {
    let status = response.status();
    let text = response
        .text()
        .map_err(|err| ApiError::new(500, format!("Claw Dashboard read failed: {err}")))?;
    if text.trim().is_empty() {
        if status.is_success() {
            return Ok(Value::Null);
        }
        return Err(ApiError::new(
            500,
            format!("Claw Dashboard HTTP {}", status.as_u16()),
        ));
    }

    let body: Value = serde_json::from_str(&text).map_err(|_| {
        ApiError::new(
            500,
            format!(
                "Claw Dashboard 返回了非 JSON 内容：HTTP {}",
                status.as_u16()
            ),
        )
    })?;
    let ok = body
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let code = body.get("code").and_then(Value::as_i64).unwrap_or_default();
    if !status.is_success() || !ok || code != 200 {
        let message = body
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("Claw Dashboard request failed");
        return Err(ApiError::new(500, format!("{message}")));
    }
    Ok(body.get("result").cloned().unwrap_or(Value::Null))
}

fn read_set_cookie(headers: &reqwest::header::HeaderMap) -> String {
    headers
        .get_all(SET_COOKIE)
        .iter()
        .filter_map(|value| value.to_str().ok())
        .filter_map(|value| value.split(';').next())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>()
        .join("; ")
}

fn collect_items(value: &Value, keys: &[&str]) -> Vec<Value> {
    if let Some(array) = value.as_array() {
        return array.clone();
    }
    for key in keys {
        if let Some(array) = value.get(*key).and_then(Value::as_array) {
            return array.clone();
        }
    }
    Vec::new()
}

fn select_active(items: Vec<Value>) -> Option<Value> {
    let first = items.first().cloned();
    items
        .into_iter()
        .find(|item| {
            item.get("active").and_then(Value::as_bool).unwrap_or(false)
                || item
                    .get("isActive")
                    .and_then(Value::as_bool)
                    .unwrap_or(false)
                || item
                    .get("isDefault")
                    .and_then(Value::as_bool)
                    .unwrap_or(false)
                || value_string_any(item, &["status"])
                    .map(|s| s.eq_ignore_ascii_case("active"))
                    .unwrap_or(false)
        })
        .or(first)
}

fn select_primary_mailbox(items: &[Value]) -> Option<Value> {
    items
        .iter()
        .find(|item| {
            value_string_any(item, &["mailboxType", "mailbox_type"])
                .map(|v| v.eq_ignore_ascii_case("primary"))
                .unwrap_or(false)
        })
        .cloned()
        .or_else(|| {
            items
                .iter()
                .find(|item| {
                    value_string_any(item, &["email"])
                        .and_then(|email| {
                            email.split_once('@').map(|(local, _)| !local.contains('.'))
                        })
                        .unwrap_or(false)
                })
                .cloned()
        })
        .or_else(|| items.first().cloned())
}

fn mailbox_root_prefix(mailbox: &Value) -> String {
    value_string_any(mailbox, &["prefix"])
        .or_else(|| value_string_any(mailbox, &["email"]))
        .unwrap_or_default()
        .split('@')
        .next()
        .unwrap_or("")
        .split('.')
        .next()
        .unwrap_or("")
        .to_string()
}

fn normalize_claw_comm_payload(input: Value) -> Result<Value, ApiError> {
    let comm_level = value_i64_any(&input, &["commLevel", "comm_level"])
        .ok_or_else(|| ApiError::new(400, "Claw commLevel 不能为空。"))?;
    if !(0..=2).contains(&comm_level) {
        return Err(ApiError::new(400, "Claw commLevel 必须是 0-2 的整数。"));
    }
    if comm_level != 2 {
        return Ok(json!({ "commLevel": comm_level }));
    }
    let ext_receive_type = value_i64_any(&input, &["extReceiveType", "ext_receive_type"])
        .ok_or_else(|| ApiError::new(400, "Claw extReceiveType 在外部通讯模式下不能为空。"))?;
    let ext_send_type = value_i64_any(&input, &["extSendType", "ext_send_type"])
        .ok_or_else(|| ApiError::new(400, "Claw extSendType 在外部通讯模式下不能为空。"))?;
    if !(0..=1).contains(&ext_receive_type) || !(0..=1).contains(&ext_send_type) {
        return Err(ApiError::new(
            400,
            "Claw extReceiveType/extSendType 必须是 0-1 的整数。",
        ));
    }
    Ok(
        json!({ "commLevel": comm_level, "extReceiveType": ext_receive_type, "extSendType": ext_send_type }),
    )
}

fn apply_default_comm_fields(mailbox: &mut Value) {
    if let Some(object) = mailbox.as_object_mut() {
        object.insert("commLevel".to_string(), json!(2));
        object.insert("extReceiveType".to_string(), json!(1));
        object.insert("extSendType".to_string(), json!(1));
    }
}

fn value_string_any(value: &Value, keys: &[&str]) -> Option<String> {
    for key in keys {
        let Some(item) = value.get(*key) else {
            continue;
        };
        if let Some(text) = item.as_str() {
            if !text.trim().is_empty() {
                return Some(text.trim().to_string());
            }
        } else if let Some(number) = item.as_i64() {
            return Some(number.to_string());
        } else if let Some(number) = item.as_u64() {
            return Some(number.to_string());
        }
    }
    None
}

fn value_i64_any(value: &Value, keys: &[&str]) -> Option<i64> {
    for key in keys {
        let Some(item) = value.get(*key) else {
            continue;
        };
        if let Some(number) = item.as_i64() {
            return Some(number);
        }
        if let Some(text) = item.as_str() {
            if let Ok(number) = text.trim().parse::<i64>() {
                return Some(number);
            }
        }
    }
    None
}

fn extract_auth_url(command: &str) -> String {
    let Some(index) = command.find("--auth-url") else {
        return String::new();
    };
    let rest = command[index + "--auth-url".len()..].trim_start();
    if let Some(stripped) = rest.strip_prefix('"') {
        return stripped.split('"').next().unwrap_or("").to_string();
    }
    rest.split_whitespace().next().unwrap_or("").to_string()
}

fn is_email(value: &str) -> bool {
    let value = value.trim();
    let Some((local, domain)) = value.split_once('@') else {
        return false;
    };
    !local.is_empty() && domain.contains('.') && !domain.starts_with('.') && !domain.ends_with('.')
}

fn http_client() -> Result<reqwest::blocking::Client, ApiError> {
    reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(30))
        .user_agent("OutlookMailManager.Native/0.1")
        .build()
        .map_err(|err| ApiError::new(500, format!("create HTTP client failed: {err}")))
}

fn url_encode(value: &str) -> String {
    url::form_urlencoded::byte_serialize(value.as_bytes()).collect()
}

fn claw_sync_mailbox(conn: &Connection, mailbox_email: &str) -> Result<Value, ApiError> {
    let mailbox_email = mailbox_email.trim().to_lowercase();
    if !is_email(&mailbox_email) {
        return Err(ApiError::new(400, "Claw 收件邮箱格式不正确。"));
    }
    if !claw_mailbox_exists(conn, &mailbox_email)? {
        return Err(ApiError::new(
            404,
            format!("Claw 邮箱未纳管：{mailbox_email}"),
        ));
    }

    let settings = load_claw_settings(conn);
    let api_key = require_claw_setting(&settings, "apiKey")?;
    let client = http_client()?;
    let token = claw_access_token(&client, &api_key, &mailbox_email)?;
    let remote_ids = claw_list_remote_message_ids(&client, &token, &mailbox_email, 500)?;
    let remote_set: std::collections::HashSet<String> = remote_ids.iter().cloned().collect();
    let local_ids = claw_provider_ids(conn, &mailbox_email)?;
    let stale_ids: Vec<String> = local_ids
        .into_iter()
        .filter(|id| !remote_set.contains(id))
        .collect();
    claw_delete_provider_ids(conn, &mailbox_email, &stale_ids)?;

    let mut saved_count = 0;
    for provider_id in &remote_ids {
        if claw_mail_exists(conn, &mailbox_email, provider_id)? {
            continue;
        }
        let mail = claw_read_remote_mail(&client, &token, &mailbox_email, provider_id)?;
        upsert_claw_mail(conn, &mailbox_email, provider_id, &mail)?;
        saved_count += 1;
    }

    Ok(json!({
        "requested": true,
        "mailboxEmail": mailbox_email,
        "remoteCount": remote_ids.len(),
        "savedCount": saved_count,
        "deletedStaleCount": stale_ids.len(),
        "source": "coremail-proxy",
        "message": if remote_ids.is_empty() {
            "Claw 远端收件箱当前没有返回邮件。".to_string()
        } else {
            format!("Claw 远端返回 {} 封，新增缓存 {} 封。", remote_ids.len(), saved_count)
        }
    }))
}

fn claw_sync_all_mailboxes(conn: &Connection) -> Result<Value, ApiError> {
    let mailboxes = claw_mailbox_emails(conn)?;
    let mut remote_count = 0;
    let mut saved_count = 0;
    let mut deleted_stale_count = 0;
    for mailbox in &mailboxes {
        let report = claw_sync_mailbox(conn, mailbox)?;
        remote_count += report
            .get("remoteCount")
            .and_then(Value::as_i64)
            .unwrap_or(0);
        saved_count += report
            .get("savedCount")
            .and_then(Value::as_i64)
            .unwrap_or(0);
        deleted_stale_count += report
            .get("deletedStaleCount")
            .and_then(Value::as_i64)
            .unwrap_or(0);
    }
    Ok(json!({
        "requested": true,
        "mailboxEmail": "",
        "remoteCount": remote_count,
        "savedCount": saved_count,
        "deletedStaleCount": deleted_stale_count,
        "source": "coremail-proxy",
        "message": format!("已同步 {} 个 Claw 子邮箱。", mailboxes.len())
    }))
}

fn claw_access_token(
    client: &reqwest::blocking::Client,
    api_key: &str,
    uid: &str,
) -> Result<String, ApiError> {
    let response = client
        .post(CLAW_TOKEN_URL)
        .header(AUTHORIZATION, format!("Bearer {api_key}"))
        .header(CONTENT_TYPE, "application/json")
        .json(&json!({ "uid": uid }))
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw token failed: {err}")))?;
    let status = response.status();
    let body: Value = response
        .json()
        .map_err(|err| ApiError::new(500, format!("parse Claw token response failed: {err}")))?;
    if !status.is_success() {
        return Err(ApiError::new(
            500,
            format!("Claw token HTTP {}: {}", status.as_u16(), body),
        ));
    }
    body.get("result")
        .and_then(|v| v.get("accessToken"))
        .and_then(Value::as_str)
        .map(str::to_string)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| ApiError::new(500, "Claw token response missing accessToken."))
}

fn claw_coremail_call(
    client: &reqwest::blocking::Client,
    token: &str,
    uid: &str,
    func: &str,
    payload: &Value,
) -> Result<Value, ApiError> {
    let response = client
        .post(CLAW_COREMAIL_PROXY_URL)
        .query(&[("uid", uid), ("func", func)])
        .header(AUTHORIZATION, format!("Bearer {token}"))
        .header(CONTENT_TYPE, "application/json")
        .json(payload)
        .send()
        .map_err(|err| ApiError::new(500, format!("Claw Coremail request failed: {err}")))?;
    parse_claw_coremail_response(response)
}

fn parse_claw_coremail_response(response: reqwest::blocking::Response) -> Result<Value, ApiError> {
    let status = response.status();
    let text = response
        .text()
        .map_err(|err| ApiError::new(500, format!("Claw Coremail read failed: {err}")))?;
    let body: Value = serde_json::from_str(&text).map_err(|_| {
        ApiError::new(
            500,
            format!("Claw Coremail 返回了非 JSON 内容：HTTP {}", status.as_u16()),
        )
    })?;
    let code = body.get("code").and_then(Value::as_str).unwrap_or("");
    if !status.is_success() || code != "S_OK" {
        let message = body
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("Claw Coremail request failed");
        return Err(ApiError::new(500, format!("{message}: {body}")));
    }
    Ok(body.get("var").cloned().unwrap_or(Value::Null))
}

fn claw_list_remote_message_ids(
    client: &reqwest::blocking::Client,
    token: &str,
    mailbox_email: &str,
    max_messages: i64,
) -> Result<Vec<String>, ApiError> {
    let mut ids = Vec::new();
    let page_size = 100;
    let mut start = 0;
    while start < max_messages {
        let limit = (max_messages - start).min(page_size);
        let messages = claw_coremail_call(
            client,
            token,
            mailbox_email,
            "mbox:listMessages",
            &json!({
                "fid": 1,
                "order": "date",
                "desc": true,
                "start": start,
                "limit": limit
            }),
        )?;
        let items = messages.as_array().cloned().unwrap_or_default();
        for item in &items {
            if let Some(id) = value_string_any(item, &["id"]) {
                ids.push(id);
            }
        }
        if items.len() < limit as usize {
            break;
        }
        start += limit;
    }
    ids.sort();
    ids.dedup();
    ids.reverse();
    Ok(ids)
}

fn claw_read_remote_mail(
    client: &reqwest::blocking::Client,
    token: &str,
    mailbox_email: &str,
    provider_id: &str,
) -> Result<Value, ApiError> {
    claw_coremail_call(
        client,
        token,
        mailbox_email,
        "mbox:readMessage",
        &json!({
            "id": provider_id,
            "mode": "html",
            "markRead": false,
            "header": true,
            "securityLevel": 1,
            "filterLinks": false,
            "filterImages": false
        }),
    )
}

fn upsert_claw_mail(
    conn: &Connection,
    mailbox_email: &str,
    provider_id: &str,
    mail: &Value,
) -> Result<(), ApiError> {
    let sender = first_json_string(mail.get("from")).unwrap_or_default();
    let recipients = serde_json::to_string(&json_string_array(mail.get("to"))).unwrap_or_default();
    let text_content = mail
        .get("text")
        .and_then(|v| v.get("content"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let html_content = mail
        .get("html")
        .and_then(|v| v.get("content"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let raw_json = serde_json::to_string(mail).unwrap_or_default();
    let has_attachments = mail
        .get("attachments")
        .and_then(Value::as_array)
        .map(|items| !items.is_empty())
        .unwrap_or(false);
    let received_at =
        value_string_any(mail, &["date", "sentDate", "receivedDate"]).unwrap_or_default();

    conn.execute(
        "INSERT INTO claw_mail_cache (
            provider_mail_id, mailbox_email, sender, sender_name, recipients, subject,
            text_content, html_content, raw_json, header_raw, has_attachments, received_at,
            cached_at
        ) VALUES (?, ?, ?, '', ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(mailbox_email, provider_mail_id) DO UPDATE SET
            sender = excluded.sender,
            recipients = excluded.recipients,
            subject = excluded.subject,
            text_content = excluded.text_content,
            html_content = excluded.html_content,
            raw_json = excluded.raw_json,
            header_raw = excluded.header_raw,
            has_attachments = excluded.has_attachments,
            received_at = excluded.received_at,
            cached_at = CURRENT_TIMESTAMP",
        params![
            provider_id,
            mailbox_email,
            sender,
            recipients,
            value_string_any(mail, &["subject"]).unwrap_or_default(),
            text_content,
            html_content,
            raw_json,
            value_string_any(mail, &["headerRaw", "header_raw"]).unwrap_or_default(),
            if has_attachments { 1 } else { 0 },
            received_at
        ],
    )?;
    Ok(())
}

fn claw_mailbox_exists(conn: &Connection, email: &str) -> Result<bool, ApiError> {
    let count = count_i64(
        conn,
        "SELECT COUNT(*) FROM claw_mailboxes WHERE email = ? AND status != 'deleted'",
        &[&email],
    )?;
    Ok(count > 0)
}

fn claw_mailbox_emails(conn: &Connection) -> Result<Vec<String>, ApiError> {
    let mut stmt = conn
        .prepare("SELECT email FROM claw_mailboxes WHERE status != 'deleted' ORDER BY email ASC")?;
    let rows = stmt
        .query_map([], |row| row.get::<_, String>(0))?
        .collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)?;
    Ok(rows)
}

fn claw_provider_ids(conn: &Connection, mailbox_email: &str) -> Result<Vec<String>, ApiError> {
    let mut stmt =
        conn.prepare("SELECT provider_mail_id FROM claw_mail_cache WHERE mailbox_email = ?")?;
    let rows = stmt
        .query_map([mailbox_email], |row| row.get::<_, String>(0))?
        .collect::<rusqlite::Result<Vec<_>>>()
        .map_err(ApiError::from)?;
    Ok(rows)
}

fn claw_mail_exists(
    conn: &Connection,
    mailbox_email: &str,
    provider_id: &str,
) -> Result<bool, ApiError> {
    let count = count_i64(
        conn,
        "SELECT COUNT(*) FROM claw_mail_cache WHERE mailbox_email = ? AND provider_mail_id = ?",
        &[&mailbox_email, &provider_id],
    )?;
    Ok(count > 0)
}

fn claw_delete_provider_ids(
    conn: &Connection,
    mailbox_email: &str,
    provider_ids: &[String],
) -> Result<(), ApiError> {
    for provider_id in provider_ids {
        conn.execute(
            "DELETE FROM claw_mail_cache WHERE mailbox_email = ? AND provider_mail_id = ?",
            params![mailbox_email, provider_id],
        )?;
    }
    Ok(())
}

fn first_json_string(value: Option<&Value>) -> Option<String> {
    match value {
        Some(Value::String(text)) => Some(text.clone()),
        Some(Value::Array(items)) => items.iter().find_map(|item| match item {
            Value::String(text) => Some(text.clone()),
            _ => None,
        }),
        _ => None,
    }
}

fn json_string_array(value: Option<&Value>) -> Vec<String> {
    match value {
        Some(Value::String(text)) if !text.trim().is_empty() => vec![text.trim().to_string()],
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(|item| item.as_str().map(str::trim).map(str::to_string))
            .filter(|text| !text.is_empty())
            .collect(),
        _ => Vec::new(),
    }
}

fn claw_mails(conn: &Connection, query: &HashMap<String, String>) -> Result<Value, ApiError> {
    let mailbox = query.get("mailbox").map(String::as_str).unwrap_or("");
    let page = parse_query_i64(query, "page", 1).max(1);
    let page_size = parse_query_i64(query, "pageSize", 100).clamp(1, 500);
    let sync_requested = query
        .get("sync")
        .map(|v| v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);
    let sync_report = if sync_requested {
        if mailbox.trim().is_empty() {
            claw_sync_all_mailboxes(conn)?
        } else {
            claw_sync_mailbox(conn, mailbox)?
        }
    } else {
        json!({
            "requested": false,
            "mailboxEmail": mailbox,
            "remoteCount": 0,
            "savedCount": 0,
            "deletedStaleCount": 0,
            "source": "cache",
            "message": "仅读取本地缓存。"
        })
    };
    let offset = (page - 1) * page_size;
    let total = count_i64(
        conn,
        "SELECT COUNT(*) FROM claw_mail_cache WHERE mailbox_email = ?",
        &[&mailbox],
    )
    .unwrap_or(0);
    let mut stmt = conn.prepare("SELECT id, mailbox_email, sender, sender_name, subject, text_content, html_content, received_at FROM claw_mail_cache WHERE mailbox_email = ? ORDER BY received_at DESC LIMIT ? OFFSET ?")?;
    let list = stmt
        .query_map(params![mailbox, page_size, offset], |row| {
            Ok(json!({
                "id": row.get::<_, i64>(0)?,
                "mailbox_email": row.get::<_, String>(1)?,
                "sender": row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                "sender_name": row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                "subject": row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                "text_content": row.get::<_, Option<String>>(5)?.unwrap_or_default(),
                "html_content": row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                "received_at": row.get::<_, Option<String>>(7)?.unwrap_or_default()
            }))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(json!({
        "list": list,
        "total": total,
        "sync": sync_report
    }))
}

fn count_i64(
    conn: &Connection,
    sql: &str,
    params: &[&dyn rusqlite::ToSql],
) -> rusqlite::Result<i64> {
    conn.query_row(sql, params, |row| row.get::<_, i64>(0))
}

fn parse_query_i64(query: &HashMap<String, String>, key: &str, default: i64) -> i64 {
    query
        .get(key)
        .and_then(|v| v.parse::<i64>().ok())
        .unwrap_or(default)
}

fn respond_json(request: Request, status: u16, value: Value) -> Result<(), String> {
    let body = serde_json::to_string(&value).map_err(|err| err.to_string())?;
    let response = Response::from_string(body)
        .with_status_code(status)
        .with_header(
            Header::from_bytes(
                &b"Content-Type"[..],
                &b"application/json; charset=utf-8"[..],
            )
            .unwrap(),
        )
        .with_header(Header::from_bytes(&b"Access-Control-Allow-Origin"[..], &b"*"[..]).unwrap());
    request.respond(response).map_err(|err| err.to_string())
}

fn respond_html(request: Request, title: String, message: String) -> Result<(), String> {
    let body = format!(
        r#"<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{}</title>
  <style>
    body{{margin:0;min-height:100vh;display:grid;place-items:center;background:#eef4ff;font-family:Segoe UI,Arial,sans-serif;color:#223047}}
    main{{width:min(520px,calc(100vw - 48px));padding:34px;border-radius:28px;background:rgba(255,255,255,.86);box-shadow:0 24px 80px rgba(37,99,235,.16)}}
    h1{{margin:0 0 12px;font-size:28px}}p{{margin:0;font-size:15px;line-height:1.7;color:#5f6f85}}
  </style>
</head>
<body><main><h1>{}</h1><p>{}</p></main></body>
</html>"#,
        escape_html(&title),
        escape_html(&title),
        escape_html(&message)
    );
    let response = Response::from_string(body)
        .with_status_code(200)
        .with_header(
            Header::from_bytes(&b"Content-Type"[..], &b"text/html; charset=utf-8"[..]).unwrap(),
        );
    request.respond(response).map_err(|err| err.to_string())
}

fn escape_html(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

struct ApiError {
    code: u16,
    message: String,
}

impl ApiError {
    fn new(code: u16, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl From<rusqlite::Error> for ApiError {
    fn from(value: rusqlite::Error) -> Self {
        Self::new(500, value.to_string())
    }
}
