use super::*;

/// 人が読めるドキュメントメタデータ。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DocumentMetadata {
    /// ドキュメントの安定 ID。
    pub id: String,
    /// ユーザー向けのドキュメント名。
    pub name: String,
    /// 計測単位名。
    pub unit: String,
}

impl DocumentMetadata {
    /// ミリメートル単位のドキュメントメタデータを作成する。
    pub(crate) fn new(name: impl Into<String>) -> Self {
        Self {
            id: "document:local".to_owned(),
            name: name.into(),
            unit: "mm".to_owned(),
        }
    }
}

/// `ProjectDocument` 全体の検証エラー。
#[derive(Debug, Clone, PartialEq)]
pub enum DocumentValidationError {
    /// 必須 ID フィールドが空、または空白のみだった。
    EmptyId(&'static str),
    /// 既に存在する ID のオブジェクトがあった。
    DuplicateId {
        /// ID が重複したオブジェクト種別。
        kind: &'static str,
        /// 重複した ID。
        id: String,
    },
    /// 参照先が存在しなかった。
    BrokenReference {
        /// 参照元オブジェクトの種別。
        source: &'static str,
        /// 参照先オブジェクトの種別。
        target_kind: &'static str,
        /// 見つからなかった参照先 ID。
        target_id: String,
    },
    /// 値の検証に失敗した。
    InvalidValue {
        /// 不正だったフィールド名。
        field: &'static str,
        /// 検証失敗の理由。
        reason: &'static str,
    },
    /// エンティティが幾何レベルの検証に失敗した。
    InvalidEntity {
        /// 検証失敗したエンティティ ID。
        entity_id: String,
        /// 幾何レベルの詳細エラー。
        error: crate::geometry::GeometryValidationError,
    },
    /// 対応していないファイル形式バージョンだった。
    UnsupportedFileFormatVersion {
        /// 入力ファイルに記録されていたバージョン。
        found: String,
    },
    /// 対応していないスキーマバージョンだった。
    UnsupportedSchemaVersion {
        /// 入力ファイルに記録されていたバージョン。
        found: String,
    },
}

/// `.kawa` JSON の入出力エラー。
#[derive(Debug, Clone, PartialEq)]
pub enum DocumentIoError {
    /// JSON シリアライズに失敗した。
    SerializeFailed(String),
    /// JSON デシリアライズに失敗した。
    DeserializeFailed(String),
    /// ファイル読み込みに失敗した。
    ReadFailed(String),
    /// ファイル書き込みに失敗した。
    WriteFailed(String),
    /// デシリアライズ後のドキュメント検証に失敗した。
    ValidationFailed(DocumentValidationError),
}

impl From<CommandError> for DocumentValidationError {
    fn from(error: CommandError) -> Self {
        match error {
            CommandError::EmptyId(kind) => Self::EmptyId(kind),
            CommandError::DuplicateId { kind, id } => Self::DuplicateId { kind, id },
            CommandError::MissingId { kind, id } => Self::BrokenReference {
                source: kind,
                target_kind: kind,
                target_id: id,
            },
            CommandError::InvalidEntity(error) => Self::InvalidEntity {
                entity_id: String::new(),
                error,
            },
            CommandError::InvalidValue { field, reason } => Self::InvalidValue { field, reason },
            CommandError::BrokenReference {
                source,
                target_kind,
                target_id,
            } => Self::BrokenReference {
                source,
                target_kind,
                target_id,
            },
            CommandError::Constraint(_) => Self::InvalidValue {
                field: "constraint",
                reason: "invalid constraint",
            },
        }
    }
}
