@tool

# Tween 资源创建菜单和可复制绑定示例；所有文件写入由用户选择目标后触发。
extends RefCounted


# --- 常量 ---

const _PRESETS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/presets/gf_tween_authoring_presets.gd")


# --- 私有变量 ---

var _dialog: EditorFileDialog = null
var _kind_picker: OptionButton = null
var _error_label: Label = null


# --- 框架内部方法 ---

## 贡献创建资源菜单，不创建资源或修改项目设置。
## [br]
## @api framework_internal
## [br]
## @return: 编辑器宿主菜单贡献。
## [br]
## @schema return: Array[Dictionary]，每项包含 id: StringName、label/section: String。
func get_menu_entries() -> Array[Dictionary]:
	return [{"id": &"create_tween_config", "label": "创建 Tween 配置…", "section": "创建"}]


## 显示创建对话框；相同入口重复调用复用对话框。
## [br]
## @api framework_internal
## [br]
## @param action_id: 仅处理 create_tween_config。
func handle_menu_action(action_id: StringName) -> void:
	if action_id != &"create_tween_config":
		return
	if not is_instance_valid(_dialog):
		_dialog = EditorFileDialog.new()
		_dialog.name = "GFTweenCreateDialog"
		_dialog.title = "创建 Tween 配置（不覆盖已有文件）"
		_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_dialog.add_filter("*.tres", "Tween 配置")
		_dialog.current_file = "new_tween.tres"
		_kind_picker = OptionButton.new()
		for label: String in ["2D 移动偏移", "UI 移动偏移", "3D 移动偏移"]:
			_kind_picker.add_item(label)
		_dialog.get_vbox().add_child(_kind_picker)
		_error_label = Label.new()
		_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dialog.get_vbox().add_child(_error_label)
		var _connected: int = _dialog.file_selected.connect(_on_file_selected)
		EditorInterface.get_base_control().add_child(_dialog)
	_error_label.text = "新建后在 Inspector 选择预设并调整步骤。"
	_dialog.popup_centered_ratio(0.6)


## 对称释放菜单持有的界面。
## [br]
## @api framework_internal
func cleanup() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
	_kind_picker = null
	_error_label = null


## 按实际资源路径生成明确 target、host 与取消所有权的绑定示例。
## [br]
## @api framework_internal
## [br]
## @param resource_path: 已保存的独立 res:// 资源路径；其他值使用占位路径。
## [br]
## @return: 供项目复制使用的 GDScript 文本。
static func make_binding_example(resource_path: String) -> String:
	var path: String = resource_path if resource_path.begins_with("res://") and not resource_path.contains("::") else "res://path/to/tween.tres"
	return "extends Node\n\n@export var target: Node\n@export var tween_config: GFTweenActionConfig = preload(%s)\nvar _action: GFVisualAction\n\nfunc _ready() -> void:\n\tif target == null or tween_config == null:\n\t\treturn\n\t_action = tween_config.create_action(target, self)\n\tvar _completion: Variant = _action.execute()\n\nfunc _exit_tree() -> void:\n\tif _action != null:\n\t\t_action.cancel()\n\t\t_action = null\n" % JSON.stringify(path)


# --- 信号处理函数 ---

func _on_file_selected(path: String) -> void:
	if not is_instance_valid(_dialog) or not is_instance_valid(_kind_picker):
		return
	if not path.begins_with("res://") or path.get_extension().to_lower() != "tres" or FileAccess.file_exists(path):
		_error_label.text = "请选择尚不存在的项目内 .tres 文件；已有文件未改动。"
		_dialog.popup_centered_ratio(0.6)
		return
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps = _PRESETS_SCRIPT.create_steps("move_by", _kind_picker.selected)
	var error: Error = ResourceSaver.save(config, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_error_label.text = "保存失败：%s" % error_string(error)
		_dialog.popup_centered_ratio(0.6)
		return
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.edit_resource(config)
