//! 将当前批次的 64 位稳定 ID 映射到前一批次的行号。仅借用有效行，预留容量不参与匹配。
use std::collections::HashMap;

use godot::builtin::{PackedInt32Array, PackedInt64Array, Variant};
use godot::global::Error;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfDataBatchRowMatchBackend {}

#[godot_api]
impl GfDataBatchRowMatchBackend {
    #[func]
    fn protocol_version(&self) -> i64 {
        1
    }

    /// 成功时转交 `PackedInt32Array`，零行也是成功。失败时返回 Godot 错误码。
    #[func]
    fn match_ids(
        &self,
        previous_ids: PackedInt64Array,
        previous_count: i64,
        current_ids: PackedInt64Array,
        current_count: i64,
    ) -> Variant {
        let (Some(previous), Some(current)) = (
            prefix(previous_ids.as_slice(), previous_count),
            prefix(current_ids.as_slice(), current_count),
        ) else {
            return Error::ERR_INVALID_PARAMETER.to_variant();
        };
        let mut rows = PackedInt32Array::new();
        rows.resize(current.len());
        if rows.len() != current.len() {
            return Error::ERR_OUT_OF_MEMORY.to_variant();
        }
        match match_into(previous, current, rows.as_mut_slice()) {
            Ok(()) => rows.to_variant(),
            Err(error) => error.to_variant(),
        }
    }
}

/// 借用恰好 `count` 个 ID。行数超出 i32 索引范围或实际存储长度时返回 `None`。
fn prefix(ids: &[i64], count: i64) -> Option<&[i64]> {
    let count = i32::try_from(count).ok()?;
    ids.get(..usize::try_from(count).ok()?)
}

/// 为当前批次按行写入旧行号，新 ID 写入 `-1`。调用者为每个当前 ID 提供一个输出槽。
///
/// # Errors
///
/// 任一批次出现重复 ID，或哈希表无法预留空间时返回错误。错误发生前可能已写入部分行。
fn match_into(previous: &[i64], current: &[i64], rows: &mut [i32]) -> Result<(), Error> {
    if previous.is_sorted_by(|a, b| a < b) && current.is_sorted_by(|a, b| a < b) {
        let mut old_row = 0;
        for (&id, row) in current.iter().zip(rows) {
            while old_row < previous.len() && previous[old_row] < id {
                old_row += 1;
            }
            *row = if previous.get(old_row) == Some(&id) {
                old_row as i32
            } else {
                -1
            };
        }
        return Ok(());
    }

    const SEEN_CURRENT: i32 = -2;
    let mut by_id = HashMap::new();
    by_id
        .try_reserve(previous.len())
        .map_err(|_| Error::ERR_OUT_OF_MEMORY)?;
    for (row, &id) in previous.iter().enumerate() {
        if by_id.insert(id, row as i32).is_some() {
            return Err(Error::ERR_INVALID_DATA);
        }
    }
    for (&id, row) in current.iter().zip(rows) {
        if let Some(slot) = by_id.get_mut(&id) {
            if *slot == SEEN_CURRENT {
                return Err(Error::ERR_INVALID_DATA);
            }
            *row = std::mem::replace(slot, SEEN_CURRENT);
        } else {
            by_id.try_reserve(1).map_err(|_| Error::ERR_OUT_OF_MEMORY)?;
            by_id.insert(id, SEEN_CURRENT);
            *row = -1;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checks_counts_before_slicing() {
        let ids = [i64::MAX, i64::MIN];
        for invalid in [-1, 3, i64::from(i32::MAX) + 1, i64::MAX] {
            assert_eq!(prefix(&ids, invalid), None);
        }
        assert_eq!(prefix(&ids, 0), Some(&ids[..0]));
        assert_eq!(prefix(&ids, 1), Some(&ids[..1]));
    }

    #[test]
    fn unordered_and_sorted_inputs_match_independent_linear_search() {
        let ids = [i64::MIN, -2, -1, 0, 1, 1_i64 << 60, i64::MAX];
        for previous_mask in 0..128 {
            let previous: Vec<i64> = (0..7)
                .filter(|i| previous_mask & (1 << i) != 0)
                .map(|i| ids[i])
                .collect();
            for current_mask in 0..128 {
                let mut current: Vec<i64> = (0..7)
                    .filter(|i| current_mask & (1 << i) != 0)
                    .map(|i| ids[i])
                    .collect();
                for _ in 0..2 {
                    let expected: Vec<i32> = current
                        .iter()
                        .map(|id| {
                            previous
                                .iter()
                                .position(|old| old == id)
                                .map_or(-1, |row| row as i32)
                        })
                        .collect();
                    let mut rows = vec![-2; current.len()];
                    assert_eq!(match_into(&previous, &current, &mut rows), Ok(()));
                    assert_eq!(rows, expected);
                    current.reverse();
                }
            }
        }
    }

    #[test]
    fn rejects_an_ambiguous_column_even_when_the_other_side_is_empty() {
        for (previous, current) in [
            (&[1, 2, 1][..], &[][..]),
            (&[][..], &[3, 1, 3][..]),
            (&[1, 1][..], &[1][..]),
            (&[1, 2][..], &[1, 2, 1][..]),
        ] {
            assert_eq!(
                match_into(previous, current, &mut vec![0; current.len()]),
                Err(Error::ERR_INVALID_DATA)
            );
        }
    }
}
