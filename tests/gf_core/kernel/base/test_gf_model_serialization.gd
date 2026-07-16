## 测试 GFModel 的 to_dict / from_dict 虚方法及 GFArchitecture 的全局状态收集/恢复。
extends GutTest


const SCORE_MODEL_FIXTURE_PATH: String = "res://tests/gf_core/fixtures/model_serialization/score_model_fixture.gd"
const SETTINGS_MODEL_FIXTURE_PATH: String = "res://tests/gf_core/fixtures/model_serialization/settings_model_fixture.gd"
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试：单 Model 序列化 ---

## 验证基类默认 to_dict 返回空字典。
func test_base_model_to_dict_returns_empty() -> void:
	var base: GFModel = GFModel.new()
	var result: Dictionary = base.to_dict()
	assert_eq(result.size(), 0, "基类 to_dict 应返回空字典。")


## 验证子类 to_dict / from_dict 往返正确。
func test_subclass_roundtrip() -> void:
	var model: ScoreModel = ScoreModel.new()
	model.score = 999
	model.level = 5

	var data: Dictionary = model.to_dict()
	assert_eq(GF_VARIANT_ACCESS.get_option_int(data, "score"), 999)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(data, "level"), 5)

	var restored: ScoreModel = ScoreModel.new()
	restored.from_dict(data)
	assert_eq(restored.score, 999, "score 应正确恢复。")
	assert_eq(restored.level, 5, "level 应正确恢复。")


## 验证空字典 from_dict 使用默认值。
func test_from_dict_with_empty_data() -> void:
	var model: ScoreModel = ScoreModel.new()
	model.score = 100
	model.from_dict({})
	assert_eq(model.score, 0, "空字典 from_dict 应使用 get 的默认值。")


# --- 测试：架构级状态收集/恢复 ---

## 验证 get_all_models_state 收集多个 Model 的状态。
func test_architecture_get_all_models_state() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	score_model.set("score", 42)
	score_model.set("level", 3)

	var settings_model: Object = _create_settings_model_fixture()
	settings_model.set("volume", 0.5)

	await arch.register_model_instance(score_model)
	await arch.register_model_instance(settings_model)

	var state: Dictionary = arch.get_all_models_state()
	assert_true(state.size() >= 2, "状态字典应至少包含 2 个 Model。")


## 验证缺少稳定标识的运行时脚本 Model 不会被写入快照。
func test_architecture_skips_model_without_stable_serialization_key() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = """extends GFModel


func to_dict() -> Dictionary:
	return { "value": 7 }
"""
	var reload_error: Error = runtime_script.reload()
	assert_eq(reload_error, OK, "动态脚本应成功编译。")

	var runtime_model: GFModel = _as_model(runtime_script.new())

	await arch.register_model_instance(runtime_model)

	var state: Dictionary = arch.get_all_models_state()

	assert_eq(state.size(), 0, "缺少稳定标识的运行时 Model 不应进入快照。")
	assert_push_error("[GFArchitecture] 可序列化 Model 缺少稳定标识：请为脚本声明 class_name 或重写 get_save_key()。")


func test_architecture_prefers_model_save_key_for_serialization() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var model: StableKeyModel = StableKeyModel.new()
	model.value = 12

	await arch.register_model_instance(model)
	var state: Dictionary = arch.get_all_models_state()
	var model_state: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(state, "stable_runtime_model")

	model.value = 0
	arch.restore_all_models_state({
		"stable_runtime_model": { "value": 42 },
	})

	assert_true(state.has("stable_runtime_model"), "Model.get_save_key() 应优先作为架构级快照键。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(model_state, "value"), 12, "快照应写入自定义存档键下。")
	assert_eq(model.value, 42, "恢复时也应使用自定义存档键。")


func test_architecture_rejects_duplicate_model_save_keys_for_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var first_model: DuplicateKeyModelA = DuplicateKeyModelA.new()
	var second_model: DuplicateKeyModelB = DuplicateKeyModelB.new()
	first_model.value = 10
	second_model.value = 20

	await arch.register_model_instance(first_model)
	await arch.register_model_instance(second_model)

	var state: Dictionary = arch.get_all_models_state()

	assert_true(state.is_empty(), "重复 Model 存档键应阻断快照，避免静默覆盖。")
	assert_push_error("[GFArchitecture] Model 快照键重复：duplicate_model。请为每个 Model 提供唯一 get_save_key()。")


func test_architecture_rejects_duplicate_model_save_keys_for_restore() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var first_model: DuplicateKeyModelA = DuplicateKeyModelA.new()
	var second_model: DuplicateKeyModelB = DuplicateKeyModelB.new()
	first_model.value = 10
	second_model.value = 20

	await arch.register_model_instance(first_model)
	await arch.register_model_instance(second_model)

	arch.restore_all_models_state({
		"duplicate_model": { "value": 99 },
	})

	assert_eq(first_model.value, 10, "重复键时 restore 不应修改前面的 Model。")
	assert_eq(second_model.value, 20, "重复键时 restore 不应修改后面的 Model。")
	assert_push_error("[GFArchitecture] Model 快照键重复：duplicate_model。请为每个 Model 提供唯一 get_save_key()。")


## 验证 restore_all_models_state 恢复多个 Model 的数据。
func test_architecture_restore_all_models_state() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	var settings_model: Object = _create_settings_model_fixture()

	await arch.register_model_instance(score_model)
	await arch.register_model_instance(settings_model)

	score_model.set("score", 100)
	score_model.set("level", 10)
	settings_model.set("volume", 0.3)

	var state: Dictionary = arch.get_all_models_state()

	score_model.set("score", 0)
	score_model.set("level", 1)
	settings_model.set("volume", 1.0)

	arch.restore_all_models_state(state)

	assert_eq(_object_int(score_model, "score"), 100, "score 应恢复为 100。")
	assert_eq(_object_int(score_model, "level"), 10, "level 应恢复为 10。")
	assert_almost_eq(_object_float(settings_model, "volume"), 0.3, 0.001, "volume 应恢复为 0.3。")


## 验证分帧 Model 快照收集与同步快照使用相同键和值。
func test_architecture_get_all_models_state_async() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	score_model.set("score", 77)
	score_model.set("level", 6)
	var settings_model: Object = _create_settings_model_fixture()
	settings_model.set("volume", 0.25)

	await arch.register_model_instance(score_model)
	await arch.register_model_instance(settings_model)

	var state: Dictionary = await arch.get_all_models_state_async({ "max_models_per_frame": 1 })

	assert_eq(state, arch.get_all_models_state(), "分帧快照应与同步快照一致。")


## 验证分帧 Model 快照恢复。
func test_architecture_restore_all_models_state_async() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	var settings_model: Object = _create_settings_model_fixture()

	await arch.register_model_instance(score_model)
	await arch.register_model_instance(settings_model)

	score_model.set("score", 33)
	score_model.set("level", 4)
	settings_model.set("volume", 0.6)
	var state: Dictionary = await arch.get_all_models_state_async({ "max_models_per_frame": 1 })

	score_model.set("score", 0)
	score_model.set("level", 0)
	settings_model.set("volume", 1.0)
	var restored: bool = await arch.restore_all_models_state_async(state, { "max_models_per_frame": 1 })

	assert_true(restored, "restore_all_models_state_async() 完整恢复时应返回 true。")
	assert_eq(_object_int(score_model, "score"), 33, "score 应通过分帧恢复。")
	assert_eq(_object_int(score_model, "level"), 4, "level 应通过分帧恢复。")
	assert_almost_eq(_object_float(settings_model, "volume"), 0.6, 0.001, "volume 应通过分帧恢复。")


## 验证全局快照中的 models 字段类型错误时安全跳过。
func test_restore_global_snapshot_skips_non_dictionary_models_data() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	score_model.set("score", 55)
	await arch.register_model_instance(score_model)

	arch.restore_global_snapshot({ "models": [] })

	assert_eq(_object_int(score_model, "score"), 55, "models 不是 Dictionary 时不应修改已注册 Model。")
	assert_push_warning("[GFArchitecture] restore_global_snapshot：models 必须是 Dictionary，已跳过 Model 恢复。")


## 验证 get_global_snapshot 包含 Model 与 CommandHistory 数据，及 restore_global_snapshot 正确恢复。
func test_architecture_global_snapshot_preserves_redo_history() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var history_util: GFCommandHistoryUtility = GFCommandHistoryUtility.new()
	history_util.init()
	await arch.register_utility_instance(history_util)

	var cmd1: GFUndoableCommand = GFUndoableCommand.new()
	var cmd2: GFUndoableCommand = GFUndoableCommand.new()
	history_util.record(cmd1)
	history_util.record(cmd2)
	var _undo_last_result_154: Variant = history_util.undo_last()

	var snapshot: Dictionary = arch.get_global_snapshot()
	history_util.clear()

	var builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	arch.restore_global_snapshot(snapshot, builder)

	assert_eq(history_util.undo_count, 1, "全局快照恢复后应保留 undo 栈。")
	assert_eq(history_util.redo_count, 1, "全局快照恢复后应保留 redo 栈。")


func test_architecture_global_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	score_model.set("score", 99)
	await arch.register_model_instance(score_model)
	
	var history_util: GFCommandHistoryUtility = GFCommandHistoryUtility.new()
	history_util.init()
	await arch.register_utility_instance(history_util)
	
	# 构造一个虚假的序列化历史数据（不依赖具体的 command 类）
	# 在真实场景下，这就代表了一个历史记录
	var fake_history_data: Array = [{"snapshot": 1}]
	# 模拟工具内有一些记录
	history_util._undo_stack.append(GFUndoableCommand.new())
	
	var global_snap: Dictionary = arch.get_global_snapshot()
	
	assert_true(global_snap.has("models"), "全局快照必须包含 models。")
	assert_true(global_snap.has("command_history"), "如果注册了命令历史工具，全局快照必须包含 command_history。")
	
	# 修改模型状态
	score_model.set("score", 0)
	
	# 设置一个不做任何事的 builder 以防止报错，并验证历史恢复是否被触达
	var mock_builder: Callable = func(data: Dictionary) -> GFUndoableCommand:
		var cmd: GFUndoableCommand = GFUndoableCommand.new()
		var _snapshot_saved: bool = cmd.set_snapshot(GF_VARIANT_ACCESS.get_option_value(data, "snapshot"))
		return cmd
		
	# 由于历史重做会在 restore 时调用 clear，我们要改写一下
	# 或者不改，依靠 deserialize_history 的能力即可
	global_snap["command_history"] = fake_history_data
		
	arch.restore_global_snapshot(global_snap, mock_builder)
	
	assert_eq(_object_int(score_model, "score"), 99, "模型状态应通过全局快照恢复。")
	assert_eq(history_util.undo_count, 1, "历史栈记录数量应通过全局快照及 builder 恢复。")


func test_architecture_global_snapshot_async() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var score_model: Object = _create_score_model_fixture()
	score_model.set("score", 88)
	await arch.register_model_instance(score_model)

	var snapshot: Dictionary = await arch.get_global_snapshot_async({ "max_models_per_frame": 1 })
	score_model.set("score", 0)
	var restored: bool = await arch.restore_global_snapshot_async(snapshot, Callable(), { "max_models_per_frame": 1 })

	assert_true(restored, "restore_global_snapshot_async() 完整恢复时应返回 true。")
	assert_eq(_object_int(score_model, "score"), 88, "分帧全局快照应恢复 Model 数据。")


func test_global_snapshot_ignores_incomplete_command_history_contract() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var history_util: IncompleteHistoryUtility = IncompleteHistoryUtility.new()
	await arch.register_utility_instance(history_util)

	var snapshot: Dictionary = arch.get_global_snapshot()

	assert_false(snapshot.has("command_history"), "命令历史快照应要求完整序列化/反序列化契约。")


func test_register_service_rejects_multiple_command_history_stores() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var first_history: CompleteHistoryUtilityA = CompleteHistoryUtilityA.new()
	var second_history: CompleteHistoryUtilityB = CompleteHistoryUtilityB.new()
	await arch.register_utility_instance(first_history)
	await arch.register_utility_instance(second_history)

	var snapshot: Dictionary = arch.get_global_snapshot()

	assert_true(snapshot.has("command_history"), "第二个服务 provider 被拒绝后，应继续使用第一个命令历史服务。")
	assert_push_error("[GFArchitecture] register_service 失败：service_key 已注册：gf.kernel.command_history_store。")


# --- 私有/辅助方法 ---

func _create_score_model_fixture() -> Object:
	return _new_model_fixture(SCORE_MODEL_FIXTURE_PATH)


func _create_settings_model_fixture() -> Object:
	return _new_model_fixture(SETTINGS_MODEL_FIXTURE_PATH)


func _new_model_fixture(path: String) -> Object:
	var resource: Resource = load(path)
	assert_true(resource is Script, "Model fixture 应是脚本资源。")
	if resource is Script:
		var script: Script = resource
		var instance: Variant = script.call(&"new")
		assert_true(instance is Object, "Model fixture 应能实例化为 Object。")
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _object_int(object_instance: Object, property_name: StringName) -> int:
	return GF_VARIANT_ACCESS.to_int(object_instance.get(property_name))


func _object_float(object_instance: Object, property_name: StringName) -> float:
	return GF_VARIANT_ACCESS.to_float(object_instance.get(property_name))


func _as_model(value: Variant) -> GFModel:
	assert_true(value is GFModel, "测试观察值应为 GFModel。")
	if value is GFModel:
		var model: GFModel = value
		return model
	return null


# --- 辅助子类 ---

## 用于测试的 Model 实现。
class ScoreModel:
	extends GFModel

	var score: int = 0
	var level: int = 1

	func to_dict() -> Dictionary:
		return {"score": score, "level": level}

	func from_dict(data: Dictionary) -> void:
		score = GF_VARIANT_ACCESS.get_option_int(data, "score")
		level = GF_VARIANT_ACCESS.get_option_int(data, "level", 1)


## 另一个用于测试的 Model 实现。
class SettingsModel:
	extends GFModel

	var volume: float = 1.0

	func to_dict() -> Dictionary:
		return {"volume": volume}

	func from_dict(data: Dictionary) -> void:
		volume = GF_VARIANT_ACCESS.get_option_float(data, "volume", 1.0)


class StableKeyModel:
	extends GFModel

	var value: int = 7

	func get_save_key() -> StringName:
		return &"stable_runtime_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GF_VARIANT_ACCESS.get_option_int(data, "value")


class DuplicateKeyModelA:
	extends GFModel

	var value: int = 0

	func get_save_key() -> StringName:
		return &"duplicate_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GF_VARIANT_ACCESS.get_option_int(data, "value")


class DuplicateKeyModelB:
	extends GFModel

	var value: int = 0

	func get_save_key() -> StringName:
		return &"duplicate_model"

	func to_dict() -> Dictionary:
		return { "value": value }

	func from_dict(data: Dictionary) -> void:
		value = GF_VARIANT_ACCESS.get_option_int(data, "value")


class IncompleteHistoryUtility:
	extends GFUtility

	func serialize_full_history() -> Dictionary:
		return { "incomplete": true }


class CompleteHistoryUtilityA:
	extends GFUtility

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		var _registered_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)

	func serialize_full_history() -> Dictionary:
		return { "complete": true }

	func deserialize_history(_data_array: Array, _command_builder: Callable) -> void:
		pass

	func deserialize_full_history(_data: Dictionary, _command_builder: Callable) -> void:
		pass


class CompleteHistoryUtilityB:
	extends GFUtility

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		var _registered_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)

	func serialize_full_history() -> Dictionary:
		return { "complete": true }

	func deserialize_history(_data_array: Array, _command_builder: Callable) -> void:
		pass

	func deserialize_full_history(_data: Dictionary, _command_builder: Callable) -> void:
		pass
