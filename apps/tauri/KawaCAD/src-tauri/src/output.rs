use kawacad_core::output::PrintableAreaMm;
use kawacad_core::print::PrintOrientation;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct PdfOutputOptions {
    pub(crate) orientation: PrintOrientation,
    pub(crate) include_dimension_labels: bool,
    pub(crate) include_scale_guide: bool,
    pub(crate) rotation_deg: u16,
}

pub(crate) fn pdf_printable_area(orientation: PrintOrientation) -> PrintableAreaMm {
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

pub(crate) fn temporary_pdf_path(path: &Path) -> Result<PathBuf, String> {
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

pub(crate) fn save_pdf_bytes(path: PathBuf, bytes: &[u8]) -> Result<(), String> {
    let temporary_path = temporary_pdf_path(&path)?;
    fs::write(&temporary_path, bytes)
        .map_err(|error| format!("Could not write PDF data: {error}"))?;
    fs::rename(&temporary_path, &path).map_err(|error| {
        let _ = fs::remove_file(&temporary_path);
        format!("Could not save PDF: {error}")
    })
}
