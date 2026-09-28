@tool

# 一次性的工作区路由命令；导航和资源交接不加入 Undo 历史。
extends GFEditorCommand


# --- 私有变量 ---

## 宿主弱引用，避免命令注册表形成保活环。
## [br]
## @api private
var _host: WeakRef = null

## 创建命令时的宿主代次。
## [br]
## @api private
var _generation: int = 0

## 贡献来源标识。
## [br]
## @api private
var _source_id: String = ""

## 本次选择的资源路径副本。
## [br]
## @api private
var _paths: PackedStringArray = PackedStringArray()


# --- 框架内部方法 ---

## 配置不可跨刷新复用的路由命令。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func configure(host: Object, generation: int, source_id: String, paths: PackedStringArray) -> void:
	_host = weakref(host)
	_generation = generation
	_source_id = source_id
	_paths = paths.duplicate()
	command_name = "打开工作区任务"


# --- 私有/辅助方法 ---

## 将执行交给仍存活的同代宿主。
## [br]
## @api private
func _do_it() -> Error:
	var host_value: Variant = _host.get_ref() if _host != null else null
	if not host_value is Object or not is_instance_valid(host_value):
		return ERR_UNAVAILABLE
	var host: Object = host_value
	var result: Variant = host.call("invoke_workspace_record", _source_id, _paths, _generation)
	if result is int:
		var error: int = result
		return error as Error
	return ERR_INVALID_DATA
