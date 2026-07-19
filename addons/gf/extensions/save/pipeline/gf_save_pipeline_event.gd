## GFSavePipelineEvent: 存档图流程事件。
##
## 用于描述 GFSaveGraphUtility 在采集/应用过程中的通用阶段、Scope、Source
## 与诊断信息。事件本身不携带业务字段，项目层可通过 payload 扩展。
## [br]
## @api public
## [br]
## @category event_contract
## [br]
## @since 3.17.0
class_name GFSavePipelineEvent
extends RefCounted


# --- 公共变量 ---

## 流程阶段标识。
## [br]
## @api public
## [br]
## @since 3.17.0
var stage: StringName = &""

## 事件严重级别，建议使用 info/warning/error。
## [br]
## @api public
## [br]
## @since 3.17.0
var severity: StringName = &"info"

## 事件关联的作用域键。
## [br]
## @api public
## [br]
## @since 3.17.0
var scope_key: StringName = &""

## 事件关联的来源键。
## [br]
## @api public
## [br]
## @since 3.17.0
var source_key: StringName = &""

## 事件关联节点路径。
## [br]
## @api public
## [br]
## @since 3.17.0
var node_path: String = ""

## 面向调试的短消息。
## [br]
## @api public
## [br]
## @since 3.17.0
var message: String = ""

## 附加通用载荷。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: Dictionary，项目或流程步骤附加的诊断字段。
var payload: Dictionary = {}

## 事件创建时间。
## [br]
## @api public
## [br]
## @since 3.17.0
var timestamp_msec: int = 0


# --- 公共方法 ---

## 配置事件内容并返回自身。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param p_stage: 流程阶段。
## [br]
## @param scope: 可选 Scope 或节点对象。
## [br]
## @param source: 可选 Source 或节点对象。
## [br]
## @param p_message: 调试消息。
## [br]
## @param p_payload: 附加载荷。
## [br]
## @param p_severity: 严重级别。
## [br]
## @param p_timestamp_msec: 调用方提供的单调时间戳；0 表示未提供。
## [br]
## @return 当前事件。
## [br]
## @schema p_payload: Dictionary，项目或流程步骤附加的诊断字段。
func configure(
	p_stage: StringName,
	scope: Object = null,
	source: Object = null,
	p_message: String = "",
	p_payload: Dictionary = {},
	p_severity: StringName = &"info",
	p_timestamp_msec: int = 0
) -> GFSavePipelineEvent:
	stage = p_stage
	severity = p_severity
	message = p_message
	payload = p_payload.duplicate(true)
	timestamp_msec = maxi(p_timestamp_msec, 0)

	_apply_scope(scope)
	_apply_source(source)
	return self


## 转换为 Dictionary，便于日志、存档或测试断言。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 事件字典。
## [br]
## @schema return: Dictionary，包含 stage、severity、scope_key、source_key、node_path、message、JSON-safe payload 与 timestamp_msec。
func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"severity": severity,
		"scope_key": scope_key,
		"source_key": source_key,
		"node_path": node_path,
		"message": message,
		"payload": GFReportValueCodec.to_report_dictionary(payload, {
			"path_redaction": "basename",
		}),
		"timestamp_msec": timestamp_msec,
	}


## 从 Dictionary 恢复事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param data: 事件字典。
## [br]
## @return 新事件。
## [br]
## @schema data: Dictionary，可包含 stage、severity、scope_key、source_key、node_path、message、payload 与 timestamp_msec。
static func from_dict(data: Dictionary) -> GFSavePipelineEvent:
	var event: GFSavePipelineEvent = GFSavePipelineEvent.new()
	event.stage = GFVariantData.get_option_string_name(data, "stage")
	event.severity = GFVariantData.get_option_string_name(data, "severity", &"info")
	event.scope_key = GFVariantData.get_option_string_name(data, "scope_key")
	event.source_key = GFVariantData.get_option_string_name(data, "source_key")
	event.node_path = GFVariantData.get_option_string(data, "node_path")
	event.message = GFVariantData.get_option_string(data, "message")
	var payload_data: Dictionary = GFVariantData.get_option_dictionary(data, "payload")
	event.payload = payload_data.duplicate(true)
	event.timestamp_msec = GFVariantData.get_option_int(data, "timestamp_msec")
	return event


# --- 私有/辅助方法 ---

func _apply_scope(scope: Object) -> void:
	if scope == null:
		return
	if scope.has_method("get_scope_key"):
		scope_key = GFVariantData.to_string_name(scope.call("get_scope_key"))
	if scope is Node:
		var scope_node: Node = scope
		node_path = _get_node_path(scope_node)


func _apply_source(source: Object) -> void:
	if source == null:
		return
	if source.has_method("get_source_key"):
		source_key = GFVariantData.to_string_name(source.call("get_source_key"))
	if source is Node:
		var source_node: Node = source
		node_path = _get_node_path(source_node)


func _get_node_path(node: Node) -> String:
	if node.is_inside_tree():
		return String(node.get_path())
	return node.name
