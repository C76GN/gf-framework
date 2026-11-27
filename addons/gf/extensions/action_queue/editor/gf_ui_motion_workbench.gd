@tool

# 工作区内的动效配方编辑和样机预览。运行状态仅属于当前打开的工具实例。
extends VBoxContainer


# --- 常量 ---

## 原生工作区按钮、焦点和尺寸约定。
## [br]
## @api private
const _WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 当前配方的独立预览控件。
## [br]
## @api private
const _PREVIEW = preload("res://addons/gf/extensions/action_queue/editor/preview/gf_ui_motion_preview.gd")

## GF 插件描述文件确定受保护的安装目录。
## [br]
## @api private
const _PLUGIN_DESCRIPTOR: String = "res://addons/gf/plugin.cfg"

## 选择器中的运行时扩展模板。
## [br]
## @api private
const _TEMPLATE: String = "res://addons/gf/extensions/action_queue/editor/ui_motion_effect_template.txt"


# --- 私有变量 ---

## 当前配方及受控样机。
## [br]
## @api private
var _preview: _PREVIEW

## 当前编辑的项目资源或尚未保存的空配方。
## [br]
## @api private
var _picker: EditorResourcePicker

## 保存或创建资源的文件对话框。
## [br]
## @api private
var _dialog: EditorFileDialog

## 当前对话框的意图。
## [br]
## @api private
var _template_mode: bool = false

## 本地文件与采样状态反馈。
## [br]
## @api private
var _status: Label


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_picker = EditorResourcePicker.new()
	_picker.base_type = "GFUIMotionRecipe"
	_picker.tooltip_text = "创建或选择项目配方"
	add_child(_picker)
	var _picked: int = _picker.resource_changed.connect(_open)
	var tools: HFlowContainer = HFlowContainer.new()
	add_child(tools)
	tools.add_child(
		_WORKSPACE_UI.make_button(
			"编辑配方",
			"",
			_edit
		)
	)
	tools.add_child(
		_WORKSPACE_UI.make_button(
			"添加属性轨道",
			"",
			_add_track
		)
	)
	tools.add_child(
		_WORKSPACE_UI.make_button(
			"另存项目配方…",
			"",
			_save
		)
	)
	tools.add_child(
		_WORKSPACE_UI.make_button(
			"创建项目效果资源…",
			"",
			_template
		)
	)
	_preview = _PREVIEW.new()
	add_child(_preview)
	_picker.edited_resource = _preview.recipe
	_dialog = EditorFileDialog.new()
	_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	add_child(_dialog)
	var _chosen: int = _dialog.file_selected.connect(_store)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


# --- 私有/辅助方法 ---

## 交给原生 Inspector 处理参数、撤销与子资源编辑。
## [br]
## @api private
func _edit() -> void:
	EditorInterface.edit_resource(_preview.recipe)


## 在工作区选择的配方立即可被 Inspector 编辑。
## [br]
## @api private
func _open(value: Resource) -> void:
	var selected: GFUIMotionRecipe
	if value is GFUIMotionRecipe:
		selected = value
	else:
		selected = GFUIMotionRecipe.new()
	if _picker.edited_resource != selected:
		_picker.edited_resource = selected
	_preview.open_recipe(selected)


## 用原生撤销历史把通用属性轨道加入配方，Inspector 可直接编辑目标及端点。
## [br]
## @api private
func _add_track() -> void:
	var recipe: GFUIMotionRecipe = _preview.recipe
	var track: GFUIMotionTrack = GFUIMotionTrack.new()
	track.effect = GFUIPropertyMotion.new()
	var tracks: Array[GFUIMotionTrack] = recipe.tracks.duplicate()
	tracks.append(track)
	var history: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	history.create_action(
		"添加界面动效轨道",
		UndoRedo.MERGE_DISABLE,
		recipe
	)
	history.add_do_property(
		recipe,
		&"tracks",
		tracks
	)
	history.add_undo_property(
		recipe,
		&"tracks",
		recipe.tracks
	)
	history.add_do_method(recipe, &"emit_changed")
	history.add_undo_method(recipe, &"emit_changed")
	history.commit_action()
	EditorInterface.edit_resource(track)


## 项目副本只能写入用户指定的新位置。
## [br]
## @api private
func _save() -> void:
	_template_mode = false
	_dialog.filters = PackedStringArray(["*.tres ; Godot 动效配方"])
	_dialog.current_file = "page_motion.tres"
	_dialog.popup_file_dialog()


## 创建一个项目方可直接修改的采样脚本。
## [br]
## @api private
func _template() -> void:
	_template_mode = true
	_dialog.filters = PackedStringArray(["*.gd ; 项目动效脚本"])
	_dialog.current_file = "my_ui_motion.gd"
	_dialog.popup_file_dialog()


## 将选中资源或模板保存到项目，保留所有已有资源。
## [br]
## @api private
func _store(path: String) -> void:
	if (
		not path.begins_with("res://")
		or path.simplify_path().to_lower().begins_with(_PLUGIN_DESCRIPTOR.get_base_dir() + "/")
		or FileAccess.file_exists(path)
	):
		_status.text = "请选择项目内尚未使用的文件名"
		return
	if _template_mode:
		var resource_path: String = path.get_basename() + ".tres"
		if path.get_extension() != "gd" or FileAccess.file_exists(resource_path):
			_status.text = "请选择未使用同名脚本或资源的 .gd 路径"
			return
		var source: String = FileAccess.get_file_as_string(_TEMPLATE)
		if source.is_empty():
			_status.text = "效果模板为空"
			return
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_status.text = "无法保存效果模板"
			return
		if not file.store_string(source):
			file.close()
			var _removed: Error = DirAccess.remove_absolute(path)
			_status.text = "效果脚本写入失败"
			return
		file.close()
		var script: GDScript = ResourceLoader.load(path) as GDScript
		var instance: Variant = script.new() if script != null and script.can_instantiate() else null
		var effect: GFUIMotionEffect
		if instance is GFUIMotionEffect:
			effect = instance
		var error: Error = ResourceSaver.save(effect, resource_path) if effect != null else ERR_CANT_CREATE
		if error != OK:
			var _removed: Error = DirAccess.remove_absolute(path)
			_status.text = error_string(error)
			return
		effect.take_over_path(resource_path)
		EditorInterface.edit_resource(effect)
		path = resource_path
	else:
		var copy: GFUIMotionRecipe = _preview.recipe.duplicate_recipe()
		if copy == null:
			_status.text = "无法复制当前配方"
			return
		var error: Error = ResourceSaver.save(copy, path)
		if error != OK:
			_status.text = error_string(error)
			return
		copy.take_over_path(path)
		_open(copy)
		EditorInterface.edit_resource(copy)
	EditorInterface.get_resource_filesystem().scan()
	_status.text = path
