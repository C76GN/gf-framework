//! GF 可选原生插件的加载入口。各后端共用同一个 Godot 扩展生命周期。
use godot::prelude::*;

mod packed_gather;
mod row_match;
mod segment_visibility;
mod terrain_rgb;
mod wfc_entropy;

/// Embeds redistribution notices in the shared library, including stripped release builds.
#[unsafe(no_mangle)]
pub static GF_NATIVE_LICENSE_NOTICES: [u8; include_bytes!(concat!(
    env!("OUT_DIR"),
    "/notices.txt"
))
.len()] = *include_bytes!(concat!(env!("OUT_DIR"), "/notices.txt"));

struct GfNative;

// SAFETY: Godot 在主线程依次调用场景级初始化与卸载，绑定只在这两个回调中发布或撤回。
#[gdextension(entry_symbol = gf_native_init)]
unsafe impl ExtensionLibrary for GfNative {
    fn on_stage_init(stage: InitStage) {
        if stage == InitStage::Scene {
            segment_visibility::binding::register();
        }
    }

    fn on_stage_deinit(stage: InitStage) {
        if stage == InitStage::Scene {
            segment_visibility::binding::unregister();
        }
    }
}
