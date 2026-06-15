## GFAutoload: GF AutoLoad 运行时解析辅助。
##
## 用于避免框架脚本在首次导入、AutoLoad 尚未注册时直接引用全局 Gf 标识符。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFAutoload
extends RefCounted


# --- 常量 ---

## GF Framework 注册到场景树根节点下的 AutoLoad 名称。
## [br]
## @api framework_internal
const AUTOLOAD_NAME: StringName = &"Gf"

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 获取 Gf AutoLoad 节点；未注册或场景树不可用时返回 null。
## [br]
## @api framework_internal
## [br]
## @return Gf AutoLoad 节点。
static func get_singleton_or_null() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return null

	var scene_tree: SceneTree = main_loop
	if scene_tree.root == null:
		return null

	return scene_tree.root.get_node_or_null(NodePath(String(AUTOLOAD_NAME)))


## 检查全局 Gf 是否已经持有架构实例。
## [br]
## @api framework_internal
## [br]
## @return 架构存在时返回 true。
static func has_architecture() -> bool:
	var singleton: Node = get_singleton_or_null()
	if singleton == null or not singleton.has_method("has_architecture"):
		return false
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(singleton.call("has_architecture"))


## 获取全局架构实例；AutoLoad 不可用或尚未创建架构时返回 null。
## 该方法只表示架构实例存在，不保证架构已经完成 init()/ready()。
## [br]
## @api framework_internal
## [br]
## @return 当前全局架构实例。
static func get_architecture_or_null() -> GFArchitecture:
	var singleton: Node = get_singleton_or_null()
	if singleton == null:
		return null
	var silent_architecture: Variant = singleton.get("_architecture")
	if silent_architecture is GFArchitecture:
		var typed_silent_architecture: GFArchitecture = silent_architecture
		return typed_silent_architecture
	if not singleton.has_method("has_architecture") or not singleton.has_method("get_architecture"):
		return null
	if not _GF_VARIANT_ACCESS_SCRIPT.to_bool(singleton.call("has_architecture")):
		return null
	var architecture: Variant = singleton.call("get_architecture")
	if architecture is GFArchitecture:
		var typed_architecture: GFArchitecture = architecture
		return typed_architecture
	return null


## 获取已完成初始化的全局架构；AutoLoad 不可用、尚未创建架构或架构未 ready 时返回 null。
## [br]
## @api framework_internal
## [br]
## @return 已完成初始化的全局架构实例。
static func get_ready_architecture_or_null() -> GFArchitecture:
	var architecture: GFArchitecture = get_architecture_or_null()
	if architecture == null or not architecture.is_inited():
		return null
	return architecture


## 获取全局架构实例；不可用时输出明确错误。
## [br]
## @api framework_internal
## [br]
## @return 当前全局架构实例。
static func get_architecture() -> GFArchitecture:
	var architecture: GFArchitecture = get_architecture_or_null()
	if architecture == null:
		push_error("[GFAutoload] Gf AutoLoad 未就绪或架构尚未初始化，请先启用 GF 插件并注册架构。")
	return architecture


## 获取已完成初始化的全局架构；不可用或未 ready 时输出明确错误。
## [br]
## @api framework_internal
## [br]
## @return 已完成初始化的全局架构实例。
static func get_ready_architecture() -> GFArchitecture:
	var architecture: GFArchitecture = get_ready_architecture_or_null()
	if architecture == null:
		push_error("[GFAutoload] Gf AutoLoad 未就绪或架构尚未完成初始化，请先完成 Gf.init() 或 Gf.set_architecture()。")
	return architecture
