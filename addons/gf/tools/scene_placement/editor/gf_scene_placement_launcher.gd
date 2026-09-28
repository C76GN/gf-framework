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

## 原生场景摆放插件在 EditorInterface 中的名称。
## [br]
## @api private
## [br]
const _PLUGIN_NAME: String = "gf/tools/scene_placement"


# --- 私有变量 ---

## 使旧的延迟关闭请求失效的共享代数。
## [br]
## @api private
## [br]
static var _ownership_generation: int = 0

## 原生插件入口当前实例的弱引用。
## [br]
## @api private
## [br]
static var _native_plugin_ref: WeakRef = null

## 启动页当前管理的插件实例弱引用。
## [br]
## @api private
## [br]
static var _managed_plugin_ref: WeakRef = null

## 启动页是否持有有效的编辑器上下文。
## [br]
## @api private
## [br]
var _has_context: bool = false

## 此启动页认领的插件所有权代数。
## [br]
## @api private
## [br]
var _owned_generation: int = 0

## Editor 根 Control 的弱引用。
## [br]
## @api private
## [br]
var _editor_base_ref: WeakRef = null


# --- Godot 生命周期方法 ---

## 创建启动说明与开关按钮，并把操作连接到本启动页的所有权管理回调。
## [br]
## @api private
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


## 先撤销页面上下文，再请求延迟关闭仍属于该页面代次的原生插件。
## [br]
## @api private
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

## 推进共享所有权代次并保存插件弱引用，使之前排队的关闭请求失效。
## [br]
## @api private
func _claim_ownership(plugin: EditorPlugin) -> void:
	_ownership_generation += 1
	_owned_generation = _ownership_generation
	_managed_plugin_ref = weakref(plugin)


## 消费本页的所有权代次；编辑器基座和插件身份仍匹配时排队静态关闭回调，避免退树调用栈中卸载插件。
## [br]
## @api private
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


## 延迟执行时重新核对所有权代次、基座和原生插件身份；任一已替换或失效就放弃关闭。
## [br]
## @api private
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


## 仅返回仍存活且等于当前原生实例的受管插件；旧实例或失效弱引用返回 null。
## [br]
## @api private
static func _get_managed_plugin() -> EditorPlugin:
	var plugin: EditorPlugin = _resolve_plugin(_managed_plugin_ref)
	if plugin != null and plugin == _resolve_plugin(_native_plugin_ref):
		return plugin
	return null


## 解析仍存活的 EditorPlugin 弱引用；无效引用返回 null。
## [br]
## @api private
## [br]
static func _resolve_plugin(plugin_ref: WeakRef) -> EditorPlugin:
	if plugin_ref == null:
		return null
	var value: Variant = plugin_ref.get_ref()
	if value is EditorPlugin:
		var plugin: EditorPlugin = value
		if is_instance_valid(plugin):
			return plugin
	return null


## 解析仍在场景树中的 Editor 根 Control 弱引用。
## [br]
## @api private
## [br]
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

## 启用或续领本页管理的插件；用户独立启用的实例不被接管，启用期间代次变化会取消本次认领。
## [br]
## @api private
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


## 有编辑器上下文时请求关闭当前原生插件，并撤销本页的所有权记录。
## [br]
## @api private
func _on_close_pressed() -> void:
	if Engine.is_editor_hint() and _has_context:
		request_plugin_close(_resolve_editor_base(_editor_base_ref))
		_owned_generation = 0
