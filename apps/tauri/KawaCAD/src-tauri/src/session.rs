use kawacad_core::document::ProjectDocument;
use kawacad_core::snapshot::CanvasViewMode;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

pub(crate) struct CadSession {
    pub(crate) document: ProjectDocument,
    pub(crate) clean_document: ProjectDocument,
    pub(crate) view_mode: CanvasViewMode,
    pub(crate) path: Option<String>,
    pub(crate) recovered_dirty: bool,
    pub(crate) recovery_candidate_id: String,
}

pub(crate) static RECOVERY_SESSION_SEQUENCE: AtomicU64 = AtomicU64::new(0);

pub(crate) fn new_recovery_candidate_id() -> String {
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
    pub(crate) fn new(name: String) -> Self {
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

    pub(crate) fn is_dirty(&self) -> bool {
        self.recovered_dirty || self.document != self.clean_document
    }
}
