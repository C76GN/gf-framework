## 用于验证架构级 Model 序列化/恢复的稳定脚本资源。
extends GFModel


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

var volume: float = 1.0


# --- 公共方法 ---

func get_save_key() -> StringName:
	return &"test_settings_model_fixture"


func to_dict() -> Dictionary:
	return {
		"volume": volume,
	}


func from_dict(data: Dictionary) -> void:
	volume = _GF_VARIANT_ACCESS_SCRIPT.get_option_float(data, "volume", 1.0)
