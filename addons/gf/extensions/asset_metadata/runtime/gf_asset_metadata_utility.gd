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
## @param target: 目标 Object。
## [br]
## @param metadata: 结构化元数据。
## [br]
## @param options: 可选项，支持 metadata_key、source_path、subject_path、subject_kind、metadata_source。
## [br]
## @schema metadata: Dictionary，要写入 Object metadata 的结构化资产元数据字段。
## [br]
## @schema options: Dictionary，可包含 metadata_key、source_path、subject_path、subject_kind 与 metadata_source。
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
	target.set_meta(metadata_key, normalized_metadata)

	var metadata_source: String = GFVariantData.get_option_string(options, "metadata_source")
	if not metadata_source.is_empty():
		target.set_meta(_get_metadata_source_key(metadata_key), metadata_source)

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
		return missing_schema_report.to_dict()
	if target == null:
		var missing_target_report: GFValidationReport = GFValidationReport.new("Asset metadata")
		var _missing_target_issue: RefCounted = missing_target_report.add_error(
			&"missing_target",
			"Metadata target is null."
		)
		return missing_target_report.to_dict()

	var metadata: Dictionary = read_object_metadata_with_schema(target, schema, options)
	return schema.validate_dictionary(metadata, _make_schema_validation_options(target, options)).to_dict()


## 检查对象是否带有资产元数据。
## [br]
## @api public
## [br]
## @param target: 目标 Object。
## [br]
## @param options: 可选项，支持 metadata_key 或 metadata_keys。
## [br]
## @schema options: Dictionary，可包含 metadata_key 或 metadata_keys。
## [br]
## @return 存在资产元数据时返回 true。
func has_object_metadata(target: Object, options: Dictionary = {}) -> bool:
	if target == null:
		return false
	for metadata_key: StringName in _get_metadata_keys(options):
		if target.has_meta(metadata_key):
			return true
	return false


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
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。
## [br]
## @return 资产元数据记录列表。
func collect_node_tree(root: Node, options: Dictionary = {}) -> Array[GFAssetMetadataRecord]:
	var records: Array[GFAssetMetadataRecord] = []
	if root == null:
		return records

	var max_depth: int = GFVariantData.get_option_int(options, "max_depth", -1)
	_collect_node_records(root, root, 0, max_depth, options, records)
	return records


## 收集节点树中的资产元数据记录字典。
## [br]
## @api public
## [br]
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。
## [br]
## @return 资产元数据记录字典列表。
## [br]
## @schema return: Array[Dictionary]，每一项包含 source_path、subject_path、subject_kind 与 metadata 字段。
func collect_node_tree_dicts(root: Node, options: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: GFAssetMetadataRecord in collect_node_tree(root, options):
		result.append(record.to_dict())
	return result


## 构建节点树资产元数据报告。
## [br]
## @api public
## [br]
## @param root: 节点树根节点。
## [br]
## @param options: 可选项，支持 collect_node_tree() 的参数。
## [br]
## @schema options: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。
## [br]
## @return 报告字典。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、next_action、source_path、entry_count、entries 与 issues。
func build_node_tree_report(root: Node, options: Dictionary = {}) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new("Asset metadata")
	if root == null:
		var _add_error_result_207: Variant = report.add_error(&"missing_root", "Root node is null.")
		return report.to_dict({}, _get_report_options())

	var entries: Array[Dictionary] = collect_node_tree_dicts(root, options)
	return report.to_dict({
		"source_path": _get_source_path(root, options),
		"entry_count": entries.size(),
		"entries": entries,
	}, _get_report_options())


# --- 私有/辅助方法 ---

func _collect_node_records(
	root: Node,
	node: Node,
	depth: int,
	max_depth: int,
	options: Dictionary,
	records: Array[GFAssetMetadataRecord]
) -> void:
	var metadata: Dictionary = read_object_metadata(node, options)
	if not metadata.is_empty():
		records.append(_make_record_for_node(root, node, metadata, options))

	if max_depth >= 0 and depth >= max_depth:
		return
	for child: Node in node.get_children():
		_collect_node_records(root, child, depth + 1, max_depth, options, records)


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


func _get_report_options() -> Dictionary:
	return {
		"next_actions": {
			"missing_root": "Pass a valid Node root before collecting asset metadata.",
		},
		"fallback_action": "Review the first reported asset metadata issue.",
		"no_action": "No action required.",
	}
