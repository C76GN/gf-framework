//! Synchronous, allocation-bounded numeric gather. GF owns admission and publication.
use godot::builtin::{Array, PackedInt32Array, PackedInt64Array, Variant, VariantType};
use godot::prelude::*;

// The public API is the GF adapter. The editor must not generate ClassDB docs
// for this implementation during first import (godotengine/godot#111048).
#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfPackedGatherBackend {}

#[godot_api]
impl GfPackedGatherBackend {
    #[func]
    fn protocol_version(&self) -> i64 {
        1
    }

    #[func]
    fn gather(
        &self,
        columns: Array<Variant>,
        selection: PackedInt32Array,
        source_count: i64,
    ) -> Array<Variant> {
        let Ok(count) = usize::try_from(source_count) else {
            return Array::new();
        };
        let indices = selection.as_slice();
        if indices
            .iter()
            .any(|&index| index < 0 || index as usize >= count)
        {
            return Array::new();
        }
        // Validate the entire call before allocating any output column.
        for column in columns.iter_shared() {
            let valid = match column.get_type() {
                VariantType::PACKED_INT32_ARRAY => column
                    .try_to::<PackedInt32Array>()
                    .is_ok_and(|values| values.len() >= count),
                VariantType::PACKED_INT64_ARRAY => column
                    .try_to::<PackedInt64Array>()
                    .is_ok_and(|values| values.len() >= count),
                _ => false,
            };
            if !valid {
                return Array::new();
            }
        }
        let mut result = Array::new();
        for column in columns.iter_shared() {
            match column.get_type() {
                VariantType::PACKED_INT32_ARRAY => {
                    let Ok(input) = column.try_to::<PackedInt32Array>() else {
                        return Array::new();
                    };
                    let mut output = PackedInt32Array::new();
                    output.resize(indices.len());
                    if !gather_into(input.as_slice(), indices, output.as_mut_slice(), count) {
                        return Array::new();
                    }
                    result.push(&output.to_variant());
                }
                VariantType::PACKED_INT64_ARRAY => {
                    let Ok(input) = column.try_to::<PackedInt64Array>() else {
                        return Array::new();
                    };
                    let mut output = PackedInt64Array::new();
                    output.resize(indices.len());
                    if !gather_into(input.as_slice(), indices, output.as_mut_slice(), count) {
                        return Array::new();
                    }
                    result.push(&output.to_variant());
                }
                _ => return Array::new(),
            }
        }
        result
    }
}

/// Validate all indices before touching the destination; no unchecked indexing or scratch vector.
fn gather_into<T: Copy>(input: &[T], indices: &[i32], output: &mut [T], count: usize) -> bool {
    if count > input.len()
        || output.len() != indices.len()
        || indices
            .iter()
            .any(|&index| index < 0 || index as usize >= count)
    {
        return false;
    }
    for (destination, &source) in output.iter_mut().zip(indices) {
        *destination = input[source as usize];
    }
    true
}

#[cfg(test)]
mod tests {
    use super::gather_into;

    #[test]
    fn preserves_extreme_i64_values_order_and_duplicates() {
        let input = [i64::MIN, 0, i64::MAX];
        let mut output = [0; 4];
        assert!(gather_into(&input, &[2, 0, 2, 1], &mut output, 3));
        assert_eq!(output, [i64::MAX, i64::MIN, i64::MAX, 0]);
    }

    #[test]
    fn failures_leave_destination_untouched_and_use_count_not_capacity() {
        for indices in [[0, -1], [0, 2], [0, i32::MAX]] {
            let mut output = [71, 72];
            assert!(!gather_into(&[1, 2, 999], &indices, &mut output, 2));
            assert_eq!(output, [71, 72]);
        }
        assert!(!gather_into(&[1], &[0], &mut [9], 2));
        assert!(!gather_into(&[1], &[0], &mut [], 1));
        assert!(gather_into::<i32>(&[], &[], &mut [], 0));
    }

    #[test]
    fn deterministic_selections_match_reference_for_both_integer_widths() {
        let input: Vec<i32> = (0..257).map(|n| n * 17 - 200).collect();
        let wide: Vec<i64> = input
            .iter()
            .map(|&n| i64::from(n) + (1_i64 << 60))
            .collect();
        let indices: Vec<i32> = (0..1000).map(|n| (n * 131 + 11) % 257).collect();
        let mut narrow_result = vec![0; indices.len()];
        let mut wide_result = vec![0; indices.len()];
        assert!(gather_into(
            &input,
            &indices,
            &mut narrow_result,
            input.len()
        ));
        assert!(gather_into(&wide, &indices, &mut wide_result, wide.len()));
        for (offset, &index) in indices.iter().enumerate() {
            assert_eq!(narrow_result[offset], input[index as usize]);
            assert_eq!(wide_result[offset], wide[index as usize]);
        }
    }
}
