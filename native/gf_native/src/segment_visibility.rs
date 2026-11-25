//! 根据 GFSegmentVisibility2D 的整数拓扑计算每对点的可见层。预算在分配输出之前校验。
use godot::prelude::*;

pub(crate) mod binding;

type Point = [i32; 2];
const MAX_COORDINATE: i32 = (1 << 30) - 1;
const MAX_POINTS: usize = 2048;
const MAX_SEGMENTS: usize = 4096;
const MAX_PAIRS: usize = 262_144;
const MAX_SEGMENT_TESTS: usize = 1_048_576;

#[derive(GodotClass)]
#[class(no_init, internal, base=RefCounted)]
struct GfSegmentVisibilityBackend {}

/// 一次同步调用借用的拓扑。坐标差、点对数和相交测试数均已经 `admit` 校验。
struct Topology<'a> {
    points: &'a [Point],
    segments: &'a [[i32; 6]],
    blocked: &'a [i64],
    valid_mask: i64,
    pair_count: usize,
}

impl<'a> Topology<'a> {
    /// 校验各列长度、具名端点及掩码所属层，超出几何或工作量上限时返回 `None`。
    fn admit(
        xy: &'a [i32],
        raw_segments: &'a [i32],
        blocked: &'a [i64],
        valid_mask: i64,
    ) -> Option<Self> {
        let (points, xy_tail) = xy.as_chunks::<2>();
        let (segments, segment_tail) = raw_segments.as_chunks::<6>();
        if !xy_tail.is_empty()
            || !segment_tail.is_empty()
            || points.len() > MAX_POINTS
            || segments.len() > MAX_SEGMENTS
            || segments.len() != blocked.len()
            || valid_mask < 0
        {
            return None;
        }
        let pair_count = points.len() * points.len().saturating_sub(1) / 2;
        if pair_count > MAX_PAIRS
            || pair_count * segments.len() > MAX_SEGMENT_TESTS
            || !xy.iter().all(in_bounds)
        {
            return None;
        }
        for (&[cx, cy, dx, dy, start, end], &mask) in segments.iter().zip(blocked) {
            if mask & !valid_mask != 0
                || ![cx, cy, dx, dy].iter().all(in_bounds)
                || !endpoint_matches(points, start, [cx, cy])
                || !endpoint_matches(points, end, [dx, dy])
            {
                return None;
            }
        }
        Some(Self {
            points,
            segments,
            blocked,
            valid_mask,
            pair_count,
        })
    }

    /// 按 `(i, j)` 的字典序写入 `i < j` 的点对。调用者须提供至少 `pair_count` 个槽位。
    fn fill(&self, output: &mut [i64]) {
        let mut index = 0;
        for (i, &a) in self.points.iter().enumerate() {
            for j in i + 1..self.points.len() {
                let b = self.points[j];
                let mut mask = self.valid_mask;
                for (&[cx, cy, dx, dy, start, end], &blocked) in
                    self.segments.iter().zip(self.blocked)
                {
                    if mask & blocked == 0 {
                        continue;
                    }
                    let named = start == i as i32
                        || end == i as i32
                        || start == j as i32
                        || end == j as i32;
                    if obstructs(a, b, [cx, cy], [dx, dy], named) {
                        mask &= !blocked;
                        if mask == 0 {
                            break;
                        }
                    }
                }
                output[index] = mask;
                index += 1;
            }
        }
    }
}

fn in_bounds(value: &i32) -> bool {
    (-MAX_COORDINATE..=MAX_COORDINATE).contains(value)
}

fn endpoint_matches(points: &[Point], row: i32, position: Point) -> bool {
    row == -1 || usize::try_from(row).ok().and_then(|i| points.get(i)) == Some(&position)
}

fn orientation(a: Point, b: Point, c: Point) -> i64 {
    // 设坐标绝对值上限为 B，坐标差至多 2B，两个乘积之差至多 8B²，仍可用 i64 表示。
    i64::from(b[0] - a[0]) * i64::from(c[1] - a[1])
        - i64::from(b[1] - a[1]) * i64::from(c[0] - a[0])
}

fn same_side(left: i64, right: i64) -> bool {
    left > 0 && right > 0 || left < 0 && right < 0
}

/// 相交时仅放行具名端点的单点接触。共线且重叠长度大于零时，即使共用端点也会遮挡。
fn obstructs(a: Point, b: Point, c: Point, d: Point, named_contact: bool) -> bool {
    let low_x = a[0].min(b[0]).max(c[0].min(d[0]));
    let high_x = a[0].max(b[0]).min(c[0].max(d[0]));
    let low_y = a[1].min(b[1]).max(c[1].min(d[1]));
    let high_y = a[1].max(b[1]).min(c[1].max(d[1]));
    if low_x > high_x || low_y > high_y {
        return false;
    }
    let abc = orientation(a, b, c);
    let abd = orientation(a, b, d);
    if same_side(abc, abd) || same_side(orientation(c, d, a), orientation(c, d, b)) {
        return false;
    }
    !named_contact || (abc == 0 && abd == 0 && (low_x < high_x || low_y < high_y))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_example_and_independent_anonymous_endpoints() {
        let points = [0, 0, 0, 3, 2, 0, -2, 0, 0, 1];
        for (segments, masks, expected) in [
            (
                vec![0, 0, 0, 3, 0, 1],
                vec![6],
                [1, 7, 7, 1, 7, 7, 1, 1, 1, 1],
            ),
            (vec![0, 0, 0, 3, -1, -1], vec![7], [0; 10]),
        ] {
            let topology = Topology::admit(&points, &segments, &masks, 7).unwrap();
            let mut rows = [0; 10];
            topology.fill(&mut rows);
            assert_eq!(rows, expected);
        }
    }

    #[test]
    fn checked_bounds_and_exact_degeneracies() {
        let b = MAX_COORDINATE;
        assert_eq!(orientation([0, 0], [b, b - 1], [b - 1, b - 2]), -1);
        assert!(obstructs([-b, -b], [b, b], [-b, b], [b, -b], false));
        assert!(!obstructs(
            [0, 0],
            [b, b - 1],
            [b - 1, b - 2],
            [b - 1, b - 2],
            false
        ));
        assert!(!obstructs([0, 0], [1, 1], [2, 2], [3, 3], false));
        assert!(!obstructs([0, 0], [2, 2], [0, 0], [0, 0], true));
        assert!(obstructs([0, 0], [2, 2], [0, 0], [0, 0], false));
        assert!(obstructs([0, 0], [2, 2], [0, 0], [1, 1], true));
    }

    #[test]
    fn rejects_invalid_raw_columns_and_excessive_work_before_allocation() {
        assert!(Topology::admit(&[], &[], &[], 0).is_some());
        assert!(Topology::admit(&[0], &[], &[], 1).is_none());
        assert!(Topology::admit(&[i32::MIN, 0], &[], &[], 1).is_none());
        assert!(Topology::admit(&[], &[0], &[], 1).is_none());
        assert!(Topology::admit(&[], &[0; 6], &[], 1).is_none());
        assert!(Topology::admit(&[], &[], &[], -1).is_none());
        for (segment, mask) in [
            ([0, 0, 1, 1, -1, -2], 1),
            ([0, 0, 1, 1, -1, 1], 1),
            ([0, 0, 1, 1, -1, 0], 1),
            ([0, 0, 1, 1, -1, -1], 2),
            ([i32::MAX, 0, 1, 1, -1, -1], 1),
            ([0, 0, 1, 1, -1, -1], -1),
        ] {
            assert!(Topology::admit(&[0, 0], &segment, &[mask], 1).is_none());
        }
        assert!(Topology::admit(&vec![0; 2 * MAX_POINTS], &[], &[], 1).is_none());
        assert!(Topology::admit(&[0; 2 * 100], &vec![-1; 6 * 300], &vec![0; 300], 1).is_none());
    }
}
