## 测试 GFRuntimeInspectorUtility 与 GFRuntimeTunableProperty。
extends GutTest


# --- 私有变量 ---

var _inspector: GFRuntimeInspectorUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_inspector = GFRuntimeInspectorUtility.new()


func after_each() -> void:
	_inspector.dispose()
	_inspector = null


# --- 测试方法 ---

func test_tunable_property_normalizes_numeric_range() -> void:
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	assert_true(property.configure_range(0.0, 100.0, 1.0), "有限且有序的数值范围应配置成功。")
	var upper_report: Dictionary = property.try_normalize_value(150)
	var lower_report: Dictionary = property.try_normalize_value(-5)

	assert_eq(GFVariantData.get_option_int(upper_report, "value"), 100, "整数值应按 schema 上限夹取。")
	assert_eq(GFVariantData.get_option_int(lower_report, "value"), 0, "整数值应按 schema 下限夹取。")


func test_tunable_property_rejects_values_outside_normalized_options() -> void:
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"quality",
		^"quality",
		GFRuntimeTunableProperty.ValueKind.INT
	).with_options(["3", "5"])

	var accepted: Dictionary = property.try_normalize_value("3")
	var rejected: Dictionary = property.try_normalize_value(9)

	assert_true(GFVariantData.get_option_bool(accepted, "ok"), "合法选项应按 value_kind 严格解析。")
	assert_eq(GFVariantData.get_option_int(accepted, "value"), 3, "数值字符串选项应解析为整数。")
	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "非法选项不应静默回退到首项。")
	assert_eq(GFVariantData.get_option_string(rejected, "error"), "value_not_allowed", "非法选项应返回稳定错误。")


func test_runtime_inspector_sets_registered_property() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	var _range_configured: bool = property.configure_range(0.0, 100.0)
	var _register_target_result_41: Variant = _inspector.register_target(&"enemy", target, [property])
	watch_signals(_inspector)

	var ok: bool = _inspector.set_property_value(&"enemy", &"health", 140)

	assert_true(ok, "注册属性应允许通过 Inspector 写入。")
	assert_eq(target.health, 100, "写入值应经过属性 schema 归一化。")
	assert_signal_emitted(_inspector, "property_changed", "成功写入后应发出变更信号。")


func test_tunable_property_rejects_invalid_structured_values() -> void:
	var target: TunableTarget = TunableTarget.new()
	var color_property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"tint",
		^"tint",
		GFRuntimeTunableProperty.ValueKind.COLOR
	)
	var position_property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"position",
		^"position",
		GFRuntimeTunableProperty.ValueKind.VECTOR2
	)
	var _register_target_result: Variant = _inspector.register_target(&"target", target, [color_property, position_property])

	assert_false(_inspector.set_property_value(&"target", &"tint", "not-a-color"), "非法 Color 输入不应写入默认颜色。")
	assert_false(_inspector.set_property_value(&"target", &"position", "1,2"), "非法 Vector2 输入不应写入零向量。")
	assert_eq(target.tint, Color.RED, "非法 Color 写入失败后目标值不应变化。")
	assert_eq(target.position, Vector2(3.0, 4.0), "非法 Vector2 写入失败后目标值不应变化。")


func test_runtime_inspector_snapshot_contains_values_and_schema() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"speed",
		^"speed",
		GFRuntimeTunableProperty.ValueKind.FLOAT
	)
	property.label = "Move Speed"
	var _range_configured: bool = property.configure_range(0.0, 10.0, 0.1)
	var _register_target_result_60: Variant = _inspector.register_target(&"player", target, [property], {
		"label": "Player",
		"group": "Combat",
	})

	var snapshot: Array[Dictionary] = _inspector.get_target_snapshot()
	var target_snapshot: Dictionary = snapshot[0]
	var properties: Array = GFVariantData.as_array(
		GFVariantData.get_option_value(target_snapshot, "properties")
	)
	var property_snapshot: Dictionary = GFVariantData.as_dictionary(properties[0])

	assert_eq(GFVariantData.get_option_string(target_snapshot, "label"), "Player", "快照应包含目标展示信息。")
	assert_eq(GFVariantData.get_option_string(property_snapshot, "label"), "Move Speed", "快照应包含属性展示信息。")
	assert_eq(GFVariantData.get_option_float(property_snapshot, "value"), 1.0, "快照应包含当前值。")
	assert_true(GFVariantData.get_option_bool(property_snapshot, "has_max_value"), "快照应包含 schema 范围。")


func test_runtime_inspector_prunes_released_targets() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	var _register_target_result: Variant = _inspector.register_target(&"temporary", target, [property])

	target = null

	assert_false(_inspector.has_target(&"temporary"), "目标对象释放后 has_target 应返回 false。")
	assert_false(_inspector.get_target_ids(true).has("temporary"), "目标对象释放后 ID 列表应清理失效目标。")


func test_runtime_inspector_respects_write_gate_and_read_only() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"enabled",
		^"enabled",
		GFRuntimeTunableProperty.ValueKind.BOOL
	)
	property.read_only = true
	var _register_target_result_86: Variant = _inspector.register_target(&"target", target, [property])

	assert_false(_inspector.set_property_value(&"target", &"enabled", false), "只读属性不应被写入。")
	assert_true(target.enabled, "只读属性写入失败后目标值不应变化。")

	property.read_only = false
	_inspector.allow_writes = false
	assert_false(_inspector.set_property_value(&"target", &"enabled", false), "全局写入门禁关闭时不应写入。")
	assert_true(target.enabled, "写入门禁关闭后目标值不应变化。")


func test_tunable_property_uses_custom_getter_and_setter() -> void:
	var target: TunableTarget = TunableTarget.new()
	var stored: FloatState = FloatState.new()
	stored.value = 2.0
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(&"custom")
	property.value_kind = GFRuntimeTunableProperty.ValueKind.FLOAT
	property.getter = func(_target: Object, _property: GFRuntimeTunableProperty) -> Variant:
		return stored.value
	property.setter = func(_target: Object, _property: GFRuntimeTunableProperty, value: Variant) -> void:
		stored.value = GFVariantData.to_float(value)

	assert_true(property.write_value(target, 4.5), "自定义 setter 应可处理无 property_name 的属性。")
	assert_eq(GFVariantData.to_float(property.read_value(target)), 4.5, "自定义 getter 应返回外部存储值。")


func test_tunable_property_rejects_reentrant_write() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	var callback_state: Dictionary = {
		"nested_result": true,
		"setter_calls": 0,
	}
	property.setter = func(
		callback_target: Object,
		callback_property: GFRuntimeTunableProperty,
		value: Variant
	) -> void:
		callback_state["setter_calls"] = (
			GFVariantData.get_option_int(callback_state, "setter_calls") + 1
		)
		if GFVariantData.get_option_int(callback_state, "setter_calls") == 1:
			callback_state["nested_result"] = callback_property.write_value(
				callback_target,
				value
			)

	assert_true(property.write_value(target, 20), "外层写入应完成一次 setter 调用。")
	assert_false(
		GFVariantData.get_option_bool(callback_state, "nested_result"),
		"同一属性的递归写入应被拒绝。"
	)
	assert_eq(
		GFVariantData.get_option_int(callback_state, "setter_calls"),
		1,
		"递归写入不得再次进入 setter。"
	)
	property.setter = Callable()


func test_runtime_inspector_rejects_commit_after_reentrant_registration_change() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	property.setter = func(
		callback_target: Object,
		_callback_property: GFRuntimeTunableProperty,
		value: Variant
	) -> void:
		var typed_target: TunableTarget = callback_target as TunableTarget
		typed_target.health = GFVariantData.to_int(value)
		var _removed: bool = _inspector.unregister_target(&"reentrant")
		var _replacement_registered: bool = _inspector.register_target(
			&"reentrant",
			callback_target,
			[property]
		)
	var _initial_registered: bool = _inspector.register_target(
		&"reentrant",
		target,
		[property]
	)
	watch_signals(_inspector)

	var result: bool = _inspector.set_property_value(
		&"reentrant",
		&"health",
		20
	)

	assert_false(
		result,
		"回调改变注册代际后，旧写操作不得报告成功提交。"
	)
	assert_signal_not_emitted(
		_inspector,
		"property_changed",
		"旧代际写操作不得向新注册发出 property_changed。"
	)
	assert_true(_inspector.has_target(&"reentrant"), "回调建立的新注册应保持有效。")
	assert_eq(target.health, 20, "已发生的项目 setter 副作用不能由 Inspector 伪装回滚。")
	property.setter = Callable()


func test_tunable_property_rejects_invalid_numeric_variants_without_writing() -> void:
	var target: TunableTarget = TunableTarget.new()
	var int_property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	)
	var float_property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"speed",
		^"speed",
		GFRuntimeTunableProperty.ValueKind.FLOAT
	)
	var _register_target_result: Variant = _inspector.register_target(&"numeric", target, [int_property, float_property])

	assert_false(_inspector.set_property_value(&"numeric", &"health", "oops"), "非法整数字符串不应静默写成 0。")
	assert_false(_inspector.set_property_value(&"numeric", &"health", {}), "Dictionary 不应转换为整数。")
	assert_false(_inspector.set_property_value(&"numeric", &"health", 1.5), "非整数 float 不应截断写入 int。")
	assert_false(_inspector.set_property_value(&"numeric", &"speed", RefCounted.new()), "Object 不应转换为浮点数。")
	assert_false(_inspector.set_property_value(&"numeric", &"speed", INF), "非有限浮点数不应写入。")
	assert_eq(target.health, 10, "非法整数输入后目标值应保持不变。")
	assert_eq(target.speed, 1.0, "非法浮点输入后目标值应保持不变。")


func test_tunable_property_rejects_non_finite_or_inverted_range_schema() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"speed",
		^"speed",
		GFRuntimeTunableProperty.ValueKind.FLOAT
	)

	assert_false(property.configure_range(NAN, 10.0), "NaN 最小值不应进入 range schema。")
	assert_false(property.configure_range(10.0, 1.0), "倒置范围不应进入 schema。")
	assert_false(property.configure_range(0.0, 10.0, INF), "非有限 step 不应进入 schema。")
	property.has_min_value = true
	property.min_value = NAN
	assert_false(property.write_value(target, 2.0), "直接加载的腐坏 range schema 也不应写入目标。")
	assert_eq(target.speed, 1.0, "腐坏 schema 写入失败后目标值应保持有限且不变。")
	var schema: Dictionary = property.to_schema()
	assert_false(GFVariantData.get_option_bool(schema, "schema_valid"), "schema 快照应暴露腐坏状态。")
	assert_eq(GFVariantData.get_option_string(schema, "schema_error"), "numeric_min_non_finite", "schema 快照应给出稳定错误。")


# --- 内部类 ---

class TunableTarget:
	extends RefCounted

	var health: int = 10
	var speed: float = 1.0
	var enabled: bool = true
	var tint: Color = Color.RED
	var position: Vector2 = Vector2(3.0, 4.0)


class FloatState:
	extends RefCounted

	var value: float = 0.0
