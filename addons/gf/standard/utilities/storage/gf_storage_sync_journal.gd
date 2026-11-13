## GFStorageSyncJournal: 同步意图与提交结果的持久化边界。
##
## 完成源成功表示持久化已经确认，不能只表示已排队或内存更新。一个记录只能有一个
## 未解决意图；不同 operation_id 不得覆盖它。Save 通过现有 Profile 事务实现本接口，
## 普通记录可以使用自己的持久化适配器。该接口不实现网络、账号认证或第二套业务事务。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFStorageSyncJournal
extends RefCounted


# --- 公共方法 ---

## 在远端发送前持久化精确意图；重复相同意图可幂等确认。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 即将发送的冻结请求，包含实际 CAS revision。
## [br]
## @return 成功表示意图已持久化；失败或未知时引擎不得发送远端写入。
func persist_intent(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _persist_intent(request)


## 持久化已查证的操作结果及 checkpoint，再释放对应未解决意图。
##
## 写入结果不能覆盖其他 operation_id 的意图；相同结果应支持幂等恢复。失败时必须
## 保留可恢复证据，不能把已知远端提交误记为未提交。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: 原持久化意图。
## [br]
## @param outcome: 已经过协议校验的远端终态。
## [br]
## @schema outcome: Closed Dictionary following GFStorageSyncTransport.conditional_write(); status is committed,conflict or not_committed. Contains namespace,key,operation_id,exists,revision,data; may contain business payload and must not be logged.
## [br]
## @return 成功表示 checkpoint 已持久化；失败要求保留待恢复状态。
func persist_outcome(request: GFStorageSyncRequest, outcome: Dictionary) -> GFAsyncCompletion:
	return _persist_outcome(request, outcome)


## 读取指定记录的未解决意图。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record_namespace: 稳定命名空间。
## [br]
## @param record_key: 稳定记录键。
## [br]
## @return 成功结果为规范意图记录；空字典仅表示确认不存在意图，读取失败不得冒充空。
## [br]
## @schema return: GFAsyncCompletion success result is Dictionary accepted by GFStorageSyncRequest.from_record(), or empty Dictionary when no unresolved intent exists.
func load_intent(record_namespace: String, record_key: String) -> GFAsyncCompletion:
	return _load_intent(record_namespace, record_key)


# --- 可重写钩子 / 虚方法 ---

## 实现持久化意图写入。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _request: 冻结意图。
## [br]
## @return 主线程完成源，成功必须表示持久化完成。
func _persist_intent(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _unsupported()


## 实现已查证结果的幂等持久化。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _request: 原意图。
## [br]
## @param _outcome: 已校验结果。
## [br]
## @schema _outcome: Closed transport result described by persist_outcome().
## [br]
## @return 主线程完成源。
func _persist_outcome(_request: GFStorageSyncRequest, _outcome: Dictionary) -> GFAsyncCompletion:
	return _unsupported()


## 实现未解决意图读取。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _record_namespace: 稳定命名空间。
## [br]
## @param _record_key: 稳定记录键。
## [br]
## @return 主线程完成源，成功值遵守 load_intent() 契约。
func _load_intent(_record_namespace: String, _record_key: String) -> GFAsyncCompletion:
	return _unsupported()


# --- 私有/辅助方法 ---

## 默认实现不假装已经完成持久化。
## [br]
## @api private
static func _unsupported() -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail("Sync journal persistence is unavailable.")
	return completion
