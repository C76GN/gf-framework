# 隔离项目的观察 AutoLoad。正常运行项目入口，不抢先调用 Gf.init 或替换生成的启动脚本。
extends Node


# --- 信号 ---

signal installer_released


# --- 私有变量 ---

var _failed: bool = false
var _assertions: int = 0
var _empty_project: bool = false
var _installer_entered: bool = false
var _installer_finished: bool = false
var _pending_architecture: GFArchitecture = null
var _existing_started: bool = false
var _existing_finished: bool = false
var _existing_initialized: bool = false
var _installer_order: Array[String] = []
var _boot_entries: int = 0
var _main_entries: int = 0
var _main_entered_ready: bool = false


# --- Godot 回调方法 ---

func _enter_tree() -> void:
	_empty_project = OS.get_cmdline_user_args().has("--empty-project")
	var _connected: int = get_tree().node_added.connect(_on_node_added)
	if _empty_project:
		# 只在隔离测试项目追加延迟探针，观察真实 Boot 是否等待 Installer 完成。
		var installers: Array = ProjectSettings.get_setting("gf/project/installers", [])
		installers = installers.duplicate()
		installers.append("res://delayed_installer.gd")
		ProjectSettings.set_setting("gf/project/installers", installers)


func _ready() -> void:
	_run.call_deferred()


# --- 公共方法 ---

func hold_installer(architecture: GFArchitecture) -> void:
	_pending_architecture = architecture
	_installer_entered = true
	await installer_released
	_installer_finished = true


func record_installer(label: String) -> void:
	_installer_order.append(label)


func observe_existing_start() -> void:
	_existing_started = true


func observe_existing_complete(initialized: bool) -> void:
	_existing_finished = true
	_existing_initialized = initialized


# --- 私有/辅助方法 ---

func _run() -> void:
	var private_root: String = OS.get_environment("GF_PROJECT_BOOTSTRAP_SMOKE_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	_check(not private_root.is_empty() and private_root.is_absolute_path(), "A private runtime root is required.")
	for directory: String in [OS.get_data_dir(), OS.get_config_dir(), OS.get_cache_dir(), OS.get_user_data_dir()]:
		_check(directory.replace("\\", "/").simplify_path().to_lower().begins_with(private_root.to_lower() + "/"), "Runtime user/config/cache roots must be private.")
	if _empty_project:
		await _exercise_empty_project()
	else:
		await _exercise_existing_project()
	if not _failed:
		var report: Dictionary = {"assertions": _assertions, "native_private_directories_verified": true, "normal_project_entry_used": true, "no_counter_modules": true}
		if _empty_project:
			report.merge({"boot_waits_for_init_before_main": true, "boot_exit_preserves_global_gf": true, "owner_retired_no_late_switch": true, "failure_stays_on_boot": true, "boot_entry_count": _boot_entries, "main_entry_count": _main_entries, "expected_boot_failure_count": 1})
		else:
			report.merge({"existing_entry_preserved": true, "existing_installer_order_preserved": true, "empty_installer_registers_no_business": true})
		print("GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_OK " + JSON.stringify(report))
	get_tree().quit(1 if _failed else 0)


func _exercise_existing_project() -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while not _existing_finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_existing_started and _existing_finished and _existing_initialized, "The original scene must explicitly complete its own real Gf.init integration.")
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://existing.tscn", "The original project entry scene must remain current.")
	_check(_installer_order == ["one", "legacy"], "Real Installer execution must retain the prior order; the generated Installer adds no business work.")
	_check(_boot_entries == 0 and _main_entries == 0, "Existing-project integration must not run the generated Boot or Main.")
	_assert_ready_and_empty()


func _exercise_empty_project() -> void:
	var configured_main: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(configured_main == "res://app/boot.tscn", "The engine must launch the generated Boot through the actual project main-scene setting.")
	await _wait_for_installer()
	if _failed:
		return
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://app/boot.tscn", "Boot must remain current while its real Installer is suspended.")
	var actual_boot: Node = get_tree().current_scene
	var started: bool = actual_boot.get("_started")
	_check(started and _boot_entries == 1, "The original generated Boot must execute exactly once before awaiting initialization.")
	_check(_main_entries == 0 and not _pending_architecture.is_inited(), "Main must not enter the tree before GF becomes ready.")
	var initial_architecture: GFArchitecture = _pending_architecture
	installer_released.emit()
	await _wait_for_scene("res://app/main.tscn")
	_check(_installer_finished and _main_entries == 1 and _main_entered_ready, "Main must enter only after the held real Installer and GF initialization finish.")
	_assert_ready_and_empty()
	_check(Gf.get_architecture() == initial_architecture and not initial_architecture.is_disposed(), "Destroying Boot during the normal scene switch must not dispose the global architecture.")
	await _exercise_retired_boot()
	if _failed:
		return
	await _exercise_failed_boot()


func _exercise_retired_boot() -> void:
	# 测试观察者显式结束上一场景的架构，再让同一原始 Boot 开始新的真实异步初始化。
	Gf.get_architecture().dispose()
	ProjectSettings.set_setting("gf/project/installers", ["res://delayed_installer.gd"])
	_installer_entered = false
	_installer_finished = false
	_pending_architecture = null
	_check(get_tree().change_scene_to_file("res://app/boot.tscn") == OK, "The retired-owner scenario must start the actual generated Boot.")
	await _wait_for_installer()
	if _failed:
		return
	var boot: Node = get_tree().current_scene
	var boot_ref: WeakRef = weakref(boot)
	_check(boot != null and boot.scene_file_path == "res://app/boot.tscn", "The actual Boot must own the suspended initialization.")
	var architecture: GFArchitecture = _pending_architecture
	_check(get_tree().change_scene_to_file("res://sentinel.tscn") == OK, "The fixture must retire Boot before its pending initialization finishes.")
	await _wait_for_scene("res://sentinel.tscn")
	_check(boot_ref.get_ref() == null, "The former Boot owner must be destroyed before releasing the Installer.")
	_check(not architecture.is_disposed(), "Boot retirement must not dispose Gf's pending architecture.")
	installer_released.emit()
	var deadline: int = Time.get_ticks_msec() + 10000
	while not architecture.is_inited() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	for _frame: int in range(3):
		await get_tree().process_frame
	_check(_installer_finished and architecture.is_inited(), "The global GF initialization must finish after its Boot owner leaves.")
	_check(Gf.has_architecture() and Gf.get_architecture() == architecture and not architecture.is_disposed(), "The same global architecture must remain ready after Boot retirement.")
	_check(get_tree().current_scene.scene_file_path == "res://sentinel.tscn" and _main_entries == 1, "A late initialization callback must not replace the current scene with Main.")


func _exercise_failed_boot() -> void:
	# 移除但不替换真实 AutoLoad，使其既有退出状态令 Gf.init 返回 false。
	# 不关闭原生错误输出；runner 只在本 phase 精确验收这一条预期产品诊断。
	var gf_node: Node = get_tree().root.get_node("Gf")
	get_tree().root.remove_child(gf_node)
	_check(not gf_node.is_inside_tree(), "The real Gf AutoLoad must leave the tree for the failure precondition.")
	_check(get_tree().change_scene_to_file("res://app/boot.tscn") == OK, "The failure scenario must execute the original generated Boot.")
	await _wait_for_scene("res://app/boot.tscn")
	for _frame: int in range(3):
		await get_tree().process_frame
	var boot: Node = get_tree().current_scene
	var started: bool = boot.get("_started")
	_check(started and _boot_entries == 3, "The failed Boot must have actually executed its initialization call.")
	_check(boot.scene_file_path == "res://app/boot.tscn" and _main_entries == 1, "Failed initialization must leave Boot current and never enter Main.")
	get_tree().root.add_child(gf_node)
	_check(gf_node.is_inside_tree(), "The fixture must return the real AutoLoad to its owner for normal cleanup.")


func _wait_for_installer() -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while not _installer_entered and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_installer_entered and _pending_architecture != null, "The real delayed Installer must be reached within ten seconds.")


func _wait_for_scene(path: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			return
		await get_tree().process_frame
	_check(false, "The expected current scene was not reached within ten seconds: " + path)


func _assert_ready_and_empty() -> void:
	_check(Gf.has_architecture(), "Real project startup must publish an architecture.")
	if not Gf.has_architecture():
		return
	var architecture: GFArchitecture = Gf.get_architecture()
	var state: Dictionary = architecture.get_debug_lifecycle_state()
	var models: Dictionary = state["models"]
	var systems: Dictionary = state["systems"]
	var utilities: Dictionary = state["utilities"]
	_check(architecture.is_inited() and architecture.is_accepting_runtime_work(), "The architecture must be READY and accept runtime work.")
	_check(models.is_empty() and systems.is_empty() and utilities.is_empty(), "The generated Installer must register no Counter or other business modules.")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		push_error("GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_FAILED: " + message)


# --- 信号处理函数 ---

func _on_node_added(node: Node) -> void:
	if node.scene_file_path == "res://app/boot.tscn":
		_boot_entries += 1
	elif node.scene_file_path == "res://app/main.tscn":
		_main_entries += 1
		_main_entered_ready = Gf.has_architecture() and Gf.get_architecture().is_inited()
