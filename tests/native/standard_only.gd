extends Node


func _ready() -> void:
	var enabled: Variant = ProjectSettings.get_setting("gf/extensions/enabled")
	var errors: Array[String] = preload("res://tests/native/terrain_rgb/acceptance.gd").check(true)
	errors.append_array(preload("res://tests/native/wfc_entropy/acceptance.gd").check(true))
	if enabled != [] or ProjectSettings.get_setting("gf/extensions/selection_mode") != "explicit":
		errors.append("Expected an explicit empty extension selection.")
	if not errors.is_empty():
		push_error(str(errors))
		get_tree().quit(1)
		return
	print("GF_NATIVE_STANDARD_ONLY=passed")
	get_tree().quit()
