@tool

# 仅用于证明预览不会实例化带项目脚本的来源场景。
extends Node3D


# --- Godot 生命周期方法 ---

func _init() -> void:
	var previous: Variant = Engine.get_meta(&"gf_placement_canary_instances", 0)
	var count: int = 0
	if previous is int:
		count = previous
	Engine.set_meta(&"gf_placement_canary_instances", count + 1)
