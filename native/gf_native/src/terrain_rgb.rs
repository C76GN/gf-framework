//! Decode the RGB channels of the base mip level into independent height samples.
use godot::builtin::{PackedByteArray, PackedFloat32Array, VarArray};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfTerrainRgbBackend {}

#[godot_api]
impl GfTerrainRgbBackend {
    #[func]
    fn protocol_version(&self) -> i64 {
        1
    }

    // Protocol 1 returns [samples, minimum, maximum]. An empty result tells GF to use
    // its portable decoder, which owns the public diagnostic for the first invalid pixel.
    #[func]
    fn decode(
        &self,
        pixels: PackedByteArray,
        size: Vector2i,
        stride: i64,
        scale: f64,
        offset: f64,
    ) -> VarArray {
        if size.x <= 0 || size.y <= 0 || !matches!(stride, 3 | 4) {
            return VarArray::new();
        }
        let stride = stride as usize;
        let Some(count) = (size.x as usize).checked_mul(size.y as usize) else {
            return VarArray::new();
        };
        let Some(base_bytes) = count.checked_mul(stride) else {
            return VarArray::new();
        };
        let Some(base) = pixels.as_slice().get(..base_bytes) else {
            return VarArray::new();
        };
        if !scale.is_finite() || !offset.is_finite() {
            return VarArray::new();
        }
        let mut samples = PackedFloat32Array::new();
        samples.resize(count);
        let Some((minimum, maximum)) =
            decode_base(base, stride, scale, offset, samples.as_mut_slice())
        else {
            return VarArray::new();
        };
        varray![
            &samples.to_variant(),
            &minimum.to_variant(),
            &maximum.to_variant()
        ]
    }
}

fn decode_base(
    bytes: &[u8],
    stride: usize,
    scale: f64,
    offset: f64,
    samples: &mut [f32],
) -> Option<(f32, f32)> {
    let mut minimum = f32::INFINITY;
    let mut maximum = f32::NEG_INFINITY;
    for (rgb, sample) in bytes.chunks_exact(stride).zip(samples) {
        let encoded = u32::from_be_bytes([0, rgb[0], rgb[1], rgb[2]]);
        *sample = ((-10000.0 + f64::from(encoded) * 0.1) * scale + offset) as f32;
        if !sample.is_finite() {
            return None;
        }
        minimum = minimum.min(*sample);
        maximum = maximum.max(*sample);
    }
    Some((minimum, maximum))
}

#[cfg(test)]
mod tests {
    use super::decode_base;

    #[test]
    fn ignores_alpha_and_computes_extrema_after_scaling() {
        let mut result = [0.0; 2];
        assert_eq!(
            decode_base(&[0, 0, 0, 240, 1, 134, 160, 19], 4, -0.5, 1.0, &mut result),
            Some((1.0, 5001.0))
        );
        assert_eq!(result, [5001.0, 1.0]);
    }

    #[test]
    fn rejects_overflow_after_a_valid_pixel() {
        let mut result = [0.0; 2];
        assert_eq!(
            decode_base(&[1, 134, 160, 255, 255, 255], 3, 1e35, 0.0, &mut result),
            None
        );
    }
}
