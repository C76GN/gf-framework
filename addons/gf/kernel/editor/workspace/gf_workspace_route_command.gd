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


# --- 可重写钩子 / 虚方法 ---

## 通过弱引用取得仍存活的宿主，将贡献来源、选择路径与创建代次交给固定路由入口。
## 由宿主在打开页面及接收方回调前后校验代次和页面资格；命令自身不持有页面或宿主的强引用。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 宿主失效时为 ERR_UNAVAILABLE；宿主返回整数错误码时原样返回，否则为 ERR_INVALID_DATA。
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


# --- 框架内部方法 ---

## 配置不可跨刷新复用的路由命令。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param host: 执行路由的工作区宿主，仅保留弱引用。
## [br]
## @param generation: 创建命令时的宿主代次，执行时必须仍然匹配。
## [br]
## @param source_id: 任务或资源动作的全局贡献来源标识。
## [br]
## @param paths: 本次资源选择的路径，配置时复制；普通页面任务使用空数组。
func configure(host: Object, generation: int, source_id: String, paths: PackedStringArray) -> void:
	_host = weakref(host)
	_generation = generation
	_source_id = source_id
	_paths = paths.duplicate()
	command_name = "打开工作区任务"
