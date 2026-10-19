use std::str;

use axum::{Json, Router, http::Method, http::StatusCode, routing::get};
use serde::Serialize;
use tokio::{net::TcpListener, process::Command, sync::Mutex};
use tower_http::cors::{Any, CorsLayer};

#[derive(Serialize)]
struct JsonResponse {
    command: String,
    combined_output: String,
}

// Only one command may run at a time
static RUN_LOCK: Mutex<()> = Mutex::const_new(());

async fn run(command: &'static str, args: &'static [&'static str]) -> (StatusCode, Json<JsonResponse>) {
    let _lock = RUN_LOCK.lock().await;

    let command_str = format!("{} {:?}", command, args);

    let (status, combined_output) = match Command::new(command).args(args).output().await {
        Ok(output) => {
            let stdout = str::from_utf8(&output.stdout).unwrap_or("Invalid UTF-8 in stdout");
            let stderr = str::from_utf8(&output.stderr).unwrap_or("Invalid UTF-8 in stderr");
            (StatusCode::OK, format!("{}\n{}", stdout, stderr))
        }
        Err(err) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Failed to execute command: {}", err),
        ),
    };

    (
        status,
        Json(JsonResponse {
            command: command_str,
            combined_output,
        }),
    )
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> std::io::Result<()> {
    println!("*******************************************");
    println!("qemu-openwrt-web-backend");
    println!("*******************************************");

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers(Any);

    let app = Router::new()
        .route("/reboot", get(|| run("/run/qemu_qmp.sh", &["-R"])))
        .route("/reset", get(|| run("/run/qemu_qmp.sh", &["-r"])))
        .route("/get_openwrt_info", get(|| run("/run/qemu_qmp.sh", &["-V"])))
        .route("/get_container_info", get(|| run("cat", &["/var/www/system_info.txt"])))
        .route("/factory_reset", get(|| run("/run/factory_reset.sh", &[])))
        .route("/get_openwrt_ip_addresses", get(|| run("/run/qemu_qmp.sh", &["-c", "ip -json addr"])))
        .route("/get_luci_web_button_json", get(|| run("sh", &["-c", "echo $LUCI_WEB_BUTTON_JSON"])))
        .layer(cors);

    let listener = TcpListener::bind("127.0.0.1:8080").await?;
    axum::serve(listener, app).await
}
