use crate::session::CadSession;
use kawacad_core::document::ProjectDocument;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;
use tauri::Manager;

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct RecoveryMetadata {
    pub(crate) display_name: String,
    pub(crate) original_document_path: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct RecoveryCandidate {
    pub(crate) id: String,
    pub(crate) display_name: String,
    pub(crate) original_document_path: Option<String>,
    pub(crate) updated_at_ms: u64,
    pub(crate) status: String,
    pub(crate) details: Option<String>,
}
pub(crate) fn application_data_directory(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map_err(|error| format!("Could not determine the application data directory: {error}"))
}

pub(crate) fn application_data_path(app: &tauri::AppHandle, name: &str) -> Result<PathBuf, String> {
    application_data_directory(app).map(|directory| directory.join(name))
}

pub(crate) fn recovery_directory(
    base_directory: &Path,
    candidate_id: &str,
) -> Result<PathBuf, String> {
    if candidate_id.is_empty()
        || !candidate_id.chars().all(|character| {
            character.is_ascii_alphanumeric() || character == '-' || character == '_'
        })
    {
        return Err("Invalid recovery candidate identifier".to_owned());
    }
    Ok(base_directory.join("Recovery").join(candidate_id))
}

pub(crate) fn recovery_paths(
    base_directory: &Path,
    candidate_id: &str,
) -> Result<(PathBuf, PathBuf), String> {
    let directory = recovery_directory(base_directory, candidate_id)?;
    Ok((
        directory.join("snapshot.kawa"),
        directory.join("metadata.json"),
    ))
}

pub(crate) fn recovery_candidates_at(
    base_directory: &Path,
) -> Result<Vec<RecoveryCandidate>, String> {
    let root = base_directory.join("Recovery");
    if !root.exists() {
        return Ok(Vec::new());
    }
    let mut candidates = Vec::new();
    for entry in fs::read_dir(&root)
        .map_err(|error| format!("Could not read recovery directory: {error}"))?
    {
        let entry = entry.map_err(|error| format!("Could not read recovery candidate: {error}"))?;
        if !entry.path().is_dir() {
            continue;
        }
        let id = entry.file_name().to_string_lossy().to_string();
        let (snapshot_path, metadata_path) = recovery_paths(base_directory, &id)?;
        let updated_at_ms = snapshot_path
            .metadata()
            .or_else(|_| entry.metadata())
            .and_then(|metadata| metadata.modified())
            .ok()
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map(|duration| duration.as_millis() as u64)
            .unwrap_or(0);
        let metadata = fs::read_to_string(&metadata_path)
            .map_err(|error| format!("Could not read recovery metadata: {error}"))
            .and_then(|contents| {
                serde_json::from_str::<RecoveryMetadata>(&contents)
                    .map_err(|error| format!("Could not read recovery metadata: {error}"))
            });
        let snapshot_validation = ProjectDocument::read_json_file(&snapshot_path)
            .map(|_| ())
            .map_err(|error| format!("Could not validate recovery snapshot: {error:?}"));
        match (metadata, snapshot_validation) {
            (Ok(metadata), Ok(())) => candidates.push(RecoveryCandidate {
                id,
                display_name: metadata.display_name,
                original_document_path: metadata.original_document_path,
                updated_at_ms,
                status: "recoverable".to_owned(),
                details: None,
            }),
            (metadata, snapshot) => {
                let details = metadata
                    .as_ref()
                    .err()
                    .cloned()
                    .or_else(|| snapshot.err())
                    .unwrap_or_else(|| "Recovery candidate is incomplete".to_owned());
                let (display_name, original_document_path) = metadata
                    .ok()
                    .map(|metadata| (metadata.display_name, metadata.original_document_path))
                    .unwrap_or_else(|| ("破損した復旧候補".to_owned(), None));
                candidates.push(RecoveryCandidate {
                    id,
                    display_name,
                    original_document_path,
                    updated_at_ms,
                    status: "broken".to_owned(),
                    details: Some(details),
                });
            }
        }
    }
    candidates.sort_by_key(|candidate| std::cmp::Reverse(candidate.updated_at_ms));
    Ok(candidates)
}

pub(crate) fn save_recovery_snapshot_at(
    session: &CadSession,
    base_directory: &Path,
) -> Result<(), String> {
    let (snapshot_path, metadata_path) =
        recovery_paths(base_directory, &session.recovery_candidate_id)?;
    let directory = snapshot_path
        .parent()
        .ok_or_else(|| "Could not determine recovery directory".to_owned())?;
    if !session.is_dirty() {
        if directory.exists() {
            fs::remove_dir_all(directory)
                .map_err(|error| format!("Could not remove clean recovery snapshot: {error}"))?;
        }
        return Ok(());
    }
    fs::create_dir_all(directory)
        .map_err(|error| format!("Could not create recovery directory: {error}"))?;
    let temporary_snapshot = snapshot_path.with_extension("kawa.tmp");
    session
        .document
        .write_json_file(&temporary_snapshot)
        .map_err(|error| format!("Could not write recovery snapshot: {error:?}"))?;
    fs::rename(&temporary_snapshot, &snapshot_path)
        .map_err(|error| format!("Could not commit recovery snapshot: {error}"))?;
    let metadata = RecoveryMetadata {
        display_name: session.document.metadata().name.clone(),
        original_document_path: session.path.clone(),
    };
    let contents = serde_json::to_vec_pretty(&metadata)
        .map_err(|error| format!("Could not serialize recovery metadata: {error}"))?;
    fs::write(metadata_path, contents)
        .map_err(|error| format!("Could not write recovery metadata: {error}"))
}

pub(crate) fn discard_recovery_snapshot_at(
    base_directory: &Path,
    candidate_id: &str,
) -> Result<(), String> {
    let (snapshot_path, _) = recovery_paths(base_directory, candidate_id)?;
    let directory = snapshot_path
        .parent()
        .ok_or_else(|| "Could not determine recovery directory".to_owned())?;
    if directory.exists() {
        fs::remove_dir_all(directory)
            .map_err(|error| format!("Could not discard recovery snapshot: {error}"))?;
    }
    Ok(())
}
