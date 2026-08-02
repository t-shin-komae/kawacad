use std::fs;
use std::path::Path;

use super::{DocumentIoError, ProjectDocument};

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
        let mut document: ProjectDocument = serde_json::from_str(json)
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
