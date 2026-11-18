//! Native capabilities shipped together in the optional GF platform addon.
use godot::prelude::*;

mod packed_gather;

struct GfNative;

// SAFETY: Each module registers its engine API through godot-rust.
#[gdextension]
unsafe impl ExtensionLibrary for GfNative {}
