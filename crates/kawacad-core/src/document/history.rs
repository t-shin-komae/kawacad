use super::{DocumentIoError, ProjectDocument};
use crate::command::{CommandError, CommandResult};

#[derive(Debug, Clone, Default)]
pub(in crate::document) struct HistoryStore {
    undo_stack: Vec<HistorySnapshot>,
    redo_stack: Vec<HistorySnapshot>,
}

#[derive(Debug, Clone)]
pub(in crate::document) struct PendingHistoryEntry {
    snapshot: HistorySnapshot,
}

#[derive(Debug, Clone)]
struct HistorySnapshot {
    json: String,
}

impl HistoryStore {
    pub(in crate::document) fn capture_pending_entry(
        document: &ProjectDocument,
    ) -> CommandResult<PendingHistoryEntry> {
        Ok(PendingHistoryEntry {
            snapshot: HistorySnapshot::capture(document)?,
        })
    }

    pub(in crate::document) fn record_applied_command(&mut self, entry: PendingHistoryEntry) {
        self.undo_stack.push(entry.snapshot);
        self.redo_stack.clear();
    }

    pub(in crate::document) fn can_undo(&self) -> bool {
        !self.undo_stack.is_empty()
    }

    pub(in crate::document) fn can_redo(&self) -> bool {
        !self.redo_stack.is_empty()
    }

    pub(in crate::document) fn undo_document(
        &mut self,
        current: &ProjectDocument,
    ) -> CommandResult<ProjectDocument> {
        let Some(previous) = self.undo_stack.pop() else {
            return Err(empty_history_error("undo"));
        };

        let current_snapshot = match HistorySnapshot::capture(current) {
            Ok(snapshot) => snapshot,
            Err(error) => {
                self.undo_stack.push(previous);
                return Err(error);
            }
        };
        self.redo_stack.push(current_snapshot);

        match previous.restore_document() {
            Ok(document) => Ok(document),
            Err(_) => {
                let _ = self.redo_stack.pop();
                self.undo_stack.push(previous);
                Err(restore_snapshot_error("undo"))
            }
        }
    }

    pub(in crate::document) fn redo_document(
        &mut self,
        current: &ProjectDocument,
    ) -> CommandResult<ProjectDocument> {
        let Some(next) = self.redo_stack.pop() else {
            return Err(empty_history_error("redo"));
        };

        let current_snapshot = match HistorySnapshot::capture(current) {
            Ok(snapshot) => snapshot,
            Err(error) => {
                self.redo_stack.push(next);
                return Err(error);
            }
        };
        self.undo_stack.push(current_snapshot);

        match next.restore_document() {
            Ok(document) => Ok(document),
            Err(_) => {
                let _ = self.undo_stack.pop();
                self.redo_stack.push(next);
                Err(restore_snapshot_error("redo"))
            }
        }
    }
}

impl HistorySnapshot {
    fn capture(document: &ProjectDocument) -> CommandResult<Self> {
        serde_json::to_string(document)
            .map(|json| Self { json })
            .map_err(|_| CommandError::InvalidValue {
                field: "document snapshot",
                reason: "failed to serialize current state",
            })
    }

    fn restore_document(&self) -> Result<ProjectDocument, DocumentIoError> {
        ProjectDocument::from_json_str(&self.json)
    }
}

fn empty_history_error(field: &'static str) -> CommandError {
    CommandError::InvalidValue {
        field,
        reason: match field {
            "undo" => "no undo history",
            "redo" => "no redo history",
            _ => "no history",
        },
    }
}

fn restore_snapshot_error(field: &'static str) -> CommandError {
    CommandError::InvalidValue {
        field,
        reason: "failed to restore snapshot",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_undo_and_redo_history() {
        let mut history = HistoryStore::default();
        let document = ProjectDocument::new("empty");

        assert_empty_history_error(history.undo_document(&document), "undo", "no undo history");
        assert_empty_history_error(history.redo_document(&document), "redo", "no redo history");
    }

    #[test]
    fn restores_undo_and_redo_snapshots() {
        let mut history = HistoryStore::default();
        let original = ProjectDocument::new("original");
        let mut updated = ProjectDocument::new("updated");
        updated
            .apply_command(crate::command::DocumentCommand::SetPrintOrientation {
                orientation: crate::print::PrintOrientation::Landscape,
            })
            .unwrap();

        history.record_applied_command(HistoryStore::capture_pending_entry(&original).unwrap());

        let restored = history.undo_document(&updated).unwrap();
        assert_eq!(
            restored.settings().orientation,
            crate::print::PrintOrientation::Portrait
        );
        assert!(!history.can_undo());
        assert!(history.can_redo());

        let redone = history.redo_document(&restored).unwrap();
        assert_eq!(
            redone.settings().orientation,
            crate::print::PrintOrientation::Landscape
        );
        assert!(history.can_undo());
        assert!(!history.can_redo());
    }

    #[test]
    fn recording_new_command_discards_redo_history() {
        let mut history = HistoryStore::default();
        let original = ProjectDocument::new("original");
        let updated = ProjectDocument::new("updated");
        let replacement = ProjectDocument::new("replacement");

        history.record_applied_command(HistoryStore::capture_pending_entry(&original).unwrap());
        let restored = history.undo_document(&updated).unwrap();
        assert!(history.can_redo());

        history.record_applied_command(HistoryStore::capture_pending_entry(&restored).unwrap());

        assert!(history.can_undo());
        assert!(!history.can_redo());
        assert_empty_history_error(
            history.redo_document(&replacement),
            "redo",
            "no redo history",
        );
    }

    fn assert_empty_history_error(
        result: CommandResult<ProjectDocument>,
        field: &'static str,
        reason: &'static str,
    ) {
        match result {
            Err(CommandError::InvalidValue {
                field: actual,
                reason: actual_reason,
            }) => {
                assert_eq!(actual, field);
                assert_eq!(actual_reason, reason);
            }
            other => panic!("expected empty history error, got {other:?}"),
        }
    }
}
