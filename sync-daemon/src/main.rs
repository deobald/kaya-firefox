use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use chrono::Utc;
use rand::RngCore;
use ring::aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use thiserror::Error;

const NONCE_LEN: usize = 12;
const KEY_LEN: usize = 32;

fn setup_logging() {
    let log_path = get_kaya_dir().join("log");

    let base = fern::Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{}] {}: {}",
                Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ"),
                record.level(),
                message
            ))
        })
        .level(log::LevelFilter::Info)
        .chain(io::stderr());

    let dispatch = if let Ok(log_file) = fern::log_file(&log_path) {
        base.chain(log_file)
    } else {
        eprintln!(
            "Warning: could not open log file {:?}, logging to stderr only",
            log_path
        );
        base
    };

    if let Err(e) = dispatch.apply() {
        eprintln!("Warning: failed to initialize logging: {}", e);
    }
}

#[derive(Error, Debug)]
enum KayaError {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("Base64 decode error: {0}")]
    Base64(#[from] base64::DecodeError),
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("Config error: {0}")]
    Config(String),
    #[error("Encryption error: {0}")]
    Encryption(String),
}

#[derive(Debug, Serialize, Deserialize)]
struct IncomingMessage {
    id: Option<u64>,
    message: String,
    filename: Option<String>,
    #[serde(rename = "type")]
    content_type: Option<String>,
    text: Option<String>,
    base64: Option<String>,
    server: Option<String>,
    email: Option<String>,
    password: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct OutgoingMessage {
    id: Option<u64>,
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    urls: Option<Vec<String>>,
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    message_type: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct Config {
    server: Option<String>,
    email: Option<String>,
    encrypted_password: Option<String>,
    encryption_key: Option<String>,
}

fn get_kaya_dir() -> PathBuf {
    dirs::home_dir()
        .expect("Could not find home directory")
        .join(".kaya")
}

fn get_anga_dir() -> PathBuf {
    get_kaya_dir().join("anga")
}

fn get_meta_dir() -> PathBuf {
    get_kaya_dir().join("meta")
}

fn get_config_path() -> PathBuf {
    get_kaya_dir().join(".config")
}

fn ensure_directories() -> io::Result<()> {
    fs::create_dir_all(get_anga_dir())?;
    fs::create_dir_all(get_meta_dir())?;
    Ok(())
}

fn generate_encryption_key() -> [u8; KEY_LEN] {
    let mut key = [0u8; KEY_LEN];
    rand::thread_rng().fill_bytes(&mut key);
    key
}

fn encrypt_password(password: &str, key: &[u8; KEY_LEN]) -> Result<String, KayaError> {
    let unbound_key = UnboundKey::new(&AES_256_GCM, key)
        .map_err(|e| KayaError::Encryption(format!("Failed to create key: {:?}", e)))?;
    let key = LessSafeKey::new(unbound_key);

    let mut nonce_bytes = [0u8; NONCE_LEN];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::assume_unique_for_key(nonce_bytes);

    let mut in_out = password.as_bytes().to_vec();
    key.seal_in_place_append_tag(nonce, Aad::empty(), &mut in_out)
        .map_err(|e| KayaError::Encryption(format!("Failed to encrypt: {:?}", e)))?;

    let mut result = nonce_bytes.to_vec();
    result.extend(in_out);
    Ok(BASE64.encode(&result))
}

fn decrypt_password(encrypted: &str, key: &[u8; KEY_LEN]) -> Result<String, KayaError> {
    let data = BASE64.decode(encrypted)?;
    if data.len() < NONCE_LEN + 16 {
        return Err(KayaError::Encryption("Invalid encrypted data".to_string()));
    }

    let (nonce_bytes, ciphertext) = data.split_at(NONCE_LEN);
    let nonce_array: [u8; NONCE_LEN] = nonce_bytes
        .try_into()
        .map_err(|_| KayaError::Encryption("Invalid nonce".to_string()))?;
    let nonce = Nonce::assume_unique_for_key(nonce_array);

    let unbound_key = UnboundKey::new(&AES_256_GCM, key)
        .map_err(|e| KayaError::Encryption(format!("Failed to create key: {:?}", e)))?;
    let key = LessSafeKey::new(unbound_key);

    let mut in_out = ciphertext.to_vec();
    let plaintext = key
        .open_in_place(nonce, Aad::empty(), &mut in_out)
        .map_err(|e| KayaError::Encryption(format!("Failed to decrypt: {:?}", e)))?;

    String::from_utf8(plaintext.to_vec())
        .map_err(|e| KayaError::Encryption(format!("Invalid UTF-8: {}", e)))
}

fn load_config() -> Result<Config, KayaError> {
    let path = get_config_path();
    if !path.exists() {
        return Ok(Config::default());
    }
    let content = fs::read_to_string(&path)?;
    let config: Config = toml::from_str(&content)
        .map_err(|e| KayaError::Config(format!("Invalid config: {}", e)))?;
    Ok(config)
}

fn save_config(config: &Config) -> Result<(), KayaError> {
    ensure_directories()?;
    let content = toml::to_string(config)
        .map_err(|e| KayaError::Config(format!("Failed to serialize: {}", e)))?;
    fs::write(get_config_path(), content)?;
    Ok(())
}

fn handle_config_message(msg: &IncomingMessage) -> Result<(), KayaError> {
    log::info!(
        "Received config message: server={:?}, email={:?}",
        msg.server,
        msg.email
    );

    let server = msg.server.clone();
    let email = msg.email.clone();
    let password = msg.password.clone();

    let key = generate_encryption_key();
    let encrypted_password = if let Some(ref pwd) = password {
        Some(encrypt_password(pwd, &key)?)
    } else {
        None
    };

    let config = Config {
        server,
        email,
        encrypted_password,
        encryption_key: Some(BASE64.encode(key)),
    };

    save_config(&config)?;
    Ok(())
}

fn handle_anga_message(msg: &IncomingMessage) -> Result<(), KayaError> {
    log::info!(
        "Received anga message: filename={:?}, type={:?}",
        msg.filename,
        msg.content_type
    );

    ensure_directories()?;

    let filename = msg
        .filename
        .as_ref()
        .ok_or_else(|| KayaError::Config("Missing filename".to_string()))?;

    let content = match msg.content_type.as_deref() {
        Some("base64") => {
            let b64 = msg
                .base64
                .as_ref()
                .ok_or_else(|| KayaError::Config("Missing base64 content".to_string()))?;
            BASE64.decode(b64)?
        }
        Some("text") | None => {
            let text = msg
                .text
                .as_ref()
                .ok_or_else(|| KayaError::Config("Missing text content".to_string()))?;
            text.as_bytes().to_vec()
        }
        Some(t) => return Err(KayaError::Config(format!("Unknown content type: {}", t))),
    };

    let path = get_anga_dir().join(filename);
    fs::write(&path, content)?;

    Ok(())
}

fn handle_meta_message(msg: &IncomingMessage) -> Result<(), KayaError> {
    log::info!("Received meta message: filename={:?}", msg.filename);

    ensure_directories()?;

    let filename = msg
        .filename
        .as_ref()
        .ok_or_else(|| KayaError::Config("Missing filename".to_string()))?;

    let text = msg
        .text
        .as_ref()
        .ok_or_else(|| KayaError::Config("Missing text content".to_string()))?;

    let path = get_meta_dir().join(filename);
    fs::write(&path, text)?;

    Ok(())
}

fn get_all_bookmarked_urls() -> Result<Vec<String>, KayaError> {
    let anga_dir = get_anga_dir();
    if !anga_dir.exists() {
        return Ok(Vec::new());
    }

    let mut urls = Vec::new();

    for entry in fs::read_dir(anga_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().map(|e| e == "url").unwrap_or(false) {
            if let Ok(content) = fs::read_to_string(&path) {
                for line in content.lines() {
                    if line.starts_with("URL=") {
                        urls.push(line[4..].to_string());
                    }
                }
            }
        }
    }

    Ok(urls)
}

fn read_native_message() -> Result<Option<IncomingMessage>, KayaError> {
    let stdin = io::stdin();
    let mut handle = stdin.lock();

    let mut len_bytes = [0u8; 4];
    match handle.read_exact(&mut len_bytes) {
        Ok(_) => {}
        Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e.into()),
    }

    let len = u32::from_ne_bytes(len_bytes) as usize;
    if len == 0 || len > 1024 * 1024 * 100 {
        return Err(KayaError::Config(format!(
            "Invalid message length: {}",
            len
        )));
    }

    let mut buffer = vec![0u8; len];
    handle.read_exact(&mut buffer)?;

    let message: IncomingMessage = serde_json::from_slice(&buffer)?;
    Ok(Some(message))
}

fn write_native_message(msg: &OutgoingMessage) -> Result<(), KayaError> {
    let json = serde_json::to_vec(msg)?;
    let len = (json.len() as u32).to_ne_bytes();

    let stdout = io::stdout();
    let mut handle = stdout.lock();
    handle.write_all(&len)?;
    handle.write_all(&json)?;
    handle.flush()?;

    Ok(())
}

fn sync_with_server() -> Result<(), KayaError> {
    let config = load_config()?;

    let server = match config.server {
        Some(s) => s,
        None => return Ok(()),
    };

    let email = match config.email {
        Some(e) => e,
        None => return Ok(()),
    };

    let password = match (&config.encrypted_password, &config.encryption_key) {
        (Some(enc), Some(key_b64)) => {
            let key_bytes = BASE64.decode(key_b64)?;
            let key: [u8; KEY_LEN] = key_bytes
                .try_into()
                .map_err(|_| KayaError::Encryption("Invalid key length".to_string()))?;
            decrypt_password(enc, &key)?
        }
        _ => return Ok(()),
    };

    let client = reqwest::blocking::Client::new();

    let (anga_downloaded, anga_uploaded) = sync_anga(&client, &server, &email, &password)?;
    let (meta_downloaded, meta_uploaded) = sync_meta(&client, &server, &email, &password)?;

    let total_downloaded = anga_downloaded + meta_downloaded;
    let total_uploaded = anga_uploaded + meta_uploaded;

    if total_downloaded > 0 || total_uploaded > 0 {
        log::info!(
            "Sync complete: {} downloaded, {} uploaded",
            total_downloaded,
            total_uploaded
        );
    }

    Ok(())
}

fn sync_anga(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
) -> Result<(usize, usize), KayaError> {
    let url = format!(
        "{}/api/v1/{}/anga",
        server.trim_end_matches('/'),
        urlencoding::encode(email)
    );

    let response = client.get(&url).basic_auth(email, Some(password)).send()?;

    if !response.status().is_success() {
        return Err(KayaError::Http(response.error_for_status().unwrap_err()));
    }

    let server_files: HashSet<String> = response
        .text()?
        .lines()
        .map(|l| {
            urlencoding::decode(l.trim())
                .unwrap_or_default()
                .to_string()
        })
        .filter(|s| !s.is_empty())
        .collect();

    let anga_dir = get_anga_dir();
    let local_files: HashSet<String> = if anga_dir.exists() {
        fs::read_dir(&anga_dir)?
            .filter_map(|e| e.ok())
            .filter(|e| e.path().is_file())
            .filter_map(|e| e.file_name().into_string().ok())
            .filter(|n| !n.starts_with('.'))
            .collect()
    } else {
        HashSet::new()
    };

    let to_download: Vec<_> = server_files.difference(&local_files).collect();
    let to_upload: Vec<_> = local_files.difference(&server_files).collect();

    let downloaded = to_download.len();
    let uploaded = to_upload.len();

    for filename in to_download {
        log::info!("  downloading anga: {}", filename);
        download_anga(client, server, email, password, filename)?;
    }

    for filename in to_upload {
        log::info!("  uploading anga: {}", filename);
        upload_anga(client, server, email, password, filename)?;
    }

    Ok((downloaded, uploaded))
}

fn download_anga(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
    filename: &str,
) -> Result<(), KayaError> {
    let url = format!(
        "{}/api/v1/{}/anga/{}",
        server.trim_end_matches('/'),
        urlencoding::encode(email),
        urlencoding::encode(filename)
    );

    let response = client.get(&url).basic_auth(email, Some(password)).send()?;

    if response.status().is_success() {
        let content = response.bytes()?;
        let path = get_anga_dir().join(filename);
        fs::write(path, content)?;
    }

    Ok(())
}

fn upload_anga(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
    filename: &str,
) -> Result<(), KayaError> {
    let path = get_anga_dir().join(filename);
    let content = fs::read(&path)?;

    let url = format!(
        "{}/api/v1/{}/anga/{}",
        server.trim_end_matches('/'),
        urlencoding::encode(email),
        urlencoding::encode(filename)
    );

    let content_type = mime_type_for(filename);

    let part = reqwest::blocking::multipart::Part::bytes(content)
        .file_name(filename.to_string())
        .mime_str(&content_type)
        .unwrap();

    let form = reqwest::blocking::multipart::Form::new().part("file", part);

    let response = client
        .post(&url)
        .basic_auth(email, Some(password))
        .multipart(form)
        .send()?;

    if response.status() == reqwest::StatusCode::CONFLICT {
        // File already exists, that's fine
    } else if !response.status().is_success() {
        log::error!("Failed to upload anga {}: {}", filename, response.status());
    }

    Ok(())
}

fn sync_meta(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
) -> Result<(usize, usize), KayaError> {
    let url = format!(
        "{}/api/v1/{}/meta",
        server.trim_end_matches('/'),
        urlencoding::encode(email)
    );

    let response = client.get(&url).basic_auth(email, Some(password)).send()?;

    if !response.status().is_success() {
        return Err(KayaError::Http(response.error_for_status().unwrap_err()));
    }

    let server_files: HashSet<String> = response
        .text()?
        .lines()
        .map(|l| {
            urlencoding::decode(l.trim())
                .unwrap_or_default()
                .to_string()
        })
        .filter(|s| !s.is_empty())
        .collect();

    let meta_dir = get_meta_dir();
    let local_files: HashSet<String> = if meta_dir.exists() {
        fs::read_dir(&meta_dir)?
            .filter_map(|e| e.ok())
            .filter(|e| e.path().is_file())
            .filter_map(|e| e.file_name().into_string().ok())
            .filter(|n| !n.starts_with('.') && n.ends_with(".toml"))
            .collect()
    } else {
        HashSet::new()
    };

    let to_download: Vec<_> = server_files.difference(&local_files).collect();
    let to_upload: Vec<_> = local_files.difference(&server_files).collect();

    let downloaded = to_download.len();
    let uploaded = to_upload.len();

    for filename in to_download {
        log::info!("  downloading meta: {}", filename);
        download_meta(client, server, email, password, filename)?;
    }

    for filename in to_upload {
        log::info!("  uploading meta: {}", filename);
        upload_meta(client, server, email, password, filename)?;
    }

    Ok((downloaded, uploaded))
}

fn download_meta(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
    filename: &str,
) -> Result<(), KayaError> {
    let url = format!(
        "{}/api/v1/{}/meta/{}",
        server.trim_end_matches('/'),
        urlencoding::encode(email),
        urlencoding::encode(filename)
    );

    let response = client.get(&url).basic_auth(email, Some(password)).send()?;

    if response.status().is_success() {
        let content = response.bytes()?;
        let path = get_meta_dir().join(filename);
        fs::write(path, content)?;
    }

    Ok(())
}

fn upload_meta(
    client: &reqwest::blocking::Client,
    server: &str,
    email: &str,
    password: &str,
    filename: &str,
) -> Result<(), KayaError> {
    let path = get_meta_dir().join(filename);
    let content = fs::read(&path)?;

    let url = format!(
        "{}/api/v1/{}/meta/{}",
        server.trim_end_matches('/'),
        urlencoding::encode(email),
        urlencoding::encode(filename)
    );

    let part = reqwest::blocking::multipart::Part::bytes(content)
        .file_name(filename.to_string())
        .mime_str("application/toml")
        .unwrap();

    let form = reqwest::blocking::multipart::Form::new().part("file", part);

    let response = client
        .post(&url)
        .basic_auth(email, Some(password))
        .multipart(form)
        .send()?;

    if response.status() == reqwest::StatusCode::CONFLICT {
        // File already exists, that's fine
    } else if !response.status().is_success() {
        log::error!("Failed to upload meta {}: {}", filename, response.status());
    }

    Ok(())
}

fn mime_type_for(filename: &str) -> String {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "md" => "text/markdown",
        "url" | "txt" => "text/plain",
        "json" => "application/json",
        "toml" => "application/toml",
        "pdf" => "application/pdf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        "html" | "htm" => "text/html",
        _ => "application/octet-stream",
    }
    .to_string()
}

fn main() {
    setup_logging();

    if let Err(e) = ensure_directories() {
        log::error!("Failed to create directories: {}", e);
        std::process::exit(1);
    }

    log::info!("Kaya sync daemon started");

    let running = Arc::new(AtomicBool::new(true));
    let running_clone = running.clone();

    thread::spawn(move || {
        while running_clone.load(Ordering::Relaxed) {
            if let Err(e) = sync_with_server() {
                log::error!("Sync error: {}", e);
            }
            thread::sleep(Duration::from_secs(60));
        }
    });

    loop {
        match read_native_message() {
            Ok(Some(msg)) => {
                let id = msg.id;
                let result = match msg.message.as_str() {
                    "config" => handle_config_message(&msg),
                    "anga" => handle_anga_message(&msg),
                    "meta" => handle_meta_message(&msg),
                    other => Err(KayaError::Config(format!(
                        "Unknown message type: {}",
                        other
                    ))),
                };

                let response = match result {
                    Ok(_) => {
                        let urls = get_all_bookmarked_urls().ok();
                        OutgoingMessage {
                            id,
                            success: true,
                            error: None,
                            urls,
                            message_type: Some("bookmarks".to_string()),
                        }
                    }
                    Err(e) => OutgoingMessage {
                        id,
                        success: false,
                        error: Some(e.to_string()),
                        urls: None,
                        message_type: None,
                    },
                };

                if let Err(e) = write_native_message(&response) {
                    log::error!("Failed to write response: {}", e);
                }
            }
            Ok(None) => {
                running.store(false, Ordering::Relaxed);
                log::info!("Kaya sync daemon shutting down");
                break;
            }
            Err(e) => {
                log::error!("Error reading message: {}", e);
                let response = OutgoingMessage {
                    id: None,
                    success: false,
                    error: Some(e.to_string()),
                    urls: None,
                    message_type: None,
                };
                let _ = write_native_message(&response);
            }
        }
    }
}
