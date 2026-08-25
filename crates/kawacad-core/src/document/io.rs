use std::fs;
use std::path::Path;

use super::{DocumentIoError, ProjectDocument, FILE_FORMAT_VERSION, SCHEMA_VERSION};

const LEGACY_FILE_FORMAT_VERSION: &str = "0.1.0";
const LEGACY_SCHEMA_VERSION: &str = "0.1.0";

pub(crate) struct DocumentIo;

impl DocumentIo {
    pub(crate) fn to_json_pretty_string(
        document: &ProjectDocument,
    ) -> Result<String, DocumentIoError> {
        document
            .validate()
            .map_err(DocumentIoError::ValidationFailed)?;
        serde_json::to_string_pretty(document)
            .map_err(|error| DocumentIoError::SerializeFailed(error.to_string()))
    }

    pub(crate) fn from_json_str(json: &str) -> Result<ProjectDocument, DocumentIoError> {
        let mut value: serde_json::Value = serde_json::from_str(json)
            .map_err(|error| DocumentIoError::DeserializeFailed(error.to_string()))?;
        migrate_legacy_document(&mut value)?;
        let mut document: ProjectDocument = serde_json::from_value(value)
            .map_err(|error| DocumentIoError::DeserializeFailed(error.to_string()))?;
        // `locked` was user-configurable in earlier files. Parts are fixed by
        // definition now, so legacy values are normalized during import.
        for part in &mut document.parts {
            part.locked = true;
        }
        document
            .validate()
            .map_err(DocumentIoError::ValidationFailed)?;
        Ok(document)
    }

    pub(crate) fn write_json_file(
        document: &ProjectDocument,
        path: impl AsRef<Path>,
    ) -> Result<(), DocumentIoError> {
        let json = Self::to_json_pretty_string(document)?;
        fs::write(path, json).map_err(|error| DocumentIoError::WriteFailed(error.to_string()))
    }

    pub(crate) fn read_json_file(
        path: impl AsRef<Path>,
    ) -> Result<ProjectDocument, DocumentIoError> {
        let json = fs::read_to_string(path)
            .map_err(|error| DocumentIoError::ReadFailed(error.to_string()))?;
        Self::from_json_str(&json)
    }
}

fn migrate_legacy_document(value: &mut serde_json::Value) -> Result<(), DocumentIoError> {
    let is_legacy = value
        .get("fileFormatVersion")
        .and_then(serde_json::Value::as_str)
        == Some(LEGACY_FILE_FORMAT_VERSION)
        && value
            .get("schemaVersion")
            .and_then(serde_json::Value::as_str)
            == Some(LEGACY_SCHEMA_VERSION);
    if !is_legacy {
        return Ok(());
    }

    let document = value
        .get_mut("document")
        .and_then(serde_json::Value::as_object_mut)
        .ok_or_else(|| {
            DocumentIoError::DeserializeFailed("legacy document metadata is missing".to_owned())
        })?;
    document
        .remove("name")
        .and_then(|name| name.as_str().map(str::to_owned))
        .filter(|name| !name.trim().is_empty())
        .ok_or_else(|| {
            DocumentIoError::DeserializeFailed("legacy document name is missing".to_owned())
        })?;
    value["fileFormatVersion"] = serde_json::Value::String(FILE_FORMAT_VERSION.to_owned());
    value["schemaVersion"] = serde_json::Value::String(SCHEMA_VERSION.to_owned());
    Ok(())
}
