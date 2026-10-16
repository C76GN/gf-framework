## GFResourceSnapshotBroker：以预加载 Resource 映射提供独立实例的异步资源服务。
## 映射初始化后冻结；不调用全局 ResourceLoader，不修改或销毁资源内容。
## Resource 自身由引用计数持有，项目仍须按自己的资源数据契约控制修改。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFResourceSnapshotBroker
extends GFResourceBroker


# --- 私有变量 ---

## 冻结路径到 Resource 的绑定，释放 Broker 不使已交付 Resource 失效。
## [br]
## @api private
var _resources: Dictionary[String, Resource] = {}

## 防止已服务过的映射在原代中被替换。
## [br]
## @api private
var _configured: bool = false


# --- 公共方法 ---

## 冻结资源映射并初始化 Broker；失败不提交部分映射。
## 路径是逻辑资源路径，可以没有对应磁盘文件；不同代可映射到不同 Resource。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param resources: 1–4096 项逻辑路径与非空 Resource。
## [br]
## @schema resources: Dictionary[String, Resource]，键须为可规范化的 res:// 或 uid:// 路径；规范化后不能重复。
## [br]
## @return 已配置返回 ERR_ALREADY_IN_USE，无效输入返回 ERR_INVALID_PARAMETER。
func configure(resources: Dictionary) -> Error:
	if _configured:
		return ERR_ALREADY_IN_USE
	init()
	if not can_claim_service_domain():
		return ERR_ALREADY_IN_USE
	if resources.is_empty() or resources.size() > 4096:
		return ERR_INVALID_PARAMETER
	var prepared: Dictionary[String, Resource] = {}
	for key: Variant in resources:
		if not key is String or not resources[key] is Resource:
			return ERR_INVALID_PARAMETER
		var path: String = key
		var identity: GFResourceIdentity = GFResourceIdentity.from_path(
			path,
			&"",
			"",
			{ "check_exists": false }
		)
		var supported_path: bool = identity.canonical_path.begins_with("res://")
		if identity.canonical_path.begins_with("uid://"):
			supported_path = ResourceUID.text_to_id(identity.canonical_path) != ResourceUID.INVALID_ID
		if (
			not identity.has_identity()
			or not supported_path
			or prepared.has(identity.canonical_path)
		):
			return ERR_INVALID_PARAMETER
		var resource: Resource = resources[key]
		prepared[identity.canonical_path] = resource
	_resources = prepared
	_configured = true
	return OK


## 获取实例是否拥有已冻结映射；服务域仍会核对具体实现身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 配置成功时为 true。
func is_configured() -> bool:
	return _configured


# --- 可重写钩子 / 虚方法 ---

## 对实例私有映射执行准入，不访问全局 path keyed threaded loader。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param path: 规范化逻辑路径。
## [br]
## @param type_hint: 可选原生类或全局脚本类型。
## [br]
## @return 缺失路径或类型不符时失败。
func _request_threaded_resource(path: String, type_hint: String) -> Error:
	if not _resources.has(path):
		return ERR_FILE_NOT_FOUND
	var resource: Resource = _resources[path]
	if not type_hint.is_empty() and not resource.is_class(type_hint):
		var script: Script = resource.get_script()
		if script == null or script.get_global_name() != StringName(type_hint):
			return ERR_INVALID_DATA
	return OK


## 最早在下一次 pump 交付；请求与结果只访问本代映射。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param path: 已准入路径。
## [br]
## @param _previous_progress: 此后端不需要中间进度。
## [br]
## @return completed 适配器结果。
## [br]
## @schema return: Dictionary with status: StringName, progress: float, resource: Resource, has_resource: bool, error: String.
func _poll_threaded_resource(path: String, _previous_progress: float) -> Dictionary:
	return {
		"status": &"loaded",
		"progress": 1.0,
		"resource": _resources[path],
		"has_resource": true,
		"error": "",
	}
