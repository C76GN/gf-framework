@tool

# GF 插件工具菜单管理辅助。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _menu: PopupMenu


# --- 公共方法 ---

## 创建并注册 GF 工具菜单。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
## [br]
## @param handler: 处理菜单 ID 的回调。
## [br]
## @param menu_entries: 菜单项记录列表。
## [br]
## @schema menu_entries: Array of Dictionary entries with label, id, and optional section.
func setup(plugin: EditorPlugin, handler: Callable, menu_entries: Array = []) -> void:
	if plugin == null:
		return
	cleanup(plugin)
	_menu = PopupMenu.new()
	var _connected: int = _menu.id_pressed.connect(handler)
	_populate_menu(menu_entries)
	plugin.add_tool_submenu_item("GF", _menu)


## 移除并释放 GF 工具菜单。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func cleanup(plugin: EditorPlugin) -> void:
	if plugin != null:
		plugin.remove_tool_menu_item("GF")
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


# --- 私有/辅助方法 ---

func _populate_menu(menu_entries: Array) -> void:
	var current_section: String = ""
	for entry_variant: Variant in menu_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "label").strip_edges()
		var id: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "id", -1)
		if label.is_empty() or id < 0:
			continue

		var section: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "section").strip_edges()
		if section.is_empty():
			section = "工具"
		if section != current_section:
			_menu.add_separator(section)
			current_section = section

		_menu.add_item(label, id)
