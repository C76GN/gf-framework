//! 独立基准工程使用的 GDExtension，用同样的格子与目标队列测量原生寻路开销。
use godot::builtin::{PackedByteArray, PackedInt32Array};
use godot::prelude::*;
use std::collections::VecDeque;

struct FoundationProbe;

// SAFETY: 扩展注册完全由 godot-rust 管理，此探针仅由隔离的基准工程加载。
#[gdextension]
unsafe impl ExtensionLibrary for FoundationProbe {}

#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfFoundationProbe {}

#[godot_api]
impl GfFoundationProbe {
    /// 从有效目标向外搜索，依次返回每格的下一步和到达目标的步数，两列均按行排列。
    /// 不可达的格子填 `-1`。网格尺寸或掩码长度无效时返回空数组。
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
        // 两列共用一次分配，前半存下一步格号，后半存距目标的步数，未到达的格子两列均为 -1。
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

/// 按右、左、下、上访问相邻格。同长路径由队列入队顺序决定，基准与脚本须使用同一顺序。
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
