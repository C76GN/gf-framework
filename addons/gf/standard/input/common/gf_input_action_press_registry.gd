# GFInputActionPressRegistry: 标准输入模块内部 InputMap 动作按压聚合器。
#
# 多个虚拟输入源可共享同一个 InputMap 动作；只有最后一个 owner 释放后才真正释放动作。
# owner 生命周期由 GFLifetimeSubscription 绑定，Node 退出树时会自动释放其全部动作。
extends RefCounted


# --- 私有变量 ---

static var _action_owners: Dictionary = {}
static var _owner_lifetimes: Dictionary = {}


# --- 公共方法 ---

## 以 owner 身份按下动作。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param action_id: InputMap 动作名。
## [br]
## @param owner: 当前按压来源对象。
## [br]
## @param channel_id: owner 内部的稳定通道 ID。
## [br]
## @param strength: 动作强度。
## [br]
## @return 按压成功时返回 true。
static func press(
	action_id: StringName,
	owner: Object,
	channel_id: StringName = &"default",
	strength: float = 1.0
) -> bool:
	var _pruned_count: int = prune_released_owners()
	var owner_key: String = _make_owner_key(owner, channel_id)
	if action_id == &"" or owner_key.is_empty():
		return false

	var normalized_strength: float = _normalize_strength(strength)
	if normalized_strength <= 0.0:
		return release(action_id, owner, channel_id)
	if not _ensure_owner_lifetime(owner, owner_key):
		return false

	var owners: Dictionary = _get_or_create_action_owners(action_id)
	owners[owner_key] = normalized_strength
	Input.action_press(action_id, _get_max_strength(owners))
	return true


## 释放指定 owner 的动作按压。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param action_id: InputMap 动作名。
## [br]
## @param owner: 当前按压来源对象。
## [br]
## @param channel_id: owner 内部的稳定通道 ID。
## [br]
## @return 找到 owner 按压时返回 true。
static func release(action_id: StringName, owner: Object, channel_id: StringName = &"default") -> bool:
	var _pruned_count: int = prune_released_owners()
	var owner_key: String = _make_owner_key(owner, channel_id)
	if action_id == &"" or owner_key.is_empty():
		return false
	return _release_action_owner_key(action_id, owner_key)


## 释放指定 owner 持有的所有动作。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param owner: 当前按压来源对象。
## [br]
## @return 找到 owner 生命周期时返回 true。
static func release_owner(owner: Object) -> bool:
	if not is_instance_valid(owner):
		return false
	var owner_prefix: String = "%d:" % owner.get_instance_id()
	var owner_keys: Array[String] = []
	for owner_key_value: Variant in _owner_lifetimes.keys():
		var owner_key: String = GFVariantData.to_text(owner_key_value)
		if owner_key.begins_with(owner_prefix):
			owner_keys.append(owner_key)
	for owner_key: String in owner_keys:
		_cancel_owner_lifetime(owner_key)
	return not owner_keys.is_empty()


## 释放全部虚拟动作并清空静态生命周期状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
static func clear_all() -> void:
	var action_ids: Array[StringName] = []
	for action_key: Variant in _action_owners.keys():
		var action_id: StringName = _variant_to_action_id(action_key)
		if action_id != &"":
			action_ids.append(action_id)
	var lifetimes: Array = _owner_lifetimes.values()
	_action_owners.clear()
	_owner_lifetimes.clear()
	for action_id: StringName in action_ids:
		Input.action_release(action_id)
	for lifetime_value: Variant in lifetimes:
		var lifetime: GFLifetimeSubscription = _variant_to_lifetime(lifetime_value)
		if lifetime != null:
			var _cancelled: bool = lifetime.cancel()


## 清理已释放普通 Object owner。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @return 本次清理的 owner 数量。
static func prune_released_owners() -> int:
	var owner_keys: Array[String] = []
	for owner_key_value: Variant in _owner_lifetimes.keys():
		var owner_key: String = GFVariantData.to_text(owner_key_value)
		var lifetime: GFLifetimeSubscription = _get_owner_lifetime(owner_key)
		if lifetime == null or lifetime.owner_is_released():
			owner_keys.append(owner_key)
	for owner_key: String in owner_keys:
		_cancel_owner_lifetime(owner_key)
	return owner_keys.size()


# --- 私有/辅助方法 ---

static func _release_action_owner_key(action_id: StringName, owner_key: String) -> bool:

	var owners: Dictionary = _get_action_owners(action_id)
	if owners.is_empty():
		return false

	var removed_owner: bool = owners.erase(owner_key)
	if not removed_owner:
		return false
	if owners.is_empty():
		var _removed_action: bool = _action_owners.erase(action_id)
		Input.action_release(action_id)
	else:
		Input.action_press(action_id, _get_max_strength(owners))
	if not _owner_key_has_actions(owner_key):
		_cancel_owner_lifetime(owner_key)
	return true


static func _release_owner_key(owner_key: String) -> void:
	var action_ids: Array[StringName] = []
	for action_key: Variant in _action_owners.keys():
		var action_id: StringName = _variant_to_action_id(action_key)
		if action_id != &"" and _get_action_owners(action_id).has(owner_key):
			action_ids.append(action_id)
	var _removed_lifetime: bool = _owner_lifetimes.erase(owner_key)
	for action_id: StringName in action_ids:
		_remove_action_owner_key(action_id, owner_key)


static func _remove_action_owner_key(action_id: StringName, owner_key: String) -> void:
	var owners: Dictionary = _get_action_owners(action_id)
	if owners.is_empty() or not owners.erase(owner_key):
		return
	if owners.is_empty():
		var _removed_action: bool = _action_owners.erase(action_id)
		Input.action_release(action_id)
	else:
		Input.action_press(action_id, _get_max_strength(owners))


static func _ensure_owner_lifetime(owner: Object, owner_key: String) -> bool:
	var current: GFLifetimeSubscription = _get_owner_lifetime(owner_key)
	if current != null and current.is_active():
		return true
	var lifetime: GFLifetimeSubscription = GFLifetimeSubscription.new(
		owner,
		func() -> void:
			_release_owner_key(owner_key),
		"virtual_input:%s" % owner_key
	)
	if not lifetime.is_active():
		return false
	_owner_lifetimes[owner_key] = lifetime
	return true


static func _cancel_owner_lifetime(owner_key: String) -> void:
	var lifetime: GFLifetimeSubscription = _get_owner_lifetime(owner_key)
	var _removed_lifetime: bool = _owner_lifetimes.erase(owner_key)
	if lifetime != null and lifetime.is_active():
		var _cancelled: bool = lifetime.cancel()
	else:
		_release_owner_key(owner_key)


static func _owner_key_has_actions(owner_key: String) -> bool:
	for owners_value: Variant in _action_owners.values():
		if owners_value is Dictionary:
			var owners: Dictionary = owners_value
			if owners.has(owner_key):
				return true
	return false


static func _make_owner_key(owner: Object, channel_id: StringName) -> String:
	if not is_instance_valid(owner):
		return ""
	var channel_text: String = String(channel_id)
	return "%d:%d:%s" % [owner.get_instance_id(), channel_text.length(), channel_text]


static func _get_owner_lifetime(owner_key: String) -> GFLifetimeSubscription:
	return _variant_to_lifetime(GFVariantData.get_option_value(_owner_lifetimes, owner_key))


static func _variant_to_lifetime(value: Variant) -> GFLifetimeSubscription:
	if value is GFLifetimeSubscription:
		var lifetime: GFLifetimeSubscription = value
		return lifetime
	return null

static func _get_or_create_action_owners(action_id: StringName) -> Dictionary:
	var owners: Dictionary = _get_action_owners(action_id)
	if owners.is_empty() and not _action_owners.has(action_id):
		owners = {}
		_action_owners[action_id] = owners
	return owners


static func _get_action_owners(action_id: StringName) -> Dictionary:
	var value: Variant = _action_owners.get(action_id)
	if value is Dictionary:
		var owners: Dictionary = value
		return owners
	return {}


static func _get_max_strength(owners: Dictionary) -> float:
	var result: float = 0.0
	for strength_value: Variant in owners.values():
		var strength: float = 0.0
		if strength_value is float:
			strength = strength_value
		elif strength_value is int:
			var strength_int: int = strength_value
			strength = float(strength_int)
		else:
			continue
		result = maxf(result, _normalize_strength(strength))
	return result


static func _normalize_strength(strength: float) -> float:
	if is_nan(strength) or is_inf(strength):
		return 0.0
	return clampf(strength, 0.0, 1.0)


static func _variant_to_action_id(value: Variant) -> StringName:
	if value is StringName:
		var action_id: StringName = value
		return action_id
	if value is String:
		var action_text: String = value
		return StringName(action_text)
	return &""
