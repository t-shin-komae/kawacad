//! KawaCAD のドキュメントモデルで使う幾何プリミティブと検証。

/// 幾何エンティティの安定 ID。
pub type EntityId = String;
/// 描画レイヤーの安定 ID。
pub type LayerId = String;
/// 共有スタイルの安定 ID。
pub type SharedStyleId = String;

/// 既定の幾何許容誤差。単位はミリメートル。
pub const GEOMETRY_EPSILON_MM: f64 = 1e-6;

/// 安定 ID、任意のレイヤー、型付きペイロードを持つドキュメントエンティティ。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Entity {
    /// エンティティの安定 ID。
    pub id: EntityId,
    /// このエンティティを所有するレイヤーの任意 ID。
    pub layer_id: Option<LayerId>,
    /// このエンティティが参照する共有スタイルの任意 ID。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub style_id: Option<SharedStyleId>,
    /// 幾何ペイロード。
    pub kind: EntityKind,
}

impl Entity {
    /// レイヤー未割り当てのエンティティを作成する。
    pub fn new(id: impl Into<EntityId>, kind: EntityKind) -> Self {
        Self {
            id: id.into(),
            layer_id: None,
            style_id: None,
            kind,
        }
    }

    /// このエンティティをレイヤーに割り当てる。
    pub fn on_layer(mut self, layer_id: impl Into<LayerId>) -> Self {
        self.layer_id = Some(layer_id.into());
        self
    }

    /// このエンティティに共有スタイルを割り当てる。
    pub fn with_style(mut self, style_id: impl Into<SharedStyleId>) -> Self {
        self.style_id = Some(style_id.into());
        self
    }

    /// エンティティ ID と型付きペイロードを検証する。
    pub fn validate(&self) -> Result<(), GeometryValidationError> {
        if self.id.trim().is_empty() {
            return Err(GeometryValidationError::EmptyEntityId);
        }

        self.kind.validate()
    }
}

/// 現行ドキュメントで対応する幾何ペイロード。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EntityKind {
    /// 単独の点。
    Point(Point2),
    /// 2点間の直線分。
    LineSegment(LineSegment),
    /// 中心と半径で表す円。
    Circle(Circle),
    /// 中心、半径、開始角、掃引角で表す円弧。
    Arc(Arc),
    /// 対称拘束に使う補助中心線。
    CenterLine(LineSegment),
}

impl EntityKind {
    /// このペイロードの寸法と数値を検証する。
    pub fn validate(&self) -> Result<(), GeometryValidationError> {
        match self {
            Self::Point(point) => validate_point(*point),
            Self::LineSegment(line) | Self::CenterLine(line) => {
                validate_point(line.start)?;
                validate_point(line.end)?;
                if line.length_mm() <= GEOMETRY_EPSILON_MM {
                    return Err(GeometryValidationError::DegenerateLineSegment);
                }
                Ok(())
            }
            Self::Circle(circle) => {
                validate_point(circle.center)?;
                validate_positive_length(circle.radius_mm, "circle radius")
            }
            Self::Arc(arc) => {
                validate_point(arc.center)?;
                validate_positive_length(arc.radius_mm, "arc radius")?;
                validate_finite(arc.start_angle_rad, "arc start angle")?;
                validate_finite(arc.sweep_angle_rad, "arc sweep angle")?;
                if arc.sweep_angle_rad.abs() <= f64::EPSILON {
                    return Err(GeometryValidationError::DegenerateArc);
                }
                Ok(())
            }
        }
    }
}

/// 2次元モデル空間の点。単位はミリメートル。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Point2 {
    /// X 座標。単位はミリメートル。
    pub x_mm: f64,
    /// Y 座標。単位はミリメートル。
    pub y_mm: f64,
}

impl Point2 {
    /// ミリメートル座標から点を作成する。
    pub const fn new(x_mm: f64, y_mm: f64) -> Self {
        Self { x_mm, y_mm }
    }
}

/// モデル空間の2点を結ぶ直線分。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LineSegment {
    /// 線分の始点。
    pub start: Point2,
    /// 線分の終点。
    pub end: Point2,
}

impl LineSegment {
    /// 始点と終点から線分を作成する。
    pub fn new(start: Point2, end: Point2) -> Self {
        Self { start, end }
    }

    /// ユークリッド距離による線分長をミリメートルで返す。
    pub fn length_mm(&self) -> f64 {
        let dx = self.end.x_mm - self.start.x_mm;
        let dy = self.end.y_mm - self.start.y_mm;
        dx.hypot(dy)
    }
}

/// モデル空間上の円。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Circle {
    /// モデル座標における円の中心。
    pub center: Point2,
    /// 円の半径。単位はミリメートル。
    pub radius_mm: f64,
}

/// モデル空間上の円弧。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Arc {
    /// モデル座標における円弧の中心。
    pub center: Point2,
    /// 円弧の半径。単位はミリメートル。
    pub radius_mm: f64,
    /// 開始角。単位はラジアン。
    pub start_angle_rad: f64,
    /// 掃引角。単位はラジアン。
    pub sweep_angle_rad: f64,
}

/// 幾何レベルの検証エラー。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GeometryValidationError {
    /// エンティティ ID が空。
    EmptyEntityId,
    /// 数値フィールドが NaN または無限大。
    NonFiniteValue(&'static str),
    /// 長さ系フィールドがゼロまたは負数。
    NonPositiveLength(&'static str),
    /// 線分がモデル許容誤差より短い。
    DegenerateLineSegment,
    /// 円弧の掃引角が実質的にゼロ。
    DegenerateArc,
}

fn validate_point(point: Point2) -> Result<(), GeometryValidationError> {
    validate_finite(point.x_mm, "point x")?;
    validate_finite(point.y_mm, "point y")
}

fn validate_positive_length(
    value: f64,
    field: &'static str,
) -> Result<(), GeometryValidationError> {
    validate_finite(value, field)?;
    if value <= GEOMETRY_EPSILON_MM {
        return Err(GeometryValidationError::NonPositiveLength(field));
    }
    Ok(())
}

fn validate_finite(value: f64, field: &'static str) -> Result<(), GeometryValidationError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(GeometryValidationError::NonFiniteValue(field))
    }
}
