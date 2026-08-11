## GFStorageAsyncRequestOptions: 异步 Storage caller 观察生命周期的不可变选项。
##
## 选项只弱持有 owner，并可绑定只读取消令牌与单调 timeout。必须通过 `create()`
## 构造；直接 `new()` 或非法参数会得到 `is_valid() == false` 的对象，避免把错误选项
## 静默解释成没有生命周期约束。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageAsyncRequestOptions
extends RefCounted


# --- 私有变量 ---

var _configured: bool = false
var _owner_ref: WeakRef = null
var _owner_id: int = 0
var _cancel_token: GFCancellationToken = null
var _timeout_msec: int = 0


# --- 公共方法 ---

## 创建 caller 生命周期选项。
##
## owner 不会被强持有；需要在 Node 离树时结束观察的调用方，应另行传入由
## `GFCancellationSource.cancel_when_node_exits()` 驱动的 token。timeout 从公开 request
## 调用时刻开始使用 Utility 的单调时钟计算，`0` 表示不设截止时间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 当前 consumer 的非空生命周期 owner。
## [br]
## @param cancel_token: 可选只读取消令牌；已取消令牌会在 worker 接纳前参与仲裁。
## [br]
## @param timeout_msec: 非负单调超时毫秒数；`0` 表示不设截止时间。
## [br]
## @return 始终返回对象；参数非法时对象的 `is_valid()` 为 false。
static func create(
	owner: Object,
	cancel_token: GFCancellationToken = null,
	timeout_msec: int = 0
) -> GFStorageAsyncRequestOptions:
	var options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.new()
	if owner == null or not is_instance_valid(owner) or timeout_msec < 0:
		return options
	options._configured = true
	options._owner_ref = weakref(owner)
	options._owner_id = owner.get_instance_id()
	options._cancel_token = cancel_token
	options._timeout_msec = timeout_msec
	return options


## 返回选项是否由合法参数创建。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅 `create()` 接受全部参数时返回 true；owner 后续释放不会改写该配置事实。
func is_valid() -> bool:
	return _configured and _owner_ref != null and _owner_id != 0


# --- 框架内部方法 ---

## 返回仍存活的弱 owner。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return owner 仍有效时返回对象，否则返回 null。
func get_owner_for_framework() -> Object:
	if not is_valid():
		return null
	var owner_value: Variant = _owner_ref.get_ref()
	if not (owner_value is Object):
		return null
	var owner: Object = owner_value
	if not is_instance_valid(owner) or owner.get_instance_id() != _owner_id:
		return null
	return owner


## 返回配置时冻结的 owner 实例 ID。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return 配置时冻结的 owner 实例 ID；无效配置返回 0。
func get_owner_id_for_framework() -> int:
	return _owner_id


## 返回弱 owner 是否已经释放。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return 配置有效且弱 owner 已释放时返回 true。
func owner_is_released_for_framework() -> bool:
	return is_valid() and get_owner_for_framework() == null


## 返回配置的只读取消令牌。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return 配置的只读取消令牌；未配置时返回 null。
func get_cancel_token_for_framework() -> GFCancellationToken:
	return _cancel_token


## 返回配置的单调 timeout 毫秒数。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return 非负 timeout 毫秒数；`0` 表示无 deadline。
func get_timeout_msec_for_framework() -> int:
	return _timeout_msec
