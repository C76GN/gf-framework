//! Native capabilities shipped together in the optional GF platform addon.
use godot::prelude::*;

mod packed_gather;
mod row_match;
mod terrain_rgb;
mod wfc_entropy;

// A public data symbol keeps the licenses in stripped shared libraries on every target.
#[unsafe(no_mangle)]
pub static GF_NATIVE_LICENSE_NOTICES: [u8; include_bytes!(concat!(
    env!("OUT_DIR"),
    "/notices.txt"
))
.len()] = *include_bytes!(concat!(env!("OUT_DIR"), "/notices.txt"));

struct GfNative;

// SAFETY: Each module registers its engine API through godot-rust.
#[gdextension(entry_symbol = gf_native_init)]
unsafe impl ExtensionLibrary for GfNative {}
