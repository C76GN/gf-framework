## GFAnalyticsSchemaRegistry: 精确版本 Analytics 事件 Schema 注册表。
##
## 注册表以 event_name 与 schema_version 的组合保存隔离副本，
## 禁止同版本覆盖，也不提供隐式 latest 回退。公开 getter 再返回副本，
## 避免调用方通过可变 Resource 改写已经注册的契约。单个 Registry 最多保存
## 1024 个 Schema、同一事件最多 32 个精确版本，并对定义图、辅助值和文本执行
## 累计硬预算；只接受内置声明式 EventSchema、DictionarySchema、Field 和规则脚本。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFAnalyticsSchemaRegistry
extends Resource


# --- 常量 ---

const _MAX_SCHEMA_COUNT: int = 1024
const _MAX_VERSIONS_PER_EVENT: int = 32
const _MAX_SCHEMA_VERSION: int = 2_147_483_647
const _MAX_TOTAL_GRAPH_NODES: int = 65_536
const _MAX_TOTAL_AUXILIARY_NODES: int = 131_072
const _MAX_TOTAL_TEXT_BYTES: int = 16 * 1024 * 1024
const _GF_ANALYTICS_EVENT_SCHEMA_SCRIPT = preload(
	"res://addons/gf/standard/utilities/analytics/gf_analytics_event_schema.gd"
)


# --- 私有变量 ---

var _schemas_by_event: Dictionary = {}
var _schema_count: int = 0
var _registered_graph_nodes: int = 0
var _registered_auxiliary_nodes: int = 0
var _registered_text_bytes: int = 0


# --- 公共方法 ---

## 注册一个事件 Schema 的隔离副本。
## [br]
## 同一事件的同一版本只能注册一次；无效定义、容量超限或版本重复都会失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param schema: 待注册事件 Schema。
## [br]
## @return 注册结果。
## [br]
## @schema return: Dictionary with ok, reason, event_name, schema_version, registered_count, and validation.
func register_schema(schema: GFAnalyticsEventSchema) -> Dictionary:
	if schema == null:
		var missing_report: GFValidationReport = GFValidationReport.new(
			"GFAnalyticsSchemaRegistry.register_schema"
		)
		var _missing_issue: RefCounted = missing_report.add_error(
			&"missing_schema",
			"Analytics event schema is required."
		)
		return _make_registration_result(false, "invalid_schema", &"", 0, missing_report)
	if schema.get_script() != _GF_ANALYTICS_EVENT_SCHEMA_SCRIPT:
		var unsupported_report: GFValidationReport = GFValidationReport.new(
			"GFAnalyticsSchemaRegistry.register_schema"
		)
		var _unsupported_issue: RefCounted = unsupported_report.add_error(
			&"unsupported_schema_definition_type",
			"Analytics registry only accepts the built-in GFAnalyticsEventSchema script."
		)
		return _make_registration_result(
			false,
			"invalid_schema",
			schema.event_name,
			schema.schema_version,
			unsupported_report
		)

	var validation_report: GFValidationReport = schema.validate_definition()
	if not validation_report.is_ok():
		return _make_registration_result(
			false,
			"invalid_schema",
			schema.event_name,
			schema.schema_version,
			validation_report
		)

	var bucket: Dictionary = _get_event_bucket(schema.event_name)
	if bucket.has(schema.schema_version):
		return _make_registration_failure(
			&"already_registered",
			"Analytics event schema version is already registered.",
			schema
		)
	if _schema_count >= _MAX_SCHEMA_COUNT:
		return _make_registration_failure(
			&"registry_full",
			"Analytics schema registry is full.",
			schema,
			{
				"max_schema_count": _MAX_SCHEMA_COUNT,
			}
		)
	if bucket.size() >= _MAX_VERSIONS_PER_EVENT:
		return _make_registration_failure(
			&"version_limit_reached",
			"Analytics event schema version limit is reached.",
			schema,
			{
				"max_versions_per_event": _MAX_VERSIONS_PER_EVENT,
			}
		)

	var footprint: Dictionary = schema.get_validated_definition_footprint_for_framework()
	var graph_nodes: int = GFVariantData.get_option_int(footprint, "graph_nodes")
	var auxiliary_nodes: int = GFVariantData.get_option_int(footprint, "auxiliary_nodes")
	var text_bytes: int = GFVariantData.get_option_int(footprint, "text_bytes")
	if (
		_registered_graph_nodes + graph_nodes > _MAX_TOTAL_GRAPH_NODES
		or _registered_auxiliary_nodes + auxiliary_nodes > _MAX_TOTAL_AUXILIARY_NODES
		or _registered_text_bytes + text_bytes > _MAX_TOTAL_TEXT_BYTES
	):
		return _make_registration_failure(
			&"registry_budget_exceeded",
			"Analytics schema registry footprint budget would be exceeded.",
			schema,
			{
				"registered_graph_nodes": _registered_graph_nodes,
				"registered_auxiliary_nodes": _registered_auxiliary_nodes,
				"registered_text_bytes": _registered_text_bytes,
				"requested_graph_nodes": graph_nodes,
				"requested_auxiliary_nodes": auxiliary_nodes,
				"requested_text_bytes": text_bytes,
				"max_total_graph_nodes": _MAX_TOTAL_GRAPH_NODES,
				"max_total_auxiliary_nodes": _MAX_TOTAL_AUXILIARY_NODES,
				"max_total_text_bytes": _MAX_TOTAL_TEXT_BYTES,
			}
		)

	var stored_schema: GFAnalyticsEventSchema = schema.duplicate_schema()
	bucket[schema.schema_version] = stored_schema
	_schemas_by_event[schema.event_name] = bucket
	_schema_count += 1
	_registered_graph_nodes += graph_nodes
	_registered_auxiliary_nodes += auxiliary_nodes
	_registered_text_bytes += text_bytes
	return _make_registration_result(
		true,
		"registered",
		schema.event_name,
		schema.schema_version,
		validation_report
	)


## 检查精确事件 Schema 版本是否存在。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event_name: 稳定事件名。
## [br]
## @param schema_version: 1..2_147_483_647 范围内的精确版本。
## [br]
## @return 已注册时返回 true。
func has_schema(event_name: StringName, schema_version: int) -> bool:
	if event_name == &"" or schema_version <= 0 or schema_version > _MAX_SCHEMA_VERSION:
		return false
	return _get_event_bucket(event_name).has(schema_version)


## 获取精确事件 Schema 版本的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event_name: 稳定事件名。
## [br]
## @param schema_version: 1..2_147_483_647 范围内的精确版本。
## [br]
## @return 已注册 Schema 的副本；不存在时返回 null。
func get_schema(
	event_name: StringName,
	schema_version: int
) -> GFAnalyticsEventSchema:
	var stored_schema: GFAnalyticsEventSchema = _get_stored_schema(event_name, schema_version)
	if stored_schema == null:
		return null
	return stored_schema.duplicate_schema()


## 获取事件已经注册的版本列表。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event_name: 稳定事件名。
## [br]
## @return 升序版本数组。
func get_versions(event_name: StringName) -> PackedInt32Array:
	var versions: PackedInt32Array = PackedInt32Array()
	var bucket: Dictionary = _get_event_bucket(event_name)
	for version_value: Variant in bucket.keys():
		if version_value is int:
			var version: int = version_value
			var _version_appended: bool = versions.append(version)
	versions.sort()
	return versions


## 使用精确注册版本校验事件属性。
## [br]
## 版本不存在时返回 schema_not_registered，不会自动选择其他版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event_name: 稳定事件名。
## [br]
## @param schema_version: 1..2_147_483_647 范围内的精确版本。
## [br]
## @param properties: 编码前事件属性。
## [br]
## @param options: 传给事件 Schema 的校验上下文与预算。
## [br]
## @return 校验报告。
## [br]
## @schema properties: Dictionary analytics event properties before report encoding.
## [br]
## @schema options: Dictionary validation context and bounded traversal options.
func validate(
	event_name: StringName,
	schema_version: int,
	properties: Dictionary,
	options: Dictionary = {}
) -> GFValidationReport:
	var stored_schema: GFAnalyticsEventSchema = _get_stored_schema(event_name, schema_version)
	if stored_schema == null:
		var missing_report: GFValidationReport = GFValidationReport.new(
			"analytics:%s@%d" % [String(event_name), schema_version],
			{
				"event_name": String(event_name),
				"schema_version": schema_version,
			}
		)
		var _missing_issue: RefCounted = missing_report.add_error(
			&"schema_not_registered",
			"Exact analytics event schema version is not registered.",
			String(event_name),
			"properties",
			{
				"event_name": String(event_name),
				"schema_version": schema_version,
			}
		)
		return missing_report
	return stored_schema.validate_registered_properties_for_framework(properties, options)


## 获取不含业务属性和默认值的调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 注册表调试信息。
## [br]
## @schema return: Dictionary with event_count, schema_count, registered footprint counters, registry limits, and events; each event contains event_name and versions.
func get_debug_snapshot() -> Dictionary:
	var event_names: PackedStringArray = PackedStringArray()
	for event_key: Variant in _schemas_by_event.keys():
		var event_name_text: String = GFVariantData.to_text(event_key)
		var _event_name_appended: bool = event_names.append(event_name_text)
	event_names.sort()

	var event_summaries: Array[Dictionary] = []
	for event_name_text: String in event_names:
		event_summaries.append({
			"event_name": event_name_text,
			"versions": get_versions(StringName(event_name_text)),
		})
	return {
		"event_count": _schemas_by_event.size(),
		"schema_count": _schema_count,
		"max_schema_count": _MAX_SCHEMA_COUNT,
		"max_versions_per_event": _MAX_VERSIONS_PER_EVENT,
		"registered_graph_nodes": _registered_graph_nodes,
		"registered_auxiliary_nodes": _registered_auxiliary_nodes,
		"registered_text_bytes": _registered_text_bytes,
		"max_total_graph_nodes": _MAX_TOTAL_GRAPH_NODES,
		"max_total_auxiliary_nodes": _MAX_TOTAL_AUXILIARY_NODES,
		"max_total_text_bytes": _MAX_TOTAL_TEXT_BYTES,
		"events": event_summaries,
	}


# --- 私有/辅助方法 ---

func _get_event_bucket(event_name: StringName) -> Dictionary:
	var bucket_value: Variant = _schemas_by_event.get(event_name)
	if bucket_value is Dictionary:
		var bucket: Dictionary = bucket_value
		return bucket
	return {}


func _get_stored_schema(
	event_name: StringName,
	schema_version: int
) -> GFAnalyticsEventSchema:
	if event_name == &"" or schema_version <= 0 or schema_version > _MAX_SCHEMA_VERSION:
		return null
	var bucket: Dictionary = _get_event_bucket(event_name)
	var schema_value: Variant = bucket.get(schema_version)
	if schema_value is GFAnalyticsEventSchema:
		var stored_schema: GFAnalyticsEventSchema = schema_value
		return stored_schema
	return null


func _make_registration_failure(
	kind: StringName,
	message: String,
	schema: GFAnalyticsEventSchema,
	metadata: Dictionary = {}
) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new(
		"analytics:%s@%d" % [String(schema.event_name), schema.schema_version],
		{
			"event_name": String(schema.event_name),
			"schema_version": schema.schema_version,
		}
	)
	var issue_metadata: Dictionary = metadata.duplicate(true)
	issue_metadata["event_name"] = String(schema.event_name)
	issue_metadata["schema_version"] = schema.schema_version
	var _failure_issue: RefCounted = report.add_error(
		kind,
		message,
		String(schema.event_name),
		"properties",
		issue_metadata
	)
	return _make_registration_result(
		false,
		String(kind),
		schema.event_name,
		schema.schema_version,
		report
	)


func _make_registration_result(
	ok: bool,
	reason: String,
	event_name: StringName,
	schema_version: int,
	validation_report: GFValidationReport
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"event_name": String(event_name),
		"schema_version": schema_version,
		"registered_count": _schema_count,
		"validation": validation_report.to_dict(),
	}
