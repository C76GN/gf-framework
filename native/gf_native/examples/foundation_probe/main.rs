//! Benchmark-only GDExtension. This example is never linked into gf_native.dll.
use godot::builtin::{PackedByteArray, PackedInt32Array};
use godot::prelude::*;
use std::collections::VecDeque;

struct FoundationProbe;

// SAFETY: Registration is handled by godot-rust and only happens in the private probe project.
#[gdextension]
unsafe impl ExtensionLibrary for FoundationProbe {}

#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfFoundationProbe {}

#[godot_api]
impl GfFoundationProbe {
    #[func]
    fn flow(
        &self,
        size: Vector2i,
        passable: PackedByteArray,
        goals: PackedInt32Array,
    ) -> PackedInt32Array {
        let Some(count) = cell_count(size) else {
            return PackedInt32Array::new();
        };
        let mask = passable.as_slice();
        if mask.len() != count {
            return PackedInt32Array::new();
        }
        // Store the next cell on the path. Distances follow in the second half.
        let mut result = PackedInt32Array::new();
        result.resize(count * 2);
        let (next, distance) = result.as_mut_slice().split_at_mut(count);
        distance.fill(-1);
        next.fill(-1);
        let mut queue = VecDeque::new();
        for &goal in goals.as_slice() {
            if let Ok(cell) = usize::try_from(goal)
                && cell < count
                && mask[cell] != 0
                && distance[cell] < 0
            {
                distance[cell] = 0;
                next[cell] = goal;
                queue.push_back(cell);
            }
        }
        while let Some(cell) = queue.pop_front() {
            for neighbor in neighbors(cell, size).into_iter().flatten() {
                if mask[neighbor] != 0 && distance[neighbor] < 0 {
                    next[neighbor] = cell as i32;
                    distance[neighbor] = distance[cell] + 1;
                    queue.push_back(neighbor);
                }
            }
        }
        result
    }
}

fn cell_count(size: Vector2i) -> Option<usize> {
    let width = usize::try_from(size.x).ok()?;
    let height = usize::try_from(size.y).ok()?;
    let count = width.checked_mul(height)?;
    (1..=1_048_576).contains(&count).then_some(count)
}

// Right, left, down, up. Equal-cost ties in GF's queue preserve insertion order.
fn neighbors(cell: usize, size: Vector2i) -> [Option<usize>; 4] {
    let width = size.x as usize;
    let x = (cell % width) as i32;
    let y = (cell / width) as i32;
    [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)].map(|(nx, ny)| {
        if (0..size.x).contains(&nx) && (0..size.y).contains(&ny) {
            Some(ny as usize * width + nx as usize)
        } else {
            None
        }
    })
}
