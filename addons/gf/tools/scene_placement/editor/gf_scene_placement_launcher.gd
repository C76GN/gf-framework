@tool

## GFScenePlacementLauncher: GF 工作区中的原生 3D 摆放插件开关。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFScenePlacementLauncher
extends VBoxContainer


# --- 常量 ---

const _PLUGIN_NAME: String = "gf/tools/scene_placement"


# --- 私有变量 ---

static var _ownership_generation: int = 0
static var _native_plugin_ref: WeakRef = null
static var _managed_plugin_ref: WeakRef = null

var _has_context: bool = false
var _owned_generation: int = 0
var _editor_base_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GFScenePlacementLauncher"
	var description: Label = Label.new()
	description.text = "3D 场景摆放\n\n打开独立侧栏后，选择 PackedScene 和父 Node3D，再通过 3D 视口摆放。\n线框预览不实例化源场景节点；确认支持原生 Undo / Redo。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	var open_button: Button = Button.new()
	open_button.name = "OpenScenePlacement"
	open_button.text = "打开 3D 摆放工具"
	add_child(open_button)
	var _open_connected: int = open_button.pressed.connect(_on_open_pressed)
	var close_button: Button = Button.new()
	close_button.name = "CloseScenePlacement"
	close_button.text = "关闭 3D 摆放工具"
	add_child(close_button)
	var _close_connected: int = close_button.pressed.connect(_on_close_pressed)


func _exit_tree() -> void:
	_has_context = false
	_request_owned_close()


# --- 框架内部方法 ---

## 根工作区释放上下文时延迟关闭本启动页拥有的原生子插件。
## 仅延续启动页已管理的同一原生实例；用户独立启用的插件不因页面构建而被接管。
## 延续管理或再次打开会作废旧关闭请求，避免晚到回调关闭新的使用方。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param context: GF 编辑器上下文；null 表示页面被卸载。
func set_editor_context(context: GFEditorToolContext) -> void:
	_has_context = context != null
	if _has_context:
		_editor_base_ref = null
		if (
			Engine.is_editor_hint()
			and is_instance_valid(context.plugin)
			and context.plugin.is_inside_tree()
			and is_instance_valid(EditorInterface)
		):
			var editor_base: Control = EditorInterface.get_base_control()
			if is_instance_valid(editor_base):
				_editor_base_ref = weakref(editor_base)
		if _resolve_editor_base(_editor_base_ref) != null:
			var managed_plugin: EditorPlugin = _get_managed_plugin()
			if managed_plugin != null:
				_claim_ownership(managed_plugin)
	else:
		_request_owned_close()


## 记录原生插件实例的启停，使关闭请求与该实例的生命周期绑定。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param plugin: 正在进入或退出编辑器树的原生摆放插件实例。
## [br]
## @param entered: true 表示实例进入编辑器树；false 表示该实例退出。
static func notify_plugin_lifecycle(plugin: EditorPlugin, entered: bool) -> void:
	if not is_instance_valid(plugin):
		return
	if entered:
		_ownership_generation += 1
		_native_plugin_ref = weakref(plugin)
		_managed_plugin_ref = null
	elif _resolve_plugin(_native_plugin_ref) == plugin:
		_ownership_generation += 1
		_native_plugin_ref = null
		_managed_plugin_ref = null


## 请求关闭当前摆放子插件；新的打开动作会作废这次关闭。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param editor_base: 在插件启用期间取得的原生编辑器基座；退树后不再排队关闭。
static func request_plugin_close(editor_base: Control) -> void:
	if not is_instance_valid(editor_base) or not editor_base.is_inside_tree() or editor_base.is_queued_for_deletion():
		return
	var plugin: EditorPlugin = _resolve_plugin(_native_plugin_ref)
	if plugin == null:
		return
	_ownership_generation += 1
	var editor_base_ref: WeakRef = weakref(editor_base)
	GFScenePlacementLauncher._disable_owned_plugin.call_deferred(_ownership_generation, editor_base_ref, weakref(plugin))


# --- 私有/辅助方法 ---

func _claim_ownership(plugin: EditorPlugin) -> void:
	_ownership_generation += 1
	_owned_generation = _ownership_generation
	_managed_plugin_ref = weakref(plugin)


func _request_owned_close() -> void:
	if _owned_generation == 0:
		return
	var closing_generation: int = _owned_generation
	_owned_generation = 0
	if closing_generation != _ownership_generation:
		return
	if _resolve_editor_base(_editor_base_ref) == null:
		return
	var plugin: EditorPlugin = _get_managed_plugin()
	if plugin == null:
		return
	# EditorNode 退出时正在遍历并卸载插件；不能在该调用栈中再次删除插件。
	# 静态 Callable 不捕获即将销毁的启动页，且只关闭仍属于该次使用方的插件。
	GFScenePlacementLauncher._disable_owned_plugin.call_deferred(closing_generation, _editor_base_ref, weakref(plugin))


static func _disable_owned_plugin(closing_generation: int, editor_base_ref: WeakRef, plugin_ref: WeakRef) -> void:
	if closing_generation != _ownership_generation:
		return
	if _resolve_editor_base(editor_base_ref) == null:
		return
	var plugin: EditorPlugin = _resolve_plugin(plugin_ref)
	if plugin == null or plugin != _resolve_plugin(_native_plugin_ref):
		return
	if not Engine.is_editor_hint() or not is_instance_valid(EditorInterface):
		return
	if EditorInterface.is_plugin_enabled(_PLUGIN_NAME):
		EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)


static func _get_managed_plugin() -> EditorPlugin:
	var plugin: EditorPlugin = _resolve_plugin(_managed_plugin_ref)
	if plugin != null and plugin == _resolve_plugin(_native_plugin_ref):
		return plugin
	return null


static func _resolve_plugin(plugin_ref: WeakRef) -> EditorPlugin:
	if plugin_ref == null:
		return null
	var value: Variant = plugin_ref.get_ref()
	if value is EditorPlugin:
		var plugin: EditorPlugin = value
		if is_instance_valid(plugin):
			return plugin
	return null


static func _resolve_editor_base(editor_base_ref: WeakRef) -> Control:
	if editor_base_ref == null:
		return null
	var value: Variant = editor_base_ref.get_ref()
	if value is Control:
		var editor_base: Control = value
		if is_instance_valid(editor_base) and editor_base.is_inside_tree() and not editor_base.is_queued_for_deletion():
			return editor_base
	return null


# --- 信号处理函数 ---

func _on_open_pressed() -> void:
	if Engine.is_editor_hint() and _has_context and _resolve_editor_base(_editor_base_ref) != null:
		if EditorInterface.is_plugin_enabled(_PLUGIN_NAME):
			var managed_plugin: EditorPlugin = _get_managed_plugin()
			if managed_plugin != null:
				_claim_ownership(managed_plugin)
			else:
				_ownership_generation += 1
			return
		var activation_generation: int = _ownership_generation + 1
		EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
		if not _has_context or _resolve_editor_base(_editor_base_ref) == null:
			return
		if _ownership_generation != activation_generation:
			return
		var activated_plugin: EditorPlugin = _resolve_plugin(_native_plugin_ref)
		if activated_plugin != null and EditorInterface.is_plugin_enabled(_PLUGIN_NAME):
			_claim_ownership(activated_plugin)


func _on_close_pressed() -> void:
	if Engine.is_editor_hint() and _has_context:
		request_plugin_close(_resolve_editor_base(_editor_base_ref))
		_owned_generation = 0
