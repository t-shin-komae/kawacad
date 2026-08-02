use super::*;

pub(in crate::document) struct RadiusEntity {
    pub(in crate::document) radius_mm: f64,
}

pub(in crate::document) fn direction(line: crate::geometry::LineSegment) -> Point2 {
    normalized_direction(line.start, line.end)
}

pub(in crate::document) fn horizontal_direction_sign(start: Point2, end: Point2) -> f64 {
    if end.x_mm >= start.x_mm {
        1.0
    } else {
        -1.0
    }
}

pub(in crate::document) fn vertical_direction_sign(start: Point2, end: Point2) -> f64 {
    if end.y_mm >= start.y_mm {
        1.0
    } else {
        -1.0
    }
}

pub(in crate::document) fn cross_product(lhs: Point2, rhs: Point2) -> f64 {
    lhs.x_mm * rhs.y_mm - lhs.y_mm * rhs.x_mm
}

pub(in crate::document) fn points_close(lhs: Point2, rhs: Point2) -> bool {
    approx_eq(lhs.x_mm, rhs.x_mm) && approx_eq(lhs.y_mm, rhs.y_mm)
}

pub(in crate::document) fn points_approximately_equal(lhs: Point2, rhs: Point2) -> bool {
    points_close(lhs, rhs)
}

pub(in crate::document) fn entities_approximately_equal(lhs: &[Entity], rhs: &[Entity]) -> bool {
    if lhs.len() != rhs.len() {
        return false;
    }

    lhs.iter().zip(rhs).all(|(lhs, rhs)| {
        if lhs.id != rhs.id || lhs.layer_id != rhs.layer_id {
            return false;
        }

        match (&lhs.kind, &rhs.kind) {
            (EntityKind::Point(lhs), EntityKind::Point(rhs)) => {
                points_approximately_equal(*lhs, *rhs)
            }
            (EntityKind::LineSegment(lhs), EntityKind::LineSegment(rhs))
            | (EntityKind::CenterLine(lhs), EntityKind::CenterLine(rhs)) => {
                points_approximately_equal(lhs.start, rhs.start)
                    && points_approximately_equal(lhs.end, rhs.end)
            }
            (EntityKind::Circle(lhs), EntityKind::Circle(rhs)) => {
                points_approximately_equal(lhs.center, rhs.center)
                    && approx_eq(lhs.radius_mm, rhs.radius_mm)
            }
            (EntityKind::Arc(lhs), EntityKind::Arc(rhs)) => {
                points_approximately_equal(lhs.center, rhs.center)
                    && approx_eq(lhs.radius_mm, rhs.radius_mm)
                    && approx_eq(lhs.start_angle_rad, rhs.start_angle_rad)
                    && approx_eq(lhs.sweep_angle_rad, rhs.sweep_angle_rad)
            }
            _ => false,
        }
    })
}

pub(in crate::document) fn distance_between(lhs: Point2, rhs: Point2) -> f64 {
    (rhs.x_mm - lhs.x_mm).hypot(rhs.y_mm - lhs.y_mm)
}

pub(in crate::document) fn point_line_distance(
    point: Point2,
    line: crate::geometry::LineSegment,
) -> f64 {
    signed_point_line_distance(point, line).abs()
}

pub(in crate::document) fn signed_point_line_distance(
    point: Point2,
    line: crate::geometry::LineSegment,
) -> f64 {
    let axis_direction = normalized_direction(line.start, line.end);
    let axis_normal = Point2::new(-axis_direction.y_mm, axis_direction.x_mm);
    let relative = Point2::new(point.x_mm - line.start.x_mm, point.y_mm - line.start.y_mm);
    dot_product(relative, axis_normal)
}

pub(in crate::document) fn project_point_onto_line(
    point: Point2,
    line: crate::geometry::LineSegment,
) -> Point2 {
    let axis_direction = normalized_direction(line.start, line.end);
    let relative = Point2::new(point.x_mm - line.start.x_mm, point.y_mm - line.start.y_mm);
    let parallel_distance = dot_product(relative, axis_direction);
    Point2::new(
        line.start.x_mm + axis_direction.x_mm * parallel_distance,
        line.start.y_mm + axis_direction.y_mm * parallel_distance,
    )
}

pub(in crate::document) fn signed_angle(lhs: Point2, rhs: Point2) -> f64 {
    cross_product(lhs, rhs).atan2(dot_product(lhs, rhs))
}

pub(in crate::document) fn normalize_angle(angle_rad: f64) -> f64 {
    let two_pi = std::f64::consts::TAU;
    let normalized = angle_rad.rem_euclid(two_pi);
    if normalized > std::f64::consts::PI {
        normalized - two_pi
    } else {
        normalized
    }
}

pub(in crate::document) fn normalize_positive_angle(angle_rad: f64) -> f64 {
    angle_rad.rem_euclid(std::f64::consts::TAU)
}

pub(in crate::document) fn point_on_arc(arc: &crate::geometry::Arc, angle_rad: f64) -> Point2 {
    Point2::new(
        arc.center.x_mm + arc.radius_mm * angle_rad.cos(),
        arc.center.y_mm + arc.radius_mm * angle_rad.sin(),
    )
}

pub(in crate::document) fn approx_eq(lhs: f64, rhs: f64) -> bool {
    (lhs - rhs).abs() <= GEOMETRY_EPSILON_MM
}

pub(in crate::document) fn clamp(value: f64, min: f64, max: f64) -> f64 {
    value.max(min).min(max)
}

pub(in crate::document) fn normalized_direction(anchor: Point2, target: Point2) -> Point2 {
    let dx = target.x_mm - anchor.x_mm;
    let dy = target.y_mm - anchor.y_mm;
    let length = dx.hypot(dy);
    if length <= GEOMETRY_EPSILON_MM {
        Point2::new(1.0, 0.0)
    } else {
        Point2::new(dx / length, dy / length)
    }
}

pub(in crate::document) fn align_direction(reference: Point2, current: Point2) -> Point2 {
    if dot_product(reference, current) < 0.0 {
        Point2::new(-reference.x_mm, -reference.y_mm)
    } else {
        reference
    }
}

pub(in crate::document) fn perpendicular_direction_closest_to(
    reference: Point2,
    current: Point2,
) -> Point2 {
    let candidate_a = Point2::new(-reference.y_mm, reference.x_mm);
    let candidate_b = Point2::new(reference.y_mm, -reference.x_mm);
    if dot_product(candidate_a, current) >= dot_product(candidate_b, current) {
        candidate_a
    } else {
        candidate_b
    }
}

pub(in crate::document) fn rotate_direction(direction: Point2, angle_rad: f64) -> Point2 {
    let cos_theta = angle_rad.cos();
    let sin_theta = angle_rad.sin();
    Point2::new(
        direction.x_mm * cos_theta - direction.y_mm * sin_theta,
        direction.x_mm * sin_theta + direction.y_mm * cos_theta,
    )
}

pub(in crate::document) fn dot_product(lhs: Point2, rhs: Point2) -> f64 {
    lhs.x_mm * rhs.x_mm + lhs.y_mm * rhs.y_mm
}

pub(in crate::document) fn mirror_point_across_line(
    point: Point2,
    axis_line: crate::geometry::LineSegment,
) -> Point2 {
    let axis_direction = normalized_direction(axis_line.start, axis_line.end);
    let axis_normal = Point2::new(-axis_direction.y_mm, axis_direction.x_mm);
    let relative = Point2::new(
        point.x_mm - axis_line.start.x_mm,
        point.y_mm - axis_line.start.y_mm,
    );
    let parallel_distance = dot_product(relative, axis_direction);
    let normal_distance = dot_product(relative, axis_normal);
    Point2::new(
        axis_line.start.x_mm + axis_direction.x_mm * parallel_distance
            - axis_normal.x_mm * normal_distance,
        axis_line.start.y_mm + axis_direction.y_mm * parallel_distance
            - axis_normal.y_mm * normal_distance,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::LineSegment;

    fn assert_point_close(actual: Point2, expected: Point2) {
        assert!(
            points_close(actual, expected),
            "expected {actual:?} to be close to {expected:?}"
        );
    }

    #[test]
    fn points_close_requires_both_coordinates_to_match() {
        assert!(points_close(Point2::new(1.0, 2.0), Point2::new(1.0, 2.0)));
        assert!(!points_close(Point2::new(1.0, 2.0), Point2::new(1.0, 2.1)));
        assert!(!points_close(Point2::new(1.0, 2.0), Point2::new(1.1, 2.0)));
    }

    #[test]
    fn angle_and_direction_helpers_keep_expected_orientation() {
        assert!(approx_eq(
            normalize_angle(std::f64::consts::PI * 1.5),
            -std::f64::consts::FRAC_PI_2
        ));
        assert!(approx_eq(
            normalize_angle(-std::f64::consts::PI * 1.5),
            std::f64::consts::FRAC_PI_2
        ));
        assert_point_close(
            align_direction(Point2::new(1.0, 0.0), Point2::new(-2.0, 0.0)),
            Point2::new(-1.0, 0.0),
        );
        assert_point_close(
            align_direction(Point2::new(1.0, 0.0), Point2::new(2.0, 0.0)),
            Point2::new(1.0, 0.0),
        );
        assert_point_close(
            perpendicular_direction_closest_to(Point2::new(1.0, 0.0), Point2::new(0.0, 3.0)),
            Point2::new(0.0, 1.0),
        );
        assert_point_close(
            perpendicular_direction_closest_to(Point2::new(1.0, 0.0), Point2::new(0.0, -3.0)),
            Point2::new(0.0, -1.0),
        );
        assert_point_close(
            rotate_direction(Point2::new(1.0, 0.0), std::f64::consts::FRAC_PI_2),
            Point2::new(0.0, 1.0),
        );
    }

    #[test]
    fn mirror_point_across_line_handles_vertical_and_diagonal_axes() {
        let vertical_axis = LineSegment::new(Point2::new(2.0, -10.0), Point2::new(2.0, 10.0));
        assert_point_close(
            mirror_point_across_line(Point2::new(5.0, 3.0), vertical_axis),
            Point2::new(-1.0, 3.0),
        );

        let diagonal_axis = LineSegment::new(Point2::new(0.0, 0.0), Point2::new(10.0, 10.0));
        assert_point_close(
            mirror_point_across_line(Point2::new(2.0, 5.0), diagonal_axis),
            Point2::new(5.0, 2.0),
        );
    }
}
