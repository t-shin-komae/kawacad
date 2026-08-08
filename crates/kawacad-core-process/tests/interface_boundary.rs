//! Boundary tests for the UI/Core interface.
//!
//! These tests exercise the public pipe-based Core process boundary described
//! in `docs/design/internal-interface-spec.md` and verify behavior recorded in
//! `docs/spec/functional-spec.md`.

use kawacad_core::command::DocumentCommand;
use kawacad_core::constraints::{
    Constraint, ConstraintKind, ConstraintStatus, ConstraintTarget, ConstraintValue,
    ControlPointKind,
};
use kawacad_core::derived::{DerivedElement, OffsetCurve, OffsetDirection};
use kawacad_core::free_text::FreeText;
use kawacad_core::geometry::{Arc, Circle, Entity, EntityKind, LineSegment, Point2};
use kawacad_core::layers::{Layer, LayerKind, LayerStyle, LinePattern, Rgba};
use kawacad_core::measurement::{MeasurementAnnotation, MeasurementAnnotationKind};
use kawacad_core::parameters::{Parameter, ParameterUnit};
use kawacad_core::shared_styles::SharedStyle;
use serde_json::json;
use std::cell::RefCell;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
enum LeatherConstraintStatus {
    Unknown,
    UnderConstrained,
    FullyConstrained,
    OverConstrained,
    Conflicting,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherDocumentState {
    snapshot: LeatherDocumentSnapshotSummary,
    history: LeatherHistoryState,
    layers: Vec<Layer>,
    shared_styles: Vec<SharedStyle>,
    parameters: Vec<LeatherParameterUsage>,
    entities: Vec<Entity>,
    derived_elements: Vec<DerivedElement>,
    entity_constraint_statuses: Vec<LeatherEntityConstraintStatus>,
    coincident_point_groups: Vec<LeatherCoincidentPointGroup>,
    constraints: Vec<Constraint>,
    free_texts: Vec<FreeText>,
    measurement_annotations: Vec<MeasurementAnnotation>,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherHistoryState {
    can_undo: bool,
    can_redo: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherEntityConstraintStatus {
    entity_id: String,
    status: LeatherConstraintStatus,
    remaining_dof: usize,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherCoincidentPointGroup {
    id: String,
    representative: Point2,
    targets: Vec<ConstraintTarget>,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherDocumentSnapshotSummary {
    name: String,
    statistics: LeatherDocumentStatistics,
    edit_display_summary: LeatherConstraintSummary,
    output_preview_summary: LeatherConstraintSummary,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherDocumentStatistics {
    layer_count: usize,
    shared_style_count: usize,
    parameter_count: usize,
    entity_count: usize,
    constraint_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherConstraintSummary {
    visible_entity_count: usize,
    constraint_count: usize,
    constraint_status: LeatherConstraintStatus,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LeatherParameterUsage {
    id: String,
    name: String,
    value_mm: f64,
    unit: ParameterUnit,
    memo: String,
    usage_count: usize,
    used_constraint_ids: Vec<String>,
    unused: bool,
}

#[derive(Debug, serde::Deserialize)]
struct ErrorEnvelope {
    error: ErrorBody,
}

#[derive(Debug, serde::Deserialize)]
struct ErrorBody {
    code: String,
    message: String,
    #[serde(default)]
    details: serde_json::Value,
}

struct TestDocument {
    child: Child,
    stdin: RefCell<ChildStdin>,
    stdout: RefCell<BufReader<ChildStdout>>,
    startup_json_file: Option<PathBuf>,
}

impl TestDocument {
    fn new(name: &str) -> Self {
        Self::start(&["--new", name], None)
    }

    fn from_json(json: &str) -> Self {
        let doc = Self::new("json-loader");
        doc.load_document(json);
        doc
    }

    fn from_file(path: &Path) -> Self {
        Self::start(&["--read-kawa-file", path.to_string_lossy().as_ref()], None)
    }

    fn start(args: &[&str], startup_json_file: Option<PathBuf>) -> Self {
        let mut child = Command::new(env!("CARGO_BIN_EXE_kawacad-core-process"))
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .expect("core process should start");
        let stdin = child.stdin.take().expect("core process stdin should open");
        let stdout = child
            .stdout
            .take()
            .expect("core process stdout should open");
        Self {
            child,
            stdin: RefCell::new(stdin),
            stdout: RefCell::new(BufReader::new(stdout)),
            startup_json_file,
        }
    }

    fn state(&self) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "documentState",
            "payload": {
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn apply(&self, command: DocumentCommand) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "applyCommand",
            "payload": {
                "command": serde_json::to_value(command).expect("command should serialize"),
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn preview(&self, command: DocumentCommand) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "previewCommand",
            "payload": {
                "command": serde_json::to_value(command).expect("command should serialize"),
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn undo(&self) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "undo",
            "payload": {
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn redo(&self) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "redo",
            "payload": {
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn write_json_file(&self, path: &Path) {
        let response = self.rpc_value(json!({
            "kind": "writeKawaFile",
            "payload": {
                "path": path.to_string_lossy()
            }
        }));
        assert_eq!(response["written"], true);
    }

    fn load_document(&self, document_json: &str) -> LeatherDocumentState {
        let response = self.rpc_value(json!({
            "kind": "loadDocument",
            "payload": {
                "json": document_json,
                "viewMode": "editDisplay"
            }
        }));
        serde_json::from_value(response).expect("state response should decode")
    }

    fn rpc_value(&self, request: serde_json::Value) -> serde_json::Value {
        let response = self.rpc_response(request);
        if let Ok(error) = serde_json::from_str::<ErrorEnvelope>(&response) {
            panic!("unexpected core process error: {}", error.error.message);
        }
        serde_json::from_str(&response).expect("response should be valid json")
    }

    fn rpc_response(&self, request: serde_json::Value) -> String {
        let mut stdin = self.stdin.borrow_mut();
        writeln!(stdin, "{request}").expect("request should be written to core process");
        stdin.flush().expect("request should flush");
        drop(stdin);

        let mut response = String::new();
        self.stdout
            .borrow_mut()
            .read_line(&mut response)
            .expect("response should be read from core process");
        assert!(
            !response.is_empty(),
            "core process should return one JSON line"
        );
        response.trim_end_matches(['\r', '\n']).to_owned()
    }
}

impl Drop for TestDocument {
    fn drop(&mut self) {
        let _ = self.stdin.get_mut().flush();
        let _ = self.child.kill();
        let _ = self.child.wait();
        if let Some(path) = &self.startup_json_file {
            let _ = std::fs::remove_file(path);
        }
    }
}

#[test]
fn view_mode_boundary_uses_edit_display_and_output_preview_names() {
    let doc = TestDocument::new("view-mode-boundary");

    doc.apply(DocumentCommand::AddLayer(Layer::new(
        "layer:guide",
        "Guide",
        LayerKind::Dimension,
        false,
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:cut",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(20.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(
        Entity::new(
            "entity:guide",
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(0.0, 10.0),
                Point2::new(20.0, 10.0),
            )),
        )
        .on_layer("layer:guide"),
    ));

    let edit_display_state = doc.state();
    assert_eq!(edit_display_state.entities.len(), 2);

    let output_preview_response = doc.rpc_value(json!({
        "kind": "documentState",
        "payload": {
            "viewMode": "outputPreview"
        }
    }));
    assert!(output_preview_response["snapshot"]
        .get("editDisplaySummary")
        .is_some());
    assert!(output_preview_response["snapshot"]
        .get("outputPreviewSummary")
        .is_some());
    assert!(output_preview_response["snapshot"]
        .get("historySummary")
        .is_none());
    assert!(output_preview_response["snapshot"]
        .get("finalSummary")
        .is_none());

    let output_preview_state: LeatherDocumentState =
        serde_json::from_value(output_preview_response)
            .expect("output preview state should decode");
    assert_eq!(
        output_preview_state
            .entities
            .iter()
            .map(|entity| entity.id.as_str())
            .collect::<Vec<_>>(),
        ["entity:cut"]
    );

    let legacy_error = doc.rpc_error(json!({
        "kind": "documentState",
        "payload": {
            "viewMode": "historyEdit"
        }
    }));
    assert!(legacy_error.contains("historyEdit"));
}

#[test]
fn uc1_basic_shapes_and_constraint_status_are_reported_through_the_boundary() {
    let doc = TestDocument::new("uc1-basic-shapes");

    let initial = doc.state();
    assert_eq!(initial.snapshot.name, "uc1-basic-shapes");
    assert_eq!(initial.snapshot.statistics.layer_count, 1);
    assert_eq!(initial.entities.len(), 0);
    assert_eq!(
        initial.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::Unknown
    );

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-a",
        EntityKind::Point(Point2::new(0.0, 0.0)),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:point-a-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:point-a".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));

    let fixed_state = doc.state();
    assert_eq!(
        fixed_state.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::FullyConstrained
    );
    assert_eq!(fixed_state.constraints.len(), 1);
    assert_eq!(fixed_state.constraints[0].kind, ConstraintKind::Fixed);
    let point_status = fixed_state
        .entity_constraint_statuses
        .iter()
        .find(|status| status.entity_id == "entity:point-a")
        .expect("point entity status");
    assert_eq!(
        point_status.status,
        LeatherConstraintStatus::FullyConstrained
    );
    assert_eq!(point_status.remaining_dof, 0);

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(100.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:circle-a",
        EntityKind::Circle(Circle {
            center: Point2::new(10.0, 10.0),
            radius_mm: 5.0,
        }),
    )));

    let state = doc.state();
    assert_eq!(state.entities.len(), 3);
    assert!(matches!(state.entities[0].kind, EntityKind::Point(_)));
    assert!(matches!(state.entities[1].kind, EntityKind::LineSegment(_)));
    assert!(matches!(state.entities[2].kind, EntityKind::Circle(_)));

    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::FixedMm(100.0)),
        status: ConstraintStatus::Unknown,
    }));

    let constrained_state = doc.state();
    assert_eq!(
        constrained_state
            .snapshot
            .edit_display_summary
            .constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
    assert_eq!(constrained_state.constraints.len(), 2);
    assert_eq!(
        constrained_state.constraints[1].kind,
        ConstraintKind::SegmentLength
    );
    assert!(matches!(
        constrained_state.constraints[1].value,
        Some(ConstraintValue::FixedMm(100.0))
    ));
}

#[test]
fn uc2_parameter_driven_dimension_updates_are_visible_at_the_boundary() {
    let doc = TestDocument::new("uc2-parameter-update");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:anchor",
        EntityKind::Point(Point2::new(0.0, 0.0)),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(50.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddParameter(Parameter {
        id: "parameter:width".to_owned(),
        name: "width".to_owned(),
        value_mm: 50.0,
        unit: ParameterUnit::Millimeter,
        memo: "line length".to_owned(),
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:anchor-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:anchor".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::Parameter("parameter:width".to_owned())),
        status: ConstraintStatus::Unknown,
    }));

    let initial = doc.state();
    assert_eq!(initial.parameters.len(), 1);
    assert_eq!(initial.parameters[0].usage_count, 1);
    assert_eq!(
        initial.parameters[0].used_constraint_ids,
        vec!["constraint:line-a-length"]
    );
    assert!(!initial.parameters[0].unused);
    assert_eq!(initial.constraints[1].kind, ConstraintKind::SegmentLength);
    assert!(matches!(
        initial.constraints[1].value,
        Some(ConstraintValue::Parameter(ref id)) if id == "parameter:width"
    ));
    assert_eq!(
        initial.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
    assert_line_length(&initial, "entity:line-a", 50.0);

    doc.apply(DocumentCommand::SetParameterValue {
        parameter_id: "parameter:width".to_owned(),
        value_mm: 60.0,
    });

    let updated = doc.state();
    assert_eq!(updated.parameters[0].value_mm, 60.0);
    assert_eq!(updated.parameters[0].usage_count, 1);
    assert_eq!(
        updated.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
    assert_line_length(&updated, "entity:line-a", 60.0);
}

#[test]
fn uc3_conflicting_constraint_is_rejected_and_keeps_state_unchanged() {
    let doc = TestDocument::new("uc3-conflict-reject");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-a",
        EntityKind::Point(Point2::new(0.0, 0.0)),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-b",
        EntityKind::Point(Point2::new(10.0, 0.0)),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:point-a-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:point-a".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:point-b-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:point-b".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(100.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length-100".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::FixedMm(100.0)),
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    assert_eq!(before.constraints.len(), 3);
    assert_eq!(before.constraints[0].kind, ConstraintKind::Fixed);
    assert_eq!(before.constraints[1].kind, ConstraintKind::Fixed);
    assert_eq!(before.constraints[2].kind, ConstraintKind::SegmentLength);
    assert_eq!(
        before.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    let conflict = doc.rpc_error(json!({
        "kind": "applyCommand",
        "payload": {
            "command": serde_json::to_value(DocumentCommand::AddConstraint(Constraint {
                id: "constraint:line-a-length-50".to_owned(),
                kind: ConstraintKind::SegmentLength,
                targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
                value: Some(ConstraintValue::FixedMm(50.0)),
                status: ConstraintStatus::Unknown,
            }))
            .expect("command should serialize"),
            "viewMode": "editDisplay"
        }
    }));
    assert!(conflict.contains("would conflict with existing constraints"));

    let after = doc.state();
    assert_eq!(after, before);
    assert_eq!(
        after.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
}

#[test]
fn uc3_duplicate_constraint_is_rejected_and_keeps_state_unchanged() {
    let doc = TestDocument::new("uc3-duplicate-constraint");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(10.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-b",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 4.0),
            Point2::new(10.0, 4.0),
        )),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:parallel-a".to_owned(),
        kind: ConstraintKind::Parallel,
        targets: vec![
            ConstraintTarget::Entity("entity:line-a".to_owned()),
            ConstraintTarget::Entity("entity:line-b".to_owned()),
        ],
        value: None,
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    let error = doc.rpc_error_envelope(json!({
        "kind": "applyCommand",
        "payload": {
            "command": serde_json::to_value(DocumentCommand::AddConstraint(Constraint {
                id: "constraint:parallel-b".to_owned(),
                kind: ConstraintKind::Parallel,
                targets: vec![
                    ConstraintTarget::Entity("entity:line-b".to_owned()),
                    ConstraintTarget::Entity("entity:line-a".to_owned()),
                ],
                value: None,
                status: ConstraintStatus::Unknown,
            }))
            .expect("command should serialize"),
            "viewMode": "editDisplay"
        }
    }));
    assert_eq!(error.error.code, "duplicateConstraint");
    assert_eq!(error.error.details["commandKind"], "addConstraint");
    assert_eq!(error.error.details["constraintKind"], "parallel");
    assert_eq!(
        error.error.details["existingConstraintId"],
        "constraint:parallel-a"
    );

    let after = doc.state();
    assert_eq!(after.constraints.len(), 1);
    assert_eq!(after, before);
}

#[test]
fn uc4_undo_redo_restores_previous_snapshots_through_the_boundary() {
    let doc = TestDocument::new("uc4-undo-redo");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(100.0, 0.0),
        )),
    )));
    let after_first = doc.state();
    assert_eq!(after_first.entities.len(), 1);
    assert!(after_first.history.can_undo);
    assert!(!after_first.history.can_redo);
    assert!(matches!(
        after_first.entities[0].kind,
        EntityKind::LineSegment(_)
    ));

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:circle-a",
        EntityKind::Circle(Circle {
            center: Point2::new(5.0, 5.0),
            radius_mm: 3.0,
        }),
    )));
    let after_second = doc.state();
    assert_eq!(after_second.entities.len(), 2);
    assert!(matches!(
        after_second.entities[1].kind,
        EntityKind::Circle(_)
    ));

    let after_undo_1 = doc.undo();
    assert_eq!(after_undo_1.entities.len(), 1);
    assert!(after_undo_1.history.can_undo);
    assert!(after_undo_1.history.can_redo);
    assert!(matches!(
        after_undo_1.entities[0].kind,
        EntityKind::LineSegment(_)
    ));

    let after_undo_2 = doc.undo();
    assert_eq!(after_undo_2.entities.len(), 0);
    assert!(!after_undo_2.history.can_undo);
    assert!(after_undo_2.history.can_redo);
    assert_eq!(
        after_undo_2.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::Unknown
    );

    let after_redo_1 = doc.redo();
    assert_eq!(after_redo_1.entities.len(), 1);
    assert!(matches!(
        after_redo_1.entities[0].kind,
        EntityKind::LineSegment(_)
    ));

    let after_redo_2 = doc.redo();
    assert_eq!(after_redo_2.entities.len(), 2);
    assert!(after_redo_2.history.can_undo);
    assert!(!after_redo_2.history.can_redo);
    assert!(matches!(
        after_redo_2.entities[1].kind,
        EntityKind::Circle(_)
    ));

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-a",
        EntityKind::Point(Point2::new(5.0, 5.0)),
    )));
    let after_new_change = doc.state();
    assert_eq!(after_new_change.entities.len(), 3);
    assert!(after_new_change.history.can_undo);
    assert!(!after_new_change.history.can_redo);
    assert!(matches!(
        after_new_change.entities[2].kind,
        EntityKind::Point(_)
    ));

    let redo_after_new_change = doc.rpc_error(json!({
        "kind": "redo",
        "payload": {
            "viewMode": "editDisplay"
        }
    }));
    assert!(redo_after_new_change.contains("redo history"));
}

#[test]
fn uc4_compound_command_is_one_atomic_history_entry_through_the_boundary() {
    let doc = TestDocument::new("uc4-compound");

    let after_compound = doc.apply(DocumentCommand::Compound(vec![
        DocumentCommand::AddEntity(Entity::new(
            "entity:line-a",
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(0.0, 0.0),
                Point2::new(100.0, 0.0),
            )),
        )),
        DocumentCommand::AddConstraint(Constraint {
            id: "constraint:line-a-horizontal".to_owned(),
            kind: ConstraintKind::Horizontal,
            targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
            value: None,
            status: ConstraintStatus::Unknown,
        }),
    ]));

    assert_eq!(after_compound.entities.len(), 1);
    assert_eq!(after_compound.constraints.len(), 1);
    assert!(after_compound.history.can_undo);

    let after_undo = doc.undo();
    assert_eq!(after_undo.entities.len(), 0);
    assert_eq!(after_undo.constraints.len(), 0);
    assert!(after_undo.history.can_redo);

    let after_redo = doc.redo();
    assert_eq!(after_redo.entities.len(), 1);
    assert_eq!(after_redo.constraints.len(), 1);
}

#[test]
fn measurement_annotations_are_returned_separately_from_constraints_through_the_boundary() {
    let doc = TestDocument::new("measurement-annotations");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(40.0, 0.0),
        )),
    )));

    let state = doc.apply(DocumentCommand::AddMeasurementAnnotation(
        MeasurementAnnotation {
            id: "measurement:line-a-length".to_owned(),
            kind: MeasurementAnnotationKind::SegmentLength,
            targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
            label_offset_mm: Point2::new(4.0, 2.0),
            overall_offset_mm: Point2::new(0.0, 8.0),
            visible: true,
        },
    ));

    assert_eq!(state.constraints.len(), 0);
    assert_eq!(state.measurement_annotations.len(), 1);
    assert_eq!(
        state.measurement_annotations[0].id,
        "measurement:line-a-length"
    );

    let after_undo = doc.undo();
    assert!(after_undo.measurement_annotations.is_empty());

    let after_redo = doc.redo();
    assert_eq!(after_redo.measurement_annotations.len(), 1);
}

#[test]
fn free_texts_are_returned_and_mutated_through_the_boundary() {
    let doc = TestDocument::new("free-text-boundary");

    let added = doc.apply(DocumentCommand::AddFreeText(FreeText::new(
        "free-text:note",
        "Skive this edge",
        Point2::new(12.0, -8.0),
        4.0,
    )));
    assert_eq!(added.free_texts.len(), 1);
    assert_eq!(added.free_texts[0].content, "Skive this edge");
    assert_eq!(added.free_texts[0].position_mm, Point2::new(12.0, -8.0));
    assert_eq!(added.free_texts[0].font_size_mm, 4.0);

    let updated = doc.apply(DocumentCommand::UpdateFreeText(FreeText::new(
        "free-text:note",
        "Skive after dye",
        Point2::new(20.0, -6.0),
        5.0,
    )));
    assert_eq!(updated.free_texts.len(), 1);
    assert_eq!(updated.free_texts[0].content, "Skive after dye");
    assert_eq!(updated.free_texts[0].position_mm, Point2::new(20.0, -6.0));
    assert_eq!(updated.free_texts[0].font_size_mm, 5.0);

    let after_undo = doc.undo();
    assert_eq!(after_undo.free_texts[0].content, "Skive this edge");

    let after_redo = doc.redo();
    assert_eq!(after_redo.free_texts[0].content, "Skive after dye");

    let deleted = doc.apply(DocumentCommand::DeleteFreeText("free-text:note".to_owned()));
    assert!(deleted.free_texts.is_empty());
}

#[test]
fn uc5_save_and_reload_round_trip_preserves_the_boundary_state() {
    let doc = TestDocument::new("uc5-round-trip");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-a",
        EntityKind::Point(Point2::new(-12.0, 18.0)),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(-45.0, -20.0),
            Point2::new(40.0, -20.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:circle-a",
        EntityKind::Circle(Circle {
            center: Point2::new(10.0, -10.0),
            radius_mm: 6.0,
        }),
    )));
    doc.apply(DocumentCommand::AddParameter(Parameter {
        id: "parameter:width".to_owned(),
        name: "width".to_owned(),
        value_mm: 40.0,
        unit: ParameterUnit::Millimeter,
        memo: "round trip".to_owned(),
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:point-a-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:point-a".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::Parameter("parameter:width".to_owned())),
        status: ConstraintStatus::Unknown,
    }));

    let original_state = doc.state();
    assert_eq!(
        original_state
            .snapshot
            .edit_display_summary
            .constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    let path = unique_temp_path("uc5-round-trip.kawa");
    doc.write_json_file(&path);
    let original_json =
        std::fs::read_to_string(&path).expect("written document should be readable");
    let from_json = TestDocument::from_json(&original_json);
    let mut loaded_from_json_state = from_json.state();
    loaded_from_json_state.history = original_state.history.clone();
    assert_eq!(loaded_from_json_state, original_state);
    let from_file = TestDocument::from_file(&path);
    let mut loaded_from_file_state = from_file.state();
    loaded_from_file_state.history = original_state.history.clone();
    assert_eq!(loaded_from_file_state, original_state);

    std::fs::remove_file(&path).expect("temporary file should be removable");
}

#[test]
fn uc5_legacy_write_json_file_alias_is_not_part_of_the_boundary() {
    let doc = TestDocument::new("uc5-no-write-json-alias");
    let path = unique_temp_path("uc5-no-write-json-alias.kawa");
    let error = doc.rpc_error(json!({
        "kind": "writeJsonFile",
        "payload": {
            "path": path.to_string_lossy()
        }
    }));
    assert!(error.contains("unknown variant"));
}

#[test]
fn uc6_layer_visibility_updates_the_visible_snapshot_without_losing_constraint_summary() {
    let doc = TestDocument::new("uc6-layer-visibility");

    doc.apply(DocumentCommand::AddLayer(Layer::new(
        "layer:construction",
        "Construction",
        LayerKind::Construction,
        false,
    )));

    doc.apply(DocumentCommand::AddEntity(
        Entity::new("entity:anchor", EntityKind::Point(Point2::new(0.0, 0.0)))
            .on_layer("layer:cut-line"),
    ));
    doc.apply(DocumentCommand::AddEntity(
        Entity::new(
            "entity:circle-hidden",
            EntityKind::Circle(Circle {
                center: Point2::new(20.0, 20.0),
                radius_mm: 4.0,
            }),
        )
        .on_layer("layer:construction"),
    ));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:anchor-fixed".to_owned(),
        kind: ConstraintKind::Fixed,
        targets: vec![ConstraintTarget::Entity("entity:anchor".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    assert_eq!(
        before.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::FullyConstrained
    );
    assert_eq!(before.entities.len(), 2);
    assert!(matches!(before.entities[0].kind, EntityKind::Point(_)));
    assert!(matches!(before.entities[1].kind, EntityKind::Circle(_)));

    doc.apply(DocumentCommand::SetLayerVisibility {
        layer_id: "layer:construction".to_owned(),
        visible: false,
    });

    let after = doc.state();
    assert_eq!(
        after.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::FullyConstrained
    );
    assert_eq!(after.entities.len(), 1);
    assert!(matches!(after.entities[0].kind, EntityKind::Point(_)));
    assert!(after
        .layers
        .iter()
        .any(|layer| layer.id == "layer:construction" && !layer.visible));
}

#[test]
fn uc7_editing_a_constrained_entity_propagates_when_constraints_can_still_be_satisfied() {
    let doc = TestDocument::new("uc7-edit-reject");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(100.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::FixedMm(100.0)),
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    assert_eq!(
        before.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
    assert_line_length(&before, "entity:line-a", 100.0);

    let after = doc.apply(DocumentCommand::UpdateEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(50.0, 0.0),
        )),
    )));

    let line = line_segment(&after, "entity:line-a");
    assert_mm_eq(line.start.x_mm, -50.0);
    assert_mm_eq(line.end.x_mm, 50.0);
    assert_mm_eq(line.start.y_mm, 0.0);
    assert_mm_eq(line.end.y_mm, 0.0);
    assert_line_length(&after, "entity:line-a", 100.0);
    assert_eq!(
        after.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );
    assert_ne!(after, before);
}

#[test]
fn uc8_deleting_parameters_and_entities_keeps_references_consistent() {
    let doc = TestDocument::new("uc8-delete-consistency");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(40.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-b",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 10.0),
            Point2::new(40.0, 10.0),
        )),
    )));
    doc.apply(DocumentCommand::AddParameter(Parameter {
        id: "parameter:width".to_owned(),
        name: "width".to_owned(),
        value_mm: 40.0,
        unit: ParameterUnit::Millimeter,
        memo: "delete flow".to_owned(),
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::Parameter("parameter:width".to_owned())),
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-b-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-b".to_owned())],
        value: Some(ConstraintValue::FixedMm(40.0)),
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    assert_eq!(before.parameters.len(), 1);
    assert_eq!(before.constraints.len(), 2);
    assert_eq!(
        before.parameters[0].used_constraint_ids,
        vec!["constraint:line-a-length"]
    );

    doc.apply(DocumentCommand::DeleteParameter {
        parameter_id: "parameter:width".to_owned(),
        replacement_value_mm: 60.0,
    });

    let after_parameter_delete = doc.state();
    assert_eq!(after_parameter_delete.parameters.len(), 0);
    assert_eq!(after_parameter_delete.constraints.len(), 2);
    assert!(matches!(
        after_parameter_delete.constraints[0].value,
        Some(ConstraintValue::FixedMm(60.0))
    ));
    assert_line_length(&after_parameter_delete, "entity:line-a", 60.0);
    assert_eq!(
        after_parameter_delete
            .snapshot
            .edit_display_summary
            .constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    doc.apply(DocumentCommand::DeleteEntity("entity:line-b".to_owned()));

    let after_entity_delete = doc.state();
    assert_eq!(after_entity_delete.entities.len(), 1);
    assert_eq!(after_entity_delete.constraints.len(), 1);
    assert_eq!(
        after_entity_delete.constraints[0].id,
        "constraint:line-a-length"
    );
    assert!(after_entity_delete
        .constraints
        .iter()
        .all(
            |constraint| constraint.targets.iter().all(|target| match target {
                ConstraintTarget::Entity(entity_id) => entity_id == "entity:line-a",
                ConstraintTarget::ControlPoint { entity_id, .. } => entity_id == "entity:line-a",
            })
        ));
    assert_eq!(
        after_entity_delete
            .snapshot
            .edit_display_summary
            .constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    let broken_ref_error = doc.rpc_error(json!({
        "kind": "applyCommand",
        "payload": {
            "command": serde_json::to_value(DocumentCommand::AddConstraint(Constraint {
                id: "constraint:missing-target".to_owned(),
                kind: ConstraintKind::SegmentLength,
                targets: vec![ConstraintTarget::Entity("entity:missing".to_owned())],
                value: Some(ConstraintValue::FixedMm(10.0)),
                status: ConstraintStatus::Unknown,
            }))
            .expect("command should serialize"),
            "viewMode": "editDisplay"
        }
    }));
    assert!(broken_ref_error.contains("references missing entity"));
}

#[test]
fn uc9_representative_constraint_types_update_geometry_through_the_boundary() {
    let doc = TestDocument::new("uc9-constraint-variants");

    doc.apply(DocumentCommand::AddLayer(Layer::new(
        "layer:construction",
        "Construction",
        LayerKind::Construction,
        false,
    )));

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-horizontal",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 2.0),
            Point2::new(20.0, 8.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-vertical",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(3.0, 0.0),
            Point2::new(8.0, 20.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-parallel",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 10.0),
            Point2::new(10.0, 16.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-perpendicular",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(10.0, 0.0),
            Point2::new(18.0, 12.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-anchor",
        EntityKind::Point(Point2::new(4.0, 3.0)),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:point-mirror",
        EntityKind::Point(Point2::new(1.0, 1.0)),
    )));
    doc.apply(DocumentCommand::AddEntity(
        Entity::new(
            "entity:symmetry-axis",
            EntityKind::CenterLine(LineSegment::new(
                Point2::new(0.0, -10.0),
                Point2::new(0.0, 10.0),
            )),
        )
        .on_layer("layer:construction"),
    ));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:circle-a",
        EntityKind::Circle(Circle {
            center: Point2::new(20.0, 20.0),
            radius_mm: 5.0,
        }),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-tangent",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(-10.0, 0.0),
            Point2::new(0.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:arc-tangent",
        EntityKind::Arc(Arc {
            center: Point2::new(10.0, 0.0),
            radius_mm: 10.0,
            start_angle_rad: std::f64::consts::PI,
            sweep_angle_rad: std::f64::consts::FRAC_PI_2,
        }),
    )));

    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:horizontal".to_owned(),
        kind: ConstraintKind::Horizontal,
        targets: vec![ConstraintTarget::Entity(
            "entity:line-horizontal".to_owned(),
        )],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:vertical".to_owned(),
        kind: ConstraintKind::Vertical,
        targets: vec![ConstraintTarget::Entity("entity:line-vertical".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:parallel".to_owned(),
        kind: ConstraintKind::Parallel,
        targets: vec![
            ConstraintTarget::Entity("entity:line-horizontal".to_owned()),
            ConstraintTarget::Entity("entity:line-parallel".to_owned()),
        ],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:perpendicular".to_owned(),
        kind: ConstraintKind::Perpendicular,
        targets: vec![
            ConstraintTarget::Entity("entity:line-horizontal".to_owned()),
            ConstraintTarget::Entity("entity:line-perpendicular".to_owned()),
        ],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:tangent".to_owned(),
        kind: ConstraintKind::Tangent,
        targets: vec![
            ConstraintTarget::ControlPoint {
                entity_id: "entity:line-tangent".to_owned(),
                point: ControlPointKind::End,
            },
            ConstraintTarget::ControlPoint {
                entity_id: "entity:arc-tangent".to_owned(),
                point: ControlPointKind::Start,
            },
        ],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:symmetric".to_owned(),
        kind: ConstraintKind::Symmetric,
        targets: vec![
            ConstraintTarget::Entity("entity:point-anchor".to_owned()),
            ConstraintTarget::Entity("entity:point-mirror".to_owned()),
            ConstraintTarget::Entity("entity:symmetry-axis".to_owned()),
        ],
        value: None,
        status: ConstraintStatus::Unknown,
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:diameter".to_owned(),
        kind: ConstraintKind::Diameter,
        targets: vec![ConstraintTarget::Entity("entity:circle-a".to_owned())],
        value: Some(ConstraintValue::FixedMm(20.0)),
        status: ConstraintStatus::Unknown,
    }));

    let state = doc.state();
    assert_eq!(state.constraints.len(), 7);
    assert_eq!(state.constraints[0].kind, ConstraintKind::Horizontal);
    assert_eq!(state.constraints[1].kind, ConstraintKind::Vertical);
    assert_eq!(state.constraints[2].kind, ConstraintKind::Parallel);
    assert_eq!(state.constraints[3].kind, ConstraintKind::Perpendicular);
    assert_eq!(state.constraints[4].kind, ConstraintKind::Tangent);
    assert_eq!(state.constraints[5].kind, ConstraintKind::Symmetric);
    assert_eq!(state.constraints[6].kind, ConstraintKind::Diameter);
    assert_eq!(
        state.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    let horizontal = line_segment(&state, "entity:line-horizontal");
    assert_eq!(horizontal.start.y_mm, horizontal.end.y_mm);

    let vertical = line_segment(&state, "entity:line-vertical");
    assert_eq!(vertical.start.x_mm, vertical.end.x_mm);

    let parallel = line_segment(&state, "entity:line-parallel");
    assert_eq!(parallel.start.y_mm, parallel.end.y_mm);

    let perpendicular = line_segment(&state, "entity:line-perpendicular");
    assert_eq!(perpendicular.start.x_mm, perpendicular.end.x_mm);

    let mirror = point_entity(&state, "entity:point-mirror");
    assert_eq!(mirror.x_mm, -4.0);
    assert_eq!(mirror.y_mm, 3.0);

    let circle = circle_entity(&state, "entity:circle-a");
    assert!((circle.radius_mm - 10.0).abs() < 1e-6);
}

#[test]
fn uc10_deleting_a_constraint_breaks_the_dependency_chain_at_the_boundary() {
    let doc = TestDocument::new("uc10-delete-constraint");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(30.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddParameter(Parameter {
        id: "parameter:width".to_owned(),
        name: "width".to_owned(),
        value_mm: 30.0,
        unit: ParameterUnit::Millimeter,
        memo: "delete constraint".to_owned(),
    }));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-length".to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: Some(ConstraintValue::Parameter("parameter:width".to_owned())),
        status: ConstraintStatus::Unknown,
    }));

    let before = doc.state();
    assert_eq!(before.constraints.len(), 1);
    assert_eq!(before.parameters.len(), 1);
    assert_eq!(before.parameters[0].usage_count, 1);
    assert_eq!(
        before.parameters[0].used_constraint_ids,
        vec!["constraint:line-a-length"]
    );
    assert_line_length(&before, "entity:line-a", 30.0);
    assert_eq!(
        before.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::UnderConstrained
    );

    doc.apply(DocumentCommand::DeleteConstraint(
        "constraint:line-a-length".to_owned(),
    ));

    let after_delete = doc.state();
    assert_eq!(after_delete.constraints.len(), 0);
    assert_eq!(after_delete.parameters.len(), 1);
    assert_eq!(after_delete.parameters[0].usage_count, 0);
    assert!(after_delete.parameters[0].used_constraint_ids.is_empty());
    assert_line_length(&after_delete, "entity:line-a", 30.0);
    assert_eq!(
        after_delete.snapshot.edit_display_summary.constraint_status,
        LeatherConstraintStatus::Unknown
    );

    doc.apply(DocumentCommand::SetParameterValue {
        parameter_id: "parameter:width".to_owned(),
        value_mm: 40.0,
    });

    let after_parameter_change = doc.state();
    assert_eq!(after_parameter_change.constraints.len(), 0);
    assert_eq!(after_parameter_change.parameters[0].value_mm, 40.0);
    assert_line_length(&after_parameter_change, "entity:line-a", 30.0);
    assert_eq!(
        after_parameter_change
            .snapshot
            .edit_display_summary
            .constraint_status,
        LeatherConstraintStatus::Unknown
    );
}

#[test]
fn uc11_layer_addition_and_state_updates_are_visible_through_the_boundary() {
    let doc = TestDocument::new("uc11-layer-management");

    let before = doc.state();
    let initial_layer_count = before.layers.len();

    doc.apply(DocumentCommand::AddLayer(Layer::new(
        "layer:user-boundary",
        "User Boundary",
        LayerKind::Dimension,
        false,
    )));

    let after_add = doc.state();
    assert_eq!(after_add.layers.len(), initial_layer_count + 1);
    let added_layer = after_add
        .layers
        .iter()
        .find(|layer| layer.id == "layer:user-boundary")
        .expect("added layer should exist");
    assert_eq!(added_layer.name, "User Boundary");
    assert_eq!(added_layer.kind, LayerKind::Dimension);
    assert!(added_layer.visible);
    assert!(!added_layer.printable);

    doc.apply(DocumentCommand::SetLayerVisibility {
        layer_id: "layer:user-boundary".to_owned(),
        visible: true,
    });
    doc.apply(DocumentCommand::SetLayerPrintable {
        layer_id: "layer:user-boundary".to_owned(),
        printable: true,
    });
    doc.apply(DocumentCommand::SetLayerStyle {
        layer_id: "layer:user-boundary".to_owned(),
        style: LayerStyle {
            stroke: Rgba {
                red: 0.2,
                green: 0.4,
                blue: 0.6,
                alpha: 1.0,
            },
            stroke_width_mm: 0.5,
            pattern: LinePattern::Dotted,
        },
    });

    let after_update = doc.state();
    let updated_layer = after_update
        .layers
        .iter()
        .find(|layer| layer.id == "layer:user-boundary")
        .expect("updated layer should exist");
    assert!(updated_layer.visible);
    assert!(updated_layer.printable);
    assert_eq!(updated_layer.style.stroke.red, 0.2);
    assert_eq!(updated_layer.style.stroke.green, 0.4);
    assert_eq!(updated_layer.style.stroke.blue, 0.6);
    assert_eq!(updated_layer.style.stroke_width_mm, 0.5);
    assert_eq!(updated_layer.style.pattern, LinePattern::Dotted);
    assert_eq!(after_update.layers.len(), initial_layer_count + 1);
    assert_eq!(
        after_update.snapshot.statistics.layer_count,
        initial_layer_count + 1
    );
}

#[test]
fn shared_style_commands_are_visible_through_the_boundary() {
    let doc = TestDocument::new("shared-style-boundary");
    let initial_style_count = doc.state().shared_styles.len();
    doc.apply(DocumentCommand::AddSharedStyle(SharedStyle::new(
        "style:stitch",
        "Stitch",
        LayerStyle {
            stroke: Rgba {
                red: 0.8,
                green: 0.1,
                blue: 0.2,
                alpha: 1.0,
            },
            stroke_width_mm: 0.35,
            pattern: LinePattern::Dashed,
        },
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(20.0, 0.0),
        )),
    )));
    let after_apply = doc.apply(DocumentCommand::SetEntitySharedStyle {
        entity_id: "entity:line".to_owned(),
        style_id: Some("style:stitch".to_owned()),
    });

    assert_eq!(
        after_apply.snapshot.statistics.shared_style_count,
        initial_style_count + 1
    );
    assert_eq!(after_apply.shared_styles.len(), initial_style_count + 1);
    assert_eq!(
        after_apply
            .shared_styles
            .iter()
            .find(|style| style.id == "style:stitch")
            .map(|style| style.name.as_str()),
        Some("Stitch")
    );
    assert_eq!(
        after_apply.entities[0].style_id.as_deref(),
        Some("style:stitch")
    );

    let after_update = doc.apply(DocumentCommand::UpdateSharedStyle(SharedStyle::new(
        "style:stitch",
        "Stitch Updated",
        LayerStyle {
            stroke: Rgba {
                red: 0.1,
                green: 0.2,
                blue: 0.9,
                alpha: 1.0,
            },
            stroke_width_mm: 0.5,
            pattern: LinePattern::Dotted,
        },
    )));
    assert_eq!(
        after_update
            .shared_styles
            .iter()
            .find(|style| style.id == "style:stitch")
            .map(|style| (style.name.as_str(), style.style.pattern)),
        Some(("Stitch Updated", LinePattern::Dotted))
    );

    let after_delete = doc.apply(DocumentCommand::DeleteSharedStyle(
        "style:stitch".to_owned(),
    ));
    assert_eq!(after_delete.shared_styles.len(), initial_style_count);
    assert!(after_delete
        .shared_styles
        .iter()
        .all(|style| style.id != "style:stitch"));
    assert_eq!(after_delete.entities[0].style_id, None);

    let after_undo = doc.undo();
    assert_eq!(after_undo.shared_styles.len(), initial_style_count + 1);
    assert_eq!(
        after_undo.entities[0].style_id.as_deref(),
        Some("style:stitch")
    );
}

#[test]
fn derived_element_shared_style_round_trips_through_the_boundary() {
    let doc = TestDocument::new("derived-shared-style-boundary");
    doc.apply(DocumentCommand::AddSharedStyle(SharedStyle::new(
        "style:stitch",
        "Stitch",
        LayerStyle {
            stroke: Rgba {
                red: 0.8,
                green: 0.1,
                blue: 0.2,
                alpha: 1.0,
            },
            stroke_width_mm: 0.35,
            pattern: LinePattern::Dashed,
        },
    )));
    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(20.0, 0.0),
        )),
    )));

    let derived = DerivedElement::offset_curve(
        "derived:offset",
        Some("layer:cut-line".to_owned()),
        OffsetCurve {
            source_entity_ids: vec!["entity:line".to_owned()],
            source_resolved_entity_ids: Vec::new(),
            distance: ConstraintValue::FixedMm(3.0),
            direction: OffsetDirection::Left,
        },
    )
    .with_style("style:stitch");
    let after_add = doc.apply(DocumentCommand::AddDerivedElement(derived));

    assert_eq!(
        after_add.derived_elements[0].style_id.as_deref(),
        Some("style:stitch")
    );
    assert!(after_add
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:offset:resolved:"))
        .all(|entity| entity.style_id.as_deref() == Some("style:stitch")));

    let mut cleared = after_add.derived_elements[0].clone();
    cleared.style_id = None;
    let after_clear = doc.apply(DocumentCommand::UpdateDerivedElement(cleared));

    assert_eq!(after_clear.derived_elements[0].style_id, None);
    assert!(after_clear
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:offset:resolved:"))
        .all(|entity| entity.style_id.is_none()));
}

#[test]
fn uc15_preview_command_returns_projected_state_without_mutating_history() {
    let doc = TestDocument::new("uc15-drag-preview");

    doc.apply(DocumentCommand::AddEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(100.0, 0.0),
        )),
    )));
    doc.apply(DocumentCommand::AddConstraint(Constraint {
        id: "constraint:line-a-horizontal".to_owned(),
        kind: ConstraintKind::Horizontal,
        targets: vec![ConstraintTarget::Entity("entity:line-a".to_owned())],
        value: None,
        status: ConstraintStatus::Unknown,
    }));

    let before_preview = doc.state();
    let preview = doc.preview(DocumentCommand::UpdateEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(150.0, 50.0),
        )),
    )));

    let preview_line = line_segment(&preview, "entity:line-a");
    assert_mm_eq(preview_line.start.x_mm, 0.0);
    assert_mm_eq(preview_line.start.y_mm, 0.0);
    assert_mm_eq(preview_line.end.x_mm, 150.0);
    assert_mm_eq(preview_line.end.y_mm, 0.0);
    assert!(preview.history.can_undo);
    assert!(!preview.history.can_redo);

    let after_preview = doc.state();
    assert_eq!(after_preview, before_preview);

    let committed = doc.apply(DocumentCommand::UpdateEntity(Entity::new(
        "entity:line-a",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(0.0, 0.0),
            Point2::new(150.0, 50.0),
        )),
    )));
    let committed_line = line_segment(&committed, "entity:line-a");
    assert_eq!(committed_line, preview_line);

    let undone = doc.undo();
    assert_eq!(
        line_segment(&undone, "entity:line-a"),
        line_segment(&before_preview, "entity:line-a")
    );
    assert!(undone.history.can_redo);
}

#[test]
fn uc15_diagonal_drag_is_projected_when_connected_line_can_only_move_vertically() {
    let doc = TestDocument::new("uc15-vertical-only-drag");

    doc.apply(DocumentCommand::Compound(vec![
        DocumentCommand::AddEntity(Entity::new(
            "entity:left",
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(0.0, -40.0),
                Point2::new(0.0, 0.0),
            )),
        )),
        DocumentCommand::AddEntity(Entity::new(
            "entity:top",
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(0.0, 0.0),
                Point2::new(100.0, 0.0),
            )),
        )),
        DocumentCommand::AddEntity(Entity::new(
            "entity:right",
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(100.0, -40.0),
                Point2::new(100.0, 0.0),
            )),
        )),
        constraint(
            "constraint:left-vertical",
            ConstraintKind::Vertical,
            vec![ConstraintTarget::Entity("entity:left".to_owned())],
            None,
        ),
        constraint(
            "constraint:top-horizontal",
            ConstraintKind::Horizontal,
            vec![ConstraintTarget::Entity("entity:top".to_owned())],
            None,
        ),
        constraint(
            "constraint:right-vertical",
            ConstraintKind::Vertical,
            vec![ConstraintTarget::Entity("entity:right".to_owned())],
            None,
        ),
        constraint(
            "constraint:left-top",
            ConstraintKind::Coincident,
            vec![
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:left".to_owned(),
                    point: kawacad_core::constraints::ControlPointKind::End,
                },
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:top".to_owned(),
                    point: kawacad_core::constraints::ControlPointKind::Start,
                },
            ],
            None,
        ),
        constraint(
            "constraint:right-top",
            ConstraintKind::Coincident,
            vec![
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:right".to_owned(),
                    point: kawacad_core::constraints::ControlPointKind::End,
                },
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:top".to_owned(),
                    point: kawacad_core::constraints::ControlPointKind::End,
                },
            ],
            None,
        ),
    ]));

    let diagonal_drag = Entity::new(
        "entity:top",
        EntityKind::LineSegment(LineSegment::new(
            Point2::new(2.0, 20.0),
            Point2::new(102.0, 20.0),
        )),
    );
    let preview = doc.preview(DocumentCommand::UpdateEntity(diagonal_drag.clone()));
    let preview_top = line_segment(&preview, "entity:top");
    assert_mm_eq(preview_top.start.x_mm, 0.0);
    assert_mm_eq(preview_top.start.y_mm, 20.0);
    assert_mm_eq(preview_top.end.x_mm, 100.0);
    assert_mm_eq(preview_top.end.y_mm, 20.0);

    let committed = doc.apply(DocumentCommand::UpdateEntity(diagonal_drag));
    assert_eq!(line_segment(&committed, "entity:top"), preview_top);
}

fn constraint(
    id: &str,
    kind: ConstraintKind,
    targets: Vec<ConstraintTarget>,
    value: Option<ConstraintValue>,
) -> DocumentCommand {
    DocumentCommand::AddConstraint(Constraint {
        id: id.to_owned(),
        kind,
        targets,
        value,
        status: ConstraintStatus::Unknown,
    })
}

fn assert_line_length(state: &LeatherDocumentState, entity_id: &str, expected: f64) {
    let entity = state
        .entities
        .iter()
        .find(|entity| entity.id == entity_id)
        .unwrap_or_else(|| panic!("missing entity: {entity_id}"));
    let length = match &entity.kind {
        EntityKind::LineSegment(line) => line.length_mm(),
        other => panic!("expected line segment, found {other:?}"),
    };
    assert!(
        (length - expected).abs() < 1e-6,
        "expected line length {expected}, found {length}"
    );
}

fn assert_mm_eq(actual: f64, expected: f64) {
    assert!(
        (actual - expected).abs() < 1e-6,
        "expected {expected}, found {actual}"
    );
}

fn line_segment(state: &LeatherDocumentState, entity_id: &str) -> LineSegment {
    let entity = state
        .entities
        .iter()
        .find(|entity| entity.id == entity_id)
        .unwrap_or_else(|| panic!("missing entity: {entity_id}"));
    match &entity.kind {
        EntityKind::LineSegment(line) => *line,
        other => panic!("expected line segment, found {other:?}"),
    }
}

fn point_entity(state: &LeatherDocumentState, entity_id: &str) -> Point2 {
    let entity = state
        .entities
        .iter()
        .find(|entity| entity.id == entity_id)
        .unwrap_or_else(|| panic!("missing entity: {entity_id}"));
    match &entity.kind {
        EntityKind::Point(point) => *point,
        other => panic!("expected point, found {other:?}"),
    }
}

fn circle_entity(state: &LeatherDocumentState, entity_id: &str) -> Circle {
    let entity = state
        .entities
        .iter()
        .find(|entity| entity.id == entity_id)
        .unwrap_or_else(|| panic!("missing entity: {entity_id}"));
    match &entity.kind {
        EntityKind::Circle(circle) => *circle,
        other => panic!("expected circle, found {other:?}"),
    }
}

fn unique_temp_path(name: &str) -> PathBuf {
    let unique_suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time should be after unix epoch")
        .as_nanos();
    std::env::temp_dir().join(format!("leather-interface-boundary-{unique_suffix}-{name}"))
}

trait RpcError {
    fn rpc_error(&self, request: serde_json::Value) -> String;
    fn rpc_error_envelope(&self, request: serde_json::Value) -> ErrorEnvelope;
}

impl RpcError for TestDocument {
    fn rpc_error(&self, request: serde_json::Value) -> String {
        self.rpc_error_envelope(request).error.message
    }

    fn rpc_error_envelope(&self, request: serde_json::Value) -> ErrorEnvelope {
        let response = self.rpc_response(request);
        serde_json::from_str(&response).expect("error envelope should be valid json")
    }
}
