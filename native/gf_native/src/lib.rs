//! Native capabilities shipped together in the optional GF platform addon.
use godot::prelude::*;

mod packed_gather;
mod terrain_rgb;

struct GfNative;

// SAFETY: Each module registers its engine API through godot-rust.
#[gdextension]
unsafe impl ExtensionLibrary for GfNative {}
