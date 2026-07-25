## 测试 GFLevelUtility 的关卡读取、流程信号与运行时清理。
extends GutTest


const GF_LEVEL_UTILITY = preload("res://addons/gf/extensions/domain/level/gf_level_utility.gd")


# --- 辅助类型 ---

class ConfigProviderStub extends GFConfigProvider:
	var records: Dictionary = {}

	func get_record(table_name: StringName, id: Variant) -> Variant:
		var table_records: Dictionary = GFVariantData.get_option_dictionary(records, table_name)
		return GFVariantData.get_option_value(table_records, id)


class UndoableCommandStub extends GFUndoableCommand:
	func execute() -> Variant:
		return null

	func undo() -> Variant:
		return null


class WaitingAction extends GFVisualAction:
	signal completed

	var cancelled: bool = false

	func execute() -> Variant:
		return completed

	func cancel() -> void:
		cancelled = true


# --- 私有变量 ---

var _arch: GFArchitecture
var _level: GFLevelUtility
var _config: ConfigProviderStub
var _history: GFCommandHistoryUtility
var _actions: GFActionQueueSystem
var _progress: GFLevelProgressModel


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_arch = GFArchitecture.new()
	_level = GF_LEVEL_UTILITY.new()
	_config = ConfigProviderStub.new()
	_history = GFCommandHistoryUtility.new()
	_actions = GFActionQueueSystem.new()
	_progress = GFLevelProgressModel.new()

	_config.records = {
		&"levels": {
			&"1": {
				"name": "Level 1",
				"moves": 10,
			},
		},
	}

	await _arch.register_utility_instance(_config)
	await _arch.register_model_instance(_progress)
	await _arch.register_utility_instance(_history)
	await _arch.register_system_instance(_actions)
	await _arch.register_utility_instance(_level)
	var history_cleanup: Callable = func() -> void:
		_history.clear()
	var _register_history_cleanup_result: bool = _level.register_runtime_cleanup(&"command_history", history_cleanup, 100)
	var _register_runtime_cleanup_result_72: Variant = _level.register_runtime_cleanup(&"action_queue", func() -> void:
		_actions.clear_queue(true)
		_actions.clear_all_named_queues(true)
	)
	await Gf.set_architecture(_arch)


func after_each() -> void:
	if _arch != null:
		_arch.dispose()
	_arch = null
	Gf._architecture = null


# --- 测试 ---

func test_start_level_loads_data_from_config_provider() -> void:
	var data: Dictionary = _level.start_level(1)

	assert_eq(GFVariantData.get_option_string(data, "name"), "Level 1", "start_level 应从配置工具读取关卡数据。")
	assert_eq(_level.current_level_id, &"1", "当前关卡 ID 应规范化为 StringName。")
	assert_eq(GFVariantData.get_option_int(_level.current_level_data, "moves"), 10, "当前关卡数据应保存在工具中。")


func test_init_preserves_catalog_assigned_before_lifecycle() -> void:
	var level: GFLevelUtility = GF_LEVEL_UTILITY.new()
	var catalog: GFLevelCatalog = _make_catalog()

	level.catalog = catalog
	level.init()

	assert_eq(level.get_catalog(), catalog, "init 不应清空 Installer 或外部提前注入的目录资源。")


func test_start_level_emits_signal() -> void:
	watch_signals(_level)

	var _start_level_result_109: Variant = _level.start_level(1)

	assert_signal_emitted(_level, "level_started", "开始关卡时应发出 level_started。")


func test_start_level_rejects_empty_id_without_emitting_started() -> void:
	watch_signals(_level)

	var data: Dictionary = _level.start_level("")

	assert_true(data.is_empty(), "空关卡 ID 应被拒绝。")
	assert_eq(_level.current_level_id, &"", "空 ID 不应创建不可操作的当前关卡状态。")
	assert_signal_not_emitted(_level, "level_started", "空 ID 不应发出 level_started。")
	assert_push_error("[GFLevelUtility] start_level 失败：关卡 ID 为空。")


func test_load_level_data_rejects_empty_id_before_provider_lookup() -> void:
	var data: Dictionary = _level.load_level_data("")

	assert_true(data.is_empty(), "空关卡 ID 不应进入配置或目录查询。")
	assert_push_error("[GFLevelUtility] load_level_data 失败：关卡 ID 为空。")


func test_start_level_signal_data_cannot_mutate_current_state() -> void:
	var _connect_result_115: Variant = _level.level_started.connect(func(_level_id: Variant, signal_payload: Dictionary) -> void:
		signal_payload["moves"] = 0
	)

	var data: Dictionary = _level.start_level(1)

	assert_eq(GFVariantData.get_option_int(data, "moves"), 10, "返回数据应保持关卡配置值。")
	assert_eq(GFVariantData.get_option_int(_level.current_level_data, "moves"), 10, "信号监听者不应通过 Dictionary 引用污染 current_level_data。")


func test_strict_start_level_rejects_missing_data() -> void:
	_config.records.clear()
	_level.fail_on_missing_level_data = true

	var data: Dictionary = _level.start_level(&"missing")

	assert_true(data.is_empty(), "严格模式下缺失关卡数据应返回空字典。")
	assert_eq(_level.current_level_id, &"", "严格模式下缺失关卡不应更新 current_level_id。")
	assert_push_error("[GFLevelUtility] 找不到关卡数据：missing")


func test_restart_level_clears_runtime_and_emits_signal() -> void:
	var command: UndoableCommandStub = UndoableCommandStub.new()
	_history.record(command)
	var _start_level_result_139: Variant = _level.start_level(1)
	watch_signals(_level)

	var data: Dictionary = _level.restart_level()

	assert_eq(GFVariantData.get_option_string(data, "name"), "Level 1", "restart_level 应返回当前关卡数据。")
	assert_eq(_history.undo_count, 0, "重开关卡应清理命令历史。")
	assert_signal_emitted(_level, "level_restarted", "重开关卡时应发出 level_restarted。")
	assert_signal_not_emitted(_level, "level_started", "重开关卡不应重复发出 level_started。")


func test_register_runtime_cleanup_tracks_callbacks() -> void:
	var state: Dictionary = { "called": false }
	assert_true(_level.register_runtime_cleanup(&"test", func() -> void:
		state["called"] = true
	), "有效清理回调应注册成功。")

	_level.clear_level_runtime()

	assert_true(GFVariantData.get_option_bool(state, "called"), "清理运行时时应调用外部注册的清理回调。")
	assert_true(_level.has_runtime_cleanup(&"test"), "注册后应可查询清理项。")
	assert_true(_level.get_runtime_cleanup_ids().has("test"), "清理项列表应包含注册 ID。")


func test_restart_level_stops_current_action_queue_wait() -> void:
	var action: WaitingAction = WaitingAction.new()
	_actions.enqueue(action)
	var _start_level_result_166: Variant = _level.start_level(1)
	await get_tree().process_frame

	var _restart_level_result_169: Variant = _level.restart_level()
	await get_tree().process_frame

	assert_true(action.cancelled, "重开关卡清理运行时时应取消当前等待中的表现动作。")
	assert_false(_actions.is_processing, "重开关卡后动作队列不应继续卡在等待状态。")


func test_restart_level_clears_named_action_queues() -> void:
	var action: WaitingAction = WaitingAction.new()
	var named_queue: GFActionQueueSystem = _actions.get_named_queue(&"cutscene")
	named_queue.enqueue(action)
	var _start_level_result_180: Variant = _level.start_level(1)
	await get_tree().process_frame

	var _restart_level_result_183: Variant = _level.restart_level()
	await get_tree().process_frame

	assert_true(action.cancelled, "重开关卡清理运行时时应取消命名队列中的当前动作。")
	assert_false(named_queue.is_processing, "重开关卡后命名队列不应继续等待。")


func test_restart_level_reloads_clean_config_data() -> void:
	var _start_level_result_191: Variant = _level.start_level(1)
	_level.current_level_data["moves"] = 0

	var data: Dictionary = _level.restart_level()

	assert_eq(GFVariantData.get_option_int(data, "moves"), 10, "restart_level 应重新读取干净的关卡配置数据。")


func test_win_and_lose_current_level_emit_signals() -> void:
	var _start_level_result_200: Variant = _level.start_level(1)
	watch_signals(_level)

	_level.win_current_level()
	_level.lose_current_level()

	assert_signal_emitted(_level, "level_won", "胜利时应发出 level_won。")
	assert_signal_emitted(_level, "level_lost", "失败时应发出 level_lost。")


func test_load_level_data_falls_back_to_catalog_entry() -> void:
	_config.records.clear()
	_level.set_catalog(_make_catalog())

	var data: Dictionary = _level.start_level(&"level_1")

	assert_eq(GFVariantData.get_option_string(data, "scene_path"), "res://levels/level_1.tscn", "配置表缺失时应从目录条目读取场景路径。")
	assert_eq(GFVariantData.get_option_string(data, "difficulty"), "intro", "目录条目 metadata 应进入关卡数据。")


func test_complete_current_level_updates_progress_and_unlocks_next_levels() -> void:
	_config.records.clear()
	_level.set_catalog(_make_catalog())
	var _start_level_result_223: Variant = _level.start_level(&"level_1")

	_level.complete_current_level({ "stars": 3 })

	assert_true(_progress.is_level_completed(&"level_1"), "完成关卡应写入通用进度模型。")
	assert_true(_progress.is_level_unlocked(&"level_2"), "完成关卡应可按目录顺序解锁下一关。")
	assert_true(_progress.is_level_unlocked(&"bonus"), "完成关卡应可解锁条目声明的额外关卡。")
	assert_eq(GFVariantData.get_option_int(_progress.get_level_result(&"level_1"), "stars"), 3, "完成结果应存入进度模型。")


func test_start_next_level_uses_catalog_order() -> void:
	_config.records.clear()
	_level.set_catalog(_make_catalog())
	var _start_level_result_236: Variant = _level.start_level(&"level_1")

	var data: Dictionary = _level.start_next_level()

	assert_eq(GFVariantData.to_string_name(_level.current_level_id), &"level_2", "start_next_level 应切换到目录顺序中的下一关。")
	assert_eq(GFVariantData.get_option_string(data, "scene_path"), "res://levels/level_2.tscn", "返回数据应来自下一关目录条目。")


# --- 私有/辅助方法 ---

func _make_catalog() -> GFLevelCatalog:
	var level_1: GFLevelEntry = GFLevelEntry.new()
	level_1.level_id = &"level_1"
	level_1.pack_id = &"main"
	level_1.scene_path = "res://levels/level_1.tscn"
	level_1.sort_order = 1
	level_1.metadata = { "difficulty": "intro" }
	level_1.unlocks_on_complete = [&"bonus"]

	var level_2: GFLevelEntry = GFLevelEntry.new()
	level_2.level_id = &"level_2"
	level_2.pack_id = &"main"
	level_2.scene_path = "res://levels/level_2.tscn"
	level_2.sort_order = 2

	var bonus: GFLevelEntry = GFLevelEntry.new()
	bonus.level_id = &"bonus"
	bonus.pack_id = &"bonus"
	bonus.scene_path = "res://levels/bonus.tscn"
	bonus.sort_order = 10

	var catalog: GFLevelCatalog = GFLevelCatalog.new()
	catalog.entries = [level_1, level_2, bonus]
	return catalog
