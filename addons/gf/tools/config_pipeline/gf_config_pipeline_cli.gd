# Thin SceneTree wrapper for running GFConfigPipelineCommand with Godot `-s`.
extends SceneTree


# --- 常量 ---

const _GF_CONFIG_PIPELINE_COMMAND_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd")


# --- Godot 生命周期方法 ---

func _init() -> void:
	var command: _GF_CONFIG_PIPELINE_COMMAND_SCRIPT = _GF_CONFIG_PIPELINE_COMMAND_SCRIPT.new()
	var result: Dictionary = command.run(OS.get_cmdline_user_args())
	var output_text: String = command.make_output_text(result, GFVariantData.get_option_bool(result, "pretty_output", true))
	if not output_text.is_empty():
		print(output_text)
	quit(GFVariantData.get_option_int(result, "exit_code"))
