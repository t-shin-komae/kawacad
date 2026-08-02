#[path = "support.rs"]
mod support;

use kawacad_core::command::DocumentCommand;
use kawacad_core::constraints::{ConstraintKind, ConstraintTarget, ConstraintValue};
use kawacad_core::layers::{LayerKind, LayerStyle, LinePattern, Rgba};
use kawacad_core::round_holes::{RoundHole, RoundHoleKind};
use kawacad_core::stitch_start_points::StitchStartPoint;
use support::*;

#[test]
fn document_command_round_trips_through_serde() {
    let commands = vec![
        DocumentCommand::RenameDocument {
            name: "Pattern A".to_owned(),
        },
        DocumentCommand::AddEntity(point_entity("entity:point", point(0.0, 0.0))),
        DocumentCommand::UpdateEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )),
        DocumentCommand::MoveEntities {
            entity_ids: vec!["entity:line".to_owned()],
            delta: point(3.0, -2.0),
            allow_single_line_stretch: true,
        },
        DocumentCommand::MoveControlPoint {
            target: point_target(
                "entity:line",
                kawacad_core::constraints::ControlPointKind::Start,
            ),
            position: point(4.0, 5.0),
            allow_projection: true,
        },
        DocumentCommand::DeleteEntity("entity:obsolete".to_owned()),
        DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:key-ring",
            "entity:circle",
            RoundHoleKind::KeyRing,
        )),
        DocumentCommand::UpdateRoundHole(RoundHole::new(
            "round-hole:key-ring",
            "entity:circle",
            RoundHoleKind::Rivet,
        )),
        DocumentCommand::DeleteRoundHole("round-hole:key-ring".to_owned()),
        DocumentCommand::AddStitchStartPoint(StitchStartPoint::new(
            "stitch-start:a",
            "entity:stitch-line",
            None,
            0.25,
        )),
        DocumentCommand::UpdateStitchStartPoint(StitchStartPoint::new(
            "stitch-start:a",
            "derived:offset",
            Some(1),
            0.75,
        )),
        DocumentCommand::DeleteStitchStartPoint("stitch-start:a".to_owned()),
        DocumentCommand::AddLayer(layer("layer:user", "User", LayerKind::Dimension, true)),
        DocumentCommand::SetLayerVisibility {
            layer_id: "layer:user".to_owned(),
            visible: false,
        },
        DocumentCommand::SetLayerPrintable {
            layer_id: "layer:user".to_owned(),
            printable: true,
        },
        DocumentCommand::SetLayerStyle {
            layer_id: "layer:user".to_owned(),
            style: LayerStyle {
                stroke: Rgba {
                    red: 0.1,
                    green: 0.2,
                    blue: 0.3,
                    alpha: 1.0,
                },
                stroke_width_mm: 0.4,
                pattern: LinePattern::Dashed,
            },
        },
        DocumentCommand::AddConstraint(constraint(
            "constraint:fixed",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point")],
            None,
        )),
        DocumentCommand::AddConstraint(constraint(
            "constraint:tangent",
            ConstraintKind::Tangent,
            vec![
                point_target(
                    "entity:line",
                    kawacad_core::constraints::ControlPointKind::End,
                ),
                point_target(
                    "entity:arc",
                    kawacad_core::constraints::ControlPointKind::Start,
                ),
            ],
            None,
        )),
        DocumentCommand::UpdateConstraint(constraint(
            "constraint:fixed",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point")],
            None,
        )),
        DocumentCommand::DeleteConstraint("constraint:fixed".to_owned()),
        DocumentCommand::AddParameter(parameter("parameter:length", "length", 12.5)),
        DocumentCommand::UpdateParameter(parameter("parameter:length", "length", 20.0)),
        DocumentCommand::DeleteParameter {
            parameter_id: "parameter:length".to_owned(),
            replacement_value_mm: 18.0,
        },
        DocumentCommand::SetParameterValue {
            parameter_id: "parameter:length".to_owned(),
            value_mm: 24.0,
        },
        DocumentCommand::Compound(vec![
            DocumentCommand::AddEntity(point_entity("entity:compound-point", point(0.0, 0.0))),
            DocumentCommand::AddLayer(layer(
                "layer:compound",
                "Compound",
                LayerKind::Dimension,
                true,
            )),
        ]),
    ];

    for command in commands {
        let json = serde_json::to_string(&command).expect("command should serialize");
        let decoded: DocumentCommand =
            serde_json::from_str(&json).expect("command should deserialize");
        assert_eq!(decoded, command);
    }
}

#[test]
fn document_command_supports_nested_constraint_targets() {
    let command = DocumentCommand::AddConstraint(constraint(
        "constraint:angle",
        ConstraintKind::Angle,
        vec![
            ConstraintTarget::Entity("entity:line-a".to_owned()),
            ConstraintTarget::Entity("entity:line-b".to_owned()),
        ],
        Some(ConstraintValue::FixedDegrees(45.0)),
    ));

    let json = serde_json::to_string(&command).expect("command should serialize");
    assert!(json.contains("fixedDegrees"));
    assert!(!json.contains("fixedRadians"));

    let decoded: DocumentCommand = serde_json::from_str(&json).expect("command should deserialize");
    assert_eq!(decoded, command);
}
