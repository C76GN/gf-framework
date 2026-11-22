//! Entropy-based tiled WFC. Directional masks and fixed cells arrive in GF declaration order.
use godot::builtin::{PackedFloat64Array, PackedInt32Array, PackedInt64Array};
use godot::prelude::*;
use std::collections::{HashMap, VecDeque};

const COMPLETE: i64 = -1;
const STEP_LIMIT: i64 = -2;

#[derive(GodotClass)]
#[class(init, internal, singleton)]
struct GfWfcEntropyBackend {}

#[godot_api]
impl GfWfcEntropyBackend {
    #[func]
    fn protocol_version(&self) -> i64 {
        1
    }

    // Empty rules permit every neighbor. An empty result requests the portable solver.
    // Otherwise the header contains steps and COMPLETE, STEP_LIMIT, or a contradiction cell.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn solve_entropy(
        &self,
        size: Vector2i,
        allowed: PackedInt64Array,
        weights: PackedFloat64Array,
        fixed: PackedInt32Array,
        seed: i64,
        max_steps: i64,
        periodic: bool,
    ) -> PackedInt64Array {
        solve(
            size,
            allowed.as_slice(),
            weights.as_slice(),
            fixed.as_slice(),
            seed as u32,
            max_steps,
            periodic,
        )
        .map(PackedInt64Array::from)
        .unwrap_or_default()
    }
}

fn draw(state: &mut u32) -> f64 {
    *state ^= *state << 13;
    *state ^= *state >> 17;
    *state ^= *state << 5;
    f64::from(*state) / 4294967296.0
}

// Each cell returns its low word followed by its high word for tilesets above 64 entries.
fn solve(
    size: Vector2i,
    packed_rules: &[i64],
    weights: &[f64],
    fixed: &[i32],
    seed: u32,
    limit: i64,
    periodic: bool,
) -> Option<Vec<i64>> {
    let width = usize::try_from(size.x).ok()?;
    let height = usize::try_from(size.y).ok()?;
    let count = width.checked_mul(height)?;
    let tiles = weights.len();
    if !(1..=4096).contains(&count) || !(1..=128).contains(&tiles) || limit < 1 {
        return None;
    }
    let words = tiles.div_ceil(64);
    if !packed_rules.is_empty() && packed_rules.len() != 4 * tiles * words {
        return None;
    }
    let all = u128::MAX >> (128 - tiles);
    let mut allowed = Vec::with_capacity(4 * tiles);
    for chunk in packed_rules.chunks_exact(words) {
        let mut mask = u128::from(chunk[0] as u64);
        if words == 2 {
            mask |= u128::from(chunk[1] as u64) << 64;
        }
        if mask & !all != 0 {
            return None;
        }
        allowed.push(mask);
    }
    let (fixed_cells, remainder) = fixed.as_chunks::<2>();
    if fixed_cells.len() > count
        || !remainder.is_empty()
        || weights.iter().any(|w| !w.is_finite() || *w <= 0.0)
    {
        return None;
    }
    let equal_weights = weights.iter().all(|w| *w == weights[0]);
    let mut uniform_entropies = [None; 129];
    let mut entropies = HashMap::new();
    // Zero marks a cell with no fixed assignment until initialization completes.
    let mut domains = vec![0; count];
    let mut steps = 0;
    let mut rng = if seed == 0 { 0x6d2b79f5 } else { seed };
    let mut queue = VecDeque::new();
    for &[cell, tile] in fixed_cells {
        let cell = usize::try_from(cell).ok()?;
        let tile = usize::try_from(tile).ok()?;
        if cell >= count || tile >= tiles || domains[cell] != 0 {
            return None;
        }
        domains[cell] = 1 << tile;
        queue.push_back(cell);
    }
    for domain in &mut domains {
        if *domain == 0 {
            *domain = all;
        }
    }
    if tiles == 1 {
        queue.clear();
        queue.extend(0..count);
    }

    loop {
        if let Some(cell) = propagate(&mut domains, &mut queue, &allowed, tiles, size, periodic) {
            return Some(pack_result(&domains, words, steps, cell as i64));
        }
        let mut selected = None;
        let mut best_score = f64::INFINITY;
        let mut best_tie = f64::INFINITY;
        for (cell, &domain) in domains.iter().enumerate() {
            if domain.count_ones() <= 1 {
                continue;
            }
            let score = if equal_weights {
                *uniform_entropies[domain.count_ones() as usize]
                    .get_or_insert_with(|| entropy(domain, weights))
            } else {
                *entropies
                    .entry(domain)
                    .or_insert_with(|| entropy(domain, weights))
            };
            if !score.is_finite() {
                return None;
            }
            let tie = draw(&mut rng);
            if score < best_score
                || ((score == best_score || godot::global::is_equal_approx(score, best_score))
                    && tie < best_tie)
            {
                selected = Some(cell);
                best_score = score;
                best_tie = tie;
            }
        }
        let Some(cell) = selected else {
            return Some(pack_result(&domains, words, steps, COMPLETE));
        };
        if steps >= limit {
            return Some(pack_result(&domains, words, steps, STEP_LIMIT));
        }
        domains[cell] = choose_tile(domains[cell], weights, &mut rng);
        steps += 1;
        queue.push_back(cell);
    }
}

fn propagate(
    domains: &mut [u128],
    queue: &mut VecDeque<usize>,
    allowed: &[u128],
    tiles: usize,
    size: Vector2i,
    periodic: bool,
) -> Option<usize> {
    if allowed.is_empty() {
        queue.clear();
        return None;
    }
    while let Some(cell) = queue.pop_front() {
        for (dir, neighbor) in neighbors(cell, size, periodic).into_iter().enumerate() {
            let Some(neighbor) = neighbor else { continue };
            let mut candidates = domains[cell];
            let mut permitted = 0;
            while candidates != 0 {
                let tile = candidates.trailing_zeros() as usize;
                permitted |= allowed[dir * tiles + tile];
                candidates &= candidates - 1;
            }
            let reduced = domains[neighbor] & permitted;
            if reduced != domains[neighbor] {
                domains[neighbor] = reduced;
                if reduced == 0 {
                    return Some(neighbor);
                }
                queue.push_back(neighbor);
            }
        }
    }
    None
}

fn choose_tile(domain: u128, weights: &[f64], rng: &mut u32) -> u128 {
    let choices = || {
        weights
            .iter()
            .enumerate()
            .filter(|(i, _)| domain & (1 << i) != 0)
    };
    let mut total: f64 = choices().map(|(_, w)| w).sum();
    let mut scale = 1.0;
    if !total.is_finite() {
        scale = choices().map(|(_, w)| *w).fold(0.0, f64::max);
        total = choices().map(|(_, w)| w / scale).sum();
    }
    let threshold = draw(rng) * total;
    let mut cumulative = 0.0;
    for (tile, &weight) in weights.iter().enumerate() {
        if domain & (1 << tile) != 0 {
            cumulative += weight / scale;
            if cumulative >= threshold {
                return 1 << tile;
            }
        }
    }
    1 << domain.trailing_zeros()
}

fn pack_result(domains: &[u128], words: usize, steps: i64, outcome: i64) -> Vec<i64> {
    let mut packed = Vec::with_capacity(2 + domains.len() * words);
    packed.extend([steps, outcome]);
    for &domain in domains {
        packed.push(domain as i64);
        if words == 2 {
            packed.push((domain >> 64) as i64);
        }
    }
    packed
}

fn entropy(domain: u128, weights: &[f64]) -> f64 {
    let mut sum = 0.0;
    let mut weighted_log = 0.0;
    for (tile, &weight) in weights.iter().enumerate() {
        if domain & (1 << tile) != 0 {
            sum += weight;
            weighted_log += weight * godot::global::log(weight);
        }
    }
    if !sum.is_finite() || !weighted_log.is_finite() {
        let maximum = weights
            .iter()
            .enumerate()
            .filter(|(i, _)| domain & (1 << i) != 0)
            .map(|(_, w)| *w)
            .fold(0.0, f64::max);
        sum = 0.0;
        weighted_log = 0.0;
        for (tile, &weight) in weights.iter().enumerate() {
            if domain & (1 << tile) != 0 {
                let scaled = weight / maximum;
                sum += scaled;
                weighted_log += scaled * godot::global::log(scaled);
            }
        }
    }
    godot::global::log(sum) - weighted_log / sum
}

// Right, left, down, up. Equal-cost ties in GF's queue preserve insertion order.
fn neighbors(cell: usize, size: Vector2i, periodic: bool) -> [Option<usize>; 4] {
    let width = size.x as usize;
    let x = (cell % width) as i32;
    let y = (cell / width) as i32;
    [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)].map(|(nx, ny)| {
        if periodic {
            Some(ny.rem_euclid(size.y) as usize * width + nx.rem_euclid(size.x) as usize)
        } else if (0..size.x).contains(&nx) && (0..size.y).contains(&ny) {
            Some(ny as usize * width + nx as usize)
        } else {
            None
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn packs_both_high_bits_in_declaration_order() {
        assert_eq!(
            solve(
                Vector2i::new(2, 1),
                &[],
                &[1.0; 128],
                &[0, 63, 1, 127],
                0,
                1,
                false
            ),
            Some(vec![0, COMPLETE, i64::MIN, 0, 0, i64::MIN])
        );
    }

    #[test]
    fn propagates_singletons_before_completing_or_checking_the_step_budget() {
        assert_eq!(
            solve(Vector2i::new(1, 2), &[1, 1, 0, 0], &[1.0], &[], 0, 1, false),
            Some(vec![0, 1, 1, 0])
        );
        assert_eq!(
            solve(Vector2i::ONE, &[], &[1.0], &[], 0, 1, true),
            Some(vec![0, COMPLETE, 1])
        );
    }

    #[test]
    fn declines_unsupported_sizes_and_malformed_packed_inputs() {
        assert!(
            solve(
                Vector2i::new(2, 1),
                &[],
                &[1.0, 1.0],
                &[0, 0, 0, 1],
                0,
                1,
                false
            )
            .is_none()
        );
        assert!(solve(Vector2i::new(4097, 1), &[], &[1.0], &[], 0, 1, false).is_none());
        assert!(solve(Vector2i::ONE, &[], &[1.0; 129], &[], 0, 1, false).is_none());
        assert!(solve(Vector2i::ONE, &[], &[f64::NAN], &[], 0, 1, false).is_none());
        assert!(solve(Vector2i::ONE, &[2; 4], &[1.0], &[], 0, 1, false).is_none());
        assert!(solve(Vector2i::ONE, &[], &[1.0], &[0], 0, 1, false).is_none());
        assert!(solve(Vector2i::ONE, &[], &[1.0], &[0, 1], 0, 1, false).is_none());
    }
}
