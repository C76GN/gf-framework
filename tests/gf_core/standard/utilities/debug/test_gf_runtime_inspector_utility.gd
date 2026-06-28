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
	).with_range(0.0, 100.0, 1.0)

	assert_eq(GFVariantData.to_int(property.normalize_value(150)), 100, "整数值应按 schema 上限夹取。")
	assert_eq(GFVariantData.to_int(property.normalize_value(-5)), 0, "整数值应按 schema 下限夹取。")


func test_tunable_property_normalizes_option_fallback_to_value_kind() -> void:
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"quality",
		^"quality",
		GFRuntimeTunableProperty.ValueKind.INT
	).with_options(["3", "5"])

	var normalized: Variant = property.normalize_value(9)

	assert_true(normalized is int, "选项兜底值也应归一到 value_kind。")
	assert_eq(GFVariantData.to_int(normalized), 3, "非法输入应回退到归一化后的首个选项。")


func test_runtime_inspector_sets_registered_property() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"health",
		^"health",
		GFRuntimeTunableProperty.ValueKind.INT
	).with_range(0.0, 100.0)
	var _register_target_result_41: Variant = _inspector.register_target(&"enemy", target, [property])
	watch_signals(_inspector)

	var ok: bool = _inspector.set_property_value(&"enemy", &"health", 140)

	assert_true(ok, "注册属性应允许通过 Inspector 写入。")
	assert_eq(target.health, 100, "写入值应经过属性 schema 归一化。")
	assert_signal_emitted(_inspector, "property_changed", "成功写入后应发出变更信号。")


func test_runtime_inspector_snapshot_contains_values_and_schema() -> void:
	var target: TunableTarget = TunableTarget.new()
	var property: GFRuntimeTunableProperty = GFRuntimeTunableProperty.new(
		&"speed",
		^"speed",
		GFRuntimeTunableProperty.ValueKind.FLOAT
	)
	property.label = "Move Speed"
	var _property_with_range: GFRuntimeTunableProperty = property.with_range(0.0, 10.0, 0.1)
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


# --- 内部类 ---

class TunableTarget:
	extends RefCounted

	var health: int = 10
	var speed: float = 1.0
	var enabled: bool = true


class FloatState:
	extends RefCounted

	var value: float = 0.0
