## GFStorageSyncTransport: 不依赖具体网络协议的远端版本存储接口。
##
## 适配器接收冻结请求并返回主线程完成源。写入必须在远端原子比较 revision，且以
## namespace/key/operation_id 幂等地记录提交结果；同一 ID 绑定候选与预期 revision，
## 不得换载荷重用。mode、timeout 和 local_generation 是本地观察信息，不参与远端提交身份。
## probe 查证的是历史操作结果，不能用当前记录相似或本地时钟推断已经提交。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFStorageSyncTransport
extends RefCounted


# --- 公共方法 ---

## 获取适配器声明的能力；非布尔声明视为不支持。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 隔离的能力记录。
## [br]
## @schema return: Closed Dictionary with read:bool,conditional_write:bool,probe:bool.
func get_capabilities() -> Dictionary:
	var declared: Dictionary = _get_capabilities()
	var result: Dictionary = {}
	for key: String in [
		"read",
		"conditional_write",
		"probe",
	]:
		var value: Variant = declared.get(key)
		result[key] = value is bool and value == true
	return result


## 读取请求所指定记录的单一版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 命名空间、键和本次观察身份。
## [br]
## @return 完成源；成功结果必须符合协议字典，失败不得冒充不存在。
## [br]
## @schema return: GFAsyncCompletion success result is a closed Dictionary with namespace:String,key:String,operation_id:String,status:StringName/String(read),exists:bool,revision:String,data:Dictionary. Existing records require nonempty opaque revision; missing records require empty revision/data.
func read(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _read(request)


## 对预期 revision 执行一次条件写入。
##
## 已提交结果必须与 operation_id 的幂等记录一致。冲突必须返回实际存在状态与
## revision；not_committed 只用于能够证明本次没有提交的情况。网络错误通常只能报告 unknown。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 已持久化意图所对应的精确冻结请求。
## [br]
## @return 主线程完成源；不能以取消等待冒充远端撤销。
## [br]
## @schema return: GFAsyncCompletion success result is a closed Dictionary with namespace,key,operation_id,status(committed/conflict/not_committed/unknown),exists:bool,revision:String,data:Dictionary. Committed requires exists=true and nonempty revision; unknown/not_committed carry exists=false,empty revision/data; conflict describes current remote record.
func conditional_write(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _conditional_write(request)


## 以原 operation_id 查证一次历史提交，永不隐式重发写入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 原持久化意图。
## [br]
## @return 主线程完成源；无法证明结果时报告 unknown。
## [br]
## @schema return: GFAsyncCompletion success result follows conditional_write(), but status is committed/not_committed/unknown; committed describes the historical commit, not necessarily the latest remote revision.
func probe(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _probe(request)


# --- 可重写钩子 / 虚方法 ---

## 声明实际支持的协议能力。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 能力字典，默认不支持任何操作。
## [br]
## @schema return: Dictionary with read,conditional_write,probe booleans.
func _get_capabilities() -> Dictionary:
	return {}


## 开始只读请求；实现负责冻结认证会话并在主线程完成。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _request: 冻结输入。
## [br]
## @return 符合 read() 契约的完成源。
func _read(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _unsupported()


## 开始一次远端条件提交；不允许退化为无条件覆盖。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _request: 精确持久化意图。
## [br]
## @return 符合 conditional_write() 契约的完成源。
func _conditional_write(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _unsupported()


## 查证原操作的持久化结果。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _request: 原提交身份及候选。
## [br]
## @return 符合 probe() 契约的完成源。
func _probe(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _unsupported()


# --- 私有/辅助方法 ---

## 默认协议明确报告不可用。
## [br]
## @api private
static func _unsupported() -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail("Sync transport capability is unavailable.")
	return completion
