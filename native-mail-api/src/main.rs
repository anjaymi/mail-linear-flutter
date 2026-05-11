#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;
use std::fs;
use std::sync::Arc;
use std::thread;

use tiny_http::Server;

mod app;
mod db;
mod error;
mod http;
mod process_watcher;
mod routes;

use crate::app::AppState;
use crate::db::connection::{open_database, resolve_db_path};
use crate::db::legacy::migrate_legacy_if_needed;
use crate::db::migrations::run_migrations;
use crate::process_watcher::watch_parent_process;
use crate::routes::handle_request;

fn main() {
    let port = env::var("PORT")
        .ok()
        .and_then(|v| v.parse::<u16>().ok())
        .unwrap_or(3000);
    let db_path = resolve_db_path();
    if let Some(parent) = db_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let conn = open_database(&db_path).expect("open sqlite database");
    run_migrations(&conn).expect("run migrations");
    migrate_legacy_if_needed(&conn, &db_path);
    drop(conn);

    watch_parent_process();

    let bind = format!("127.0.0.1:{port}");
    let server = Server::http(&bind).expect("bind native api server");
    eprintln!("[READY] Rust native API running on http://{bind}");

    let state = Arc::new(AppState { db_path });
    for request in server.incoming_requests() {
        let state = state.clone();
        thread::spawn(move || {
            if let Err(err) = handle_request(request, state) {
                eprintln!("[ERROR] {err}");
            }
        });
    }
}
