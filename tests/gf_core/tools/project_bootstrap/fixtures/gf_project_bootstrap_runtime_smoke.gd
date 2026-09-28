# 在生成结果的隔离项目内执行真实 Gf.init、Installer 与可见按钮链路。
extends SceneTree


# --- 私有变量 ---

var _failed: bool = false
var _assertions: int = 0


# --- Godot 回调方法 ---

func _initialize() -> void:
	_run.call_deferred()


# --- 私有/辅助方法 ---

func _run() -> void:
	var private_root: String = OS.get_environment("GF_PROJECT_BOOTSTRAP_SMOKE_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	_check(not private_root.is_empty() and private_root.is_absolute_path(), "A private runtime root is required.")
	for directory: String in [OS.get_data_dir(), OS.get_config_dir(), OS.get_cache_dir(), OS.get_user_data_dir()]:
		_check(directory.replace("\\", "/").simplify_path().to_lower().begins_with(private_root.to_lower() + "/"), "Runtime user/config/cache roots must be private.")
	var paths: Array[String] = ["res://game/bootstrap/bootstrap.tscn", "res://second_example/bootstrap.tscn"]
	if OS.get_cmdline_user_args().has("--empty-project"):
		ProjectSettings.set_setting("gf/project/installers", PackedStringArray(["res://empty_example/game_installer.gd"]))
		paths = ["res://empty_example/bootstrap.tscn"]
	for path: String in paths:
		var loaded: Resource = load(path)
		_check(loaded is PackedScene, "Generated scene must load: " + path)
		if not loaded is PackedScene:
			break
		var packed: PackedScene = loaded
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		var button_node: Node = scene.get_node("Center/Content/Increment")
		var status_node: Node = scene.get_node("Center/Content/Status")
		_check(button_node is Button and status_node is Label, "Generated scene must expose the visible counter controls.")
		if button_node is Button and status_node is Label:
			var button: Button = button_node
			var status: Label = status_node
			var ready_deadline: int = Time.get_ticks_msec() + 10000
			while button.disabled and Time.get_ticks_msec() < ready_deadline:
				await process_frame
			_check(not button.disabled, "Gf.init and generated Installers must complete.")
			_check(status.text.contains("计数：0"), "The initial counter must be visible.")
			button.pressed.emit()
			_check(status.text.contains("计数：1"), "Button -> System -> Model -> visible Label must work.")
		root.remove_child(scene)
		scene.free()
		await process_frame
	if not _failed:
		print("GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_OK " + JSON.stringify({"assertions": _assertions, "native_private_directories_verified": true, "kernel_counter_scene_count": paths.size()}))
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		push_error("GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_FAILED: " + message)
