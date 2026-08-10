## GFFlowContext: 通用流程图执行上下文。
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

const _REPORT_SCHEMA_PROJECTION = preload(
	"res://addons/gf/kernel/core/gf_report_schema_projection.gd"
)


# --- 公共变量 ---

## 共享数据表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema values: 流程执行期间共享的项目自定义 Dictionary；键通常为 StringName，值由项目决定。
var values: Dictionary = {}

## 下一个节点覆盖。流程节点可写入该列表动态控制分支。
## [br]
## @api public
## [br]
## @since 3.17.0
var next_node_ids: PackedStringArray = PackedStringArray()

## 是否显式覆盖了下一个节点。允许节点用空列表表达“停止继续推进”。
## [br]
## @api public
## [br]
## @since 3.17.0
var has_next_node_override: bool = false


# --- 私有变量 ---

var _architecture_ref: WeakRef = null
var _condition_handlers: Dictionary = {}
var _node_runtime_states: Dictionary = {}


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
	return GFVariantData.get_option_value(values, key, default_value)


## 覆盖当前节点执行后的下一个节点列表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_ids: 节点标识列表。
func set_next_nodes(node_ids: PackedStringArray) -> void:
	next_node_ids = node_ids.duplicate()
	has_next_node_override = true


## 检查当前节点是否显式覆盖了后继节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 已覆盖返回 true。
func has_next_nodes_override() -> bool:
	return has_next_node_override


## 清空下一个节点覆盖。
## [br]
## @api public
## [br]
## @since 3.17.0
func clear_next_nodes() -> void:
	next_node_ids.clear()
	has_next_node_override = false


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
		return _make_condition_result(false, condition_id, default_value, "condition_id_is_empty")
	if not _condition_handlers.has(condition_id):
		return _make_condition_result(false, condition_id, default_value, "missing_condition_handler")

	var handler: Callable = _get_callable_value(GFVariantData.get_option_value(_condition_handlers, condition_id, Callable()))
	if not handler.is_valid():
		return _make_condition_result(false, condition_id, default_value, "invalid_condition_handler")

	var raw_result: Variant = handler.call(condition_id, payload, self)
	return _normalize_condition_result(condition_id, raw_result, default_value)


## 写入指定流程节点的运行态值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_id: 节点标识。
## [br]
## @param key: 运行态键。
## [br]
## @param value: 运行态值。
## [br]
## @schema value: 要写入指定节点运行态的任意项目值。
func set_node_runtime_value(node_id: StringName, key: StringName, value: Variant) -> void:
	if node_id == &"" or key == &"":
		return
	if not _node_runtime_states.has(node_id):
		_node_runtime_states[node_id] = {}
	var state: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_node_runtime_states, node_id, {}))
	state[key] = value


## 读取指定流程节点的运行态值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_id: 节点标识。
## [br]
## @param key: 运行态键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @schema default_value: 运行态缺失时返回的任意默认值。
## [br]
## @return: 运行态值或默认值。
## [br]
## @schema return: 节点运行态中的项目值，或传入的 default_value。
func get_node_runtime_value(node_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var state: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_node_runtime_states, node_id, {}))
	if state.is_empty():
		return default_value
	return GFVariantData.get_option_value(state, key, default_value)


## 清空节点运行态。node_id 为空时清空全部节点运行态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_id: 节点标识。
func clear_node_runtime_state(node_id: StringName = &"") -> void:
	if node_id == &"":
		_node_runtime_states.clear()
		return
	_erase_dictionary_key(_node_runtime_states, node_id)


## 创建 Flow 上下文运行快照。
##
## 快照包含共享 values、下一个节点覆盖和节点运行态。条件处理器是运行时 Callable，
## 不会被序列化；恢复快照时也不会修改当前已注册的条件处理器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 快照选项，支持 metadata、include_condition_handler_ids 和 json_compatible。
## [br]
## @schema options: Dictionary，包含 metadata: Dictionary、include_condition_handler_ids: bool 与 json_compatible: bool。
## [br]
## @return: 运行快照。
## [br]
## @schema return: Dictionary，包含 values、next_node_ids、has_next_node_override、runtime_state、condition_handler_ids 和 metadata。
func create_runtime_snapshot(options: Dictionary = {}) -> Dictionary:
	var json_compatible: bool = GFVariantData.get_option_bool(options, "json_compatible", false)
	var snapshot: Dictionary = {
		"values": _to_snapshot_dictionary(values, json_compatible),
		"next_node_ids": _to_snapshot_value(next_node_ids, json_compatible),
		"has_next_node_override": has_next_node_override,
		"runtime_state": serialize_runtime_state(json_compatible),
		"metadata": _to_snapshot_dictionary(
			GFVariantData.get_option_dictionary(options, "metadata"),
			json_compatible
		),
	}
	if GFVariantData.get_option_bool(options, "include_condition_handler_ids", true):
		snapshot["condition_handler_ids"] = _to_snapshot_value(
			_get_condition_handler_ids(),
			json_compatible
		)
	return snapshot


## 恢复 Flow 上下文运行快照。
##
## 只恢复可序列化运行数据，不覆盖 architecture 或条件处理器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param snapshot: create_runtime_snapshot() 生成的快照。
## [br]
## @schema snapshot: Dictionary，包含 values、next_node_ids、has_next_node_override 和 runtime_state。
## [br]
## @return: 快照有效并完成恢复时返回 true。
func restore_runtime_snapshot(snapshot: Dictionary) -> bool:
	var parsed: Dictionary = _parse_runtime_snapshot(snapshot)
	if not GFVariantData.get_option_bool(parsed, "valid", false):
		return false

	values = GFVariantData.get_option_dictionary(parsed, "values").duplicate(true)
	next_node_ids = GFVariantData.get_option_packed_string_array(parsed, "next_node_ids")
	has_next_node_override = GFVariantData.get_option_bool(parsed, "has_next_node_override")
	_node_runtime_states = GFVariantData.get_option_dictionary(parsed, "node_states").duplicate(true)
	return true


## 序列化上下文持有的节点运行态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param json_compatible: 为 true 时输出 JSON-safe 报告值；默认为 false，保留运行时原始 Variant。
## [br]
## @return: 运行态快照。
## [br]
## @schema return: 包含 nodes 字段的 Dictionary；nodes 按 node_id 保存节点运行态 Dictionary。
func serialize_runtime_state(json_compatible: bool = false) -> Dictionary:
	var node_states: Dictionary = {}
	for node_id: Variant in _node_runtime_states.keys():
		var runtime_state: Dictionary = GFVariantData.as_dictionary(_node_runtime_states[node_id])
		var state_key: Variant = node_id
		if json_compatible:
			state_key = GFVariantData.to_text(node_id)
		node_states[state_key] = _to_snapshot_dictionary(runtime_state, json_compatible)
	var state: Dictionary = {
		"nodes": node_states,
	}
	return state


## 反序列化节点运行态到当前上下文。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param data: 运行态快照。
## [br]
## @schema data: serialize_runtime_state() 返回的运行态 Dictionary。
func deserialize_runtime_state(data: Dictionary) -> void:
	var parsed: Dictionary = _parse_node_runtime_states(data)
	if not GFVariantData.get_option_bool(parsed, "valid", false):
		push_error("[GFFlowContext] deserialize_runtime_state 失败：nodes 必须是节点 ID 到 Dictionary 的映射。")
		return
	_node_runtime_states = GFVariantData.get_option_dictionary(parsed, "node_states").duplicate(true)


# --- 框架内部方法 ---

## 获取单个节点运行态的隔离副本，供 Flow Runner 避免复制完整 Context。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param node_id: 节点标识。
## [br]
## @return: 节点运行态的深拷贝；不存在时为空字典。
## [br]
## @schema return: 指定节点的项目运行态 Dictionary。
func get_node_runtime_state_snapshot(node_id: StringName) -> Dictionary:
	var state_value: Variant = GFVariantData.get_option_value(_node_runtime_states, node_id, {})
	if not (state_value is Dictionary):
		return {}
	var state: Dictionary = state_value
	return state.duplicate(true)


## 原子替换单个节点运行态，供 Flow Runner 写回隔离执行结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param node_id: 节点标识。
## [br]
## @param state: 新运行态；空字典表示删除该节点状态。
## [br]
## @schema state: 指定节点的项目运行态 Dictionary。
func replace_node_runtime_state(node_id: StringName, state: Dictionary) -> void:
	if node_id == &"":
		return
	if state.is_empty():
		_erase_dictionary_key(_node_runtime_states, node_id)
		return
	_node_runtime_states[node_id] = state.duplicate(true)


# --- 私有/辅助方法 ---

func _parse_runtime_snapshot(snapshot: Dictionary) -> Dictionary:
	if (
		not snapshot.has("values")
		or not snapshot.has("next_node_ids")
		or not snapshot.has("has_next_node_override")
	):
		return {}
	var values_value: Variant = snapshot["values"]
	var next_node_ids_value: Variant = snapshot["next_node_ids"]
	var override_value: Variant = snapshot["has_next_node_override"]
	if (
		not (values_value is Dictionary)
		or not (next_node_ids_value is PackedStringArray)
		or typeof(override_value) != TYPE_BOOL
	):
		return {}

	var runtime_state: Dictionary = {}
	if snapshot.has("runtime_state"):
		var runtime_state_value: Variant = snapshot["runtime_state"]
		if not (runtime_state_value is Dictionary):
			return {}
		runtime_state = runtime_state_value
	elif snapshot.has("nodes"):
		var legacy_nodes_value: Variant = snapshot["nodes"]
		if not (legacy_nodes_value is Dictionary):
			return {}
		runtime_state = {"nodes": legacy_nodes_value}
	else:
		return {}

	var parsed_runtime_state: Dictionary = _parse_node_runtime_states(runtime_state)
	if not GFVariantData.get_option_bool(parsed_runtime_state, "valid", false):
		return {}
	var parsed_values: Dictionary = values_value
	var parsed_next_node_ids: PackedStringArray = next_node_ids_value
	return {
		"valid": true,
		"values": parsed_values.duplicate(true),
		"next_node_ids": parsed_next_node_ids.duplicate(),
		"has_next_node_override": override_value,
		"node_states": GFVariantData.get_option_dictionary(parsed_runtime_state, "node_states"),
	}


func _parse_node_runtime_states(data: Dictionary) -> Dictionary:
	if not data.has("nodes"):
		return {}
	var node_states_value: Variant = data["nodes"]
	if not (node_states_value is Dictionary):
		return {}
	var node_states: Dictionary = node_states_value
	var normalized: Dictionary = {}
	for node_id_variant: Variant in node_states.keys():
		var node_id: StringName = GFVariantData.to_string_name(node_id_variant)
		var state_value: Variant = node_states[node_id_variant]
		if node_id == &"" or not (state_value is Dictionary):
			return {}
		var state: Dictionary = state_value
		if not state.is_empty():
			normalized[node_id] = state.duplicate(true)
	return {
		"valid": true,
		"node_states": normalized,
	}

func _normalize_condition_result(condition_id: StringName, raw_result: Variant, default_value: Variant) -> Dictionary:
	if raw_result is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(raw_result)
		return {
			"ok": GFVariantData.get_option_bool(data, "ok", true),
			"condition_id": condition_id,
			"value": GFVariantData.get_option_value(data, "value", default_value),
			"reason": GFVariantData.get_option_string(data, "reason", GFVariantData.get_option_string(data, "error", "")),
			"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
		}
	if raw_result == null:
		return _make_condition_result(true, condition_id, default_value, "")
	return _make_condition_result(true, condition_id, raw_result, "")


func _make_condition_result(ok: bool, condition_id: StringName, value: Variant, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"condition_id": condition_id,
		"value": value,
		"reason": reason,
		"metadata": {},
	}


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _to_snapshot_dictionary(value: Dictionary, json_compatible: bool) -> Dictionary:
	if not json_compatible:
		return value.duplicate(true)
	return _REPORT_SCHEMA_PROJECTION.to_report_dictionary(value, {
		"path_redaction": "basename",
	})


func _to_snapshot_value(value: Variant, json_compatible: bool) -> Variant:
	if not json_compatible:
		return GFVariantData.duplicate_variant(value)
	return GFReportValueCodec.to_json_compatible(value, {
		"path_redaction": "basename",
	})


func _get_condition_handler_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for condition_id: Variant in _condition_handlers.keys():
		var text: String = GFVariantData.to_text(condition_id)
		if text.is_empty():
			continue
		var _appended: bool = ids.append(text)
	ids.sort()
	return ids


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return
