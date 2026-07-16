## 用于验证架构级 Model 序列化/恢复的稳定脚本资源。
extends GFModel


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

var score: int = 0
var level: int = 1


# --- 公共方法 ---

func get_save_key() -> StringName:
	return &"test_score_model_fixture"


func to_dict() -> Dictionary:
	return {
		"score": score,
		"level": level,
	}


func from_dict(data: Dictionary) -> void:
	score = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "score", 0)
	level = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "level", 1)
