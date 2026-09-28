# 工作区贡献的纯数据协议；不加载脚本、不实例化工具、不执行动作。
extends RefCounted


# --- 常量 ---

## 两类工作区记录共同允许的字段。
## [br]
## @api private
const _COMMON_KEYS: Array[String] = [
	"owner_package_id", "source_id", "title", "description", "keywords", "group", "page_path", "action_id",
]

## 资源动作只接受这些原生资源类别，避免发现阶段加载自定义脚本。
## [br]
## @api private
const _RESOURCE_TYPES: Array[String] = [
	"Resource", "PackedScene", "Texture2D", "AudioStream", "Font", "Material", "Mesh", "Script",
]


# --- 框架内部方法 ---

## 校验工作区记录，并将本地来源 ID 加上所属模块前缀。
## page_owners 限定目标为同一来源已贡献的页面，拒绝任意脚本或跨工具跳转。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
static func parse_records(
	value: Variant, owner_id: String, page_owners: Dictionary, resource_actions: bool = false
) -> Dictionary:
	var records: Array[Dictionary] = []
	var errors: Array[String] = []
	if not value is Array:
		return {"records": records, "errors": ["Workspace records must be an array."]}
	var values: Array = value
	if values.size() > 1024:
		return {"records": records, "errors": ["Workspace record budget exceeded."]}
	var identities: Dictionary = {}
	for raw: Variant in values:
		if not raw is Dictionary:
			errors.append("Workspace record must be an object.")
			continue
		var record: Dictionary = raw
		var error: String = _validate_record(record, owner_id, page_owners, resource_actions)
		if not error.is_empty():
			errors.append(error)
			continue
		var owner: String = str(record.get("owner_package_id", owner_id))
		var identity: String = "%s:%s" % [owner, record["source_id"]]
		if identities.has(identity):
			errors.append("Duplicate workspace source_id: %s" % identity)
			continue
		identities[identity] = true
		var normalized: Dictionary = record.duplicate(true)
		normalized["owner_package_id"] = owner
		normalized["source_id"] = identity
		normalized["title"] = str(record["title"]).strip_edges()
		normalized["description"] = str(record.get("description", ""))
		normalized["group"] = str(record.get("group", "常用"))
		var keywords: Array = record.get("keywords", [])
		normalized["keywords"] = keywords.duplicate()
		normalized["action_id"] = str(record.get("action_id", ""))
		if resource_actions:
			var selection_count: float = record.get("max_selection", 1)
			normalized["max_selection"] = int(selection_count)
		records.append(normalized)
	return {"records": records, "errors": errors}


# --- 私有/辅助方法 ---

## 按关闭的字段和类型集合校验一条记录。
## [br]
## @api private
static func _validate_record(
	record: Dictionary, owner_id: String, page_owners: Dictionary, resource_actions: bool
) -> String:
	for key: Variant in record:
		if not key is String:
			return "Workspace field names must be strings."
		if not _COMMON_KEYS.has(key) and not (resource_actions and key in ["resource_types", "max_selection"]):
			return "Unknown workspace field: %s" % key
	for field: String in ["owner_package_id", "source_id", "title", "description", "group", "page_path", "action_id"]:
		if record.has(field) and (not record[field] is String or str(record[field]).length() > 4096):
			return "Invalid workspace text field: %s" % field
	var owner: String = str(record.get("owner_package_id", owner_id))
	var identity: String = str(record.get("source_id", ""))
	if owner.is_empty() or identity.strip_edges().is_empty() or identity != identity.strip_edges() or identity.length() > 128 or identity.contains(":"):
		return "Workspace record requires an owner and a local source_id."
	if str(record.get("title", "")).strip_edges().is_empty():
		return "Workspace record requires a title."
	var page_path: String = str(record.get("page_path", ""))
	if page_path.is_empty() or str(page_owners.get(page_path, "")) != owner:
		return "Workspace target must be a page contributed by the same owner: %s" % page_path
	var keywords: Variant = record.get("keywords", [])
	if not _is_text_array(keywords, 32):
		return "Workspace keywords must be a bounded string array."
	if resource_actions:
		if str(record.get("action_id", "")).strip_edges().is_empty():
			return "Resource action requires an action_id."
		var types: Variant = record.get("resource_types", [])
		if not _is_text_array(types, 8):
			return "Resource types must be a bounded string array."
		var type_values: Array = types
		if type_values.is_empty():
			return "Resource action requires at least one resource type."
		for type_name: String in type_values:
			if not _RESOURCE_TYPES.has(type_name):
				return "Unsupported resource action type: %s" % type_name
		var count: Variant = record.get("max_selection", 1)
		if not (count is int or count is float):
			return "max_selection must be an integer from 1 to 100."
		var numeric_count: float = count
		if not is_finite(numeric_count) or numeric_count != floor(numeric_count) or numeric_count < 1 or numeric_count > 100:
			return "max_selection must be an integer from 1 to 100."
	return ""


## 仅接收有界的非空字符串数组。
## [br]
## @api private
static func _is_text_array(value: Variant, maximum: int) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	if values.size() > maximum:
		return false
	for item: Variant in values:
		if not item is String or str(item).strip_edges().is_empty() or str(item).length() > 128:
			return false
	return true
