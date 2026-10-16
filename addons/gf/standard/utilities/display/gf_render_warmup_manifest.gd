## GFRenderWarmupManifest: 通用渲染预热清单。
##
## 只描述需要提前触碰的渲染相关资源，不绑定具体关卡、材质命名或项目加载流程。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFRenderWarmupManifest
extends Resource


# --- 导出变量 ---

## 清单稳定标识，便于诊断和队列统计。
## [br]
## @api public
@export var manifest_id: StringName = &""

## 预热条目列表。条目字段为 resource_path、resource、kind、type_hint、metadata。
## [br]
## @api public
## [br]
## @schema entries: Array[Dictionary]，元素包含 resource_path: String、resource: Resource 或 null、kind: StringName、type_hint: String 和 metadata: Dictionary。
@export var entries: Array[Dictionary] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，会复制到 describe() 结果中。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加资源路径条目。
## [br]
## @api public
## [br]
## @param entry_resource_path: 资源路径。
## [br]
## @param kind: 资源类别提示。
## [br]
## @param type_hint: ResourceLoader 类型提示。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @schema entry_metadata: Dictionary[String, Variant]，会复制到 manifest 条目的 metadata。
## [br]
## @return 添加后的条目索引；失败返回 -1。
func add_resource_path(
	entry_resource_path: String,
	kind: StringName = &"",
	type_hint: String = "",
	entry_metadata: Dictionary = {}
) -> int:
	if entry_resource_path.is_empty():
		return -1

	entries.append(
		{
			"resource_path": entry_resource_path,
			"resource": null,
			"kind": kind,
			"type_hint": type_hint,
			"metadata": entry_metadata.duplicate(true),
		}
	)
	return entries.size() - 1


## 添加已持有的资源条目。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param resource: 资源实例。
## [br]
## @param kind: 资源类别提示。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @schema entry_metadata: Dictionary[String, Variant]，会复制到 manifest 条目的 metadata。
## [br]
## @return 添加后的条目索引；失败返回 -1。
func add_resource(
	resource: Resource,
	kind: StringName = &"",
	entry_metadata: Dictionary = {}
) -> int:
	if resource == null:
		return -1

	entries.append(
		{
			"resource_path": resource.resource_path,
			"resource": resource,
			"kind": kind,
			"type_hint": "",
			"metadata": entry_metadata.duplicate(true),
		}
	)
	return entries.size() - 1


## 合并另一个清单的条目。
## [br]
## @api public
## [br]
## @param manifest: 来源清单。
## [br]
## @return 新增条目数量。
func append_manifest(manifest: GFRenderWarmupManifest) -> int:
	if manifest == null:
		return 0

	var added_count: int = 0
	for entry: Dictionary in manifest.get_entries():
		entries.append(entry)
		added_count += 1
	return added_count


## 清空清单条目。
## [br]
## @api public
func clear() -> void:
	entries.clear()


## 获取条目数量。
## [br]
## @api public
## [br]
## @return 条目数量。
func get_entry_count() -> int:
	return entries.size()


## 检查清单是否为空。
## [br]
## @api public
## [br]
## @return 为空返回 true。
func is_empty() -> bool:
	return entries.is_empty()


## 规范化预热条目字典。
## [br]
## @api public
## [br]
## @param entry: 输入条目。
## [br]
## @schema entry: Dictionary，包含 resource_path、resource、kind、type_hint 和 metadata 的 manifest 条目。
## [br]
## @return 包含 resource_path、resource、kind、type_hint、metadata 的规范化副本。
## [br]
## @schema return: Dictionary，规范化后的 manifest 条目，包含 resource_path、resource、kind、type_hint 和 metadata。
static func normalize_entry(entry: Dictionary) -> Dictionary:
	return {
		"resource_path": GFVariantData.get_option_string(entry, "resource_path"),
		"resource": GFVariantData.get_option_value(entry, "resource"),
		"kind": GFVariantData.get_option_string_name(entry, "kind"),
		"type_hint": GFVariantData.get_option_string(entry, "type_hint"),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}


## 获取条目副本。
## [br]
## @api public
## [br]
## @return 条目数组副本。
## [br]
## @schema return: Array[Dictionary]，规范化后的 manifest 条目列表。
func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		result.append(normalize_entry(entry))
	return result


## 描述清单。
## [br]
## @api public
## [br]
## @return 清单描述字典。
## [br]
## @schema return: Dictionary，包含 manifest_id、entry_count、entries 和 metadata。
func describe() -> Dictionary:
	var described_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var normalized: Dictionary = normalize_entry(entry)
		described_entries.append(
			{
				"resource_path": GFVariantData.get_option_string(normalized, "resource_path"),
				"kind": GFVariantData.get_option_string_name(normalized, "kind"),
				"type_hint": GFVariantData.get_option_string(normalized, "type_hint"),
				"metadata": GFVariantData.get_option_dictionary(normalized, "metadata").duplicate(true),
				"has_resource": GFVariantData.get_option_value(normalized, "resource") is Resource,
			}
		)
	return {
		"manifest_id": manifest_id,
		"entry_count": entries.size(),
		"entries": described_entries,
		"metadata": metadata.duplicate(true),
	}
