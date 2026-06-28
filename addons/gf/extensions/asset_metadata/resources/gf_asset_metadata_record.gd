## GFAssetMetadataRecord: 资产元数据记录。
##
## 记录某个导入资产、节点或资源片段上的结构化元数据，不解释字段业务含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFAssetMetadataRecord
extends Resource


# --- 导出变量 ---

## 元数据来源资产路径。
## [br]
## @api public
@export var source_path: String = ""

## 元数据所属对象相对路径。节点树中通常是相对根节点的 NodePath。
## [br]
## @api public
@export var subject_path: NodePath = NodePath(".")

## 元数据所属对象类别，例如 node、resource 或 asset。
## [br]
## @api public
@export var subject_kind: StringName = &""

## 结构化元数据。框架只复制和查询，不解释业务字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存导入资产、节点或资源片段的项目自定义元数据字段。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置记录。
## [br]
## @api public
## [br]
## @param p_source_path: 来源资产路径。
## [br]
## @param p_subject_path: 所属对象路径。
## [br]
## @param p_subject_kind: 所属对象类别。
## [br]
## @param p_metadata: 结构化元数据。
## [br]
## @schema p_metadata: Dictionary，保存导入资产、节点或资源片段的项目自定义元数据字段。
## [br]
## @return 当前记录。
func configure(
	p_source_path: String = "",
	p_subject_path: NodePath = NodePath("."),
	p_subject_kind: StringName = &"",
	p_metadata: Dictionary = {}
) -> GFAssetMetadataRecord:
	source_path = _normalize_source_path(p_source_path)
	subject_path = p_subject_path
	subject_kind = p_subject_kind
	metadata = p_metadata.duplicate(true)
	return self


## 检查记录是否没有元数据。
## [br]
## @api public
## [br]
## @return 没有元数据时返回 true。
func is_empty() -> bool:
	return metadata.is_empty()


## 检查元数据键是否存在。StringName 与 String 形式会被同时识别。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @return 存在时返回 true。
func has_value(key: StringName) -> bool:
	return metadata.has(key) or metadata.has(String(key))


## 读取元数据值并返回安全副本。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @schema default_value: Variant，缺失时返回的调用方默认值，会按 GFVariantData 规则复制。
## [br]
## @return 元数据值副本或默认值。
## [br]
## @schema return: Variant，元数据值副本；缺失时为 default_value 的安全副本。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	if metadata.has(key):
		return GFVariantData.duplicate_variant(metadata[key])

	var key_text: String = String(key)
	if metadata.has(key_text):
		return GFVariantData.duplicate_variant(metadata[key_text])
	return GFVariantData.duplicate_variant(default_value)


## 转换为字典。
## [br]
## @api public
## [br]
## @return 记录字典副本。
## [br]
## @schema return: Dictionary，包含 source_path、subject_path、subject_kind 与 metadata 字段。
func to_dict() -> Dictionary:
	return {
		"source_path": source_path,
		"subject_path": String(subject_path),
		"subject_kind": subject_kind,
		"metadata": metadata.duplicate(true),
	}


## 从字典应用字段。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary，可包含 source_path、subject_path、subject_kind 与 metadata 字段。
func apply_dict(data: Dictionary) -> void:
	source_path = _normalize_source_path(GFVariantData.get_option_string(data, "source_path"))
	subject_path = NodePath(GFVariantData.get_option_string(data, "subject_path", "."))
	subject_kind = GFVariantData.get_option_string_name(data, "subject_kind", &"")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建记录深拷贝。
## [br]
## @api public
## [br]
## @return 新记录。
func duplicate_record() -> GFAssetMetadataRecord:
	var script: Script = _get_script_value(get_script())
	var record: GFAssetMetadataRecord = _get_record_value(script.call("new") if script != null else null)
	if record == null:
		record = GFAssetMetadataRecord.new()
	record.apply_dict(to_dict())
	return record


## 从字典创建记录。
## [br]
## @api public
## [br]
## @param data: 输入字典。
## [br]
## @schema data: Dictionary，可包含 source_path、subject_path、subject_kind 与 metadata 字段。
## [br]
## @return 新记录。
static func from_dict(data: Dictionary) -> GFAssetMetadataRecord:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	record.apply_dict(data)
	return record


# --- 私有/辅助方法 ---

func _get_record_value(value: Variant) -> GFAssetMetadataRecord:
	if value is GFAssetMetadataRecord:
		var record: GFAssetMetadataRecord = value
		return record
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _normalize_source_path(path: String) -> String:
	return GFPathTools.normalize_resource_path(path)
