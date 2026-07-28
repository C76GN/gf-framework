## GFNetworkSimulationAdapter: 网络协调器的项目模拟协议。
##
## 项目继承该类型并实现同步状态捕获、校验、恢复、输入授权和单 tick 模拟。
## 所有钩子必须同步完成，不应执行 await、网络发送或协调器重入。
## _validate_state() 与 _validate_input() 还必须是无副作用的纯校验；项目 Adapter 属于
## 受信代码，协调器无法撤销校验钩子私自修改的项目状态。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 10.0.0
class_name GFNetworkSimulationAdapter
extends RefCounted


# --- 可重写钩子 / 虚方法 ---

## 捕获指定 tick 的完整项目同步状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _tick: 待捕获状态的模拟 tick。
## [br]
## @param _context: 协调器提供的无业务载荷上下文副本。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 捕获报告。
## [br]
## @schema return: Dictionary { ok: bool, state?: Dictionary, error?: String }.
func _capture_state(_tick: int, _context: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"error": "capture_state_not_implemented",
	}


## 校验来自权威端的完整同步状态。
##
## 项目应在此执行字段 schema、范围和不变量校验；GF 的通用结构预算不能替代项目 schema。
## 该钩子必须无副作用，不得修改项目模拟状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _state: 待应用的完整状态副本。
## [br]
## @param _tick: 状态所属 tick。
## [br]
## @param _context: 协调器上下文副本。
## [br]
## @schema _state: Dictionary，项目定义的完整同步状态。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 校验报告。
## [br]
## @schema return: Dictionary { ok: bool, error?: String }.
func _validate_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"error": "validate_state_not_implemented",
	}


## 恢复指定 tick 的完整同步状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _state: 待恢复的状态副本。
## [br]
## @param _tick: 状态所属 tick。
## [br]
## @param _context: 协调器上下文副本。
## [br]
## @schema _state: Dictionary，项目定义的完整同步状态。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 恢复报告。
## [br]
## @schema return: Dictionary { ok: bool, error?: String }.
func _restore_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"error": "restore_state_not_implemented",
	}


## 校验并授权一帧输入。
##
## 项目必须使用 actual_peer_id 判断实体控制权；payload 中自带的 owner 字段不能作为授权。
## Authority 会在收包排队时和目标 tick 模拟前各调用一次，以避免控制权变化产生
## time-of-check/time-of-use 间隙；两次调用都必须只读取当前授权状态。
## 该钩子必须无副作用，不得修改项目模拟状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _frame: 待校验输入帧副本。
## [br]
## @param _actual_peer_id: 底层 transport 报告的实际来源 peer。
## [br]
## @param _context: 协调器上下文副本。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 输入校验报告。
## [br]
## @schema return: Dictionary { ok: bool, error?: String }.
func _validate_input(
	_frame: GFNetworkInputFrame,
	_actual_peer_id: int,
	_context: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"error": "validate_input_not_implemented",
	}


## 执行一个完整模拟 tick。
##
## inputs 已在当前 authority tick 重新授权，并按 peer_id、sequence 稳定排序；
## 无输入 tick 也会收到空数组。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _tick: 要执行的连续模拟 tick。
## [br]
## @param _inputs: 该 tick 的输入帧副本。
## [br]
## @param _context: 协调器上下文副本。
## [br]
## @schema _inputs: Array[GFNetworkInputFrame]，按 peer_id、sequence 升序排列。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 模拟报告。
## [br]
## @schema return: Dictionary { ok: bool, error?: String }.
func _simulate_tick(
	_tick: int,
	_inputs: Array[GFNetworkInputFrame],
	_context: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"error": "simulate_tick_not_implemented",
	}


## 比较预测状态与权威状态是否等价。
##
## 默认使用 Godot Variant 相等比较；项目可重写以加入量化容差。
## 该钩子必须无副作用，不得修改项目模拟状态。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param predicted_state: 本地预测状态副本。
## [br]
## @param authoritative_state: 权威状态副本。
## [br]
## @param _tick: 两份状态所属 tick。
## [br]
## @param _context: 协调器上下文副本。
## [br]
## @schema predicted_state: Dictionary，项目定义的预测状态。
## [br]
## @schema authoritative_state: Dictionary，项目定义的权威状态。
## [br]
## @schema _context: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
## [br]
## @return 项目认为两份状态等价时返回 true。
func _states_equal(
	predicted_state: Dictionary,
	authoritative_state: Dictionary,
	_tick: int,
	_context: Dictionary
) -> bool:
	return predicted_state == authoritative_state
