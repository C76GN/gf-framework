@tool

# 项目私有编辑器偏好；不写 project.godot 或游戏 user://。
extends RefCounted


# --- 常量 ---

const _SECTION: String = "gf_asset_browser"
const _KEY: String = "view_v1"


# --- 框架内部方法 ---

## 读取当前项目的个人浏览状态，损坏字段按有界缺省处理。
## [br]
## @api framework_internal
## [br]
## @return 规范化状态。
## [br]
## @schema return: Dictionary with favorites, recent, scope, type_filter and include_addons.
static func load_state() -> Dictionary:
	var state: Dictionary = {}
	if Engine.is_editor_hint():
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings != null:
			var value: Variant = settings.get_project_metadata(_SECTION, _KEY, {})
			if value is Dictionary:
				state = value
	return normalize_state(state)


## 保存有界状态到 Godot 编辑器项目 metadata。
## [br]
## @api framework_internal
## [br]
## @param state: 浏览状态。
## [br]
## @schema state: Dictionary with favorites, recent, scope, type_filter and include_addons.
static func save_state(state: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		settings.set_project_metadata(_SECTION, _KEY, normalize_state(state))


## 校验偏好版本与值容量，只保留本工具拥有的纯数据字段。
## [br]
## @api framework_internal
## [br]
## @param state: 原始编辑器偏好。
## [br]
## @schema state: Dictionary containing optional favorites/recent string arrays and view fields.
## [br]
## @return 规范化状态。
## [br]
## @schema return: Dictionary with favorites, recent, scope, type_filter and include_addons.
static func normalize_state(state: Dictionary) -> Dictionary:
	var scope: String = GFVariantData.get_option_string(state, "scope", "res://")
	if not scope.begins_with("res://") or scope.length() > 512:
		scope = "res://"
	return {
		"favorites": _bounded_ids(state.get("favorites"), 1000),
		"recent": _bounded_ids(state.get("recent"), 100),
		"scope": scope,
		"type_filter": GFVariantData.get_option_string(state, "type_filter").left(128),
		"include_addons": GFVariantData.get_option_bool(state, "include_addons"),
	}


# --- 私有/辅助方法 ---

static func _bounded_ids(value: Variant, limit: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not (value is Array or value is PackedStringArray):
		return result
	var values: Array = []
	if value is Array:
		values = value
	elif value is PackedStringArray:
		var packed_values: PackedStringArray = value
		values = Array(packed_values)
	for item: Variant in values:
		if result.size() >= limit:
			break
		if item is String or item is StringName:
			var identity: String = GFVariantData.to_text(item)
			if not identity.is_empty() and identity.length() <= 512 and not result.has(identity):
				var _appended: bool = result.append(identity)
	return result
