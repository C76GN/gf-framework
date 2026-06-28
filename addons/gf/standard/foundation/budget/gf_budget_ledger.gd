## GFBudgetLedger: 通用资源预算账本。
##
## 用于记录一组抽象资源的容量、可用量和消耗结果。
## 资源含义由项目决定，框架只提供预算检查、消费、释放和快照。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFBudgetLedger
extends RefCounted


# --- 信号 ---

## 资源预算变化后发出。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param available: 当前可用量。
## [br]
## @param capacity: 当前容量。
signal budget_changed(budget_id: StringName, available: float, capacity: float)

## 资源消费成功后发出。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param amount: 消费数量。
signal budget_consumed(budget_id: StringName, amount: float)

## 资源消费被拒绝后发出。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param amount: 请求数量。
## [br]
## @param reason: 拒绝原因。
signal budget_rejected(budget_id: StringName, amount: float, reason: String)

## 所有预算清空后发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param budget_ids: 被清空的预算标识列表。
signal budgets_cleared(budget_ids: PackedStringArray)


# --- 私有变量 ---

var _budgets: Dictionary = {}


# --- 公共方法 ---

## 设置预算容量，并可选重置可用量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param capacity: 容量。
## [br]
## @param reset_available: 是否把可用量重置为容量。
func set_capacity(budget_id: StringName, capacity: float, reset_available: bool = true) -> void:
	if budget_id == &"":
		return

	var normalized_capacity: float = _normalize_non_negative_amount(capacity)
	var entry: Dictionary = _get_or_make_entry(budget_id)
	entry["capacity"] = normalized_capacity
	if reset_available:
		entry["available"] = normalized_capacity
	else:
		entry["available"] = clampf(_get_entry_available(entry), 0.0, normalized_capacity)
	_budgets[budget_id] = entry
	budget_changed.emit(budget_id, _get_entry_available(entry), normalized_capacity)


## 设置当前可用量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param available: 可用量。
func set_available(budget_id: StringName, available: float) -> void:
	if budget_id == &"":
		return

	var entry: Dictionary = _get_or_make_entry(budget_id)
	var capacity: float = _get_entry_capacity(entry)
	entry["available"] = clampf(_normalize_non_negative_amount(available), 0.0, capacity)
	_budgets[budget_id] = entry
	budget_changed.emit(budget_id, _get_entry_available(entry), capacity)


## 获取容量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @return 容量；不存在时返回 0。
func get_capacity(budget_id: StringName) -> float:
	return _get_entry_capacity(_get_entry_copy(budget_id))


## 获取可用量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @return 可用量；不存在时返回 0。
func get_available(budget_id: StringName) -> float:
	return _get_entry_available(_get_entry_copy(budget_id))


## 是否有足够预算。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param amount: 请求数量。
## [br]
## @return 预算足够时返回 true。
func can_consume(budget_id: StringName, amount: float) -> bool:
	if budget_id == &"" or not _is_finite_amount(amount) or amount < 0.0:
		return false
	return get_available(budget_id) >= amount


## 尝试消费预算。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param amount: 消费数量。
## [br]
## @param metadata: 调用方附加信息。
## [br]
## @return 消费结果字典。
## [br]
## @schema metadata: Dictionary copied into the consume result.
## [br]
## @schema return: Dictionary with ok, budget_id, amount, reason, available, capacity, and metadata.
func consume(budget_id: StringName, amount: float, metadata: Dictionary = {}) -> Dictionary:
	if budget_id == &"":
		budget_rejected.emit(budget_id, amount, "empty_budget_id")
		return _make_result(false, budget_id, amount, "empty_budget_id", metadata)
	if not _is_finite_amount(amount):
		budget_rejected.emit(budget_id, amount, "invalid_amount")
		return _make_result(false, budget_id, amount, "invalid_amount", metadata)
	if amount < 0.0:
		budget_rejected.emit(budget_id, amount, "negative_amount")
		return _make_result(false, budget_id, amount, "negative_amount", metadata)
	if not _budgets.has(budget_id):
		budget_rejected.emit(budget_id, amount, "missing_budget")
		return _make_result(false, budget_id, amount, "missing_budget", metadata)
	if not can_consume(budget_id, amount):
		budget_rejected.emit(budget_id, amount, "insufficient_budget")
		return _make_result(false, budget_id, amount, "insufficient_budget", metadata)

	var entry: Dictionary = _get_entry_copy(budget_id)
	entry["available"] = _get_entry_available(entry) - amount
	_budgets[budget_id] = entry
	budget_consumed.emit(budget_id, amount)
	budget_changed.emit(budget_id, _get_entry_available(entry), _get_entry_capacity(entry))
	return _make_result(true, budget_id, amount, "", metadata)


## 释放预算，可用量不会超过容量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识。
## [br]
## @param amount: 释放数量。
func release(budget_id: StringName, amount: float) -> void:
	if budget_id == &"" or not _is_finite_amount(amount) or amount <= 0.0:
		return
	if not _budgets.has(budget_id):
		return

	var entry: Dictionary = _get_entry_copy(budget_id)
	var capacity: float = _get_entry_capacity(entry)
	entry["available"] = clampf(_get_entry_available(entry) + amount, 0.0, capacity)
	_budgets[budget_id] = entry
	budget_changed.emit(budget_id, _get_entry_available(entry), capacity)


## 将一个或全部预算重置为容量。
## [br]
## @api public
## [br]
## @param budget_id: 预算标识；为空时重置全部。
func reset(budget_id: StringName = &"") -> void:
	if budget_id != &"":
		if not _budgets.has(budget_id):
			return
		var entry: Dictionary = _get_entry_copy(budget_id)
		entry["available"] = _get_entry_capacity(entry)
		_budgets[budget_id] = entry
		budget_changed.emit(budget_id, _get_entry_available(entry), _get_entry_capacity(entry))
		return

	for key: StringName in _budgets.keys():
		reset(key)


## 清空所有预算。
## [br]
## @api public
func clear() -> void:
	if _budgets.is_empty():
		return

	var budget_ids: PackedStringArray = PackedStringArray()
	for budget_id: StringName in _budgets.keys():
		var _append_result: bool = budget_ids.append(String(budget_id))
	budget_ids.sort()
	_budgets.clear()
	budgets_cleared.emit(budget_ids)


## 获取预算快照。
## [br]
## @api public
## [br]
## @return 预算字典副本。
## [br]
## @schema return: Dictionary from budget id to capacity and available values.
func get_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in _budgets.keys():
		result[String(key)] = _get_entry_copy(key)
	return result


# --- 私有/辅助方法 ---

func _get_or_make_entry(budget_id: StringName) -> Dictionary:
	if _budgets.has(budget_id):
		return _get_entry_copy(budget_id)
	return {
		"capacity": 0.0,
		"available": 0.0,
	}


func _get_entry_copy(budget_id: StringName) -> Dictionary:
	return GFVariantData.to_dictionary(_budgets[budget_id]) if _budgets.has(budget_id) else {}


func _get_entry_capacity(entry: Dictionary) -> float:
	return GFVariantData.get_option_float(entry, "capacity", 0.0)


func _get_entry_available(entry: Dictionary) -> float:
	return GFVariantData.get_option_float(entry, "available", 0.0)


func _make_result(
	ok: bool,
	budget_id: StringName,
	amount: float,
	reason: String,
	metadata: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"budget_id": budget_id,
		"amount": amount,
		"reason": reason,
		"available": get_available(budget_id),
		"capacity": get_capacity(budget_id),
		"metadata": metadata.duplicate(true),
	}


func _normalize_non_negative_amount(value: float) -> float:
	if not _is_finite_amount(value):
		return 0.0
	return maxf(0.0, value)


func _is_finite_amount(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
