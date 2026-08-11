pub mod direct_print;

use kawacad_core::command::{DocumentCommand, SelectionReference};
use kawacad_core::constraints::{ConstraintKind, ConstraintTarget, ConstraintValue};
use kawacad_core::document::DerivedElementPreflightKind;
use kawacad_core::document::ProjectDocument;
use kawacad_core::geometry::Point2;
use kawacad_core::output::{
    BuildOutputDocumentModelOptions, BuildOutputDocumentModelResult, OutputDocumentModel,
    PrintableAreaMm,
};
use kawacad_core::print::PrintOrientation;
use kawacad_core::snapshot::CanvasViewMode;
use kawacad_output_engine::render_pdf;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;
use std::time::{Instant, SystemTime, UNIX_EPOCH};
use tauri::Manager;

struct CadSession {
    document: ProjectDocument,
    clean_document: ProjectDocument,
    view_mode: CanvasViewMode,
    path: Option<String>,
    recovered_dirty: bool,
    recovery_candidate_id: String,
}

static RECOVERY_SESSION_SEQUENCE: AtomicU64 = AtomicU64::new(0);

fn new_recovery_candidate_id() -> String {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or(0);
    let sequence = RECOVERY_SESSION_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    format!(
        "{timestamp:032x}-{:08x}-{sequence:016x}",
        std::process::id()
    )
}

impl CadSession {
    fn new(name: String) -> Self {
        let document = ProjectDocument::new(name);
        Self {
            clean_document: document.clone(),
            document,
            view_mode: CanvasViewMode::EditDisplay,
            path: None,
            recovered_dirty: false,
            recovery_candidate_id: new_recovery_candidate_id(),
        }
    }

    fn is_dirty(&self) -> bool {
        self.recovered_dirty || self.document != self.clean_document
    }
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct RecoveryMetadata {
    display_name: String,
    original_document_path: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RecoveryCandidate {
    id: String,
    display_name: String,
    original_document_path: Option<String>,
    updated_at_ms: u64,
    status: String,
    details: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PdfOutputOptions {
    orientation: PrintOrientation,
    include_dimension_labels: bool,
    include_scale_guide: bool,
    rotation_deg: u16,
}

fn application_data_directory(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map_err(|error| format!("Could not determine the application data directory: {error}"))
}

fn application_data_path(app: &tauri::AppHandle, name: &str) -> Result<PathBuf, String> {
    application_data_directory(app).map(|directory| directory.join(name))
}

fn recovery_directory(base_directory: &Path, candidate_id: &str) -> Result<PathBuf, String> {
    if candidate_id.is_empty()
        || !candidate_id.chars().all(|character| {
            character.is_ascii_alphanumeric() || character == '-' || character == '_'
        })
    {
        return Err("Invalid recovery candidate identifier".to_owned());
    }
    Ok(base_directory.join("Recovery").join(candidate_id))
}

fn recovery_paths(base_directory: &Path, candidate_id: &str) -> Result<(PathBuf, PathBuf), String> {
    let directory = recovery_directory(base_directory, candidate_id)?;
    Ok((
        directory.join("snapshot.kawa"),
        directory.join("metadata.json"),
    ))
}

fn recovery_candidates_at(base_directory: &Path) -> Result<Vec<RecoveryCandidate>, String> {
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

fn save_recovery_snapshot_at(session: &CadSession, base_directory: &Path) -> Result<(), String> {
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

fn discard_recovery_snapshot_at(base_directory: &Path, candidate_id: &str) -> Result<(), String> {
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

struct AppState {
    cad_session: Mutex<CadSession>,
    prepared_prints: Mutex<direct_print::PreparedPrintStore<direct_print::PreparedDirectPrint>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ParameterUsage {
    id: String,
    name: String,
    value_mm: f64,
    unit: kawacad_core::parameters::ParameterUnit,
    memo: String,
    usage_count: usize,
    used_constraint_ids: Vec<String>,
}

fn parameters_with_usage(document: &ProjectDocument) -> Vec<ParameterUsage> {
    document
        .parameters()
        .iter()
        .map(|parameter| {
            let used_constraint_ids = document
                .constraints()
                .iter()
                .filter(|constraint| {
                    !constraint.id.starts_with("constraint:implicit:")
                        && matches!(
                            &constraint.value,
                            Some(ConstraintValue::Parameter(parameter_id)) if parameter_id == &parameter.id
                        )
                })
                .map(|constraint| constraint.id.clone());
            let used_derived_element_ids = document
                .derived_elements()
                .iter()
                .filter(|derived_element| match &derived_element.kind {
                    kawacad_core::derived::DerivedElementKind::OffsetCurve(offset_curve) => matches!(
                        &offset_curve.distance,
                        ConstraintValue::Parameter(parameter_id) if parameter_id == &parameter.id
                    ),
                    kawacad_core::derived::DerivedElementKind::Fillet(fillet) => matches!(
                        &fillet.radius,
                        ConstraintValue::Parameter(parameter_id) if parameter_id == &parameter.id
                    ),
                })
                .map(|derived_element| derived_element.id.clone());
            let used_constraint_ids = used_constraint_ids
                .chain(used_derived_element_ids)
                .collect::<Vec<_>>();
            ParameterUsage {
                id: parameter.id.clone(),
                name: parameter.name.clone(),
                value_mm: parameter.value_mm,
                unit: parameter.unit,
                memo: parameter.memo.clone(),
                usage_count: used_constraint_ids.len(),
                used_constraint_ids,
            }
        })
        .collect()
}

fn state_for(session: &CadSession) -> serde_json::Value {
    let document = &session.document;
    let snapshot = document.drawing_snapshot(session.view_mode);
    // `DrawingEntityMetadata.entity_id` is intentionally not serialized by
    // Core because it is a transient rendering join key.  The desktop adapter
    // exposes that join explicitly so React can edit the owning derived
    // element rather than a resolved, non-persistent display entity.
    let drawing_entity_metadata = document
        .drawing_entity_metadata(session.view_mode)
        .into_iter()
        .map(|item| {
            serde_json::json!({
                "entityId": item.entity_id,
                "derivedElementId": item.derived_element_id,
                "resolvedIndex": item.resolved_index,
                "sourceEntityId": item.source_entity_id,
                "suppressedByFillet": item.suppressed_by_fillet,
            })
        })
        .collect::<Vec<_>>();
    let output_preview = matches!(session.view_mode, CanvasViewMode::OutputPreview).then(|| {
        let orientation = document.settings().orientation;
        let (width_mm, height_mm) = match orientation {
            PrintOrientation::Portrait => (210.0, 297.0),
            PrintOrientation::Landscape => (297.0, 210.0),
        };
        match document.build_output_document_model(BuildOutputDocumentModelOptions {
            orientation,
            include_dimension_labels: true,
            include_scale_guide: true,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -width_mm / 2.0,
                right_mm: width_mm / 2.0,
                top_mm: height_mm / 2.0,
                bottom_mm: -height_mm / 2.0,
            },
        }) {
            Ok(result) => serde_json::json!({
                "pages": result.output_document_model.pages,
                "warnings": result.warnings,
            }),
            Err(error) => serde_json::json!({
                "pages": [],
                "warnings": [{ "message": error.to_string() }],
            }),
        }
    });
    serde_json::json!({
        "snapshot": {
            "name": document.metadata().name,
            "constraintStatus": snapshot.constraint_status,
            "statistics": {
                "layerCount": document.layers().len(),
                "sharedStyleCount": document.shared_styles().len(),
                "parameterCount": document.parameters().len(),
                "partCount": document.parts().len(),
                "entityCount": document.entities().len(),
                "derivedElementCount": document.derived_elements().len(),
                "constraintCount": document.constraints().len(),
            },
        },
        "viewMode": session.view_mode,
        "outputPreview": output_preview,
        "history": { "canUndo": document.can_undo(), "canRedo": document.can_redo() },
        "persistence": {
            "isDirty": session.is_dirty(),
            "hasPath": session.path.is_some(),
            "path": session.path,
        },
        "settings": document.settings(),
        "layers": document.layers(),
        "sharedStyles": document.shared_styles(),
        "parameters": parameters_with_usage(document),
        "parts": document.parts(),
        "entities": snapshot.entities,
        "drawingEntityMetadata": drawing_entity_metadata,
        "canvasProjection": document.canvas_projection(session.view_mode),
        "derivedElements": document.derived_elements(),
        "freeTexts": document.free_texts(),
        "roundHoles": document.round_holes(),
        "stitchStartPoints": document.stitch_start_points(),
        "measurementAnnotations": document.measurement_annotations(),
        "measurementEvaluations": document.measurement_evaluations(),
        "dimensionConstraintAnnotations": document.dimension_constraint_annotations(),
        "warnings": document.document_warnings(),
        "entityConstraintStatuses": document.entity_constraint_statuses(),
        "coincidentPointGroups": document.coincident_point_groups(),
        "constraints": document.constraints(),
    })
}

fn lock_session(state: &AppState) -> Result<std::sync::MutexGuard<'_, CadSession>, String> {
    state
        .cad_session
        .lock()
        .map_err(|_| "CAD session lock was poisoned".to_owned())
}

fn pdf_printable_area(orientation: PrintOrientation) -> PrintableAreaMm {
    let (width_mm, height_mm) = match orientation {
        PrintOrientation::Portrait => (210.0, 297.0),
        PrintOrientation::Landscape => (297.0, 210.0),
    };
    let inset_mm = 5.0;
    PrintableAreaMm {
        left_mm: -width_mm / 2.0 + inset_mm,
        right_mm: width_mm / 2.0 - inset_mm,
        top_mm: height_mm / 2.0 - inset_mm,
        bottom_mm: -height_mm / 2.0 + inset_mm,
    }
}

fn temporary_pdf_path(path: &Path) -> Result<PathBuf, String> {
    let directory = path
        .parent()
        .ok_or_else(|| "Could not determine the PDF destination directory".to_owned())?;
    let file_name = path
        .file_name()
        .ok_or_else(|| "Could not determine the PDF file name".to_owned())?
        .to_string_lossy();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| format!("Could not create a temporary PDF path: {error}"))?
        .as_nanos();
    Ok(directory.join(format!(".{file_name}.{nonce}.tmp")))
}

fn save_pdf_bytes(path: PathBuf, bytes: &[u8]) -> Result<(), String> {
    let temporary_path = temporary_pdf_path(&path)?;
    fs::write(&temporary_path, bytes)
        .map_err(|error| format!("Could not write PDF data: {error}"))?;
    fs::rename(&temporary_path, &path).map_err(|error| {
        let _ = fs::remove_file(&temporary_path);
        format!("Could not save PDF: {error}")
    })
}

#[tauri::command]
fn document_state(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let session = lock_session(&state)?;
    Ok(state_for(&session))
}

#[tauri::command]
fn prepare_pdf_output(
    options: PdfOutputOptions,
    state: tauri::State<'_, AppState>,
) -> Result<BuildOutputDocumentModelResult, String> {
    let session = lock_session(&state)?;
    session
        .document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: options.orientation,
            include_dimension_labels: options.include_dimension_labels,
            include_scale_guide: options.include_scale_guide,
            rotation_deg: options.rotation_deg,
            printable_area_mm: pdf_printable_area(options.orientation),
        })
        .map_err(|error| format!("Could not prepare PDF output: {error}"))
}

#[tauri::command]
fn save_prepared_pdf(
    output_document_model: OutputDocumentModel,
    path: String,
) -> Result<(), String> {
    let pdf = render_pdf(&output_document_model)
        .map_err(|error| format!("Could not render PDF: {error:?}"))?;
    save_pdf_bytes(PathBuf::from(path), &pdf.bytes)
}

#[tauri::command]
async fn direct_print_availability() -> Result<direct_print::DirectPrintAvailability, String> {
    tauri::async_runtime::spawn_blocking(direct_print::current_availability)
        .await
        .map_err(|error| format!("Direct print availability worker failed: {error}"))
}

#[tauri::command]
async fn list_printers() -> Result<Vec<direct_print::DirectPrinter>, String> {
    tauri::async_runtime::spawn_blocking(direct_print::list_printers)
        .await
        .map_err(|error| format!("Direct printer enumeration worker failed: {error}"))?
}

#[tauri::command]
async fn inspect_printer(
    request: direct_print::InspectPrinterRequest,
) -> Result<direct_print::PrinterInspection, String> {
    tauri::async_runtime::spawn_blocking(move || direct_print::inspect_printer(&request))
        .await
        .map_err(|error| format!("Direct printer inspection worker failed: {error}"))?
}

#[tauri::command]
async fn prepare_direct_print(
    request: direct_print::PrepareDirectPrintRequest,
    window: tauri::WebviewWindow,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let (document, document_fingerprint) = {
        let session = lock_session(&state)?;
        (
            session.document.clone(),
            serde_json::to_string(&session.document)
                .map_err(|error| format!("Could not fingerprint the current document: {error}"))?,
        )
    };
    let request_for_worker = request.clone();
    let prepared = tauri::async_runtime::spawn_blocking(move || {
        let inspection = direct_print::inspect_printer(&direct_print::InspectPrinterRequest {
            printer_id: request_for_worker.printer_id.clone(),
            options: request_for_worker.options.clone(),
        })?;
        if !inspection.selectable {
            return Err(inspection
                .reason
                .unwrap_or_else(|| "The selected printer cannot use direct printing".to_owned()));
        }
        let printable_area_mm = inspection
            .printable_area_mm
            .ok_or_else(|| "The selected printer did not provide a printable area".to_owned())?;
        let orientation = match request_for_worker.options.orientation.as_str() {
            "portrait" => PrintOrientation::Portrait,
            "landscape" => PrintOrientation::Landscape,
            _ => return Err("Direct printing requires a valid A4 orientation".to_owned()),
        };
        let output = document
            .build_output_document_model(BuildOutputDocumentModelOptions {
                orientation,
                include_dimension_labels: request_for_worker.options.include_dimension_labels,
                include_scale_guide: request_for_worker.options.include_scale_guide,
                rotation_deg: 0,
                printable_area_mm,
            })
            .map_err(|error| format!("Could not prepare direct print output: {error}"))?;
        let artifact = direct_print::create_artifact(&output.output_document_model)?;
        Ok(direct_print::PreparedDirectPrint {
            printer_id: request_for_worker.printer_id,
            options: request_for_worker.options,
            document_fingerprint,
            capability_fingerprint: inspection.capability_fingerprint.ok_or_else(|| {
                "The selected printer did not provide a capability fingerprint".to_owned()
            })?,
            output,
            artifact,
        })
    })
    .await
    .map_err(|error| format!("Direct print preparation worker failed: {error}"))??;

    let response_output = prepared.output.clone();
    let artifact_bytes = prepared.artifact.byte_len();
    let prepared_print_id = state
        .prepared_prints
        .lock()
        .map_err(|_| "Prepared print store lock was poisoned".to_owned())?
        .register(
            window.label().to_owned(),
            request.generation,
            artifact_bytes,
            prepared,
            Instant::now(),
        )
        .map_err(|error| match error {
            direct_print::PreparedPrintStoreError::Superseded => {
                "Prepared direct print was superseded".to_owned()
            }
            direct_print::PreparedPrintStoreError::Busy => {
                "Too many direct print preparations are active".to_owned()
            }
            direct_print::PreparedPrintStoreError::Stale => {
                "Prepared direct print is stale".to_owned()
            }
        })?;
    Ok(serde_json::json!({
        "preparedPrintId": prepared_print_id,
        "outputDocumentModel": response_output.output_document_model,
        "warnings": response_output.warnings,
    }))
}

#[tauri::command]
async fn run_prepared_direct_print(
    prepared_print_id: String,
    window: tauri::WebviewWindow,
    state: tauri::State<'_, AppState>,
) -> Result<(), String> {
    let prepared = state
        .prepared_prints
        .lock()
        .map_err(|_| "Prepared print store lock was poisoned".to_owned())?
        .take(window.label(), &prepared_print_id, Instant::now())
        .map_err(|_| "Prepared direct print is stale".to_owned())?;
    let document_fingerprint = {
        let session = lock_session(&state)?;
        serde_json::to_string(&session.document)
            .map_err(|error| format!("Could not fingerprint the current document: {error}"))?
    };
    if document_fingerprint != prepared.document_fingerprint {
        return Err("Prepared direct print is stale because the document changed".to_owned());
    }
    tauri::async_runtime::spawn_blocking(move || direct_print::send(&prepared))
        .await
        .map_err(|error| format!("Direct print submission worker failed: {error}"))?
}

#[tauri::command]
fn discard_prepared_direct_print(
    prepared_print_id: String,
    window: tauri::WebviewWindow,
    state: tauri::State<'_, AppState>,
) -> Result<(), String> {
    let mut prepared_prints = state
        .prepared_prints
        .lock()
        .map_err(|_| "Prepared print store lock was poisoned".to_owned())?;
    prepared_prints.discard(window.label(), &prepared_print_id, Instant::now());
    Ok(())
}

#[tauri::command]
fn new_document(
    name: String,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let trimmed_name = name.trim();
    if trimmed_name.is_empty() {
        return Err("Project name is required".to_owned());
    }
    let mut session = lock_session(&state)?;
    *session = CadSession::new(trimmed_name.to_owned());
    Ok(state_for(&session))
}

#[tauri::command]
fn open_document(
    path: String,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let document = ProjectDocument::read_json_file(&path)
        .map_err(|error| format!("Could not open project: {error:?}"))?;
    let mut session = lock_session(&state)?;
    session.clean_document = document.clone();
    session.document = document;
    session.view_mode = CanvasViewMode::EditDisplay;
    session.path = Some(path);
    session.recovered_dirty = false;
    Ok(state_for(&session))
}

fn reload_document_from_path(session: &mut CadSession) -> Result<(), String> {
    let path = session
        .path
        .clone()
        .ok_or_else(|| "No project file path has been selected".to_owned())?;
    let document = ProjectDocument::read_json_file(&path)
        .map_err(|error| format!("Could not reload project: {error:?}"))?;
    session.clean_document = document.clone();
    session.document = document;
    session.recovered_dirty = false;
    Ok(())
}

#[tauri::command]
fn reload_document(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut session = lock_session(&state)?;
    reload_document_from_path(&mut session)?;
    Ok(state_for(&session))
}

#[tauri::command]
fn set_view_mode(
    view_mode: String,
    _output_landscape: Option<bool>,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let view_mode: CanvasViewMode = serde_json::from_value(serde_json::Value::String(view_mode))
        .map_err(|error| format!("Invalid canvas view mode: {error}"))?;
    let mut session = lock_session(&state)?;
    session.view_mode = view_mode;
    Ok(state_for(&session))
}

#[tauri::command]
fn save_document(
    path: String,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let mut session = lock_session(&state)?;
    session
        .document
        .write_json_file(&path)
        .map_err(|error| format!("Could not save project: {error:?}"))?;
    session.clean_document = session.document.clone();
    session.path = Some(path);
    session.recovered_dirty = false;
    Ok(state_for(&session))
}

#[tauri::command]
fn save_current_document(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut session = lock_session(&state)?;
    let path = session
        .path
        .clone()
        .ok_or_else(|| "No project file path has been selected".to_owned())?;
    session
        .document
        .write_json_file(&path)
        .map_err(|error| format!("Could not save project: {error:?}"))?;
    session.clean_document = session.document.clone();
    session.recovered_dirty = false;
    Ok(state_for(&session))
}

#[tauri::command]
fn apply_command(
    command: serde_json::Value,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let command: DocumentCommand =
        serde_json::from_value(command).map_err(|error| format!("Invalid CAD command: {error}"))?;
    let mut session = lock_session(&state)?;
    session
        .document
        .apply_command(command)
        .map_err(|error| format!("CAD command was rejected: {error:?}"))?;
    Ok(state_for(&session))
}

#[tauri::command]
fn preview_command(
    command: serde_json::Value,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let command: DocumentCommand =
        serde_json::from_value(command).map_err(|error| format!("Invalid CAD command: {error}"))?;
    let session = lock_session(&state)?;
    let preview = session
        .document
        .preview_command(command)
        .map_err(|error| format!("CAD preview was rejected: {error:?}"))?;
    let preview_session = CadSession {
        clean_document: session.clean_document.clone(),
        document: preview,
        view_mode: session.view_mode,
        path: session.path.clone(),
        recovered_dirty: session.recovered_dirty,
        recovery_candidate_id: session.recovery_candidate_id.clone(),
    };
    Ok(state_for(&preview_session))
}

#[tauri::command]
fn preflight_constraint(
    kind: String,
    targets: serde_json::Value,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let kind: ConstraintKind = serde_json::from_value(serde_json::Value::String(kind))
        .map_err(|error| format!("Invalid constraint kind: {error}"))?;
    let targets: Vec<ConstraintTarget> = serde_json::from_value(targets)
        .map_err(|error| format!("Invalid constraint targets: {error}"))?;
    let session = lock_session(&state)?;
    serde_json::to_value(
        session
            .document
            .preflight_constraint(kind, targets)
            .map_err(|error| format!("Constraint cannot be added: {error:?}"))?,
    )
    .map_err(|error| format!("Could not serialize constraint preflight: {error}"))
}

#[tauri::command]
fn preflight_derived_element(
    kind: String,
    hit_entity_id: Option<String>,
    selected_entity_ids: Vec<String>,
    click_point: Option<serde_json::Value>,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let kind: DerivedElementPreflightKind = serde_json::from_value(serde_json::Value::String(kind))
        .map_err(|error| format!("Invalid derived element kind: {error}"))?;
    let click_point: Option<Point2> = click_point
        .map(serde_json::from_value)
        .transpose()
        .map_err(|error| format!("Invalid canvas point: {error}"))?;
    let session = lock_session(&state)?;
    serde_json::to_value(
        session
            .document
            .preflight_derived_element(kind, hit_entity_id, selected_entity_ids, click_point)
            .map_err(|error| format!("Derived element cannot be added: {error:?}"))?,
    )
    .map_err(|error| format!("Could not serialize derived preflight: {error}"))
}

#[tauri::command]
fn layer_deletion_impact(
    layer_id: String,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let session = lock_session(&state)?;
    serde_json::to_value(
        session
            .document
            .layer_deletion_impact(&layer_id)
            .map_err(|error| format!("Could not inspect layer deletion: {error:?}"))?,
    )
    .map_err(|error| format!("Could not serialize layer deletion impact: {error}"))
}

/// Export a selected dependency closure without duplicating Core's clipboard
/// semantics in the web UI. The returned JSON is intentionally opaque to
/// React and is only fed back to `pasteSelection`.
#[tauri::command]
fn export_selection(
    selection: serde_json::Value,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let selection: SelectionReference = serde_json::from_value(selection)
        .map_err(|error| format!("Invalid selection reference: {error}"))?;
    let session = lock_session(&state)?;
    serde_json::to_value(
        session
            .document
            .export_selection(selection)
            .map_err(|error| format!("Selection cannot be copied: {error:?}"))?,
    )
    .map_err(|error| format!("Could not serialize selection export: {error}"))
}

/// Keep the library payload opaque to React.  The Core owns dependency
/// closure export and ID remapping; the UI only persists this returned token.
#[tauri::command]
fn export_part_library_item(
    part_id: String,
    state: tauri::State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let session = lock_session(&state)?;
    serde_json::to_value(
        session
            .document
            .export_part_library_item(&part_id)
            .map_err(|error| format!("Part cannot be added to the library: {error:?}"))?,
    )
    .map_err(|error| format!("Could not serialize part library item: {error}"))
}

fn part_library_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    application_data_path(app, "part-library.json")
}

fn load_part_library_at(path: &PathBuf) -> Result<serde_json::Value, String> {
    if !path.exists() {
        return Ok(serde_json::json!([]));
    }
    let contents = fs::read_to_string(path)
        .map_err(|error| format!("Could not read the part library: {error}"))?;
    let entries: serde_json::Value = serde_json::from_str(&contents)
        .map_err(|error| format!("Could not read the part library: {error}"))?;
    if !entries.is_array() {
        return Err("Could not read the part library: expected an array".to_owned());
    }
    Ok(entries)
}

fn save_part_library_at(path: &PathBuf, entries: &serde_json::Value) -> Result<(), String> {
    if !entries.is_array() {
        return Err("Could not save the part library: expected an array".to_owned());
    }
    let directory = path
        .parent()
        .ok_or_else(|| "Could not determine the part library directory".to_owned())?;
    fs::create_dir_all(directory)
        .map_err(|error| format!("Could not create the part library directory: {error}"))?;
    let contents = serde_json::to_vec_pretty(entries)
        .map_err(|error| format!("Could not serialize the part library: {error}"))?;
    fs::write(path, contents).map_err(|error| format!("Could not save the part library: {error}"))
}

#[tauri::command]
fn load_part_library(app: tauri::AppHandle) -> Result<serde_json::Value, String> {
    let path = part_library_path(&app)?;
    load_part_library_at(&path)
}

#[tauri::command]
fn save_part_library(app: tauri::AppHandle, entries: serde_json::Value) -> Result<(), String> {
    let path = part_library_path(&app)?;
    save_part_library_at(&path, &entries)
}

#[tauri::command]
fn recovery_candidates(app: tauri::AppHandle) -> Result<Vec<RecoveryCandidate>, String> {
    recovery_candidates_at(&application_data_directory(&app)?)
}

#[tauri::command]
fn save_recovery_snapshot(
    app: tauri::AppHandle,
    state: tauri::State<'_, AppState>,
) -> Result<(), String> {
    let session = lock_session(&state)?;
    save_recovery_snapshot_at(&session, &application_data_directory(&app)?)
}

#[tauri::command]
fn restore_recovery_snapshot(
    app: tauri::AppHandle,
    state: tauri::State<'_, AppState>,
    candidate_id: String,
) -> Result<serde_json::Value, String> {
    let base_directory = application_data_directory(&app)?;
    let (snapshot_path, metadata_path) = recovery_paths(&base_directory, &candidate_id)?;
    let metadata = fs::read_to_string(&metadata_path)
        .map_err(|error| format!("Could not read recovery metadata: {error}"))
        .and_then(|contents| {
            serde_json::from_str::<RecoveryMetadata>(&contents)
                .map_err(|error| format!("Could not read recovery metadata: {error}"))
        })?;
    let document = ProjectDocument::read_json_file(&snapshot_path)
        .map_err(|error| format!("Could not restore recovery snapshot: {error:?}"))?;
    let mut session = lock_session(&state)?;
    session.clean_document = document.clone();
    session.document = document;
    session.view_mode = CanvasViewMode::EditDisplay;
    session.path = metadata.original_document_path;
    session.recovered_dirty = true;
    session.recovery_candidate_id = candidate_id;
    Ok(state_for(&session))
}

#[tauri::command]
fn discard_recovery_snapshot(app: tauri::AppHandle, candidate_id: String) -> Result<(), String> {
    discard_recovery_snapshot_at(&application_data_directory(&app)?, &candidate_id)
}

#[tauri::command]
fn reveal_recovery_snapshot(app: tauri::AppHandle, candidate_id: String) -> Result<(), String> {
    let directory = recovery_directory(&application_data_directory(&app)?, &candidate_id)?;
    #[cfg(target_os = "macos")]
    let mut command = {
        let mut command = Command::new("open");
        command.arg(&directory);
        command
    };
    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = Command::new("explorer");
        command.arg(&directory);
        command
    };
    #[cfg(all(not(target_os = "macos"), not(target_os = "windows")))]
    let mut command = {
        let mut command = Command::new("xdg-open");
        command.arg(&directory);
        command
    };
    command
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("Could not reveal recovery snapshot: {error}"))
}

#[tauri::command]
fn undo(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut session = lock_session(&state)?;
    session
        .document
        .undo()
        .map_err(|error| format!("Undo failed: {error:?}"))?;
    Ok(state_for(&session))
}

#[tauri::command]
fn redo(state: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut session = lock_session(&state)?;
    session
        .document
        .redo()
        .map_err(|error| format!("Redo failed: {error:?}"))?;
    Ok(state_for(&session))
}

#[tauri::command]
fn exit_application(app: tauri::AppHandle) {
    app.exit(0);
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState {
            cad_session: Mutex::new(CadSession::new("Untitled".to_owned())),
            prepared_prints: Mutex::new(direct_print::PreparedPrintStore::new()),
        })
        .invoke_handler(tauri::generate_handler![
            document_state,
            prepare_pdf_output,
            save_prepared_pdf,
            direct_print_availability,
            list_printers,
            inspect_printer,
            prepare_direct_print,
            run_prepared_direct_print,
            discard_prepared_direct_print,
            new_document,
            open_document,
            save_document,
            save_current_document,
            reload_document,
            set_view_mode,
            apply_command,
            preview_command,
            preflight_constraint,
            preflight_derived_element,
            layer_deletion_impact,
            export_selection,
            export_part_library_item,
            load_part_library,
            save_part_library,
            recovery_candidates,
            save_recovery_snapshot,
            restore_recovery_snapshot,
            discard_recovery_snapshot,
            reveal_recovery_snapshot,
            undo,
            redo,
            exit_application,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temporary_directory(label: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be after epoch")
            .as_nanos();
        std::env::temp_dir().join(format!("kawa-cad-tauri-{label}-{nonce}"))
    }

    #[test]
    fn core_state_tracks_drawing_and_history() {
        let mut session = CadSession::new("Comparison".to_owned());
        let command: DocumentCommand = serde_json::from_value(json!({
            "kind": "createEntityFromGesture",
            "payload": {
                "id": "point-1",
                "layerId": null,
                "gesture": {
                    "kind": "point",
                    "position": { "xMm": 12.5, "yMm": -7.0 }
                }
            }
        }))
        .expect("test command should deserialize");

        session
            .document
            .apply_command(command)
            .expect("point should be created");
        let state = state_for(&session);
        assert_eq!(state["entities"].as_array().unwrap().len(), 1);
        assert_eq!(state["snapshot"]["constraintStatus"], "unknown");
        assert_eq!(state["history"]["canUndo"], true);
        assert_eq!(state["persistence"]["isDirty"], true);

        session.document.undo().expect("undo should succeed");
        let state = state_for(&session);
        assert!(state["entities"].as_array().unwrap().is_empty());
        assert_eq!(state["history"]["canRedo"], true);
    }

    #[test]
    fn state_reports_parameter_usage_from_constraints_and_derived_elements() {
        let mut session = CadSession::new("Parameter usage".to_owned());
        for value in [
            json!({
                "kind": "addParameter",
                "payload": { "id": "parameter:used", "name": "幅", "valueMm": 10.0, "unit": "millimeter", "memo": "" }
            }),
            json!({
                "kind": "addParameter",
                "payload": { "id": "parameter:unused", "name": "未使用", "valueMm": 5.0, "unit": "millimeter", "memo": "" }
            }),
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "line:1", "layerId": null, "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false } }
            }),
            json!({
                "kind": "addConstraint",
                "payload": {
                    "id": "constraint:length", "kind": "segmentLength", "targets": [{ "entity": "line:1" }],
                    "value": { "parameter": "parameter:used" }, "status": "underConstrained"
                }
            }),
            json!({
                "kind": "addDerivedElement",
                "payload": {
                    "id": "derived:offset", "layerId": null,
                    "kind": { "offsetCurve": { "sourceEntityIds": ["line:1"], "distance": { "parameter": "parameter:used" }, "direction": "left" } }
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value)
                        .expect("parameter usage command should deserialize"),
                )
                .expect("parameter usage command should apply");
        }

        let state = state_for(&session);
        let parameters = state["parameters"]
            .as_array()
            .expect("parameters should be serialized");
        let used = parameters
            .iter()
            .find(|parameter| parameter["id"] == "parameter:used")
            .expect("used parameter should exist");
        let unused = parameters
            .iter()
            .find(|parameter| parameter["id"] == "parameter:unused")
            .expect("unused parameter should exist");
        assert_eq!(used["usageCount"], 2);
        assert_eq!(
            used["usedConstraintIds"],
            json!(["constraint:length", "derived:offset"])
        );
        assert_eq!(unused["usageCount"], 0);
    }

    #[test]
    fn existing_core_contract_handles_react_annotation_and_clipboard_payloads() {
        let mut session = CadSession::new("Comparison".to_owned());
        let commands = [
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "point-1", "layerId": null, "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } } }
            }),
            json!({
                "kind": "addFreeText",
                "payload": { "id": "free-text-1", "content": "note", "positionMm": { "xMm": 2.0, "yMm": 3.0 }, "fontSizeMm": 3.2 }
            }),
        ];
        for value in commands {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React payload should deserialize"),
                )
                .expect("Core should accept React payload");
        }

        let copied = session
            .document
            .export_selection(SelectionReference {
                entity_ids: vec!["point-1".to_owned()],
                ..SelectionReference::default()
            })
            .expect("Core should export an opaque selection clipboard");
        assert!(!copied.clipboard_json.is_empty());
        assert_eq!(
            state_for(&session)["freeTexts"].as_array().unwrap().len(),
            1
        );
    }

    #[test]
    fn react_line_gesture_keeps_snap_and_axis_constraints_in_core() {
        let mut session = CadSession::new("Comparison".to_owned());
        for value in [
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "point-1", "layerId": null, "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } } }
            }),
            json!({
                "kind": "createEntityFromGesture",
                "payload": {
                    "id": "line-1", "layerId": null,
                    "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false, "axis": "horizontal" },
                    "startSnap": { "constraintId": "coincident-1", "target": { "entity": "point-1" } },
                    "axisConstraintId": "horizontal-1"
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React line payload should deserialize"),
                )
                .expect("Core should apply React line gesture");
        }
        let state = state_for(&session);
        assert_eq!(state["entities"].as_array().unwrap().len(), 2);
        assert_eq!(state["constraints"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn react_arc_gesture_preserves_an_explicit_large_signed_sweep() {
        let mut session = CadSession::new("Large arc".to_owned());
        for (id, end, sweep) in [
            (
                "arc:positive",
                json!({ "xMm": -9.396926207859085, "yMm": -3.4202014332566866 }),
                200.0_f64.to_radians(),
            ),
            (
                "arc:negative",
                json!({ "xMm": -9.396926207859085, "yMm": 3.4202014332566866 }),
                -200.0_f64.to_radians(),
            ),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(json!({
                        "kind": "createEntityFromGesture",
                        "payload": {
                            "id": id,
                            "layerId": null,
                            "gesture": {
                                "kind": "arc",
                                "center": { "xMm": 0.0, "yMm": 0.0 },
                                "start": { "xMm": 10.0, "yMm": 0.0 },
                                "end": end,
                                "sweepReferenceRad": sweep
                            }
                        }
                    }))
                    .expect("React arc payload should deserialize"),
                )
                .expect("Core should preserve the requested arc sweep");
        }

        let state = state_for(&session);
        let sweeps = state["entities"]
            .as_array()
            .expect("arc entities should be visible")
            .iter()
            .map(|entity| entity["kind"]["arc"]["sweepAngleRad"].as_f64())
            .collect::<Vec<_>>();
        assert_eq!(sweeps.len(), 2);
        assert!((sweeps[0].expect("positive sweep") - 200.0_f64.to_radians()).abs() < 0.0001);
        assert!((sweeps[1].expect("negative sweep") + 200.0_f64.to_radians()).abs() < 0.0001);
    }

    #[test]
    fn react_inspector_metric_payload_uses_core_tagged_entity_metric_schema() {
        let mut session = CadSession::new("Metric editor".to_owned());
        for value in [
            json!({
                "kind": "createEntityFromGesture",
                "payload": {
                    "id": "line-1", "layerId": null,
                    "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false }
                }
            }),
            json!({
                "kind": "setEntityMetric",
                "payload": {
                    "entityId": "line-1",
                    "metric": { "kind": "segmentLength", "valueMm": 35.0 }
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React metric payload should deserialize"),
                )
                .expect("Core should apply React metric payload");
        }
        let state = state_for(&session);
        assert_eq!(
            state["entities"][0]["kind"]["lineSegment"]["end"]["xMm"],
            35.0
        );
    }

    #[test]
    fn derived_display_entities_keep_an_explicit_owner_join_for_react_inspector() {
        let mut session = CadSession::new("Derived inspector".to_owned());
        for value in [
            json!({
                "kind": "createEntityFromGesture",
                "payload": {
                    "id": "line-1", "layerId": null,
                    "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false }
                }
            }),
            json!({
                "kind": "addDerivedElement",
                "payload": {
                    "id": "derived:offset-1", "layerId": null,
                    "kind": { "offsetCurve": { "sourceEntityIds": ["line-1"], "distance": { "fixedMm": 3.0 }, "direction": "left" } }
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React payload should deserialize"),
                )
                .expect("Core should apply derived element command");
        }

        let state = state_for(&session);
        let metadata = state["drawingEntityMetadata"]
            .as_array()
            .expect("adapter should expose drawing metadata");
        assert!(metadata.iter().any(|item| {
            item["derivedElementId"] == "derived:offset-1"
                && item["entityId"]
                    .as_str()
                    .is_some_and(|id| id.contains("resolved"))
        }));
    }

    #[test]
    fn view_mode_is_adapter_state_and_does_not_mutate_core_document() {
        let mut session = CadSession::new("Comparison".to_owned());
        let before = session.document.clone();
        session.view_mode = CanvasViewMode::OutputPreview;
        assert_eq!(state_for(&session)["viewMode"], "outputPreview");
        assert_eq!(session.document, before);
    }

    #[test]
    fn drag_preview_uses_core_preview_command_without_mutating_the_session_document() {
        let mut session = CadSession::new("Drag preview".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } }
                    }
                }))
                .expect("point creation command should deserialize"),
            )
            .expect("point should be created");
        let before = session.document.clone();
        let preview = session
            .document
            .preview_command(
                serde_json::from_value(json!({
                    "kind": "moveEntities",
                    "payload": {
                        "entityIds": ["point-1"],
                        "delta": { "xMm": 12.0, "yMm": -4.0 },
                        "allowSingleLineStretch": true
                    }
                }))
                .expect("preview move command should deserialize"),
            )
            .expect("preview move should succeed");
        let preview_session = CadSession {
            clean_document: session.clean_document.clone(),
            document: preview,
            view_mode: session.view_mode,
            path: session.path.clone(),
            recovered_dirty: session.recovered_dirty,
            recovery_candidate_id: session.recovery_candidate_id.clone(),
        };

        assert_eq!(session.document, before);
        assert_eq!(
            state_for(&preview_session)["entities"][0]["kind"]["point"]["xMm"],
            12.0
        );
        assert_eq!(
            state_for(&preview_session)["entities"][0]["kind"]["point"]["yMm"],
            -4.0
        );
    }

    #[test]
    fn output_preview_state_exposes_core_page_grid_without_rendering_a_pdf() {
        let mut session = CadSession::new("Preview".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } }
                    }
                }))
                .expect("preview command should deserialize"),
            )
            .expect("point should be created");
        session.view_mode = CanvasViewMode::OutputPreview;

        let preview = &state_for(&session)["outputPreview"];
        assert_eq!(preview["pages"].as_array().map(Vec::len), Some(1));
        assert_eq!(preview["pages"][0]["gridColumn"], 0);
        assert_eq!(preview["pages"][0]["gridRow"], 0);
    }

    #[test]
    fn prepared_pdf_uses_the_pdf_margin_and_writes_pdf_bytes() {
        let directory = temporary_directory("pdf-output");
        fs::create_dir_all(&directory).expect("PDF directory should be created");
        let path = directory.join("pattern.pdf");
        let mut session = CadSession::new("PDF".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } }
                    }
                }))
                .expect("PDF test command should deserialize"),
            )
            .expect("point should be created");

        let area = pdf_printable_area(PrintOrientation::Portrait);
        assert_eq!(area.left_mm, -100.0);
        assert_eq!(area.right_mm, 100.0);
        let prepared = session
            .document
            .build_output_document_model(BuildOutputDocumentModelOptions {
                orientation: PrintOrientation::Portrait,
                include_dimension_labels: true,
                include_scale_guide: true,
                rotation_deg: 0,
                printable_area_mm: area,
            })
            .expect("PDF model should be prepared");

        save_prepared_pdf(
            prepared.output_document_model,
            path.to_string_lossy().into_owned(),
        )
        .expect("PDF should be written");
        assert!(fs::read(&path)
            .expect("PDF should exist")
            .starts_with(b"%PDF-"));
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn landscape_orientation_is_exposed_by_the_tauri_state_and_survives_file_round_trip() {
        let directory = temporary_directory("landscape-orientation");
        fs::create_dir_all(&directory).expect("orientation directory should be created");
        let path = directory.join("landscape.kawa");
        let mut session = CadSession::new("Landscape".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } }
                    }
                }))
                .expect("point creation command should deserialize"),
            )
            .expect("point should be created");
        session
            .document
            .apply_command(DocumentCommand::SetPrintOrientation {
                orientation: PrintOrientation::Landscape,
            })
            .expect("landscape orientation should apply");
        session
            .document
            .write_json_file(&path)
            .expect("landscape document should be written");

        let reopened =
            ProjectDocument::read_json_file(&path).expect("landscape document should be reopened");
        session.document = reopened;
        session.view_mode = CanvasViewMode::OutputPreview;
        let state = state_for(&session);

        assert_eq!(state["settings"]["orientation"], "landscape");
        assert_eq!(state["outputPreview"]["pages"][0]["widthMm"], 297.0);
        assert_eq!(state["outputPreview"]["pages"][0]["heightMm"], 210.0);
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn reload_document_restores_the_saved_file_without_changing_adapter_view_mode() {
        let directory = temporary_directory("reload");
        fs::create_dir_all(&directory).expect("reload directory should be created");
        let path = directory.join("saved.kawa");
        let mut saved_document = ProjectDocument::new("Saved project".to_owned());
        saved_document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "saved-point",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 1.0, "yMm": 2.0 } }
                    }
                }))
                .expect("saved point command should deserialize"),
            )
            .expect("saved point should be created");
        saved_document
            .write_json_file(&path)
            .expect("saved project should be written");

        let mut session = CadSession::new("Unsaved project".to_owned());
        session.path = Some(path.to_string_lossy().into_owned());
        session.view_mode = CanvasViewMode::OutputPreview;
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "unsaved-point",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 9.0, "yMm": 9.0 } }
                    }
                }))
                .expect("unsaved point command should deserialize"),
            )
            .expect("unsaved point should be created");

        reload_document_from_path(&mut session).expect("saved project should reload");

        let state = state_for(&session);
        assert_eq!(state["snapshot"]["name"], "Saved project");
        assert_eq!(state["entities"].as_array().map(Vec::len), Some(1));
        assert_eq!(state["entities"][0]["id"], "saved-point");
        assert_eq!(state["viewMode"], "outputPreview");
        assert_eq!(state["persistence"]["isDirty"], false);
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn recovery_snapshot_round_trip_preserves_dirty_document_metadata() {
        let directory = temporary_directory("recovery");
        let mut session = CadSession::new("Recovered project".to_owned());
        session.path = Some("/projects/recovered.kawa".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 3.0, "yMm": 4.0 } }
                    }
                }))
                .expect("recovery command should deserialize"),
            )
            .expect("recovery document should become dirty");

        save_recovery_snapshot_at(&session, &directory).expect("recovery snapshot should save");
        let candidates =
            recovery_candidates_at(&directory).expect("recovery candidate should read");
        let candidate = candidates.first().expect("recovery candidate should exist");
        assert_eq!(candidate.display_name, "Recovered project");
        assert_eq!(
            candidate.original_document_path.as_deref(),
            Some("/projects/recovered.kawa")
        );

        let (snapshot_path, _) =
            recovery_paths(&directory, &candidate.id).expect("recovery paths should resolve");
        let restored = ProjectDocument::read_json_file(snapshot_path)
            .expect("snapshot should be a project document");
        assert_eq!(restored.entities().len(), 1);
        discard_recovery_snapshot_at(&directory, &candidate.id)
            .expect("recovery snapshot should discard");
        assert!(recovery_candidates_at(&directory)
            .expect("discarded recovery should be readable")
            .is_empty());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn recovery_candidates_include_multiple_documents_and_broken_snapshots() {
        let directory = temporary_directory("multiple-recovery");
        for (name, path, entity_id) in [
            ("First", "/projects/first.kawa", "point-first"),
            ("Second", "/projects/second.kawa", "point-second"),
        ] {
            let mut session = CadSession::new(name.to_owned());
            session.path = Some(path.to_owned());
            session
                .document
                .apply_command(
                    serde_json::from_value(json!({
                        "kind": "createEntityFromGesture",
                        "payload": {
                            "id": entity_id,
                            "layerId": null,
                            "gesture": { "kind": "point", "position": { "xMm": 1.0, "yMm": 2.0 } }
                        }
                    }))
                    .expect("recovery command should deserialize"),
                )
                .expect("recovery document should become dirty");
            save_recovery_snapshot_at(&session, &directory).expect("recovery snapshot should save");
        }

        let broken_directory = directory.join("Recovery").join("broken-1");
        fs::create_dir_all(&broken_directory).expect("broken candidate directory should exist");
        fs::write(
            broken_directory.join("metadata.json"),
            r#"{"displayName":"Broken","originalDocumentPath":null}"#,
        )
        .expect("broken candidate metadata should save");
        fs::write(
            broken_directory.join("snapshot.kawa"),
            "not a KawaCAD document",
        )
        .expect("broken candidate snapshot should save");

        let candidates =
            recovery_candidates_at(&directory).expect("all recovery candidates should be readable");
        assert_eq!(candidates.len(), 3);
        assert_eq!(
            candidates
                .iter()
                .filter(|candidate| candidate.status == "recoverable")
                .count(),
            2
        );
        let broken = candidates
            .iter()
            .find(|candidate| candidate.id == "broken-1")
            .expect("broken candidate should remain visible");
        assert_eq!(broken.status, "broken");
        assert!(broken.details.is_some());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn clean_recovery_snapshot_removes_stale_dirty_snapshot() {
        let directory = temporary_directory("clean-recovery");
        let mut session = CadSession::new("Snapshot".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": {
                        "id": "point-1",
                        "layerId": null,
                        "gesture": { "kind": "point", "position": { "xMm": 0.0, "yMm": 0.0 } }
                    }
                }))
                .expect("snapshot command should deserialize"),
            )
            .expect("snapshot document should become dirty");
        save_recovery_snapshot_at(&session, &directory).expect("dirty snapshot should save");
        session.clean_document = session.document.clone();
        save_recovery_snapshot_at(&session, &directory)
            .expect("clean document should clear snapshot");
        assert!(recovery_candidates_at(&directory)
            .expect("clean recovery state should be readable")
            .is_empty());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn part_library_round_trips_entries_through_local_json() {
        let directory = temporary_directory("part-library");
        let path = directory.join("library.json");
        let entries = json!([{
            "id": "entry:a",
            "name": "カードポケット",
            "libraryJson": "{\\\"selection\\\":true}",
            "sourcePart": { "id": "part:a", "quantity": 2 }
        }]);

        save_part_library_at(&path, &entries).expect("part library should save");
        assert_eq!(
            load_part_library_at(&path).expect("part library should load"),
            entries
        );
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn react_round_hole_and_stitch_commands_round_trip_through_state() {
        let mut session = CadSession::new("Hole and stitch".to_owned());
        for value in [
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "line:stitch", "layerId": null, "styleId": "style:stitch-line", "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": -4.0 }, "end": { "xMm": 20.0, "yMm": -4.0 }, "centerLine": false } }
            }),
            json!({
                "kind": "createRoundHole",
                "payload": {
                    "id": "round-hole:1",
                    "entityId": "circle:hole-1",
                    "center": { "xMm": 8.0, "yMm": -4.0 },
                    "diameterMm": 5.0,
                    "roundHoleKind": "keyRing",
                    "layerId": null,
                    "styleId": null
                }
            }),
            json!({
                "kind": "placeStitchStartPoint",
                "payload": {
                    "id": "stitch-start:1",
                    "position": { "xMm": 8.0, "yMm": -4.0 },
                    "candidateTargetIds": ["line:stitch"],
                    "maxDistanceMm": 3.0
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value)
                        .expect("React special-entity payload should deserialize"),
                )
                .expect("Core should accept the React special-entity command");
        }
        let state = state_for(&session);
        assert_eq!(state["roundHoles"].as_array().map(Vec::len), Some(1));
        assert_eq!(state["stitchStartPoints"].as_array().map(Vec::len), Some(1));
        assert!(state["entities"].as_array().is_some_and(|entities| {
            entities
                .iter()
                .any(|entity| entity["kind"]["circle"]["radiusMm"] == 2.5)
        }));
    }

    #[test]
    fn react_constraint_payload_preserves_signed_angle_value() {
        let mut session = CadSession::new("Angle constraint".to_owned());
        for value in [
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "line:a", "layerId": null, "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false } }
            }),
            json!({
                "kind": "createEntityFromGesture",
                "payload": { "id": "line:b", "layerId": null, "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 0.0, "yMm": 20.0 }, "centerLine": false } }
            }),
            json!({
                "kind": "addConstraint",
                "payload": {
                    "id": "constraint:angle",
                    "kind": "angle",
                    "targets": [{ "entity": "line:a" }, { "entity": "line:b" }],
                    "value": { "fixedDegrees": -90.0 },
                    "status": "underConstrained"
                }
            }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React angle payload should deserialize"),
                )
                .expect("Core should accept the signed angle constraint");
        }
        let constraint = &state_for(&session)["constraints"][0];
        assert_eq!(constraint["kind"], "angle");
        assert_eq!(constraint["value"]["fixedDegrees"], -90.0);
    }

    #[test]
    fn react_history_contract_supports_undo_then_redo() {
        let mut session = CadSession::new("History".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": { "id": "point:history", "layerId": null, "gesture": { "kind": "point", "position": { "xMm": 1.0, "yMm": 2.0 } } }
                }))
                .expect("history payload should deserialize"),
            )
            .expect("point should be created");
        assert_eq!(state_for(&session)["history"]["canUndo"], true);
        session.document.undo().expect("undo should succeed");
        assert_eq!(state_for(&session)["history"]["canRedo"], true);
        session.document.redo().expect("redo should succeed");
        assert_eq!(
            state_for(&session)["entities"].as_array().map(Vec::len),
            Some(1)
        );
    }

    #[test]
    fn react_move_and_control_point_commands_update_core_geometry() {
        let mut session = CadSession::new("Geometry edit".to_owned());
        session
            .document
            .apply_command(
                serde_json::from_value(json!({
                    "kind": "createEntityFromGesture",
                    "payload": { "id": "line:edit", "layerId": null, "gesture": { "kind": "line", "start": { "xMm": 0.0, "yMm": 0.0 }, "end": { "xMm": 20.0, "yMm": 0.0 }, "centerLine": false } }
                }))
                .expect("line command should deserialize"),
            )
            .expect("line should be created");
        for value in [
            json!({ "kind": "moveEntities", "payload": { "entityIds": ["line:edit"], "delta": { "xMm": 4.0, "yMm": 3.0 }, "allowSingleLineStretch": true } }),
            json!({ "kind": "moveControlPoint", "payload": { "target": { "controlPoint": { "entity_id": "line:edit", "point": "end" } }, "position": { "xMm": 30.0, "yMm": 3.0 }, "allowProjection": true } }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value).expect("React geometry edit should deserialize"),
                )
                .expect("Core should apply React geometry edit");
        }
        let entity = &state_for(&session)["entities"][0]["kind"]["lineSegment"];
        assert_eq!(entity["start"], json!({ "xMm": 4.0, "yMm": 3.0 }));
        assert_eq!(entity["end"], json!({ "xMm": 30.0, "yMm": 3.0 }));
    }

    #[test]
    fn react_free_text_lifecycle_commands_preserve_explicit_payload() {
        let mut session = CadSession::new("Notes".to_owned());
        for value in [
            json!({ "kind": "addFreeText", "payload": { "id": "free-text:1", "content": "注記", "positionMm": { "xMm": 2.0, "yMm": -3.0 }, "fontSizeMm": 3.2 } }),
            json!({ "kind": "updateFreeText", "payload": { "id": "free-text:1", "content": "更新済み", "positionMm": { "xMm": 5.0, "yMm": -1.0 }, "fontSizeMm": 4.0 } }),
        ] {
            session
                .document
                .apply_command(
                    serde_json::from_value(value)
                        .expect("React free-text payload should deserialize"),
                )
                .expect("Core should apply free-text payload");
        }
        let text = &state_for(&session)["freeTexts"][0];
        assert_eq!(text["content"], "更新済み");
        assert_eq!(text["positionMm"], json!({ "xMm": 5.0, "yMm": -1.0 }));
        session
            .document
            .apply_command(
                serde_json::from_value(
                    json!({ "kind": "deleteFreeText", "payload": "free-text:1" }),
                )
                .expect("React free-text deletion should deserialize"),
            )
            .expect("Core should delete the free text");
        assert!(state_for(&session)["freeTexts"]
            .as_array()
            .is_some_and(Vec::is_empty));
    }

    #[test]
    fn react_semantic_command_wire_shapes_deserialize_without_core_changes() {
        let commands = [
            json!({ "kind": "renameDocument", "payload": { "name": "Renamed" } }),
            json!({ "kind": "setEntityLayer", "payload": { "entityId": "entity:1", "layerId": null } }),
            json!({ "kind": "setDerivedDistance", "payload": { "derivedElementId": "derived:offset", "value": { "fixedMm": 4.0 } } }),
            json!({ "kind": "setDerivedDirection", "payload": { "derivedElementId": "derived:offset", "direction": "right" } }),
            json!({ "kind": "setDerivedSharedStyle", "payload": { "derivedElementId": "derived:offset", "styleId": "style:outer-cut-line" } }),
            json!({ "kind": "setDerivedRadiusFromPoint", "payload": { "derivedElementId": "derived:fillet", "resolvedIndex": 0, "position": { "xMm": 5.0, "yMm": 5.0 } } }),
            json!({ "kind": "setRoundHoleDiameter", "payload": { "roundHoleId": "round-hole:1", "diameterMm": 8.0 } }),
            json!({ "kind": "setRoundHoleKind", "payload": { "roundHoleId": "round-hole:1", "kind": "rivet" } }),
            json!({ "kind": "setLayerVisibility", "payload": { "layerId": "layer:cut-line", "visible": false } }),
            json!({ "kind": "setLayerPrintable", "payload": { "layerId": "layer:cut-line", "printable": true } }),
            json!({ "kind": "setPartPosition", "payload": { "partId": "part:1", "position": { "xMm": 4.0, "yMm": -2.0 } } }),
            json!({ "kind": "setPartQuantity", "payload": { "partId": "part:1", "quantity": 2 } }),
            json!({ "kind": "addParameter", "payload": { "id": "parameter:1", "name": "幅", "valueMm": 10.0, "unit": "millimeter", "memo": "" } }),
            json!({ "kind": "updateParameter", "payload": { "id": "parameter:1", "name": "幅", "valueMm": 12.0, "unit": "millimeter", "memo": "更新" } }),
            json!({ "kind": "deleteParameter", "payload": { "parameterId": "parameter:1", "replacementValueMm": 10.0 } }),
            json!({ "kind": "addMeasurementAnnotation", "payload": { "id": "measurement:1", "kind": "distance", "targets": [{ "entity": "line:1" }], "labelOffsetMm": { "xMm": 0.0, "yMm": 0.0 }, "overallOffsetMm": { "xMm": 0.0, "yMm": 0.0 }, "visible": true } }),
            json!({ "kind": "moveMeasurementAnnotation", "payload": { "annotationId": "measurement:1", "delta": { "xMm": 1.0, "yMm": 2.0 }, "labelOnly": false } }),
            json!({ "kind": "deleteMeasurementAnnotation", "payload": "measurement:1" }),
            json!({ "kind": "addDimensionConstraintAnnotation", "payload": { "constraintId": "constraint:1", "labelOffsetMm": { "xMm": 0.0, "yMm": 0.0 }, "overallOffsetMm": { "xMm": 0.0, "yMm": 0.0 }, "visible": true } }),
            json!({ "kind": "moveDimensionConstraintAnnotation", "payload": { "constraintId": "constraint:1", "delta": { "xMm": 1.0, "yMm": 2.0 }, "labelOnly": true } }),
            json!({ "kind": "deleteDimensionConstraintAnnotation", "payload": "constraint:1" }),
        ];
        for value in commands {
            serde_json::from_value::<DocumentCommand>(value.clone()).unwrap_or_else(|error| {
                panic!("React semantic command should deserialize: {value}: {error}")
            });
        }
    }
}
