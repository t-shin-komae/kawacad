use serde_json::Value;

const INTERFACE_SCHEMA: &str = include_str!("../../../schemas/interface/0.1.0.schema.json");

#[test]
fn interface_fixtures_validate_against_schema_definitions() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");

    for (fixture_name, definition_name) in [
        (
            "preflight-constraint-request.json",
            "preflightConstraintRequest",
        ),
        (
            "preflight-derived-element-request.json",
            "preflightDerivedElementRequest",
        ),
        (
            "preflight-derived-element-response.json",
            "preflightDerivedElementResponse",
        ),
        (
            "semantic-command-request.json",
            "semanticApplyCommandRequest",
        ),
        ("part-command-request.json", "semanticApplyCommandRequest"),
        ("measurement-evaluation.json", "measurementEvaluation"),
        ("export-selection-request.json", "exportSelectionRequest"),
        ("structured-error.json", "errorEnvelope"),
        (
            "build-output-document-model-request.json",
            "buildOutputDocumentModelRequest",
        ),
        (
            "derived-element-shared-style-command-request.json",
            "sharedStyleApplyCommandRequest",
        ),
        (
            "build-output-document-model-response.json",
            "buildOutputDocumentModelResponse",
        ),
        ("output-document-model.json", "outputDocumentModel"),
        ("render-pdf-request.json", "renderPdfRequest"),
        ("render-pdf-response.json", "renderPdfResponse"),
        ("render-print-request.json", "renderPrintRequest"),
        ("print-render-data.json", "printRenderData"),
    ] {
        let fixture: Value = serde_json::from_str(interface_fixture(fixture_name))
            .unwrap_or_else(|error| panic!("{fixture_name} should be valid json: {error}"));
        let definition = schema
            .pointer(&format!("/$defs/{definition_name}"))
            .unwrap_or_else(|| panic!("missing schema definition: {definition_name}"));
        validate(&fixture, definition, &schema).unwrap_or_else(|error| {
            panic!("{fixture_name} does not match {definition_name}: {error}")
        });
    }
}

#[test]
fn interface_schema_accepts_clearing_derived_element_shared_style() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");
    let fixture: Value = serde_json::json!({
        "kind": "applyCommand",
        "payload": {
            "command": {
                "kind": "updateDerivedElement",
                "payload": {
                    "id": "derived:offset",
                    "layerId": "layer:cut-line",
                    "styleId": null,
                    "kind": {
                        "offsetCurve": {
                            "sourceEntityIds": ["entity:outer-a"],
                            "distance": { "parameter": "parameter:stitch-offset" },
                            "direction": "left"
                        }
                    }
                }
            }
        }
    });
    let definition = schema
        .pointer("/$defs/sharedStyleApplyCommandRequest")
        .expect("sharedStyleApplyCommandRequest definition should exist");

    validate(&fixture, definition, &schema)
        .expect("derived element shared style clear command should validate");
}

#[test]
fn interface_schema_accepts_part_move_duplicate_and_membership_commands() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");
    let definition = schema
        .pointer("/$defs/semanticApplyCommandRequest")
        .expect("semanticApplyCommandRequest definition should exist");
    let commands = [
        serde_json::json!({
            "kind": "movePart",
            "payload": { "partId": "part:a", "delta": { "xMm": 10.0, "yMm": -10.0 } }
        }),
        serde_json::json!({
            "kind": "setPartPosition",
            "payload": { "partId": "part:a", "position": { "xMm": 25.0, "yMm": -15.0 } }
        }),
        serde_json::json!({
            "kind": "createPart",
            "payload": {
                "id": "part:auto-origin", "name": "Auto Origin",
                "entityIds": ["entity:outline"]
            }
        }),
        serde_json::json!({
            "kind": "duplicatePart",
            "payload": {
                "partId": "part:a", "newPartId": "part:b", "newName": "B",
                "idNamespace": "copy-b", "delta": { "xMm": 10.0, "yMm": -10.0 }
            }
        }),
        serde_json::json!({
            "kind": "insertPartLibraryItem",
            "payload": {
                "libraryJson": "{\"opaque\":true}",
                "newPartId": "part:library",
                "newName": "Library Part",
                "idNamespace": "library-copy",
                "delta": { "xMm": 10.0, "yMm": -10.0 }
            }
        }),
        serde_json::json!({
            "kind": "addEntitiesToPart",
            "payload": { "partId": "part:a", "entityIds": ["entity:a"] }
        }),
        serde_json::json!({
            "kind": "removeEntitiesFromPart",
            "payload": { "partId": "part:a", "entityIds": ["entity:a"] }
        }),
        serde_json::json!({
            "kind": "setPartBoundary",
            "payload": { "partId": "part:a", "entityIds": ["entity:outline"] }
        }),
        serde_json::json!({
            "kind": "updatePartSettings",
            "payload": {
                "partId": "part:a", "visible": true, "printable": false,
                "locked": true, "quantity": 2
            }
        }),
        serde_json::json!({
            "kind": "alignParts",
            "payload": { "partIds": ["part:a", "part:b"], "alignment": "horizontalCenter" }
        }),
        serde_json::json!({
            "kind": "distributeParts",
            "payload": { "partIds": ["part:a", "part:b", "part:c"], "axis": "horizontal" }
        }),
    ];

    for command in commands {
        let request = serde_json::json!({
            "kind": "applyCommand",
            "payload": { "command": command, "viewMode": "editDisplay" }
        });
        validate(&request, definition, &schema)
            .unwrap_or_else(|error| panic!("part editing command should validate: {error}"));
    }
}

#[test]
fn interface_schema_accepts_core_owned_gesture_and_property_commands() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");
    let definition = schema
        .pointer("/$defs/semanticApplyCommandRequest")
        .expect("semanticApplyCommandRequest definition should exist");
    let commands = [
        serde_json::json!({
            "kind": "createEntityFromGesture",
            "payload": {
                "id": "entity:arc",
                "layerId": "layer:cut-line",
                "gesture": {
                    "kind": "arc",
                    "center": { "xMm": 0.0, "yMm": 0.0 },
                    "start": { "xMm": 10.0, "yMm": 0.0 },
                    "end": { "xMm": 0.0, "yMm": 10.0 },
                    "sweepReferenceRad": std::f64::consts::FRAC_PI_2
                }
            }
        }),
        serde_json::json!({
            "kind": "setDerivedDistance",
            "payload": { "derivedElementId": "derived:offset", "value": { "fixedMm": 4.0 } }
        }),
        serde_json::json!({
            "kind": "setDerivedRadiusFromPoint",
            "payload": {
                "derivedElementId": "derived:fillet", "resolvedIndex": 0,
                "position": { "xMm": 5.0, "yMm": 5.0 }
            }
        }),
        serde_json::json!({
            "kind": "setDerivedDirection",
            "payload": { "derivedElementId": "derived:offset", "direction": "right" }
        }),
        serde_json::json!({
            "kind": "setRoundHoleDiameter",
            "payload": { "roundHoleId": "round-hole:a", "diameterMm": 8.0 }
        }),
    ];

    for command in commands {
        let request = serde_json::json!({
            "kind": "applyCommand",
            "payload": { "command": command, "viewMode": "editDisplay" }
        });
        validate(&request, definition, &schema)
            .unwrap_or_else(|error| panic!("Core-owned semantic command should validate: {error}"));
    }
}

#[test]
fn interface_schema_accepts_canvas_projection() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");
    let definition = schema
        .pointer("/$defs/canvasProjection")
        .expect("canvasProjection definition should exist");
    let projection = serde_json::json!({
        "visibleFreeTextIds": ["free-text:a"],
        "stitchStartPoints": [{
            "id": "stitch:a",
            "positionMm": { "xMm": 2.0, "yMm": 3.0 },
            "visible": true
        }],
        "measurementAnnotations": [{
            "id": "measurement:a",
            "visible": true,
            "startMm": { "xMm": 0.0, "yMm": 0.0 },
            "endMm": { "xMm": 10.0, "yMm": 0.0 }
        }],
        "dimensionConstraints": [],
        "constraintMarkers": []
    });

    validate(&projection, definition, &schema).expect("canvas projection should validate");
}

#[test]
fn interface_schema_rejects_camel_case_tagged_payload_fields() {
    let schema: Value =
        serde_json::from_str(INTERFACE_SCHEMA).expect("interface schema should be valid json");
    let fixture: Value = serde_json::json!({
        "paperSize": "a4",
        "orientation": "portrait",
        "scale": "actualSize",
        "pageCount": 1,
        "pages": [{
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
            "graphics": [{
                "entityId": "entity:line-a",
                "kind": "lineSegment",
                "geometry": {
                    "kind": "lineSegment",
                    "payload": {
                        "startMm": { "xMm": 0.0, "yMm": 0.0 },
                        "endMm": { "xMm": 20.0, "yMm": 0.0 }
                    }
                },
                "style": {
                    "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
                    "strokeWidthMm": 0.2,
                    "pattern": "solid"
                }
            }],
            "texts": [],
            "guide": null
        }]
    });
    let definition = schema
        .pointer("/$defs/outputDocumentModel")
        .expect("outputDocumentModel definition should exist");

    assert!(validate(&fixture, definition, &schema).is_err());
}

fn interface_fixture(name: &str) -> &'static str {
    match name {
        "preflight-constraint-request.json" => {
            include_str!("../../../tests/fixtures/interface/preflight-constraint-request.json")
        }
        "preflight-derived-element-request.json" => {
            include_str!("../../../tests/fixtures/interface/preflight-derived-element-request.json")
        }
        "preflight-derived-element-response.json" => include_str!(
            "../../../tests/fixtures/interface/preflight-derived-element-response.json"
        ),
        "semantic-command-request.json" => {
            include_str!("../../../tests/fixtures/interface/semantic-command-request.json")
        }
        "part-command-request.json" => {
            include_str!("../../../tests/fixtures/interface/part-command-request.json")
        }
        "measurement-evaluation.json" => {
            include_str!("../../../tests/fixtures/interface/measurement-evaluation.json")
        }
        "export-selection-request.json" => {
            include_str!("../../../tests/fixtures/interface/export-selection-request.json")
        }
        "structured-error.json" => {
            include_str!("../../../tests/fixtures/interface/structured-error.json")
        }
        "build-output-document-model-request.json" => {
            include_str!(
                "../../../tests/fixtures/interface/build-output-document-model-request.json"
            )
        }
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

fn validate(value: &Value, schema: &Value, root: &Value) -> Result<(), String> {
    if let Some(reference) = schema.get("$ref").and_then(Value::as_str) {
        let target = resolve_ref(reference, root)?;
        return validate(value, target, root);
    }

    if let Some(expected) = schema.get("const") {
        if value == expected {
            return Ok(());
        }
        return Err(format!("expected const {expected}, got {value}"));
    }

    if let Some(values) = schema.get("enum").and_then(Value::as_array) {
        if values.iter().any(|candidate| candidate == value) {
            return Ok(());
        }
        return Err(format!("expected one of {values:?}, got {value}"));
    }

    if let Some(options) = schema.get("oneOf").and_then(Value::as_array) {
        let matches = options
            .iter()
            .filter(|option| validate(value, option, root).is_ok())
            .count();
        return (matches == 1)
            .then_some(())
            .ok_or_else(|| format!("expected exactly one oneOf match, got {matches}"));
    }

    if let Some(options) = schema.get("anyOf").and_then(Value::as_array) {
        if options
            .iter()
            .any(|option| validate(value, option, root).is_ok())
        {
            return Ok(());
        }
        return Err("expected at least one anyOf match".to_owned());
    }

    if let Some(kind) = schema.get("type").and_then(Value::as_str) {
        match kind {
            "object" => validate_object(value, schema, root)?,
            "array" => validate_array(value, schema, root)?,
            "string" => validate_string(value, schema)?,
            "number" => validate_number(value, schema)?,
            "integer" => validate_integer(value, schema)?,
            "boolean" if value.is_boolean() => {}
            "null" if value.is_null() => {}
            _ => return Err(format!("expected type {kind}, got {value}")),
        }
    }

    Ok(())
}

fn validate_object(value: &Value, schema: &Value, root: &Value) -> Result<(), String> {
    let object = value
        .as_object()
        .ok_or_else(|| format!("expected object, got {value}"))?;
    let empty_properties = serde_json::Map::new();
    let properties = schema
        .get("properties")
        .and_then(Value::as_object)
        .unwrap_or(&empty_properties);

    if let Some(required) = schema.get("required").and_then(Value::as_array) {
        for field in required {
            let field = field
                .as_str()
                .ok_or_else(|| format!("required field name must be string: {field}"))?;
            if !object.contains_key(field) {
                return Err(format!("missing required field {field}"));
            }
        }
    }

    if schema
        .get("additionalProperties")
        .and_then(Value::as_bool)
        .is_some_and(|allowed| !allowed)
    {
        for field in object.keys() {
            if !properties.contains_key(field) {
                return Err(format!("unexpected field {field}"));
            }
        }
    }

    for (field, field_schema) in properties {
        if let Some(field_value) = object.get(field) {
            validate(field_value, field_schema, root)
                .map_err(|error| format!("{field}: {error}"))?;
        }
    }

    Ok(())
}

fn validate_array(value: &Value, schema: &Value, root: &Value) -> Result<(), String> {
    let values = value
        .as_array()
        .ok_or_else(|| format!("expected array, got {value}"))?;
    if let Some(item_schema) = schema.get("items") {
        for (index, item) in values.iter().enumerate() {
            validate(item, item_schema, root).map_err(|error| format!("[{index}]: {error}"))?;
        }
    }
    Ok(())
}

fn validate_string(value: &Value, schema: &Value) -> Result<(), String> {
    let text = value
        .as_str()
        .ok_or_else(|| format!("expected string, got {value}"))?;
    if let Some(min_length) = schema.get("minLength").and_then(Value::as_u64) {
        if text.chars().count() < min_length as usize {
            return Err(format!("expected minLength {min_length}, got {text:?}"));
        }
    }
    if schema
        .get("pattern")
        .and_then(Value::as_str)
        .is_some_and(|pattern| pattern == "^[0-9a-fA-F]*$")
        && !text.chars().all(|char| char.is_ascii_hexdigit())
    {
        return Err(format!("expected hex string, got {text:?}"));
    }
    Ok(())
}

fn validate_number(value: &Value, schema: &Value) -> Result<(), String> {
    let number = value
        .as_f64()
        .ok_or_else(|| format!("expected number, got {value}"))?;
    validate_numeric_bounds(number, schema)
}

fn validate_integer(value: &Value, schema: &Value) -> Result<(), String> {
    let number = value
        .as_i64()
        .ok_or_else(|| format!("expected integer, got {value}"))?;
    validate_numeric_bounds(number as f64, schema)
}

fn validate_numeric_bounds(number: f64, schema: &Value) -> Result<(), String> {
    if let Some(minimum) = schema.get("minimum").and_then(Value::as_f64) {
        if number < minimum {
            return Err(format!("expected minimum {minimum}, got {number}"));
        }
    }
    if let Some(minimum) = schema.get("exclusiveMinimum").and_then(Value::as_f64) {
        if number <= minimum {
            return Err(format!("expected exclusiveMinimum {minimum}, got {number}"));
        }
    }
    Ok(())
}

fn resolve_ref<'a>(reference: &str, root: &'a Value) -> Result<&'a Value, String> {
    let pointer = reference
        .strip_prefix('#')
        .ok_or_else(|| format!("only local refs are supported: {reference}"))?;
    root.pointer(pointer)
        .ok_or_else(|| format!("unresolved ref: {reference}"))
}
