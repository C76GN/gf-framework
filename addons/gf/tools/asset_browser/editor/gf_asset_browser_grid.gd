@tool

# 采用 Godot 原生 files 拖拽载荷的资源网格。
extends ItemList


# --- 私有变量 ---

var _resource_actions_enabled: bool = false


# --- Godot 回调方法 ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _resource_actions_enabled:
		return null
	var paths: PackedStringArray = get_selected_resource_paths()
	if paths.is_empty():
		return null
	var label: Label = Label.new()
	label.text = paths[0].get_file() if paths.size() == 1 else "%d 个资源" % paths.size()
	set_drag_preview(label)
	return {"type": "files", "files": paths}


# --- 框架内部方法 ---

## 完整快照过期后阻止旧路径进入原生拖放操作。
## [br]
## @api framework_internal
## [br]
## @param enabled: 当前快照是否允许执行资源动作。
func set_resource_actions_enabled(enabled: bool) -> void:
	_resource_actions_enabled = enabled


## 返回所选卡片的项目资源路径，用于原生编辑动作和宿主资源动作。
## [br]
## @api framework_internal
## [br]
## @return 去重后的项目资源路径。
func get_selected_resource_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for index: int in get_selected_items():
		var raw_path: Variant = get_item_metadata(index)
		if raw_path is String:
			var path: String = raw_path
			if path.begins_with("res://") and not paths.has(path):
				var _appended: bool = paths.append(path)
	return paths
