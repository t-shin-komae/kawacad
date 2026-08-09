use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

use kawacad_core::output::{OutputDocumentModel, PrintableAreaMm};
use kawacad_output_engine::PrintRenderData;

#[cfg(target_os = "windows")]
#[path = "direct_print/windows.rs"]
mod platform;
#[cfg(target_os = "linux")]
#[path = "direct_print/linux.rs"]
mod platform;

pub const PREPARED_PRINT_TTL: Duration = Duration::from_secs(60);
pub const MAX_PREPARED_PRINTS: usize = 8;
pub const MAX_PREPARED_ARTIFACT_BYTES: usize = 64 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectPrintAvailability {
    pub status: DirectPrintAvailabilityStatus,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum DirectPrintAvailabilityStatus {
    Available,
    UnsupportedPlatform,
    Unavailable,
}

pub fn current_availability() -> DirectPrintAvailability {
    #[cfg(target_os = "macos")]
    {
        DirectPrintAvailability {
            status: DirectPrintAvailabilityStatus::UnsupportedPlatform,
            reason: Some("Tauri/macOS does not provide direct printing".to_owned()),
        }
    }

    #[cfg(target_os = "windows")]
    {
        platform::availability()
    }

    #[cfg(target_os = "linux")]
    {
        platform::availability()
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        DirectPrintAvailability {
            status: DirectPrintAvailabilityStatus::UnsupportedPlatform,
            reason: Some("Direct printing is not supported on this platform".to_owned()),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectPrintOptions {
    pub orientation: String,
    pub include_dimension_labels: bool,
    pub include_scale_guide: bool,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareDirectPrintRequest {
    pub printer_id: String,
    pub options: DirectPrintOptions,
    pub generation: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InspectPrinterRequest {
    pub printer_id: String,
    pub options: DirectPrintOptions,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectPrinter {
    pub id: String,
    pub display_name: String,
    pub selectable: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PrinterInspection {
    pub printer_id: String,
    pub selectable: bool,
    pub printable_area_mm: Option<PrintableAreaMm>,
    pub reason: Option<String>,
    pub capability_fingerprint: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PreparedDirectPrint {
    pub printer_id: String,
    pub options: DirectPrintOptions,
    pub document_fingerprint: String,
    pub capability_fingerprint: String,
    pub output: kawacad_core::output::BuildOutputDocumentModelResult,
    pub artifact: DirectPrintArtifact,
}

#[derive(Debug, Clone)]
pub enum DirectPrintArtifact {
    Windows(PrintRenderData),
    LinuxPdf(Vec<u8>),
}

impl DirectPrintArtifact {
    pub fn byte_len(&self) -> usize {
        match self {
            Self::Windows(data) => serde_json::to_vec(data).map_or(usize::MAX, |bytes| bytes.len()),
            Self::LinuxPdf(bytes) => bytes.len(),
        }
    }
}

pub fn list_printers() -> Result<Vec<DirectPrinter>, String> {
    #[cfg(any(target_os = "windows", target_os = "linux"))]
    {
        platform::list_printers()
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    {
        Err(unavailable_error())
    }
}

pub fn inspect_printer(request: &InspectPrinterRequest) -> Result<PrinterInspection, String> {
    #[cfg(any(target_os = "windows", target_os = "linux"))]
    {
        platform::inspect_printer(request)
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    {
        let _ = request;
        Err(unavailable_error())
    }
}

pub fn create_artifact(model: &OutputDocumentModel) -> Result<DirectPrintArtifact, String> {
    #[cfg(target_os = "windows")]
    {
        kawacad_output_engine::render_print(model)
            .map(DirectPrintArtifact::Windows)
            .map_err(|error| format!("Could not render direct print data: {error:?}"))
    }

    #[cfg(target_os = "linux")]
    {
        kawacad_output_engine::render_pdf(model)
            .map(|pdf| DirectPrintArtifact::LinuxPdf(pdf.bytes))
            .map_err(|error| format!("Could not render direct print PDF: {error:?}"))
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    {
        let _ = model;
        Err(unavailable_error())
    }
}

pub fn send(prepared: &PreparedDirectPrint) -> Result<(), String> {
    #[cfg(any(target_os = "windows", target_os = "linux"))]
    {
        platform::send(prepared)
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux")))]
    {
        let _ = prepared;
        Err(unavailable_error())
    }
}

fn unavailable_error() -> String {
    current_availability()
        .reason
        .unwrap_or_else(|| "Direct printing is unavailable".to_owned())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PreparedPrintStoreError {
    Superseded,
    Busy,
    Stale,
}

struct PreparedPrint<T> {
    id: String,
    owner_window: String,
    generation: u64,
    created_at: Instant,
    artifact_bytes: usize,
    value: T,
}

pub struct PreparedPrintStore<T> {
    entries: HashMap<String, PreparedPrint<T>>,
    latest_generation_by_window: HashMap<String, u64>,
    prepared_id_by_window: HashMap<String, String>,
    total_artifact_bytes: usize,
    next_id: u64,
    max_entries: usize,
    max_artifact_bytes: usize,
}

impl<T> PreparedPrintStore<T> {
    pub fn new() -> Self {
        Self::with_capacity(MAX_PREPARED_PRINTS, MAX_PREPARED_ARTIFACT_BYTES)
    }

    fn with_capacity(max_entries: usize, max_artifact_bytes: usize) -> Self {
        Self {
            entries: HashMap::new(),
            latest_generation_by_window: HashMap::new(),
            prepared_id_by_window: HashMap::new(),
            total_artifact_bytes: 0,
            next_id: 1,
            max_entries,
            max_artifact_bytes,
        }
    }

    pub fn register(
        &mut self,
        owner_window: String,
        generation: u64,
        artifact_bytes: usize,
        value: T,
        now: Instant,
    ) -> Result<String, PreparedPrintStoreError> {
        self.remove_expired(now);

        if self
            .latest_generation_by_window
            .get(&owner_window)
            .is_some_and(|latest| generation <= *latest)
        {
            return Err(PreparedPrintStoreError::Superseded);
        }
        self.latest_generation_by_window
            .insert(owner_window.clone(), generation);

        if let Some(previous_id) = self.prepared_id_by_window.remove(&owner_window) {
            self.remove_entry(&previous_id);
        }
        if self.entries.len() >= self.max_entries
            || artifact_bytes
                > self
                    .max_artifact_bytes
                    .saturating_sub(self.total_artifact_bytes)
        {
            if self.latest_generation_by_window.get(&owner_window) == Some(&generation) {
                self.latest_generation_by_window.remove(&owner_window);
            }
            return Err(PreparedPrintStoreError::Busy);
        }

        let id = format!("prepared-print:{}", self.next_id);
        self.next_id += 1;
        self.total_artifact_bytes += artifact_bytes;
        self.prepared_id_by_window
            .insert(owner_window.clone(), id.clone());
        self.entries.insert(
            id.clone(),
            PreparedPrint {
                id: id.clone(),
                owner_window,
                generation,
                created_at: now,
                artifact_bytes,
                value,
            },
        );
        Ok(id)
    }

    pub fn take(
        &mut self,
        owner_window: &str,
        id: &str,
        now: Instant,
    ) -> Result<T, PreparedPrintStoreError> {
        self.remove_expired(now);
        let is_owned_and_current = self.entries.get(id).is_some_and(|entry| {
            entry.owner_window == owner_window
                && self.latest_generation_by_window.get(owner_window) == Some(&entry.generation)
        });
        if !is_owned_and_current {
            return Err(PreparedPrintStoreError::Stale);
        }
        self.prepared_id_by_window.remove(owner_window);
        self.entries
            .remove(id)
            .map(|entry| {
                self.total_artifact_bytes -= entry.artifact_bytes;
                if self.latest_generation_by_window.get(owner_window) == Some(&entry.generation) {
                    self.latest_generation_by_window.remove(owner_window);
                }
                entry.value
            })
            .ok_or(PreparedPrintStoreError::Stale)
    }

    pub fn discard(&mut self, owner_window: &str, id: &str, now: Instant) {
        self.remove_expired(now);
        let is_owned = self
            .entries
            .get(id)
            .is_some_and(|entry| entry.owner_window == owner_window);
        if is_owned {
            self.prepared_id_by_window.remove(owner_window);
            self.remove_entry(id);
        }
    }

    fn remove_expired(&mut self, now: Instant) {
        let expired_ids = self
            .entries
            .iter()
            .filter(|(_, entry)| {
                now.saturating_duration_since(entry.created_at) >= PREPARED_PRINT_TTL
            })
            .map(|(id, _)| id.clone())
            .collect::<Vec<_>>();
        for id in expired_ids {
            self.remove_entry(&id);
        }
    }

    fn remove_entry(&mut self, id: &str) {
        if let Some(entry) = self.entries.remove(id) {
            self.total_artifact_bytes -= entry.artifact_bytes;
            if self
                .prepared_id_by_window
                .get(&entry.owner_window)
                .is_some_and(|current| current == &entry.id)
            {
                self.prepared_id_by_window.remove(&entry.owner_window);
            }
            if self.latest_generation_by_window.get(&entry.owner_window) == Some(&entry.generation)
            {
                self.latest_generation_by_window.remove(&entry.owner_window);
            }
        }
    }
}

impl<T> Default for PreparedPrintStore<T> {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_keeps_the_latest_prepared_print_for_each_window() {
        let now = Instant::now();
        let mut store = PreparedPrintStore::with_capacity(2, 100);
        let first = store
            .register("main".to_owned(), 1, 20, "first", now)
            .expect("first preparation should be stored");
        let second = store
            .register("main".to_owned(), 2, 20, "second", now)
            .expect("second preparation should replace the first");

        assert_eq!(
            store.take("main", &first, now),
            Err(PreparedPrintStoreError::Stale)
        );
        assert_eq!(store.take("main", &second, now), Ok("second"));
    }

    #[test]
    fn discards_late_generations_and_enforces_capacity() {
        let now = Instant::now();
        let mut store = PreparedPrintStore::with_capacity(1, 30);
        let id = store
            .register("main".to_owned(), 2, 20, (), now)
            .expect("current generation should be stored");

        assert_eq!(
            store.register("main".to_owned(), 1, 20, (), now),
            Err(PreparedPrintStoreError::Superseded)
        );
        assert_eq!(
            store.register("secondary".to_owned(), 1, 20, (), now),
            Err(PreparedPrintStoreError::Busy)
        );

        store.discard("main", &id, now);
        assert_eq!(
            store.take("main", &id, now),
            Err(PreparedPrintStoreError::Stale)
        );
    }

    #[test]
    fn expires_and_rejects_prepared_prints_from_other_windows() {
        let now = Instant::now();
        let mut store = PreparedPrintStore::with_capacity(2, 100);
        let id = store
            .register("main".to_owned(), 1, 20, (), now)
            .expect("preparation should be stored");

        assert_eq!(
            store.take("secondary", &id, now),
            Err(PreparedPrintStoreError::Stale)
        );
        assert_eq!(
            store.take("main", &id, now + PREPARED_PRINT_TTL),
            Err(PreparedPrintStoreError::Stale)
        );
    }

    #[test]
    fn accepts_a_new_sheet_generation_after_the_previous_item_is_consumed() {
        let now = Instant::now();
        let mut store = PreparedPrintStore::with_capacity(2, 100);
        let id = store
            .register("main".to_owned(), 1, 20, (), now)
            .expect("first preparation should be stored");
        store
            .take("main", &id, now)
            .expect("first preparation should be consumed");

        assert!(store.register("main".to_owned(), 1, 20, (), now).is_ok());
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn submits_a4_pdf_to_the_configured_cups_printer() {
        let Ok(printer_id) = std::env::var("KAWACAD_CUPS_E2E_PRINTER") else {
            return;
        };
        let options = DirectPrintOptions {
            orientation: "portrait".to_owned(),
            include_dimension_labels: true,
            include_scale_guide: true,
        };
        let printers = list_printers().expect("CUPS printers should be listed");
        assert!(
            printers.iter().any(|printer| printer.id == printer_id),
            "configured CUPS printer should be listed"
        );
        let inspection = inspect_printer(&InspectPrinterRequest {
            printer_id: printer_id.clone(),
            options: options.clone(),
        })
        .expect("CUPS printer should be inspected");
        assert!(
            inspection.selectable,
            "configured CUPS printer must accept A4, 100%, simplex, 1-up PDF output: {:?}",
            inspection.reason
        );
        let printable_area_mm = inspection
            .printable_area_mm
            .expect("selectable printer should provide its printable area");
        let mut document = kawacad_core::document::ProjectDocument::new("CUPS E2E");
        document
            .apply_command(kawacad_core::command::DocumentCommand::AddEntity(
                kawacad_core::geometry::Entity::new(
                    "cups-e2e-line",
                    kawacad_core::geometry::EntityKind::LineSegment(
                        kawacad_core::geometry::LineSegment::new(
                            kawacad_core::geometry::Point2::new(-10.0, 0.0),
                            kawacad_core::geometry::Point2::new(10.0, 0.0),
                        ),
                    ),
                ),
            ))
            .expect("test line should be added");
        let output = document
            .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
                orientation: kawacad_core::print::PrintOrientation::Portrait,
                include_dimension_labels: options.include_dimension_labels,
                include_scale_guide: options.include_scale_guide,
                rotation_deg: 0,
                printable_area_mm,
            })
            .expect("output document model should be built");
        let artifact = create_artifact(&output.output_document_model)
            .expect("direct-print PDF should be rendered");
        let prepared = PreparedDirectPrint {
            printer_id,
            options,
            document_fingerprint: "cups-e2e".to_owned(),
            capability_fingerprint: inspection
                .capability_fingerprint
                .expect("selectable printer should provide a capability fingerprint"),
            output,
            artifact,
        };

        send(&prepared).expect("CUPS should accept the direct-print PDF");
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_reports_direct_printing_as_unsupported() {
        assert_eq!(
            current_availability().status,
            DirectPrintAvailabilityStatus::UnsupportedPlatform
        );
    }
}
