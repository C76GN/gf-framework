## GFFlowContext: 各次流程运行共享的业务上下文。
##
## 用于在流程节点之间共享数据，并提供可选的 GFArchitecture 访问入口。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFFlowContext
extends RefCounted


# --- 常量 ---

## 将上下文快照投影为安全报告数据的 schema 工具脚本。
## [br]
## @api private
const _REPORT_SCHEMA_PROJECTION = preload("res://addons/gf/kernel/core/gf_report_schema_projection.gd")


# --- 公共变量 ---

## 共享数据表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema values: 流程执行期间共享的项目自定义 Dictionary；键通常为 StringName，值由项目决定。
var values: Dictionary = {}


# --- 私有变量 ---

## 弱引用运行此反馈流程的架构。
## [br]
## @api private
var _architecture_ref: WeakRef = null

## 按 condition ID 保存可调用条件处理器。
## [br]
## @api private
var _condition_handlers: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture = null, p_values: Dictionary = {}) -> void:
	values = p_values.duplicate(true)
	set_architecture(architecture)


# --- 公共方法 ---

## 设置上下文所属架构。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param architecture: 架构实例。
func set_architecture(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 获取上下文所属架构。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 架构实例；不可用时返回 null。
func get_architecture() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	return GFAutoload.get_architecture_or_null()


## 写入共享值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param key: 键。
## [br]
## @param value: 值。
## [br]
## @schema value: 要写入 values 的任意项目值。
## [br]
## @return: 当前上下文，便于链式构造。
func set_value(key: StringName, value: Variant) -> GFFlowContext:
	values[key] = value
	return self


## 读取共享值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param key: 键。
## [br]
## @param default_value: 默认值。
## [br]
## @schema default_value: key 缺失时返回的任意默认值。
## [br]
## @return: 共享值或默认值。
## [br]
## @schema return: values 中的项目值，或传入的 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(
		values,
		key,
		default_value
	)


## 注册条件查询处理器。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param condition_id: 条件标识。
## [br]
## @param handler: 查询回调，建议签名为 func(condition_id: StringName, payload: Variant, context: GFFlowContext) -> Variant。
## [br]
## @return: 注册成功返回 true。
func register_condition_handler(condition_id: StringName, handler: Callable) -> bool:
	if condition_id == &"" or not handler.is_valid():
		return false
	_condition_handlers[condition_id] = handler
	return true


## 注销条件查询处理器。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param condition_id: 条件标识。
func unregister_condition_handler(condition_id: StringName) -> void:
	_erase_dictionary_key(_condition_handlers, condition_id)


## 检查条件查询处理器是否存在。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param condition_id: 条件标识。
## [br]
## @return: 存在返回 true。
func has_condition_handler(condition_id: StringName) -> bool:
	return _condition_handlers.has(condition_id)


## 清空所有条件查询处理器。
## [br]
## @api public
## [br]
## @since 3.17.0
func clear_condition_handlers() -> void:
	_condition_handlers.clear()


## 查询条件值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param condition_id: 条件标识。
## [br]
## @param payload: 调用方传入的载荷。
## [br]
## @schema payload: 条件处理器接收的任意项目载荷；框架只透传。
## [br]
## @param default_value: 缺失处理器或处理器未返回值时使用的默认值。
## [br]
## @schema default_value: 缺失处理器或处理器未返回值时使用的任意默认值。
## [br]
## @return: 统一条件查询结果。
## [br]
## @schema return: 包含 ok、condition_id、value、reason 和 metadata 字段的 Dictionary。
func query_condition(
	condition_id: StringName,
	payload: Variant = null,
	default_value: Variant = false
) -> Dictionary:
	if condition_id == &"":
		return _make_condition_result(
			false,
			condition_id,
			default_value,
			"condition_id_is_empty"
		)
	if not _condition_handlers.has(condition_id):
		return _make_condition_result(
			false,
			condition_id,
			default_value,
			"missing_condition_handler"
		)

	var handler: Callable = _get_callable_value(
		GFVariantData.get_option_value(
			_condition_handlers,
			condition_id,
			Callable()
		)
	)
	if not handler.is_valid():
		return _make_condition_result(
			false,
			condition_id,
			default_value,
			"invalid_condition_handler"
		)

	var raw_result: Variant = handler.call(
		condition_id,
		payload,
		self
	)
	return _normalize_condition_result(
		condition_id,
		raw_result,
		default_value
	)


## 捕获业务值和可选条件处理器标识。JSON 投影供日志使用，原始值副本供项目保存。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 可提供 json_compatible、include_condition_handler_ids 和 metadata。
## [br]
## @schema options: 可选布尔开关与项目附加的 metadata 字典。
## [br]
## @return: 独立业务数据快照。
## [br]
## @schema return: 包含 values、metadata 以及可选 condition_handler_ids。
func create_data_snapshot(options: Dictionary = {}) -> Dictionary:
	var json_compatible: bool = GFVariantData.get_option_bool(options, "json_compatible")
	var result: Dictionary = {
		"values": _to_snapshot_dictionary(values, json_compatible),
		"metadata": _to_snapshot_dictionary(
			GFVariantData.get_option_dictionary(options, "metadata"),
			json_compatible
		),
	}
	if GFVariantData.get_option_bool(
		options,
		"include_condition_handler_ids",
		true
	):
		result["condition_handler_ids"] = _to_snapshot_value(
			_get_condition_handler_ids(),
			json_compatible
		)
	return result


# --- 私有/辅助方法 ---

## 将条件处理器的多种返回值转换为统一结果字典。
## [br]
## @api private
func _normalize_condition_result(
	condition_id: StringName,
	raw_result: Variant,
	default_value: Variant
) -> Dictionary:
	if raw_result is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(raw_result)
		return {
			"ok": GFVariantData.get_option_bool(
				data,
				"ok",
				true
			),
			"condition_id": condition_id,
			"value": GFVariantData.get_option_value(
				data,
				"value",
				default_value
			),
			"reason": GFVariantData.get_option_string(
				data,
				"reason",
				GFVariantData.get_option_string(
					data,
					"error",
					""
				)
			),
			"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
		}
	if raw_result == null:
		return _make_condition_result(
			true,
			condition_id,
			default_value,
			""
		)
	return _make_condition_result(
		true,
		condition_id,
		raw_result,
		""
	)


## 构造包含状态、条件 ID、值、原因和元数据的条件结果。
## [br]
## @api private
func _make_condition_result(
	ok: bool,
	condition_id: StringName,
	value: Variant,
	reason: String
) -> Dictionary:
	return {
		"ok": ok,
		"condition_id": condition_id,
		"value": value,
		"reason": reason,
		"metadata": {},
	}


## 将 Variant 转换为 Callable，类型不符时返回空回调。
## [br]
## @api private
func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


## 复制快照字典，或按 JSON-safe 报告规则投影。
## [br]
## @api private
func _to_snapshot_dictionary(value: Dictionary, json_compatible: bool) -> Dictionary:
	if not json_compatible:
		return value.duplicate(true)
	return _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
		value,
		{ "path_redaction": "basename", }
	)


## 复制快照值，或将值转换为 JSON 兼容形式。
## [br]
## @api private
func _to_snapshot_value(value: Variant, json_compatible: bool) -> Variant:
	if not json_compatible:
		return GFVariantData.duplicate_variant(value)
	return GFReportValueCodec.to_json_compatible(
		value,
		{ "path_redaction": "basename", }
	)


## 读取并排序已注册条件处理器 ID。
## [br]
## @api private
func _get_condition_handler_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for condition_id: Variant in _condition_handlers.keys():
		var text: String = GFVariantData.to_text(condition_id)
		if text.is_empty():
			continue
		var _appended: bool = ids.append(text)
	ids.sort()
	return ids


## 从字典移除指定键。
## [br]
## @api private
func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return
