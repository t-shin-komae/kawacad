use kawacad_core::command::{
    CommandError, ConstraintCommandError, ConstraintCommandErrorCode, DocumentCommand,
    SelectionReference,
};
use kawacad_core::constraints::{
    ConstraintKind, ConstraintStatus, ConstraintTarget, ConstraintValue,
};
use kawacad_core::document::{
    DerivedElementPreflightKind, DocumentIoError, DocumentValidationError, ProjectDocument,
    FILE_FORMAT_VERSION, SCHEMA_VERSION,
};
use kawacad_core::output::{BuildOutputDocumentModelOptions, PrintableAreaMm};
use kawacad_core::output::{OutputBuildError, OutputDocumentModel};
use kawacad_core::print::{PrintOrientation, PrintSettings};
use kawacad_core::snapshot::CanvasViewMode;
use kawacad_output_engine::{render_pdf, render_print, RenderError};
use std::collections::BTreeMap;
use std::env;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::io::{self, BufRead, Write};
use std::process::ExitCode;

#[derive(Debug, serde::Deserialize)]
#[serde(
    tag = "kind",
    content = "payload",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
enum CoreRequest {
    LoadDocument {
        json: String,
        view_mode: Option<CanvasViewMode>,
    },
    DocumentState {
        view_mode: CanvasViewMode,
    },
    ApplyCommand {
        command: DocumentCommand,
        view_mode: Option<CanvasViewMode>,
    },
    PreviewCommand {
        command: DocumentCommand,
        view_mode: Option<CanvasViewMode>,
    },
    PreflightConstraint {
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
    },
    LayerDeletionImpact {
        layer_id: String,
    },
    PreflightDerivedElement {
        kind: DerivedElementPreflightKind,
        hit_entity_id: Option<String>,
        #[serde(default)]
        selected_entity_ids: Vec<String>,
        click_point: Option<kawacad_core::geometry::Point2>,
    },
    EvaluateMeasurement {
        annotation_id: String,
    },
    ExportSelection {
        selection: SelectionReference,
    },
    ExportPartLibraryItem {
        part_id: String,
    },
    Undo {
        view_mode: Option<CanvasViewMode>,
    },
    Redo {
        view_mode: Option<CanvasViewMode>,
    },
    WriteKawaFile {
        path: String,
        #[serde(default = "default_true")]
        mark_clean: bool,
    },
    BuildOutputDocumentModel {
        orientation: PrintOrientation,
        include_dimension_labels: bool,
        include_scale_guide: bool,
        rotation_deg: u16,
        printable_area_mm: PrintableAreaMm,
    },
    RenderPdf {
        output_document_model_json: String,
    },
    RenderPrint {
        output_document_model_json: String,
    },
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct VersionResponse {
    file_format_version: &'static str,
    schema_version: &'static str,
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct ErrorEnvelope {
    error: CoreError,
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct CoreError {
    code: ErrorCode,
    message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    details: Option<serde_json::Value>,
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
enum ErrorCode {
    InvalidJson,
    EmptyId,
    DuplicateId,
    MissingId,
    BrokenReference,
    InvalidValue,
    ConstraintInsufficientTargets,
    InvalidConstraintTarget,
    DuplicateConstraint,
    ConflictingConstraint,
    OutputOutOfGridBounds,
    RenderEmptyPages,
    RenderPageCountMismatch,
    RenderInvalidPageSize,
    RenderUnsupportedRotation,
    IoError,
    UnsupportedVersion,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
enum CoreConstraintStatus {
    Unknown,
    UnderConstrained,
    FullyConstrained,
    OverConstrained,
    Conflicting,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreDocumentState {
    snapshot: CoreDocumentSnapshotSummary,
    history: CoreHistoryState,
    persistence: CorePersistenceState,
    settings: PrintSettings,
    #[serde(skip_serializing_if = "Option::is_none")]
    mutation: Option<CoreMutationResult>,
    layers: Vec<kawacad_core::layers::Layer>,
    shared_styles: Vec<kawacad_core::shared_styles::SharedStyle>,
    parameters: Vec<CoreParameterUsage>,
    parts: Vec<kawacad_core::parts::Part>,
    entities: Vec<CoreDrawingEntity>,
    canvas_projection: kawacad_core::snapshot::CanvasProjection,
    derived_elements: Vec<kawacad_core::derived::DerivedElement>,
    free_texts: Vec<kawacad_core::free_text::FreeText>,
    round_holes: Vec<kawacad_core::round_holes::RoundHole>,
    stitch_start_points: Vec<kawacad_core::stitch_start_points::StitchStartPoint>,
    measurement_annotations: Vec<kawacad_core::measurement::MeasurementAnnotation>,
    measurement_evaluations: Vec<kawacad_core::measurement::MeasurementEvaluation>,
    dimension_constraint_annotations: Vec<kawacad_core::measurement::DimensionConstraintAnnotation>,
    warnings: Vec<kawacad_core::document::DocumentWarning>,
    entity_constraint_statuses: Vec<CoreEntityConstraintStatus>,
    coincident_point_groups: Vec<CoreCoincidentPointGroup>,
    constraints: Vec<kawacad_core::constraints::Constraint>,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CorePersistenceState {
    is_dirty: bool,
    revision: String,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreDrawingEntity {
    #[serde(flatten)]
    entity: kawacad_core::geometry::Entity,
    #[serde(flatten)]
    metadata: kawacad_core::snapshot::DrawingEntityMetadata,
}

impl std::ops::Deref for CoreDrawingEntity {
    type Target = kawacad_core::geometry::Entity;

    fn deref(&self) -> &Self::Target {
        &self.entity
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreMutationResult {
    created: CoreMutationIds,
    updated: CoreMutationIds,
    deleted: CoreMutationIds,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreMutationIds {
    layer_ids: Vec<String>,
    shared_style_ids: Vec<String>,
    parameter_ids: Vec<String>,
    part_ids: Vec<String>,
    entity_ids: Vec<String>,
    derived_element_ids: Vec<String>,
    free_text_ids: Vec<String>,
    round_hole_ids: Vec<String>,
    stitch_start_point_ids: Vec<String>,
    constraint_ids: Vec<String>,
    measurement_annotation_ids: Vec<String>,
    dimension_constraint_annotation_ids: Vec<String>,
}

#[derive(Debug, Clone)]
struct CoreSession {
    document: ProjectDocument,
    clean_document: ProjectDocument,
}

impl CoreSession {
    fn new(document: ProjectDocument) -> Self {
        Self {
            clean_document: document.clone(),
            document,
        }
    }

    fn is_dirty(&self) -> bool {
        self.document != self.clean_document
    }
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreHistoryState {
    can_undo: bool,
    can_redo: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreEntityConstraintStatus {
    entity_id: String,
    status: CoreConstraintStatus,
    remaining_dof: usize,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreCoincidentPointGroup {
    id: String,
    representative: kawacad_core::geometry::Point2,
    targets: Vec<kawacad_core::constraints::ConstraintTarget>,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreDocumentSnapshotSummary {
    name: String,
    statistics: CoreDocumentStatistics,
    edit_display_summary: CoreConstraintSummary,
    output_preview_summary: CoreConstraintSummary,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreDocumentStatistics {
    layer_count: usize,
    shared_style_count: usize,
    parameter_count: usize,
    part_count: usize,
    entity_count: usize,
    derived_element_count: usize,
    constraint_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreConstraintSummary {
    visible_entity_count: usize,
    constraint_count: usize,
    constraint_status: CoreConstraintStatus,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoreParameterUsage {
    id: String,
    name: String,
    value_mm: f64,
    unit: kawacad_core::parameters::ParameterUnit,
    memo: String,
    usage_count: usize,
    used_constraint_ids: Vec<String>,
    unused: bool,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    if matches!(args.next().as_deref(), Some("--version-json")) {
        println!("{}", version_json());
        return Ok(());
    }

    let args = env::args().skip(1).collect::<Vec<_>>();
    let mut session = CoreSession::new(document_from_args(&args)?);
    let stdin = io::stdin();
    let mut stdout = io::stdout().lock();

    for line in stdin.lock().lines() {
        let line = line.map_err(|error| format!("stdin read failed: {error}"))?;
        if line.trim().is_empty() {
            continue;
        }
        let response = handle_session_request_json(&mut session, &line);
        writeln!(stdout, "{response}").map_err(|error| format!("stdout write failed: {error}"))?;
        stdout
            .flush()
            .map_err(|error| format!("stdout flush failed: {error}"))?;
    }
    Ok(())
}

fn document_from_args(args: &[String]) -> Result<ProjectDocument, String> {
    match args {
        [] => Ok(ProjectDocument::new("Untitled".to_owned())),
        [flag, name] if flag == "--new" => Ok(ProjectDocument::new(name.clone())),
        [flag, path] if flag == "--read-kawa-file" => {
            ProjectDocument::read_json_file(path).map_err(|error| format_document_io_error(&error))
        }
        _ => Err(
            "usage: kawacad-core-process [--new name | --read-kawa-file path | --version-json]"
                .to_owned(),
        ),
    }
}

fn version_json() -> String {
    serde_json::to_string(&VersionResponse {
        file_format_version: FILE_FORMAT_VERSION,
        schema_version: SCHEMA_VERSION,
    })
    .expect("version response should serialize")
}

#[cfg(test)]
fn handle_request_json(document: &mut ProjectDocument, request_json: &str) -> String {
    let mut session = CoreSession::new(document.clone());
    let response = handle_session_request_json(&mut session, request_json);
    *document = session.document;
    response
}

fn handle_session_request_json(session: &mut CoreSession, request_json: &str) -> String {
    match serde_json::from_str::<CoreRequest>(request_json) {
        Ok(request) => match handle_request(session, request) {
            Ok(response) => response,
            Err(error) => error_json(error),
        },
        Err(error) => error_json(CoreError {
            code: ErrorCode::InvalidJson,
            message: format!("rpc request deserialization failed: {error}"),
            details: None,
        }),
    }
}

fn handle_request(session: &mut CoreSession, request: CoreRequest) -> Result<String, CoreError> {
    match request {
        CoreRequest::LoadDocument { json, view_mode } => ProjectDocument::from_json_str(&json)
            .map(|loaded_document| {
                session.document = loaded_document.clone();
                session.clean_document = loaded_document;
                session_document_state_json(
                    session,
                    view_mode.unwrap_or(CanvasViewMode::EditDisplay),
                    None,
                )
            })
            .map_err(core_error_from_document_io),
        CoreRequest::DocumentState { view_mode } => {
            Ok(session_document_state_json(session, view_mode, None))
        }
        CoreRequest::ApplyCommand { command, view_mode } => {
            let command_kind = command.kind_name();
            let before = session.document.clone();
            session
                .document
                .apply_command(command)
                .map(|()| {
                    let mutation = mutation_between(&before, &session.document);
                    session_document_state_json(
                        session,
                        view_mode.unwrap_or(CanvasViewMode::EditDisplay),
                        Some(mutation),
                    )
                })
                .map_err(|error| core_error_from_command(error, command_kind))
        }
        CoreRequest::PreviewCommand { command, view_mode } => {
            let command_kind = command.kind_name();
            session
                .document
                .preview_command(command)
                .map(|preview| {
                    document_state_json_with_context(
                        &preview,
                        view_mode.unwrap_or(CanvasViewMode::EditDisplay),
                        preview != session.clean_document,
                        None,
                    )
                })
                .map_err(|error| core_error_from_command(error, command_kind))
        }
        CoreRequest::PreflightConstraint { kind, targets } => session
            .document
            .preflight_constraint(kind, targets)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "constraint preflight",
                    reason: "failed to serialize preflight result",
                })
            })
            .map_err(|error| core_error_from_command(error, "preflightConstraint")),
        CoreRequest::LayerDeletionImpact { layer_id } => session
            .document
            .layer_deletion_impact(&layer_id)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "layer deletion impact",
                    reason: "failed to serialize layer deletion impact",
                })
            })
            .map_err(|error| core_error_from_command(error, "layerDeletionImpact")),
        CoreRequest::PreflightDerivedElement {
            kind,
            hit_entity_id,
            selected_entity_ids,
            click_point,
        } => session
            .document
            .preflight_derived_element(kind, hit_entity_id, selected_entity_ids, click_point)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "derived element preflight",
                    reason: "failed to serialize derived element preflight",
                })
            })
            .map_err(|error| core_error_from_command(error, "preflightDerivedElement")),
        CoreRequest::EvaluateMeasurement { annotation_id } => session
            .document
            .evaluate_measurement_by_id(&annotation_id)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "measurement evaluation",
                    reason: "failed to serialize measurement evaluation",
                })
            })
            .map_err(|error| core_error_from_command(error, "evaluateMeasurement")),
        CoreRequest::ExportSelection { selection } => session
            .document
            .export_selection(selection)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "selection clipboard",
                    reason: "failed to serialize selection export",
                })
            })
            .map_err(|error| core_error_from_command(error, "exportSelection")),
        CoreRequest::ExportPartLibraryItem { part_id } => session
            .document
            .export_part_library_item(&part_id)
            .and_then(|result| {
                serde_json::to_string(&result).map_err(|_| CommandError::InvalidValue {
                    field: "part library",
                    reason: "failed to serialize part library export",
                })
            })
            .map_err(|error| core_error_from_command(error, "exportPartLibraryItem")),
        CoreRequest::Undo { view_mode } => {
            let before = session.document.clone();
            session
                .document
                .undo()
                .map(|()| {
                    let mutation = mutation_between(&before, &session.document);
                    session_document_state_json(
                        session,
                        view_mode.unwrap_or(CanvasViewMode::EditDisplay),
                        Some(mutation),
                    )
                })
                .map_err(|error| core_error_from_command(error, "undo"))
        }
        CoreRequest::Redo { view_mode } => {
            let before = session.document.clone();
            session
                .document
                .redo()
                .map(|()| {
                    let mutation = mutation_between(&before, &session.document);
                    session_document_state_json(
                        session,
                        view_mode.unwrap_or(CanvasViewMode::EditDisplay),
                        Some(mutation),
                    )
                })
                .map_err(|error| core_error_from_command(error, "redo"))
        }
        CoreRequest::WriteKawaFile { path, mark_clean } => session
            .document
            .write_json_file(path)
            .map(|()| {
                if mark_clean {
                    session.clean_document = session.document.clone();
                }
                serde_json::json!({ "written": true }).to_string()
            })
            .map_err(core_error_from_document_io),
        CoreRequest::BuildOutputDocumentModel {
            orientation,
            include_dimension_labels,
            include_scale_guide,
            rotation_deg,
            printable_area_mm,
        } => {
            let result = session
                .document
                .build_output_document_model(BuildOutputDocumentModelOptions {
                    orientation,
                    include_dimension_labels,
                    include_scale_guide,
                    rotation_deg,
                    printable_area_mm,
                })
                .map_err(core_error_from_output_build)?;
            serde_json::to_string(&result).map_err(|error| CoreError {
                code: ErrorCode::Unknown,
                message: format!("output document model serialization failed: {error}"),
                details: None,
            })
        }
        CoreRequest::RenderPdf {
            output_document_model_json,
        } => {
            let model: OutputDocumentModel = serde_json::from_str(&output_document_model_json)
                .map_err(|error| CoreError {
                    code: ErrorCode::InvalidJson,
                    message: format!("output document model deserialization failed: {error}"),
                    details: None,
                })?;
            let pdf = render_pdf(&model).map_err(|error| core_error_from_render(error, "pdf"))?;
            Ok(serde_json::json!({
                "pdfHex": hex_encode(&pdf.bytes)
            })
            .to_string())
        }
        CoreRequest::RenderPrint {
            output_document_model_json,
        } => {
            let model: OutputDocumentModel = serde_json::from_str(&output_document_model_json)
                .map_err(|error| CoreError {
                    code: ErrorCode::InvalidJson,
                    message: format!("output document model deserialization failed: {error}"),
                    details: None,
                })?;
            let print_data =
                render_print(&model).map_err(|error| core_error_from_render(error, "print"))?;
            serde_json::to_string(&print_data).map_err(|error| CoreError {
                code: ErrorCode::Unknown,
                message: format!("print render data serialization failed: {error}"),
                details: None,
            })
        }
    }
}

fn core_error_from_render(error: RenderError, operation: &str) -> CoreError {
    let (code, details) = match error {
        RenderError::EmptyPages => (ErrorCode::RenderEmptyPages, None),
        RenderError::PageCountMismatch { declared, actual } => (
            ErrorCode::RenderPageCountMismatch,
            Some(serde_json::json!({ "declaredPageCount": declared, "actualPageCount": actual })),
        ),
        RenderError::InvalidPageSize => (ErrorCode::RenderInvalidPageSize, None),
        RenderError::UnsupportedRotation(rotation_deg) => (
            ErrorCode::RenderUnsupportedRotation,
            Some(serde_json::json!({ "rotationDeg": rotation_deg })),
        ),
    };
    CoreError {
        code,
        message: format!("{operation} render failed: {error:?}"),
        details,
    }
}

fn error_json(error: CoreError) -> String {
    serde_json::to_string(&ErrorEnvelope { error }).expect("error response should serialize")
}

#[cfg(test)]
fn document_state(document: &ProjectDocument, view_mode: CanvasViewMode) -> CoreDocumentState {
    document_state_with_context(document, view_mode, false, None)
}

fn session_document_state_json(
    session: &CoreSession,
    view_mode: CanvasViewMode,
    mutation: Option<CoreMutationResult>,
) -> String {
    document_state_json_with_context(&session.document, view_mode, session.is_dirty(), mutation)
}

fn document_state_json_with_context(
    document: &ProjectDocument,
    view_mode: CanvasViewMode,
    is_dirty: bool,
    mutation: Option<CoreMutationResult>,
) -> String {
    serde_json::to_string(&document_state_with_context(
        document, view_mode, is_dirty, mutation,
    ))
    .expect("document state should serialize")
}

fn document_state_with_context(
    document: &ProjectDocument,
    view_mode: CanvasViewMode,
    is_dirty: bool,
    mutation: Option<CoreMutationResult>,
) -> CoreDocumentState {
    let edit_display_snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let output_preview_snapshot = document.drawing_snapshot(CanvasViewMode::OutputPreview);
    let visible_snapshot = document.drawing_snapshot(view_mode);
    let drawing_metadata = document
        .drawing_entity_metadata(view_mode)
        .into_iter()
        .map(|item| (item.entity_id.clone(), item))
        .collect::<BTreeMap<_, _>>();
    CoreDocumentState {
        snapshot: CoreDocumentSnapshotSummary {
            name: document.metadata().name.clone(),
            statistics: CoreDocumentStatistics {
                layer_count: document.layers().len(),
                shared_style_count: document.shared_styles().len(),
                parameter_count: document.parameters().len(),
                part_count: document.parts().len(),
                entity_count: document.entities().len(),
                derived_element_count: document.derived_elements().len(),
                constraint_count: user_constraint_count(document),
            },
            edit_display_summary: CoreConstraintSummary {
                visible_entity_count: edit_display_snapshot.entities.len(),
                constraint_count: user_constraint_count(document),
                constraint_status: CoreConstraintStatus::from(
                    edit_display_snapshot.constraint_status,
                ),
            },
            output_preview_summary: CoreConstraintSummary {
                visible_entity_count: output_preview_snapshot.entities.len(),
                constraint_count: user_constraint_count(document),
                constraint_status: CoreConstraintStatus::from(
                    output_preview_snapshot.constraint_status,
                ),
            },
        },
        history: CoreHistoryState {
            can_undo: document.can_undo(),
            can_redo: document.can_redo(),
        },
        persistence: CorePersistenceState {
            is_dirty,
            revision: persistence_revision(document),
        },
        settings: document.settings().clone(),
        mutation,
        layers: document.layers().to_vec(),
        shared_styles: document.shared_styles().to_vec(),
        parameters: parameters_with_usage(document),
        parts: document.parts().to_vec(),
        entities: visible_snapshot
            .entities
            .into_iter()
            .map(|entity| CoreDrawingEntity {
                metadata: drawing_metadata
                    .get(&entity.id)
                    .cloned()
                    .unwrap_or_else(|| kawacad_core::snapshot::DrawingEntityMetadata {
                        entity_id: entity.id.clone(),
                        ..Default::default()
                    }),
                entity,
            })
            .collect(),
        canvas_projection: document.canvas_projection(view_mode),
        derived_elements: document.derived_elements().to_vec(),
        free_texts: document.free_texts().to_vec(),
        round_holes: document.round_holes().to_vec(),
        stitch_start_points: document.stitch_start_points().to_vec(),
        measurement_annotations: document.measurement_annotations().to_vec(),
        measurement_evaluations: document.measurement_evaluations(),
        dimension_constraint_annotations: document.dimension_constraint_annotations().to_vec(),
        warnings: document.document_warnings().to_vec(),
        entity_constraint_statuses: document
            .entity_constraint_statuses()
            .into_iter()
            .map(|status| CoreEntityConstraintStatus {
                entity_id: status.entity_id,
                status: CoreConstraintStatus::from(status.status),
                remaining_dof: status.remaining_dof,
            })
            .collect(),
        coincident_point_groups: document
            .coincident_point_groups()
            .into_iter()
            .map(|group| CoreCoincidentPointGroup {
                id: group.id,
                representative: group.representative,
                targets: group.targets,
            })
            .collect(),
        constraints: document
            .constraints()
            .iter()
            .filter(|constraint| !is_implicit_constraint_id(&constraint.id))
            .cloned()
            .collect(),
    }
}

fn persistence_revision(document: &ProjectDocument) -> String {
    let bytes = serde_json::to_vec(document).expect("project document should serialize");
    let mut hasher = DefaultHasher::new();
    bytes.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn mutation_between(before: &ProjectDocument, after: &ProjectDocument) -> CoreMutationResult {
    let (created_layers, updated_layers, deleted_layers) =
        collection_diff(before.layers(), after.layers(), |item| item.id.as_str());
    let (created_styles, updated_styles, deleted_styles) =
        collection_diff(before.shared_styles(), after.shared_styles(), |item| {
            item.id.as_str()
        });
    let (created_parameters, updated_parameters, deleted_parameters) =
        collection_diff(before.parameters(), after.parameters(), |item| {
            item.id.as_str()
        });
    let (created_parts, updated_parts, deleted_parts) =
        collection_diff(before.parts(), after.parts(), |item| item.id.as_str());
    let (created_entities, updated_entities, deleted_entities) =
        collection_diff(before.entities(), after.entities(), |item| item.id.as_str());
    let (created_derived, updated_derived, deleted_derived) = collection_diff(
        before.derived_elements(),
        after.derived_elements(),
        |item| item.id.as_str(),
    );
    let (created_texts, updated_texts, deleted_texts) =
        collection_diff(before.free_texts(), after.free_texts(), |item| {
            item.id.as_str()
        });
    let (created_holes, updated_holes, deleted_holes) =
        collection_diff(before.round_holes(), after.round_holes(), |item| {
            item.id.as_str()
        });
    let (created_stitches, updated_stitches, deleted_stitches) = collection_diff(
        before.stitch_start_points(),
        after.stitch_start_points(),
        |item| item.id.as_str(),
    );
    let (mut created_constraints, mut updated_constraints, mut deleted_constraints) =
        collection_diff(before.constraints(), after.constraints(), |item| {
            item.id.as_str()
        });
    for ids in [
        &mut created_constraints,
        &mut updated_constraints,
        &mut deleted_constraints,
    ] {
        ids.retain(|id| !is_implicit_constraint_id(id));
    }
    let (created_measurements, updated_measurements, deleted_measurements) = collection_diff(
        before.measurement_annotations(),
        after.measurement_annotations(),
        |item| item.id.as_str(),
    );
    let (created_dimensions, updated_dimensions, deleted_dimensions) = collection_diff(
        before.dimension_constraint_annotations(),
        after.dimension_constraint_annotations(),
        |item| item.constraint_id.as_str(),
    );

    CoreMutationResult {
        created: CoreMutationIds {
            layer_ids: created_layers,
            shared_style_ids: created_styles,
            parameter_ids: created_parameters,
            part_ids: created_parts,
            entity_ids: created_entities,
            derived_element_ids: created_derived,
            free_text_ids: created_texts,
            round_hole_ids: created_holes,
            stitch_start_point_ids: created_stitches,
            constraint_ids: created_constraints,
            measurement_annotation_ids: created_measurements,
            dimension_constraint_annotation_ids: created_dimensions,
        },
        updated: CoreMutationIds {
            layer_ids: updated_layers,
            shared_style_ids: updated_styles,
            parameter_ids: updated_parameters,
            part_ids: updated_parts,
            entity_ids: updated_entities,
            derived_element_ids: updated_derived,
            free_text_ids: updated_texts,
            round_hole_ids: updated_holes,
            stitch_start_point_ids: updated_stitches,
            constraint_ids: updated_constraints,
            measurement_annotation_ids: updated_measurements,
            dimension_constraint_annotation_ids: updated_dimensions,
        },
        deleted: CoreMutationIds {
            layer_ids: deleted_layers,
            shared_style_ids: deleted_styles,
            parameter_ids: deleted_parameters,
            part_ids: deleted_parts,
            entity_ids: deleted_entities,
            derived_element_ids: deleted_derived,
            free_text_ids: deleted_texts,
            round_hole_ids: deleted_holes,
            stitch_start_point_ids: deleted_stitches,
            constraint_ids: deleted_constraints,
            measurement_annotation_ids: deleted_measurements,
            dimension_constraint_annotation_ids: deleted_dimensions,
        },
    }
}

fn collection_diff<T, F>(
    before: &[T],
    after: &[T],
    id: F,
) -> (Vec<String>, Vec<String>, Vec<String>)
where
    T: PartialEq,
    F: Fn(&T) -> &str,
{
    let before_by_id = before
        .iter()
        .map(|item| (id(item), item))
        .collect::<BTreeMap<_, _>>();
    let after_by_id = after
        .iter()
        .map(|item| (id(item), item))
        .collect::<BTreeMap<_, _>>();
    let created = after_by_id
        .keys()
        .filter(|item_id| !before_by_id.contains_key(*item_id))
        .map(|item_id| (*item_id).to_owned())
        .collect();
    let updated = after_by_id
        .iter()
        .filter(|(item_id, item)| {
            before_by_id
                .get(*item_id)
                .is_some_and(|previous| *previous != **item)
        })
        .map(|(item_id, _)| (*item_id).to_owned())
        .collect();
    let deleted = before_by_id
        .keys()
        .filter(|item_id| !after_by_id.contains_key(*item_id))
        .map(|item_id| (*item_id).to_owned())
        .collect();
    (created, updated, deleted)
}

fn is_implicit_constraint_id(id: &str) -> bool {
    id.starts_with("constraint:implicit:")
}

fn user_constraint_count(document: &ProjectDocument) -> usize {
    document
        .constraints()
        .iter()
        .filter(|constraint| !is_implicit_constraint_id(&constraint.id))
        .count()
}

fn parameters_with_usage(document: &ProjectDocument) -> Vec<CoreParameterUsage> {
    document
        .parameters()
        .iter()
        .map(|parameter| {
            let used_constraint_ids: Vec<String> = document
                .constraints()
                .iter()
                .filter(|constraint| {
                    !is_implicit_constraint_id(&constraint.id)
                        && matches!(
                            constraint.value,
                            Some(ConstraintValue::Parameter(ref parameter_id))
                                if parameter_id == &parameter.id
                        )
                })
                .map(|constraint| constraint.id.clone())
                .collect();
            let used_derived_element_ids: Vec<String> = document
                .derived_elements()
                .iter()
                .filter(|derived_element| match &derived_element.kind {
                    kawacad_core::derived::DerivedElementKind::OffsetCurve(offset_curve) => {
                        matches!(
                            offset_curve.distance,
                            ConstraintValue::Parameter(ref parameter_id) if parameter_id == &parameter.id
                        )
                    }
                    kawacad_core::derived::DerivedElementKind::Fillet(fillet) => {
                        matches!(
                            fillet.radius,
                            ConstraintValue::Parameter(ref parameter_id) if parameter_id == &parameter.id
                        )
                    }
                })
                .map(|derived_element| derived_element.id.clone())
                .collect();
            let unused = used_constraint_ids.is_empty() && used_derived_element_ids.is_empty();
            CoreParameterUsage {
                id: parameter.id.clone(),
                name: parameter.name.clone(),
                value_mm: parameter.value_mm,
                unit: parameter.unit,
                memo: parameter.memo.clone(),
                usage_count: used_constraint_ids.len() + used_derived_element_ids.len(),
                used_constraint_ids: used_constraint_ids
                    .into_iter()
                    .chain(used_derived_element_ids)
                    .collect(),
                unused,
            }
        })
        .collect()
}

impl From<ConstraintStatus> for CoreConstraintStatus {
    fn from(value: ConstraintStatus) -> Self {
        match value {
            ConstraintStatus::Unknown => Self::Unknown,
            ConstraintStatus::UnderConstrained => Self::UnderConstrained,
            ConstraintStatus::FullyConstrained => Self::FullyConstrained,
            ConstraintStatus::OverConstrained => Self::OverConstrained,
            ConstraintStatus::Conflicting => Self::Conflicting,
        }
    }
}

fn core_error_from_command(error: CommandError, command_kind: &'static str) -> CoreError {
    if let CommandError::Constraint(constraint_error) = &error {
        return core_error_from_constraint_command(constraint_error, command_kind);
    }
    if let CommandError::BrokenReference {
        target_kind,
        target_id,
        ..
    } = &error
    {
        let mut details = serde_json::Map::new();
        details.insert("commandKind".to_owned(), command_kind.into());
        if *target_kind == "parameter" {
            details.insert("parameterId".to_owned(), target_id.clone().into());
        } else {
            details.insert("targetIds".to_owned(), serde_json::json!([target_id]));
        }
        return CoreError {
            code: ErrorCode::BrokenReference,
            message: format_command_error(&error),
            details: Some(serde_json::Value::Object(details)),
        };
    }
    let code = match &error {
        CommandError::EmptyId(_) => ErrorCode::EmptyId,
        CommandError::DuplicateId { .. } => ErrorCode::DuplicateId,
        CommandError::MissingId { .. } => ErrorCode::MissingId,
        CommandError::InvalidEntity(_) | CommandError::InvalidValue { .. } => {
            ErrorCode::InvalidValue
        }
        CommandError::BrokenReference { .. } => ErrorCode::BrokenReference,
        CommandError::Constraint(_) => unreachable!("constraint error handled above"),
    };
    CoreError {
        code,
        message: format_command_error(&error),
        details: None,
    }
}

fn core_error_from_constraint_command(
    error: &ConstraintCommandError,
    command_kind: &'static str,
) -> CoreError {
    let code = match error.code {
        ConstraintCommandErrorCode::InsufficientTargets => ErrorCode::ConstraintInsufficientTargets,
        ConstraintCommandErrorCode::InvalidTarget => ErrorCode::InvalidConstraintTarget,
        ConstraintCommandErrorCode::Duplicate => ErrorCode::DuplicateConstraint,
        ConstraintCommandErrorCode::Conflicting => ErrorCode::ConflictingConstraint,
    };
    CoreError {
        code,
        message: format_constraint_command_error(error),
        details: Some(constraint_error_details(error, command_kind)),
    }
}

fn constraint_error_details(
    error: &ConstraintCommandError,
    command_kind: &'static str,
) -> serde_json::Value {
    let mut details = serde_json::Map::new();
    details.insert("commandKind".to_owned(), command_kind.into());
    details.insert(
        "constraintKind".to_owned(),
        constraint_kind_name(error.constraint_kind).into(),
    );
    details.insert(
        "constraintId".to_owned(),
        error.constraint_id.clone().into(),
    );
    details.insert("targetIds".to_owned(), serde_json::json!(error.target_ids));
    if let Some(actual_target_count) = error.actual_target_count {
        details.insert("actualTargetCount".to_owned(), actual_target_count.into());
    }
    if let Some(required_target_count) = error.required_target_count {
        details.insert(
            "requiredTargetCount".to_owned(),
            required_target_count.into(),
        );
    }
    if !error.expected_target_kinds.is_empty() {
        details.insert(
            "expectedTargetKinds".to_owned(),
            serde_json::json!(error.expected_target_kinds),
        );
    }
    if !error.invalid_target_ids.is_empty() {
        details.insert(
            "invalidTargetIds".to_owned(),
            serde_json::json!(error.invalid_target_ids),
        );
    }
    if let Some(existing_constraint_id) = &error.existing_constraint_id {
        details.insert(
            "existingConstraintId".to_owned(),
            existing_constraint_id.clone().into(),
        );
    }
    if !error.conflicting_constraint_ids.is_empty() {
        details.insert(
            "conflictingConstraintIds".to_owned(),
            serde_json::json!(error.conflicting_constraint_ids),
        );
    }
    serde_json::Value::Object(details)
}

fn core_error_from_document_io(error: DocumentIoError) -> CoreError {
    let code = match &error {
        DocumentIoError::ReadFailed(_) | DocumentIoError::WriteFailed(_) => ErrorCode::IoError,
        DocumentIoError::ValidationFailed(
            DocumentValidationError::UnsupportedFileFormatVersion { .. }
            | DocumentValidationError::UnsupportedSchemaVersion { .. },
        ) => ErrorCode::UnsupportedVersion,
        DocumentIoError::ValidationFailed(DocumentValidationError::EmptyId(_)) => {
            ErrorCode::EmptyId
        }
        DocumentIoError::ValidationFailed(DocumentValidationError::DuplicateId { .. }) => {
            ErrorCode::DuplicateId
        }
        DocumentIoError::ValidationFailed(DocumentValidationError::BrokenReference { .. }) => {
            ErrorCode::BrokenReference
        }
        DocumentIoError::ValidationFailed(
            DocumentValidationError::InvalidValue { .. }
            | DocumentValidationError::InvalidEntity { .. },
        ) => ErrorCode::InvalidValue,
        DocumentIoError::SerializeFailed(_) | DocumentIoError::DeserializeFailed(_) => {
            ErrorCode::InvalidJson
        }
    };
    CoreError {
        code,
        message: format_document_io_error(&error),
        details: None,
    }
}

fn core_error_from_output_build(error: OutputBuildError) -> CoreError {
    match error {
        OutputBuildError::OutOfGridBounds => CoreError {
            code: ErrorCode::OutputOutOfGridBounds,
            message: "出力対象がA4 5x5グリッドの範囲外にあります。".to_string(),
            details: Some(serde_json::json!({
                "grid": {
                    "paperSize": "a4",
                    "columns": [-2, -1, 0, 1, 2],
                    "rows": [-2, -1, 0, 1, 2]
                }
            })),
        },
    }
}

fn format_document_io_error(error: &DocumentIoError) -> String {
    match error {
        DocumentIoError::SerializeFailed(message) => {
            format!("document serialization failed: {message}")
        }
        DocumentIoError::DeserializeFailed(message) => {
            format!("document deserialization failed: {message}")
        }
        DocumentIoError::ReadFailed(message) => format!("document read failed: {message}"),
        DocumentIoError::WriteFailed(message) => format!("document write failed: {message}"),
        DocumentIoError::ValidationFailed(error) => format_document_validation_error(error),
    }
}

fn format_document_validation_error(error: &DocumentValidationError) -> String {
    match error {
        DocumentValidationError::EmptyId(kind) => format!("{kind} id must not be empty"),
        DocumentValidationError::DuplicateId { kind, id } => format!("duplicate {kind} id: {id}"),
        DocumentValidationError::BrokenReference {
            source,
            target_kind,
            target_id,
        } => format!("{source} references missing {target_kind}: {target_id}"),
        DocumentValidationError::InvalidValue { field, reason } => {
            format!("invalid {field}: {reason}")
        }
        DocumentValidationError::InvalidEntity { entity_id, error } => {
            format!("invalid entity {entity_id}: {error:?}")
        }
        DocumentValidationError::UnsupportedFileFormatVersion { found } => {
            format!("unsupported file format version: {found}")
        }
        DocumentValidationError::UnsupportedSchemaVersion { found } => {
            format!("unsupported schema version: {found}")
        }
    }
}

fn format_command_error(error: &CommandError) -> String {
    match error {
        CommandError::EmptyId(kind) => format!("{kind} id must not be empty"),
        CommandError::DuplicateId { kind, id } => format!("duplicate {kind} id: {id}"),
        CommandError::MissingId { kind, id } => format!("missing {kind} id: {id}"),
        CommandError::InvalidEntity(error) => format!("invalid entity: {error:?}"),
        CommandError::InvalidValue { field, reason } => format!("invalid {field}: {reason}"),
        CommandError::BrokenReference {
            source,
            target_kind,
            target_id,
        } => format!("{source} references missing {target_kind}: {target_id}"),
        CommandError::Constraint(error) => format_constraint_command_error(error),
    }
}

fn format_constraint_command_error(error: &ConstraintCommandError) -> String {
    match error.code {
        ConstraintCommandErrorCode::InsufficientTargets => {
            format!(
                "{} constraint requires {} target(s), got {}",
                constraint_kind_name(error.constraint_kind),
                error.required_target_count.unwrap_or_default(),
                error.actual_target_count.unwrap_or_default()
            )
        }
        ConstraintCommandErrorCode::InvalidTarget => {
            format!(
                "{} constraint received invalid targets",
                constraint_kind_name(error.constraint_kind)
            )
        }
        ConstraintCommandErrorCode::Duplicate => {
            format!(
                "{} constraint duplicates an existing constraint",
                constraint_kind_name(error.constraint_kind)
            )
        }
        ConstraintCommandErrorCode::Conflicting => {
            format!(
                "{} constraint would conflict with existing constraints",
                constraint_kind_name(error.constraint_kind)
            )
        }
    }
}

fn constraint_kind_name(kind: ConstraintKind) -> &'static str {
    match kind {
        ConstraintKind::Coincident => "coincident",
        ConstraintKind::Horizontal => "horizontal",
        ConstraintKind::Vertical => "vertical",
        ConstraintKind::Parallel => "parallel",
        ConstraintKind::Perpendicular => "perpendicular",
        ConstraintKind::Tangent => "tangent",
        ConstraintKind::Symmetric => "symmetric",
        ConstraintKind::Distance => "distance",
        ConstraintKind::HorizontalDistance => "horizontalDistance",
        ConstraintKind::VerticalDistance => "verticalDistance",
        ConstraintKind::PointLineDistance => "pointLineDistance",
        ConstraintKind::LineLineDistance => "lineLineDistance",
        ConstraintKind::PointOnLine => "pointOnLine",
        ConstraintKind::SegmentLength => "segmentLength",
        ConstraintKind::Angle => "angle",
        ConstraintKind::Fixed => "fixed",
        ConstraintKind::Diameter => "diameter",
        ConstraintKind::Radius => "radius",
        ConstraintKind::EqualSegmentLength => "equalSegmentLength",
    }
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut encoded = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        use std::fmt::Write as _;
        let _ = write!(&mut encoded, "{byte:02x}");
    }
    encoded
}

#[cfg(test)]
mod tests {
    use super::*;
    use kawacad_core::derived::{DerivedElement, Fillet, OffsetCurve, OffsetDirection};
    use kawacad_core::geometry::{Circle, Entity, EntityKind, LineSegment, Point2};
    use kawacad_core::measurement::{MeasurementAnnotation, MeasurementAnnotationKind};
    use kawacad_core::output::BuildOutputDocumentModelResult;
    use kawacad_core::parameters::{Parameter, ParameterUnit};
    use kawacad_output_engine::PrintRenderData;

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
        Entity::new(id, EntityKind::LineSegment(LineSegment::new(start, end)))
    }

    fn circle_entity(id: &str, center: Point2, radius_mm: f64) -> Entity {
        Entity::new(id, EntityKind::Circle(Circle { center, radius_mm }))
    }

    fn parameter(id: &str, value_mm: f64) -> Parameter {
        Parameter {
            id: id.to_owned(),
            name: id.to_owned(),
            value_mm,
            unit: ParameterUnit::Millimeter,
            memo: String::new(),
        }
    }

    #[test]
    fn version_json_reports_full_versions() {
        assert_eq!(
            version_json(),
            r#"{"fileFormatVersion":"0.1.0","schemaVersion":"0.1.0"}"#
        );
    }

    #[test]
    fn document_from_args_covers_new_default_file_and_usage_paths() {
        let default_document = document_from_args(&[]).expect("default document");
        assert_eq!(default_document.metadata().name, "Untitled");
        assert_eq!(default_document.shared_styles().len(), 6);

        let named_document =
            document_from_args(&["--new".to_owned(), "Named".to_owned()]).expect("named document");
        assert_eq!(named_document.metadata().name, "Named");
        assert_eq!(
            named_document
                .shared_styles()
                .iter()
                .map(|style| style.id.as_str())
                .collect::<Vec<_>>(),
            [
                "style:outer-cut-line",
                "style:stitch-line",
                "style:fold-line",
                "style:center-line",
                "style:construction-line",
                "style:dimension-line",
            ]
        );

        let path = std::env::temp_dir().join(format!(
            "kawacad-core-process-read-{}.kawa",
            std::process::id()
        ));
        let source = ProjectDocument::new("Read Pipe".to_owned());
        source
            .write_json_file(&path)
            .expect("source document should be written");
        let loaded_document =
            document_from_args(&["--read-kawa-file".to_owned(), path.display().to_string()])
                .expect("document should load from file");
        assert_eq!(loaded_document.metadata().name, "Read Pipe");
        let _ = std::fs::remove_file(path);

        let usage_error =
            document_from_args(&["--unknown".to_owned(), "value".to_owned()]).unwrap_err();
        assert!(usage_error.contains("usage: kawacad-core-process"));
    }

    #[test]
    fn document_error_formatters_preserve_specific_context() {
        assert_eq!(
            format_document_io_error(&DocumentIoError::ReadFailed("missing file".to_owned())),
            "document read failed: missing file"
        );
        assert_eq!(
            format_document_io_error(&DocumentIoError::WriteFailed("readonly".to_owned())),
            "document write failed: readonly"
        );
        assert_eq!(
            format_document_validation_error(&DocumentValidationError::BrokenReference {
                source: "constraint",
                target_kind: "entity",
                target_id: "entity:missing".to_owned(),
            }),
            "constraint references missing entity: entity:missing"
        );
        assert_eq!(
            format_document_validation_error(&DocumentValidationError::InvalidValue {
                field: "schema",
                reason: "bad value",
            }),
            "invalid schema: bad value"
        );
    }

    #[test]
    fn handles_document_state_request_as_json_line_payload() {
        let mut document = ProjectDocument::new("Pipe Test".to_owned());
        let response = handle_request_json(
            &mut document,
            r#"{"kind":"documentState","payload":{"viewMode":"editDisplay"}}"#,
        );
        assert!(response.contains(r#""name":"Pipe Test""#));
        assert!(!response.contains(r#""error""#));
    }

    #[test]
    fn part_commands_and_state_round_trip_through_the_boundary() {
        let mut document = ProjectDocument::new("Part Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                "entity:outline",
                point(10.0, 20.0),
                15.0,
            )))
            .expect("outline circle");
        let create = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "createPart",
                    "payload": {
                        "id": "part:wallet",
                        "name": "財布外装",
                        "originMm": { "xMm": 10.0, "yMm": 20.0 },
                        "entityIds": ["entity:outline"]
                    }
                },
                "viewMode": "editDisplay"
            }
        });
        let response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &create.to_string()))
                .expect("part response json");
        assert_eq!(response["snapshot"]["statistics"]["partCount"], 1);
        assert_eq!(response["parts"][0]["name"], "財布外装");
        assert_eq!(
            response["parts"][0]["outlineEntityIds"][0],
            "entity:outline"
        );

        let delete = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": { "kind": "deletePart", "payload": "part:wallet" },
                "viewMode": "editDisplay"
            }
        });
        let response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &delete.to_string()))
                .expect("delete part response json");
        assert_eq!(response["snapshot"]["statistics"]["partCount"], 0);
        assert_eq!(response["snapshot"]["statistics"]["entityCount"], 1);
    }

    #[test]
    fn session_reports_core_owned_dirty_state_and_mutation_ids() {
        let mut session = CoreSession::new(ProjectDocument::new("Dirty Pipe"));
        let initial: serde_json::Value = serde_json::from_str(&handle_session_request_json(
            &mut session,
            r#"{"kind":"documentState","payload":{"viewMode":"editDisplay"}}"#,
        ))
        .expect("initial state");
        assert_eq!(initial["persistence"]["isDirty"], false);

        let apply = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "addEntity",
                    "payload": {
                        "id": "entity:created",
                        "layerId": null,
                        "kind": { "point": { "xMm": 1.0, "yMm": 2.0 } }
                    }
                }
            }
        });
        let applied: serde_json::Value = serde_json::from_str(&handle_session_request_json(
            &mut session,
            &apply.to_string(),
        ))
        .expect("applied state");
        assert_eq!(applied["persistence"]["isDirty"], true);
        assert_eq!(
            applied["mutation"]["created"]["entityIds"],
            serde_json::json!(["entity:created"])
        );

        let snapshot_path = std::env::temp_dir().join(format!(
            "kawacad-core-process-snapshot-{}.kawa",
            std::process::id()
        ));
        let snapshot_request = serde_json::json!({
            "kind": "writeKawaFile",
            "payload": { "path": snapshot_path, "markClean": false }
        });
        assert_eq!(
            handle_session_request_json(&mut session, &snapshot_request.to_string()),
            r#"{"written":true}"#
        );
        assert!(session.is_dirty());

        let save_path = std::env::temp_dir().join(format!(
            "kawacad-core-process-clean-{}.kawa",
            std::process::id()
        ));
        let save_request = serde_json::json!({
            "kind": "writeKawaFile",
            "payload": { "path": save_path }
        });
        assert_eq!(
            handle_session_request_json(&mut session, &save_request.to_string()),
            r#"{"written":true}"#
        );
        assert!(!session.is_dirty());
        let _ = std::fs::remove_file(snapshot_path);
        let _ = std::fs::remove_file(save_path);
    }

    #[test]
    fn drawing_entities_include_explicit_derived_metadata() {
        let mut document = ProjectDocument::new("Derived Metadata");
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:first",
                EntityKind::LineSegment(LineSegment::new(point(0.0, 0.0), point(10.0, 0.0))),
            )))
            .expect("first line");
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:second",
                EntityKind::LineSegment(LineSegment::new(point(10.0, 0.0), point(10.0, 10.0))),
            )))
            .expect("second line");
        document
            .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
                "derived:fillet",
                None,
                Fillet {
                    source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                    radius: ConstraintValue::FixedMm(2.0),
                    closed: false,
                },
            )))
            .expect("fillet");

        let state = document_state(&document, CanvasViewMode::EditDisplay);
        let first = state
            .entities
            .iter()
            .find(|item| item.id == "entity:first")
            .expect("source entity");
        assert!(first.metadata.suppressed_by_fillet);
        let resolved_line = state
            .entities
            .iter()
            .find(|item| item.metadata.resolved_index == Some(0))
            .expect("resolved line");
        assert_eq!(
            resolved_line.metadata.derived_element_id.as_deref(),
            Some("derived:fillet")
        );
        assert_eq!(
            resolved_line.metadata.source_entity_id.as_deref(),
            Some("entity:first")
        );
    }

    #[test]
    fn part_library_export_and_insert_keep_id_remapping_inside_core() {
        let mut source = ProjectDocument::new("Library Source");
        source
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                "entity:outline",
                point(10.0, 20.0),
                15.0,
            )))
            .expect("outline");
        source
            .apply_command(DocumentCommand::CreatePart {
                id: "part:source".to_owned(),
                name: "Source Part".to_owned(),
                origin_mm: Some(point(10.0, 20.0)),
                entity_ids: vec!["entity:outline".to_owned()],
            })
            .expect("source part");
        let export = source
            .export_part_library_item("part:source")
            .expect("part library export");

        let mut session = CoreSession::new(ProjectDocument::new("Library Target"));
        let insert = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "insertPartLibraryItem",
                    "payload": {
                        "libraryJson": export.library_json,
                        "newPartId": "part:inserted",
                        "newName": "Inserted Part",
                        "idNamespace": "library-test",
                        "delta": { "xMm": 5.0, "yMm": -5.0 }
                    }
                }
            }
        });
        let response: serde_json::Value = serde_json::from_str(&handle_session_request_json(
            &mut session,
            &insert.to_string(),
        ))
        .expect("insert response");
        assert_eq!(
            response["mutation"]["created"]["partIds"],
            serde_json::json!(["part:inserted"])
        );
        assert_eq!(
            response["mutation"]["created"]["entityIds"],
            serde_json::json!(["entity:copy-library-test:entity:outline"])
        );
        assert_eq!(response["parts"][0]["name"], "Inserted Part");
        assert_eq!(response["parts"][0]["originMm"]["xMm"], 15.0);
        assert_eq!(response["parts"][0]["originMm"]["yMm"], 15.0);
    }

    #[test]
    fn load_apply_preview_undo_and_redo_requests_return_document_state() {
        let mut document = ProjectDocument::new("Pipe Test".to_owned());
        let loaded_json = ProjectDocument::new("Loaded Pipe".to_owned())
            .to_json_pretty_string()
            .expect("document should serialize");
        let load_request = serde_json::json!({
            "kind": "loadDocument",
            "payload": {
                "json": loaded_json,
                "viewMode": "outputPreview"
            }
        })
        .to_string();
        let load_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &load_request))
                .expect("load response should be json");
        assert_eq!(load_response["snapshot"]["name"], "Loaded Pipe");

        let apply_request = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": DocumentCommand::AddEntity(line_entity(
                    "entity:line-a",
                    point(0.0, 0.0),
                    point(10.0, 0.0),
                )),
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let apply_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &apply_request))
                .expect("apply response should be json");
        assert_eq!(apply_response["snapshot"]["statistics"]["entityCount"], 1);
        assert_eq!(apply_response["history"]["canUndo"], true);

        let preview_request = serde_json::json!({
            "kind": "previewCommand",
            "payload": {
                "command": DocumentCommand::AddEntity(line_entity(
                    "entity:preview",
                    point(0.0, 5.0),
                    point(10.0, 5.0),
                )),
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let preview_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &preview_request))
                .expect("preview response should be json");
        assert_eq!(preview_response["snapshot"]["statistics"]["entityCount"], 2);
        assert!(document.entity("entity:preview").is_none());

        let undo_response: serde_json::Value = serde_json::from_str(&handle_request_json(
            &mut document,
            r#"{"kind":"undo","payload":{"viewMode":"editDisplay"}}"#,
        ))
        .expect("undo response should be json");
        assert_eq!(undo_response["snapshot"]["statistics"]["entityCount"], 0);
        assert_eq!(undo_response["history"]["canRedo"], true);

        let redo_response: serde_json::Value = serde_json::from_str(&handle_request_json(
            &mut document,
            r#"{"kind":"redo","payload":{"viewMode":"editDisplay"}}"#,
        ))
        .expect("redo response should be json");
        assert_eq!(redo_response["snapshot"]["statistics"]["entityCount"], 1);
    }

    #[test]
    fn document_state_reports_parameter_usage_constraints_and_groups() {
        let mut document = ProjectDocument::new("Usage Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddParameter(parameter(
                "parameter:length",
                12.0,
            )))
            .expect("parameter should be added");
        document
            .apply_command(DocumentCommand::AddParameter(parameter(
                "parameter:unused",
                5.0,
            )))
            .expect("unused parameter should be added");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:a",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("entity a");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:b",
                point(10.0, 0.0),
                point(10.0, 10.0),
            )))
            .expect("entity b");
        document
            .apply_command(DocumentCommand::AddConstraint(
                kawacad_core::constraints::Constraint {
                    id: "constraint:length".to_owned(),
                    kind: ConstraintKind::SegmentLength,
                    targets: vec![ConstraintTarget::Entity("entity:a".to_owned())],
                    value: Some(ConstraintValue::Parameter("parameter:length".to_owned())),
                    status: ConstraintStatus::Unknown,
                },
            ))
            .expect("length constraint");
        document
            .apply_command(DocumentCommand::AddConstraint(
                kawacad_core::constraints::Constraint {
                    id: "constraint:coincident".to_owned(),
                    kind: ConstraintKind::Coincident,
                    targets: vec![
                        ConstraintTarget::ControlPoint {
                            entity_id: "entity:a".to_owned(),
                            point: kawacad_core::constraints::ControlPointKind::End,
                        },
                        ConstraintTarget::ControlPoint {
                            entity_id: "entity:b".to_owned(),
                            point: kawacad_core::constraints::ControlPointKind::Start,
                        },
                    ],
                    value: None,
                    status: ConstraintStatus::Unknown,
                },
            ))
            .expect("coincident constraint");
        document
            .apply_command(DocumentCommand::AddDerivedElement(
                DerivedElement::offset_curve(
                    "derived:offset",
                    None,
                    OffsetCurve {
                        source_entity_ids: vec!["entity:a".to_owned()],
                        source_resolved_entity_ids: Vec::new(),
                        distance: ConstraintValue::Parameter("parameter:length".to_owned()),
                        direction: OffsetDirection::Left,
                    },
                ),
            ))
            .expect("offset");

        let state = document_state(&document, CanvasViewMode::EditDisplay);
        let used = state
            .parameters
            .iter()
            .find(|parameter| parameter.id == "parameter:length")
            .expect("used parameter");
        assert_eq!(used.usage_count, 2);
        assert_eq!(
            used.used_constraint_ids,
            vec!["constraint:length".to_owned(), "derived:offset".to_owned()]
        );
        let unused = state
            .parameters
            .iter()
            .find(|parameter| parameter.id == "parameter:unused")
            .expect("unused parameter");
        assert!(unused.unused);
        assert_eq!(state.snapshot.statistics.constraint_count, 2);
        assert_eq!(state.constraints.len(), 2);
        assert!(!state.coincident_point_groups.is_empty());
        assert!(!state.entity_constraint_statuses.is_empty());
    }

    #[test]
    fn preflight_constraint_returns_angle_value_from_core_shared_endpoint_logic() {
        let mut document = ProjectDocument::new("Preflight Angle Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:first",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(10.0, 0.0),
                    Point2::new(0.0, 0.0),
                )),
            )))
            .expect("first line should be added");
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:second",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(0.0, 5.0),
                )),
            )))
            .expect("second line should be added");

        let request = serde_json::json!({
            "kind": "preflightConstraint",
            "payload": {
                "kind": "angle",
                "targets": [
                    { "entity": "entity:first" },
                    { "entity": "entity:second" }
                ]
            }
        })
        .to_string();

        let response = handle_request_json(&mut document, &request);
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(value["kind"], "angle");
        assert_eq!(value["value"]["fixedDegrees"], 90.0);
        assert!(!value.as_object().unwrap().contains_key("error"));
    }

    #[test]
    fn semantic_preflight_measurement_and_clipboard_requests_round_trip_through_json() {
        let mut document = ProjectDocument::new("Semantic Pipe".to_owned());
        for entity in [
            line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
            line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
            line_entity("entity:top", point(20.0, 10.0), point(0.0, 10.0)),
            line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
        ] {
            document
                .apply_command(DocumentCommand::AddEntity(entity))
                .unwrap();
        }
        document
            .apply_command(DocumentCommand::AddMeasurementAnnotation(
                MeasurementAnnotation {
                    id: "measurement:length".into(),
                    kind: MeasurementAnnotationKind::SegmentLength,
                    targets: vec![ConstraintTarget::Entity("entity:bottom".into())],
                    label_offset_mm: point(0.0, 0.0),
                    overall_offset_mm: point(0.0, 0.0),
                    visible: true,
                },
            ))
            .unwrap();

        let preflight = serde_json::json!({
            "kind": "preflightDerivedElement",
            "payload": {
                "kind": "offsetCurve",
                "hitEntityId": "entity:bottom",
                "selectedEntityIds": [],
                "clickPoint": { "xMm": 10.0, "yMm": 5.0 }
            }
        });
        let response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &preflight.to_string()))
                .unwrap();
        assert_eq!(response["offsetOptions"][0]["scope"], "closedContour");
        assert_eq!(response["offsetOptions"][0]["direction"], "inward");

        let selected_range_preflight = serde_json::json!({
            "kind": "preflightDerivedElement",
            "payload": {
                "kind": "offsetCurve",
                "hitEntityId": "entity:bottom",
                "selectedEntityIds": ["entity:bottom", "entity:right"],
                "clickPoint": { "xMm": 10.0, "yMm": 5.0 }
            }
        });
        let selected_range_response: serde_json::Value = serde_json::from_str(
            &handle_request_json(&mut document, &selected_range_preflight.to_string()),
        )
        .unwrap();
        assert_eq!(
            selected_range_response["offsetOptions"][0]["scope"],
            "selectedRange"
        );
        assert_eq!(
            selected_range_response["offsetOptions"][0]["sourceEntityIds"],
            serde_json::json!(["entity:bottom", "entity:right"])
        );

        let evaluation: serde_json::Value = serde_json::from_str(&handle_request_json(
            &mut document,
            r#"{"kind":"evaluateMeasurement","payload":{"annotationId":"measurement:length"}}"#,
        ))
        .unwrap();
        assert_eq!(evaluation["value"]["fixedMm"], 20.0);

        let export: serde_json::Value = serde_json::from_str(&handle_request_json(
            &mut document,
            r#"{"kind":"exportSelection","payload":{"selection":{"entityIds":["entity:bottom"],"derivedElementIds":[],"constraintIds":[],"measurementAnnotationIds":[],"stitchStartPointIds":[],"freeTextIds":[]}}}"#,
        ))
        .unwrap();
        assert_eq!(export["rootCount"], 1);
        let token = export["clipboardJson"].as_str().unwrap();
        let paste = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "pasteSelection",
                    "payload": {
                        "clipboardJson": token,
                        "idNamespace": "pipe",
                        "delta": { "xMm": 5.0, "yMm": 5.0 }
                    }
                },
                "viewMode": "editDisplay"
            }
        });
        let pasted: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &paste.to_string())).unwrap();
        assert_eq!(pasted["snapshot"]["statistics"]["entityCount"], 5);
        assert!(document.entity("entity:copy-pipe:entity:bottom").is_some());
    }

    #[test]
    fn returns_error_envelope_for_invalid_request() {
        let mut document = ProjectDocument::new("Pipe Test".to_owned());
        let response = handle_request_json(&mut document, r#"{"kind":"missing"}"#);
        assert!(response.contains(r#""error""#));
        assert!(response.contains(r#""code":"invalidJson""#));
    }

    #[test]
    fn request_errors_cover_io_render_and_command_error_mappings() {
        let mut document = ProjectDocument::new("Error Pipe".to_owned());

        let invalid_load = serde_json::json!({
            "kind": "loadDocument",
            "payload": {
                "json": "{",
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let invalid_load_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &invalid_load))
                .expect("invalid load response should be json");
        assert_eq!(invalid_load_response["error"]["code"], "invalidJson");

        let duplicate_layer = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "addLayer",
                    "payload": {
                        "id": "layer:cut-line",
                        "name": "Cut Line Again",
                        "kind": "cutLine",
                        "visible": true,
                        "printable": true,
                        "style": {
                            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
                            "strokeWidthMm": 0.2,
                            "pattern": "solid"
                        }
                    }
                },
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let duplicate_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &duplicate_layer))
                .expect("duplicate response should be json");
        assert_eq!(duplicate_response["error"]["code"], "duplicateId");

        let missing_delete = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "deleteEntity",
                    "payload": "entity:missing"
                },
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let missing_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &missing_delete))
                .expect("missing response should be json");
        assert_eq!(missing_response["error"]["code"], "missingId");

        let missing_parameter = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "addConstraint",
                    "payload": {
                        "id": "constraint:bad-parameter",
                        "kind": "segmentLength",
                        "targets": [{ "entity": "entity:missing" }],
                        "value": { "parameter": "parameter:missing" },
                        "status": "unknown"
                    }
                },
                "viewMode": "editDisplay"
            }
        })
        .to_string();
        let broken_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &missing_parameter))
                .expect("broken response should be json");
        assert!(matches!(
            broken_response["error"]["code"].as_str(),
            Some("brokenReference") | Some("invalidConstraintTarget")
        ));

        let invalid_render_pdf = serde_json::json!({
            "kind": "renderPdf",
            "payload": {
                "outputDocumentModelJson": "{"
            }
        })
        .to_string();
        let invalid_pdf_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &invalid_render_pdf))
                .expect("invalid pdf response should be json");
        assert_eq!(invalid_pdf_response["error"]["code"], "invalidJson");

        let invalid_render_print = serde_json::json!({
            "kind": "renderPrint",
            "payload": {
                "outputDocumentModelJson": "{"
            }
        })
        .to_string();
        let invalid_print_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &invalid_render_print))
                .expect("invalid print response should be json");
        assert_eq!(invalid_print_response["error"]["code"], "invalidJson");

        let write_directory = serde_json::json!({
            "kind": "writeKawaFile",
            "payload": {
                "path": std::env::temp_dir().display().to_string()
            }
        })
        .to_string();
        let write_response: serde_json::Value =
            serde_json::from_str(&handle_request_json(&mut document, &write_directory))
                .expect("write error response should be json");
        assert_eq!(write_response["error"]["code"], "ioError");
    }

    #[test]
    fn render_errors_keep_specific_codes_and_details() {
        let cases = [
            (
                RenderError::EmptyPages,
                "renderEmptyPages",
                serde_json::Value::Null,
            ),
            (
                RenderError::PageCountMismatch {
                    declared: 2,
                    actual: 1,
                },
                "renderPageCountMismatch",
                serde_json::json!({ "declaredPageCount": 2, "actualPageCount": 1 }),
            ),
            (
                RenderError::InvalidPageSize,
                "renderInvalidPageSize",
                serde_json::Value::Null,
            ),
            (
                RenderError::UnsupportedRotation(45),
                "renderUnsupportedRotation",
                serde_json::json!({ "rotationDeg": 45 }),
            ),
        ];

        for (error, expected_code, expected_details) in cases {
            let value = serde_json::to_value(ErrorEnvelope {
                error: core_error_from_render(error, "test"),
            })
            .expect("render error should serialize");
            assert_eq!(value["error"]["code"], expected_code);
            assert_eq!(value["error"]["details"], expected_details);
        }
    }

    #[test]
    fn add_constraint_failure_returns_structured_insufficient_target_error() {
        let mut document = ProjectDocument::new("Constraint Error Pipe".to_owned());
        let request = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "addConstraint",
                    "payload": {
                        "id": "constraint:length-a",
                        "kind": "segmentLength",
                        "targets": [],
                        "value": { "fixedMm": 20.0 },
                        "status": "unknown"
                    }
                },
                "viewMode": "editDisplay"
            }
        })
        .to_string();

        let response = handle_request_json(&mut document, &request);
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(value["error"]["code"], "constraintInsufficientTargets");
        assert_eq!(value["error"]["details"]["commandKind"], "addConstraint");
        assert_eq!(value["error"]["details"]["constraintKind"], "segmentLength");
        assert_eq!(value["error"]["details"]["actualTargetCount"], 0);
        assert_eq!(value["error"]["details"]["requiredTargetCount"], 1);
        assert_eq!(
            value["error"]["details"]["expectedTargetKinds"],
            serde_json::json!(["line"])
        );
    }

    #[test]
    fn add_constraint_failure_returns_structured_invalid_target_error() {
        let mut document = ProjectDocument::new("Constraint Error Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:circle-a",
                EntityKind::Circle(kawacad_core::geometry::Circle {
                    center: Point2::new(0.0, 0.0),
                    radius_mm: 10.0,
                }),
            )))
            .expect("circle should be added");
        let request = serde_json::json!({
            "kind": "applyCommand",
            "payload": {
                "command": {
                    "kind": "addConstraint",
                    "payload": {
                        "id": "constraint:horizontal-a",
                        "kind": "horizontal",
                        "targets": [{ "entity": "entity:circle-a" }],
                        "value": null,
                        "status": "unknown"
                    }
                },
                "viewMode": "editDisplay"
            }
        })
        .to_string();

        let response = handle_request_json(&mut document, &request);
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(value["error"]["code"], "invalidConstraintTarget");
        assert_eq!(value["error"]["details"]["constraintKind"], "horizontal");
        assert_eq!(
            value["error"]["details"]["expectedTargetKinds"],
            serde_json::json!(["line", "point"])
        );
        assert_eq!(
            value["error"]["details"]["invalidTargetIds"],
            serde_json::json!(["entity:circle-a"])
        );
    }

    #[test]
    fn write_kawa_file_writes_current_document() {
        let mut document = ProjectDocument::new("Write Pipe".to_owned());
        let path = std::env::temp_dir().join(format!(
            "kawacad-core-process-write-{}.kawa",
            std::process::id()
        ));
        let request = format!(
            r#"{{"kind":"writeKawaFile","payload":{{"path":"{}"}}}}"#,
            path.display()
        );
        let response = handle_request_json(&mut document, &request);
        assert_eq!(response, r#"{"written":true}"#);
        let written = std::fs::read_to_string(&path).expect("document should be written");
        assert!(written.contains("\"fileFormatVersion\": \"0.1.0\""));
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn ui_core_interface_schema_contains_output_contract_definitions() {
        let schema: serde_json::Value =
            serde_json::from_str(include_str!("../../../schemas/interface/0.1.0.schema.json"))
                .expect("interface schema should be valid json");
        let defs = schema["$defs"]
            .as_object()
            .expect("interface schema should define $defs");

        for key in [
            "preflightConstraintRequest",
            "preflightConstraintResponse",
            "buildOutputDocumentModelRequest",
            "buildOutputDocumentModelResponse",
            "renderPdfRequest",
            "renderPdfResponse",
            "renderPrintRequest",
            "exportPartLibraryItemRequest",
            "partLibraryExport",
            "writeKawaFileRequest",
            "persistenceState",
            "mutationResult",
            "drawingEntityMetadata",
            "outputDocumentModel",
            "printRenderData",
        ] {
            assert!(defs.contains_key(key), "missing schema definition: {key}");
        }
    }

    #[test]
    fn shared_interface_fixtures_match_rust_wire_contract() {
        let preflight_request: CoreRequest =
            serde_json::from_str(interface_fixture("preflight-constraint-request.json"))
                .expect("preflight constraint request fixture should deserialize");
        assert!(matches!(
            preflight_request,
            CoreRequest::PreflightConstraint { .. }
        ));

        let build_request: CoreRequest = serde_json::from_str(interface_fixture(
            "build-output-document-model-request.json",
        ))
        .expect("build output request fixture should deserialize");
        assert!(matches!(
            build_request,
            CoreRequest::BuildOutputDocumentModel { .. }
        ));

        let derived_style_request: CoreRequest = serde_json::from_str(interface_fixture(
            "derived-element-shared-style-command-request.json",
        ))
        .expect("derived element shared style command request fixture should deserialize");
        assert!(matches!(
            derived_style_request,
            CoreRequest::ApplyCommand { .. }
        ));

        let build_response: BuildOutputDocumentModelResult = serde_json::from_str(
            interface_fixture("build-output-document-model-response.json"),
        )
        .expect("build output response fixture should deserialize");
        assert_eq!(build_response.output_document_model.page_count, 1);
        assert_eq!(build_response.warnings.len(), 1);

        let output_model: OutputDocumentModel =
            serde_json::from_str(interface_fixture("output-document-model.json"))
                .expect("output document model fixture should deserialize");
        assert_eq!(output_model.page_count, output_model.pages.len());

        let render_pdf_request: CoreRequest =
            serde_json::from_str(interface_fixture("render-pdf-request.json"))
                .expect("render pdf request fixture should deserialize");
        assert_render_request_model_deserializes(render_pdf_request);

        let render_pdf_response: serde_json::Value =
            serde_json::from_str(interface_fixture("render-pdf-response.json"))
                .expect("render pdf response fixture should be valid json");
        assert!(render_pdf_response["pdfHex"]
            .as_str()
            .expect("pdfHex should be a string")
            .starts_with("25504446"));

        let render_print_request: CoreRequest =
            serde_json::from_str(interface_fixture("render-print-request.json"))
                .expect("render print request fixture should deserialize");
        assert_render_request_model_deserializes(render_print_request);

        let print_data: PrintRenderData =
            serde_json::from_str(interface_fixture("print-render-data.json"))
                .expect("print render data fixture should deserialize");
        assert_eq!(print_data.pages.len(), 1);

        let print_data_value: serde_json::Value =
            serde_json::from_str(interface_fixture("print-render-data.json"))
                .expect("print render data fixture should be valid json");
        assert_eq!(
            print_data_value["pages"][0]["commands"][0]["payload"]["start_mm"]["xMm"],
            serde_json::json!(0.0)
        );
        assert_eq!(
            print_data_value["pages"][0]["commands"][1]["payload"]["position_mm"]["xMm"],
            serde_json::json!(10.0)
        );
    }

    #[test]
    fn build_output_document_model_request_returns_serialized_output_model() {
        let mut document = ProjectDocument::new("Output Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:line-a",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(20.0, 0.0),
                )),
            )))
            .expect("entity should be added");

        let response = handle_request_json(
            &mut document,
            r#"{"kind":"buildOutputDocumentModel","payload":{"orientation":"portrait","includeDimensionLabels":false,"includeScaleGuide":true,"rotationDeg":0,"printableAreaMm":{"leftMm":-100.0,"rightMm":100.0,"topMm":143.5,"bottomMm":-143.5}}}"#,
        );
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(value["outputDocumentModel"]["paperSize"], "a4");
        assert_eq!(value["outputDocumentModel"]["pageCount"], 1);
        assert_eq!(
            value["outputDocumentModel"]["pages"][0]["guide"]["label"],
            "50mm"
        );
        assert_eq!(value["warnings"], serde_json::json!([]));
    }

    #[test]
    fn build_output_document_model_request_returns_warnings_without_failing() {
        let mut document = ProjectDocument::new("Overflow Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:line-a",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(101.0, 0.0),
                )),
            )))
            .expect("overflowing entity should be added");

        let response = handle_request_json(
            &mut document,
            r#"{"kind":"buildOutputDocumentModel","payload":{"orientation":"portrait","includeDimensionLabels":false,"includeScaleGuide":false,"rotationDeg":0,"printableAreaMm":{"leftMm":-100.0,"rightMm":100.0,"topMm":143.5,"bottomMm":-143.5}}}"#,
        );
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(
            value["warnings"][0]["kind"],
            serde_json::Value::String("outOfPrintableBounds".to_string())
        );
        assert_eq!(value["outputDocumentModel"]["pageCount"], 1);
        assert_eq!(
            value["outputDocumentModel"]["pages"][0]["graphics"][0]["entityId"],
            "entity:line-a"
        );
    }

    #[test]
    fn build_output_document_model_request_fails_when_output_exceeds_a4_grid() {
        let mut document = ProjectDocument::new("Out Of Grid Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:outside-grid",
                EntityKind::Point(Point2::new(526.0, 0.0)),
            )))
            .expect("outside-grid entity should be added");

        let response = handle_request_json(
            &mut document,
            r#"{"kind":"buildOutputDocumentModel","payload":{"orientation":"portrait","includeDimensionLabels":false,"includeScaleGuide":false,"rotationDeg":0,"printableAreaMm":{"leftMm":-100.0,"rightMm":100.0,"topMm":143.5,"bottomMm":-143.5}}}"#,
        );
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");

        assert_eq!(value["error"]["code"], "outputOutOfGridBounds");
        assert!(value.get("outputDocumentModel").is_none());
    }

    #[test]
    fn render_pdf_request_returns_hex_encoded_pdf_bytes() {
        let mut document = ProjectDocument::new("PDF Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:line-a",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(20.0, 0.0),
                )),
            )))
            .expect("entity should be added");

        let model_json = serde_json::to_string(
            &document
                .build_output_document_model(BuildOutputDocumentModelOptions {
                    orientation: PrintOrientation::Portrait,
                    include_dimension_labels: false,
                    include_scale_guide: false,
                    rotation_deg: 0,
                    printable_area_mm: PrintableAreaMm {
                        left_mm: -100.0,
                        right_mm: 100.0,
                        top_mm: 143.5,
                        bottom_mm: -143.5,
                    },
                })
                .expect("output document model should build")
                .output_document_model,
        )
        .expect("model should serialize");

        let request = serde_json::json!({
            "kind": "renderPdf",
            "payload": {
                "outputDocumentModelJson": model_json
            }
        })
        .to_string();
        let response = handle_request_json(&mut document, &request);
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");
        let pdf_hex = value["pdfHex"]
            .as_str()
            .expect("pdf hex should be a string");

        assert!(pdf_hex.starts_with("255044462d312e34"));
    }

    #[test]
    fn render_print_request_returns_serialized_print_render_data() {
        let mut document = ProjectDocument::new("Print Pipe".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(Entity::new(
                "entity:line-a",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(20.0, 0.0),
                )),
            )))
            .expect("entity should be added");

        let model_json = serde_json::to_string(
            &document
                .build_output_document_model(BuildOutputDocumentModelOptions {
                    orientation: PrintOrientation::Portrait,
                    include_dimension_labels: false,
                    include_scale_guide: true,
                    rotation_deg: 0,
                    printable_area_mm: PrintableAreaMm {
                        left_mm: -100.0,
                        right_mm: 100.0,
                        top_mm: 143.5,
                        bottom_mm: -143.5,
                    },
                })
                .expect("output document model should build")
                .output_document_model,
        )
        .expect("model should serialize");

        let request = serde_json::json!({
            "kind": "renderPrint",
            "payload": {
                "outputDocumentModelJson": model_json
            }
        })
        .to_string();
        let response = handle_request_json(&mut document, &request);
        let value: serde_json::Value =
            serde_json::from_str(&response).expect("response should be valid json");
        let command_kinds = value["pages"][0]["commands"]
            .as_array()
            .expect("commands should be an array")
            .iter()
            .filter_map(|command| command["kind"].as_str())
            .collect::<Vec<_>>();

        assert_eq!(value["orientation"], "portrait");
        assert_eq!(value["pages"][0]["rotationDeg"], 0);
        assert!(command_kinds.contains(&"strokeLine"));
        assert!(command_kinds.contains(&"drawText"));
    }

    #[test]
    fn render_pdf_and_print_requests_share_multi_page_output_model_contract() {
        let mut document = ProjectDocument::new("Multi Page Output Pipe".to_owned());
        let model_json = serde_json::json!({
            "paperSize": "a4",
            "orientation": "portrait",
            "scale": "actualSize",
            "pageCount": 2,
            "pages": [
                {
                    "widthMm": 210.0,
                    "heightMm": 297.0,
                    "gridColumn": 0,
                    "gridRow": 0,
                    "rotationDeg": 0,
                    "printableAreaMm": {
                        "leftMm": -100.0,
                        "rightMm": 100.0,
                        "topMm": 143.5,
                        "bottomMm": -143.5
                    },
                    "graphics": [
                        {
                            "entityId": "entity:page-1-crossing-line",
                            "kind": "lineSegment",
                            "geometry": {
                                "kind": "lineSegment",
                                "payload": {
                                    "start_mm": { "xMm": 80.0, "yMm": 0.0 },
                                    "end_mm": { "xMm": 220.0, "yMm": 0.0 }
                                }
                            },
                            "style": {
                                "stroke": {
                                    "red": 0.0,
                                    "green": 0.0,
                                    "blue": 0.0,
                                    "alpha": 1.0
                                },
                                "strokeWidthMm": 0.2,
                                "pattern": "solid"
                            }
                        }
                    ],
                    "texts": [],
                    "guide": null
                },
                {
                    "widthMm": 210.0,
                    "heightMm": 297.0,
                    "gridColumn": 1,
                    "gridRow": 0,
                    "rotationDeg": 0,
                    "printableAreaMm": {
                        "leftMm": -100.0,
                        "rightMm": 100.0,
                        "topMm": 143.5,
                        "bottomMm": -143.5
                    },
                    "graphics": [
                        {
                            "entityId": "entity:page-2-crossing-line",
                            "kind": "lineSegment",
                            "geometry": {
                                "kind": "lineSegment",
                                "payload": {
                                    "start_mm": { "xMm": -220.0, "yMm": 0.0 },
                                    "end_mm": { "xMm": -80.0, "yMm": 0.0 }
                                }
                            },
                            "style": {
                                "stroke": {
                                    "red": 0.0,
                                    "green": 0.0,
                                    "blue": 0.0,
                                    "alpha": 1.0
                                },
                                "strokeWidthMm": 0.2,
                                "pattern": "solid"
                            }
                        }
                    ],
                    "texts": [],
                    "guide": null
                }
            ]
        })
        .to_string();

        let pdf_request = serde_json::json!({
            "kind": "renderPdf",
            "payload": {
                "outputDocumentModelJson": model_json
            }
        })
        .to_string();
        let pdf_response = handle_request_json(&mut document, &pdf_request);
        let pdf_value: serde_json::Value =
            serde_json::from_str(&pdf_response).expect("pdf response should be valid json");
        let pdf_hex = pdf_value["pdfHex"]
            .as_str()
            .expect("pdf hex should be a string");

        assert!(pdf_hex.starts_with("255044462d312e34"));
        assert!(pdf_hex.contains(&hex_encode(b"/Count 2")));
        assert!(pdf_hex.contains(&hex_encode(b"(PAGE 1/2)")));
        assert!(pdf_hex.contains(&hex_encode(b"(PAGE 2/2)")));

        let print_request = serde_json::json!({
            "kind": "renderPrint",
            "payload": {
                "outputDocumentModelJson": model_json
            }
        })
        .to_string();
        let print_response = handle_request_json(&mut document, &print_request);
        let print_value: serde_json::Value =
            serde_json::from_str(&print_response).expect("print response should be valid json");

        assert_eq!(print_value["orientation"], "portrait");
        assert_eq!(
            print_value["pages"]
                .as_array()
                .expect("pages should be array")
                .len(),
            2
        );
        assert_eq!(
            print_value["pages"][0]["clipAreaMm"]["leftMm"],
            serde_json::json!(-105.0)
        );
        assert_eq!(
            print_value["pages"][0]["clipAreaMm"]["rightMm"],
            serde_json::json!(105.0)
        );
        assert_eq!(
            print_value["pages"][0]["commands"][0]["payload"]["end_mm"]["xMm"],
            serde_json::json!(220.0)
        );
        let page_1_guide_labels = print_value["pages"][0]["commands"]
            .as_array()
            .expect("commands should be an array")
            .iter()
            .filter(|command| command["kind"] == "drawText")
            .filter_map(|command| command["payload"]["content"].as_str())
            .collect::<Vec<_>>();
        assert!(page_1_guide_labels.contains(&"PAGE 1/2"));
        assert!(page_1_guide_labels.contains(&"JOIN TOP"));
    }

    fn interface_fixture(name: &str) -> &'static str {
        match name {
            "preflight-constraint-request.json" => {
                include_str!("../../../tests/fixtures/interface/preflight-constraint-request.json")
            }
            "build-output-document-model-request.json" => include_str!(
                "../../../tests/fixtures/interface/build-output-document-model-request.json"
            ),
            "build-output-document-model-response.json" => include_str!(
                "../../../tests/fixtures/interface/build-output-document-model-response.json"
            ),
            "derived-element-shared-style-command-request.json" => include_str!(
                "../../../tests/fixtures/interface/derived-element-shared-style-command-request.json"
            ),
            "output-document-model.json" => {
                include_str!("../../../tests/fixtures/interface/output-document-model.json")
            }
            "render-pdf-request.json" => {
                include_str!("../../../tests/fixtures/interface/render-pdf-request.json")
            }
            "render-pdf-response.json" => {
                include_str!("../../../tests/fixtures/interface/render-pdf-response.json")
            }
            "render-print-request.json" => {
                include_str!("../../../tests/fixtures/interface/render-print-request.json")
            }
            "print-render-data.json" => {
                include_str!("../../../tests/fixtures/interface/print-render-data.json")
            }
            _ => panic!("unknown interface fixture: {name}"),
        }
    }

    fn assert_render_request_model_deserializes(request: CoreRequest) {
        let output_document_model_json = match request {
            CoreRequest::RenderPdf {
                output_document_model_json,
            }
            | CoreRequest::RenderPrint {
                output_document_model_json,
            } => output_document_model_json,
            _ => panic!("request should be renderPdf or renderPrint"),
        };
        let model: OutputDocumentModel = serde_json::from_str(&output_document_model_json)
            .expect("embedded output document model should deserialize");
        assert_eq!(model.page_count, model.pages.len());
    }
}
