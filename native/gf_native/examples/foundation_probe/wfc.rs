//! Bounded benchmark for explicit directional rules and positive, finite tile weights.
use super::{cell_count, neighbors};
use godot::builtin::Vector2i;
use std::collections::{HashMap, VecDeque};

fn draw(state: &mut u32) -> f64 {
    *state ^= *state << 13;
    *state ^= *state >> 17;
    *state ^= *state << 5;
    f64::from(*state) / 4294967296.0
}

// The header is (steps taken, contradiction cell or -1). Remaining entries are domain masks.
pub(super) fn solve(
    size: Vector2i,
    allowed: &[i32],
    weights: &[f64],
    fixed: &[i32],
    seed: u32,
    limit: i64,
    periodic: bool,
) -> Option<Vec<i32>> {
    let count = cell_count(size)?;
    let tiles = allowed.len() / 4;
    if count > 4096 || !(1..=30).contains(&tiles) || allowed.len() != 4 * tiles || limit < 1 {
        return None;
    }
    let (fixed_cells, remainder) = fixed.as_chunks::<2>();
    if weights.len() != tiles
        || weights.iter().any(|w| !w.is_finite() || *w <= 0.0)
        || !remainder.is_empty()
    {
        return None;
    }
    let equal_weights = weights.iter().all(|w| *w == weights[0]);
    let mut entropies = HashMap::new();
    let all = (1_i32 << tiles) - 1;
    if allowed.iter().any(|&mask| mask < 0 || mask & !all != 0) {
        return None;
    }
    let mut result = vec![all; count + 2];
    let (header, domains) = result.split_at_mut(2);
    header.copy_from_slice(&[0, -1]);
    let mut rng = if seed == 0 { 0x6d2b79f5 } else { seed };
    let mut queue = VecDeque::new();
    for &[cell, tile] in fixed_cells {
        let cell = usize::try_from(cell).ok()?;
        let tile = usize::try_from(tile).ok()?;
        if cell >= count || tile >= tiles {
            return None;
        }
        domains[cell] = 1 << tile;
        queue.push_back(cell);
    }
    if tiles == 1 {
        queue.clear();
        queue.extend(0..count);
    }

    loop {
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
                        header[1] = neighbor as i32;
                        return Some(result);
                    }
                    queue.push_back(neighbor);
                }
            }
        }
        if i64::from(header[0]) >= limit {
            break;
        }
        let mut selected = None;
        let mut best_score = f64::INFINITY;
        let mut best_tie = f64::INFINITY;
        for (cell, &domain) in domains.iter().enumerate() {
            if domain.count_ones() <= 1 {
                continue;
            }
            // For equal weights entropy is monotonic in the number of candidates.
            let score = if equal_weights {
                f64::from(domain.count_ones())
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
        let Some(cell) = selected else { break };
        let domain = domains[cell];
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
        let threshold = draw(&mut rng) * total;
        let mut cumulative = 0.0;
        for (tile, &weight) in weights.iter().enumerate() {
            if domain & (1 << tile) != 0 {
                cumulative += weight / scale;
                if cumulative >= threshold {
                    domains[cell] = 1 << tile;
                    break;
                }
            }
        }
        header[0] += 1;
        queue.push_back(cell);
    }
    Some(result)
}

fn entropy(domain: i32, weights: &[f64]) -> f64 {
    let mut sum = 0.0;
    let mut weighted_log = 0.0;
    for (tile, &weight) in weights.iter().enumerate() {
        if domain & (1 << tile) != 0 {
            sum += weight;
            weighted_log += weight * weight.ln();
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
                weighted_log += scaled * scaled.ln();
            }
        }
    }
    sum.ln() - weighted_log / sum
}
