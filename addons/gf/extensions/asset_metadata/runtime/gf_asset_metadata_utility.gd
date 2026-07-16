## GFAssetMetadataUtility: 资产元数据收集与查询工具。
##
## 统一管理导入资产元数据在 Object metadata 中的存储键、复制规则和节点树收集流程。
## 它不解释任何项目字段；业务语义应由项目代码或项目扩展消费。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFAssetMetadataUtility
extends GFUtility


# --- 常量 ---

## Object metadata 中保存 GF 资产元数据的默认键。
## [br]
## @api public
const META_ASSET_METADATA: StringName = &"gf_asset_metadata"

## Object metadata 中保存元数据来源说明的默认键。
## [br]
## @api public
const META_ASSET_METADATA_SOURCE: StringName = &"gf_asset_metadata_source"

## 对象不存在 GF 资产元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
const METADATA_STATE_ABSENT: StringName = &"absent"

## 对象带有显式空 GF 资产元数据标记。
## [br]
## @api public
## [br]
## @since 8.0.0
const METADATA_STATE_EMPTY: StringName = &"empty"

## 对象带有非空 GF 资产元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
const METADATA_STATE_VALID: StringName = &"valid"

const _CUSTOM_SOURCE_KEY_SEPARATOR: String = "__"
const _HEX_DIGITS: String = "0123456789abcdef"


# --- 公共方法 ---

## 将任意导入元数据归一为 Dictionary。
## [br]
## @api public
## [br]
## @param value: 输入元数据。Dictionary 会深拷贝；其他非 null 值会保存在 value 字段中。
## [br]
## @schema value: Variant，Dictionary 会深拷贝；其他非 null 值会保存为 { "value": value }。
## [br]
## @return 归一化后的元数据字典。
## [br]
## @schema return: Dictionary，归一化后的资产元数据字段。
static func normalize_metadata(value: Variant) -> Dictionary:
	if value == null:
		return {}
	if value is Dictionary:
		return GFVariantData.to_dictionary(value)
	return {
		"value": GFVariantData.duplicate_variant(value),
	}


## 写入对象资产元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param target: 目标 Object。
## [br]
## @param metadata: 结构化元数据。
## [br]
## @param options: 可选项，支持 metadata_key、source_path、subject_path、subject_kind、metadata_source、mark_scanned_empty。
## [br]
## @schema metadata: Dictionary，要写入 Object metadata 的结构化资产元数据字段。
## [br]
## @schema options: Dictionary，可包含 metadata_key、source_path、subject_path、subject_kind、metadata_source 与 mark_scanned_empty；mark_scanned_empty 为 true 时显式保留空元数据标记。
## [br]
## @return 写入后的记录；目标无效时返回 null。
func write_object_metadata(
	target: Object,
	metadata: Dictionary,
	options: Dictionary = {}
) -> GFAssetMetadataRecord:
	if target == null:
		return null

	var metadata_key: StringName = _get_metadata_key(options)
	var normalized_metadata: Dictionary = normalize_metadata(metadata)
	if normalized_metadata.is_empty() and not GFVariantData.get_option_bool(options, "mark_scanned_empty", false):
		clear_object_metadata(target, {
			"metadata_key": metadata_key,
			"clear_source": true,
		})
		return _make_record_for_object(target, normalized_metadata, options)

	target.set_meta(metadata_key, normalized_metadata)

	var metadata_source: String = GFVariantData.get_option_string(options, "metadata_source")
	var source_key: StringName = _get_metadata_source_key(metadata_key)
	if not metadata_source.is_empty():
		target.set_meta(source_key, metadata_source)
	elif target.has_meta(source_key):
		target.remove_meta(source_key)

	return _make_record_for_object(target, normalized_metadata, options)


## 读取对象资产元数据。
## [br]
## @api public
## [br]
## @param target: 目标 Object。
## [br]
## @param options: 可选项，支持 metadata_key 或 metadata_keys。
## [br]
## @schema options: Dictionary，可包含 metadata_key 或 metadata_keys。
## [br]
## @return 元数据字典副本；不存在时返回空字典。
## [br]
## @schema return: Dictionary，读取到的结构化资产元数据字段。
func read_object_metadata(target: Object, options: Dictionary = {}) -> Dictionary:
	if target == null:
		return {}

	for metadata_key: StringName in _get_metadata_keys(options):
		if not target.has_meta(metadata_key):
			continue

		var value: Variant = target.get_meta(metadata_key)
		return normalize_metadata(value)
	return {}


## 读取对象资产元数据，并按通用 Dictionary schema 补默认值与可选转换。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param target: 目标 Object。
## [br]
## @param schema: 通用 Dictionary schema；为空时只返回普通读取结果。
## [br]
## @param options: 可选项，支持 read_object_metadata() 的参数，并额外支持 include_optional_defaults 和 coerce_values。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、include_optional_defaults 与 coerce_values。
## [br]
## @return 补齐后的元数据字典副本。
## [br]
## @schema return: Dictionary，按 schema 归一后的资产元数据字段。
func read_object_metadata_with_schema(
	target: Object,
	schema: GFDictionarySchema,
	options: Dictionary = {}
) -> Dictionary:
	var metadata: Dictionary = read_object_metadata(target, options)
	if schema == null:
		return metadata

	var include_optional: bool = GFVariantData.get_option_bool(options, "include_optional_defaults", true)
	var should_coerce: bool = GFVariantData.get_option_bool(options, "coerce_values", schema.coerce_values)
	return schema.apply_defaults(metadata, include_optional, should_coerce)


## 用通用 Dictionary schema 校验对象资产元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param target: 目标 Object。
## [br]
## @param schema: 通用 Dictionary schema。
## [br]
## @param options: 可选项，支持 read_object_metadata() 的参数，以及 source_path、subject、path。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject 和 path。
## [br]
## @return GFValidationReport 兼容字典。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、issues 等校验报告字段。
func validate_object_metadata(
	target: Object,
	schema: GFDictionarySchema,
	options: Dictionary = {}
) -> Dictionary:
	if schema == null:
		var missing_schema_report: GFValidationReport = GFValidationReport.new("Asset metadata")
		var _missing_schema_issue: RefCounted = missing_schema_report.add_error(
			&"missing_schema",
			"Metadata schema is null."
		)
		return _encode_report(missing_schema_report.to_dict())
	if target == null:
		var missing_target_report: GFValidationReport = GFValidationReport.new("Asset metadata")
		var _missing_target_issue: RefCounted = missing_target_report.add_error(
			&"missing_target",
			"Metadata target is null."
		)
		return _encode_report(missing_target_report.to_dict())

	var metadata: Dictionary = read_object_metadata(target, options)
	return _encode_report(
		schema.validate_dictionary(metadata, _make_schema_validation_options(target, options)).to_dict()
	)


## 检查对象是否带有资产元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param target: 目标 Object。
## [br]
## @param options: 可选项，支持 metadata_key 或 metadata_keys。
## [br]
## @schema options: Dictionary，可包含 metadata_key 或 metadata_keys。
## [br]
## @return 存在资产元数据时返回 true。
func has_object_metadata(target: Object, options: Dictionary = {}) -> bool:
	return get_object_metadata_state(target, options) != METADATA_STATE_ABSENT


## 获取对象资产元数据状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param target: 目标 Object。
## [br]
## @param options: 可选项，支持 metadata_key 或 metadata_keys。
## [br]
## @schema options: Dictionary，可包含 metadata_key 或 metadata_keys。
## [br]
## @return absent、empty 或 valid。
func get_object_metadata_state(target: Object, options: Dictionary = {}) -> StringName:
	if target == null:
		return METADATA_STATE_ABSENT
	for metadata_key: StringName in _get_metadata_keys(options):
		if not target.has_meta(metadata_key):
			continue
		var metadata: Dictionary = normalize_metadata(target.get_meta(metadata_key))
		if metadata.is_empty():
			return METADATA_STATE_EMPTY
		return METADATA_STATE_VALID
	return METADATA_STATE_ABSENT


## 清除对象资产元数据。
## [br]
## @api public
## [br]
## @param target: 目标 Object。
## [br]
## @param options: 可选项，支持 metadata_key 或 metadata_keys。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys 与 clear_source。
func clear_object_metadata(target: Object, options: Dictionary = {}) -> void:
	if target == null:
		return
	for metadata_key: StringName in _get_metadata_keys(options):
		if target.has_meta(metadata_key):
			target.remove_meta(metadata_key)
		var source_key: StringName = _get_metadata_source_key(metadata_key)
		if GFVariantData.get_option_bool(options, "clear_source", true) and target.has_meta(source_key):
			target.remove_meta(source_key)


## 收集节点树中的资产元数据记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth、max_nodes。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind、max_depth 与 max_nodes；max_nodes 小于 0 表示不限制。
## [br]
## @return 资产元数据记录列表。
func collect_node_tree(root: Node, options: Dictionary = {}) -> Array[GFAssetMetadataRecord]:
	var collection: Dictionary = _collect_node_tree_data(root, options)
	return _get_record_array(collection)


## 收集节点树中的资产元数据记录字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth、max_nodes。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind、max_depth、max_nodes 与 json_safe。
## [br]
## @return 资产元数据记录字典列表。
## [br]
## @schema return: Array[Dictionary]，每一项包含 source_path、subject_path、subject_kind 与 metadata 字段。
func collect_node_tree_dicts(root: Node, options: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var collection: Dictionary = _collect_node_tree_data(root, options)
	for record: GFAssetMetadataRecord in _get_record_array(collection):
		var record_data: Dictionary = record.to_dict()
		if GFVariantData.get_option_bool(options, "json_safe", false):
			record_data = _to_json_safe_dictionary(record_data)
		result.append(record_data)
	return result


## 构建节点树资产元数据报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 collect_node_tree() 的参数。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind、max_depth 与 max_nodes。
## [br]
## @return 报告字典。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、next_action、source_path、entry_count、entries、visited_node_count、max_nodes、truncated 与 issues。
func build_node_tree_report(root: Node, options: Dictionary = {}) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new("Asset metadata")
	if root == null:
		var _add_error_result_207: Variant = report.add_error(&"missing_root", "Root node is null.")
		return _encode_report(report.to_dict({}, _get_report_options()))

	var collect_options: Dictionary = options.duplicate(true)
	collect_options["json_safe"] = false
	var collection: Dictionary = _collect_node_tree_data(root, collect_options)
	var entries: Array[Dictionary] = _records_to_dicts(_get_record_array(collection), collect_options)
	return _encode_report(report.to_dict({
		"source_path": _get_source_path(root, options),
		"entry_count": entries.size(),
		"entries": entries,
		"visited_node_count": GFVariantData.get_option_int(collection, "visited_node_count"),
		"max_nodes": GFVariantData.get_option_int(collection, "max_nodes", -1),
		"truncated": GFVariantData.get_option_bool(collection, "truncated"),
	}, _get_report_options()))


# --- 私有/辅助方法 ---

func _collect_node_tree_data(root: Node, options: Dictionary) -> Dictionary:
	var records: Array[GFAssetMetadataRecord] = []
	if root == null:
		return {
			"records": records,
			"visited_node_count": 0,
			"max_nodes": GFVariantData.get_option_int(options, "max_nodes", -1),
			"truncated": false,
		}

	var max_depth: int = GFVariantData.get_option_int(options, "max_depth", -1)
	var max_nodes: int = GFVariantData.get_option_int(options, "max_nodes", -1)
	var visited_node_count: int = 0
	var truncated: bool = false
	var stack: Array[Dictionary] = [{
		"node": root,
		"depth": 0,
	}]

	while not stack.is_empty():
		if max_nodes >= 0 and visited_node_count >= max_nodes:
			truncated = true
			break

		var item_value: Variant = stack.pop_back()
		var item: Dictionary = GFVariantData.as_dictionary(item_value)
		var node: Node = _get_node_value(GFVariantData.get_option_value(item, "node"))
		if node == null:
			continue

		visited_node_count += 1
		var depth: int = GFVariantData.get_option_int(item, "depth")
		var metadata_state: StringName = get_object_metadata_state(node, options)
		if metadata_state != METADATA_STATE_ABSENT:
			var metadata: Dictionary = read_object_metadata(node, options)
			records.append(_make_record_for_node(root, node, metadata, options))

		if max_depth >= 0 and depth >= max_depth:
			continue

		var children: Array = node.get_children()
		for child_index: int in range(children.size() - 1, -1, -1):
			var child: Node = _get_node_value(children[child_index])
			if child == null:
				continue
			stack.append({
				"node": child,
				"depth": depth + 1,
			})

	return {
		"records": records,
		"visited_node_count": visited_node_count,
		"max_nodes": max_nodes,
		"truncated": truncated,
	}


func _get_record_array(collection: Dictionary) -> Array[GFAssetMetadataRecord]:
	var records: Array[GFAssetMetadataRecord] = []
	for record_value: Variant in GFVariantData.get_option_array(collection, "records"):
		if record_value is GFAssetMetadataRecord:
			var record: GFAssetMetadataRecord = record_value
			records.append(record)
	return records


func _records_to_dicts(records: Array[GFAssetMetadataRecord], options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: GFAssetMetadataRecord in records:
		var record_data: Dictionary = record.to_dict()
		if GFVariantData.get_option_bool(options, "json_safe", false):
			record_data = _to_json_safe_dictionary(record_data)
		result.append(record_data)
	return result


func _make_record_for_node(
	root: Node,
	node: Node,
	metadata: Dictionary,
	options: Dictionary
) -> GFAssetMetadataRecord:
	var subject_path: NodePath = NodePath(".")
	if root != node:
		subject_path = root.get_path_to(node)

	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configure_result_249: Variant = record.configure(
		_normalize_source_path(_get_source_path(root, options)),
		subject_path,
		GFVariantData.get_option_string_name(options, "subject_kind", &"node"),
		metadata
	)
	return record


func _make_record_for_object(
	_target: Object,
	metadata: Dictionary,
	options: Dictionary
) -> GFAssetMetadataRecord:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configure_result_264: Variant = record.configure(
		_normalize_source_path(GFVariantData.get_option_string(options, "source_path")),
		NodePath(GFVariantData.get_option_string(options, "subject_path", ".")),
		GFVariantData.get_option_string_name(options, "subject_kind", &"object"),
		metadata
	)
	return record


func _get_source_path(root: Node, options: Dictionary) -> String:
	var explicit_source_path: String = GFVariantData.get_option_string(options, "source_path")
	if not explicit_source_path.is_empty():
		return _normalize_source_path(explicit_source_path)
	if root != null and not root.scene_file_path.is_empty():
		return _normalize_source_path(root.scene_file_path)
	return ""


func _get_metadata_key(options: Dictionary) -> StringName:
	if options.has("metadata_key"):
		var metadata_key: StringName = GFVariantData.get_option_string_name(options, "metadata_key")
		if metadata_key != &"":
			return metadata_key
	return META_ASSET_METADATA


func _get_metadata_keys(options: Dictionary) -> Array[StringName]:
	if options.has("metadata_keys"):
		var configured_keys: Array[StringName] = []
		for key: StringName in GFVariantData.get_option_string_name_array(options, "metadata_keys"):
			_append_metadata_key(configured_keys, key)
		if configured_keys.is_empty():
			configured_keys.append(META_ASSET_METADATA)
		return configured_keys
	var result: Array[StringName] = []
	result.append(_get_metadata_key(options))
	return result


func _append_metadata_key(result: Array[StringName], key: StringName) -> void:
	if key != &"" and not result.has(key):
		result.append(key)


func _make_schema_validation_options(target: Object, options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	if not result.has("subject"):
		result["subject"] = "Asset metadata"
	if not result.has("path"):
		result["path"] = "metadata"
	if not result.has("source_path"):
		var source_path: String = GFVariantData.get_option_string(options, "source_path")
		if source_path.is_empty() and target is Node:
			var node: Node = target
			source_path = node.scene_file_path
		if not source_path.is_empty():
			result["source_path"] = _normalize_source_path(source_path)
	return result


func _get_metadata_source_key(metadata_key: StringName) -> StringName:
	if metadata_key == META_ASSET_METADATA:
		return META_ASSET_METADATA_SOURCE
	return StringName(
		"%s%s%s" % [
			String(META_ASSET_METADATA_SOURCE),
			_CUSTOM_SOURCE_KEY_SEPARATOR,
			_utf8_hex(String(metadata_key)),
		]
	)


func _utf8_hex(value: String) -> String:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	var result: String = ""
	for byte: int in bytes:
		result += _HEX_DIGITS.substr((byte >> 4) & 0x0f, 1)
		result += _HEX_DIGITS.substr(byte & 0x0f, 1)
	return result


func _normalize_source_path(path: String) -> String:
	return GFPathTools.normalize_resource_path(path)


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _to_json_safe_dictionary(data: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(data, _get_report_encoding_options())


func _encode_report(report: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(report, _get_report_encoding_options())


func _get_report_encoding_options() -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_PUBLIC,
		{
			"path_redaction": "none",
			"include_resource_path": true,
		}
	)


func _get_report_options() -> Dictionary:
	return {
		"next_actions": {
			"missing_root": "Pass a valid Node root before collecting asset metadata.",
		},
		"fallback_action": "Review the first reported asset metadata issue.",
		"no_action": "No action required.",
	}
