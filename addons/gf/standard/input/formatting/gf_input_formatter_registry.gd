## GFInputFormatterRegistry: 输入格式化 provider 注册表。
##
## 为文本和图标 provider 提供可排序、可 owner 绑定、可显式释放的注册生命周期。
## GFInputFormatter 的静态入口会使用默认 registry；测试、编辑器工具或局部 UI 可创建独立 registry 避免全局污染。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer standard/input
class_name GFInputFormatterRegistry
extends RefCounted


# --- 常量 ---

## 文本 provider 注册项使用的类型标识。
## [br]
## @api private
## [br]
const _PROVIDER_KIND_TEXT: StringName = &"text"

## 图标 provider 注册项使用的类型标识。
## [br]
## @api private
## [br]
const _PROVIDER_KIND_ICON: StringName = &"icon"


# --- 私有变量 ---

## 按优先级和注册顺序保存的文本 provider 注册项。
## [br]
## @api private
## [br]
var _text_entries: Array[Dictionary] = []

## 按优先级和注册顺序保存的图标 provider 注册项。
## [br]
## @api private
## [br]
var _icon_entries: Array[Dictionary] = []

## 为新注册项分配稳定先后顺序的递增序号。
## [br]
## @api private
## [br]
var _next_order: int = 0


# --- 公共方法 ---

## 注册文本 provider 并返回释放句柄。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 文本 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。
## [br]
## @return 注册句柄；provider 为空时返回非活动句柄。
func register_text_provider(
	provider: GFInputTextProvider,
	owner: Object = null
) -> GFInputProviderRegistration:
	return _register_provider(_text_entries, _PROVIDER_KIND_TEXT, provider, owner)


## 注册图标 provider 并返回释放句柄。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 图标 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。
## [br]
## @return 注册句柄；provider 为空时返回非活动句柄。
func register_icon_provider(
	provider: GFInputIconProvider,
	owner: Object = null
) -> GFInputProviderRegistration:
	return _register_provider(_icon_entries, _PROVIDER_KIND_ICON, provider, owner)


## 注册文本 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 文本 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。
func add_text_provider(provider: GFInputTextProvider, owner: Object = null) -> void:
	var _registration: GFInputProviderRegistration = register_text_provider(provider, owner)


## 注册图标 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 图标 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。
func add_icon_provider(provider: GFInputIconProvider, owner: Object = null) -> void:
	var _registration: GFInputProviderRegistration = register_icon_provider(provider, owner)


## 移除文本 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 文本 provider。
## [br]
## @return 移除了至少一个注册时返回 true。
func remove_text_provider(provider: GFInputTextProvider) -> bool:
	return _remove_provider(_text_entries, provider)


## 移除图标 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 图标 provider。
## [br]
## @return 移除了至少一个注册时返回 true。
func remove_icon_provider(provider: GFInputIconProvider) -> bool:
	return _remove_provider(_icon_entries, provider)


## 清空文本 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_text_providers() -> void:
	_clear_entries(_text_entries)


## 清空图标 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_icon_providers() -> void:
	_clear_entries(_icon_entries)


## 获取文本 provider 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return provider 列表副本，按优先级从高到低排序。
func get_text_providers() -> Array[GFInputTextProvider]:
	var _pruned_count: int = _prune_entries(_text_entries)
	_sort_entries(_text_entries)
	var result: Array[GFInputTextProvider] = []
	for entry: Dictionary in _text_entries:
		var provider: GFInputTextProvider = _get_text_provider_from_entry(entry)
		if provider != null:
			result.append(provider)
	return result


## 获取图标 provider 列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return provider 列表副本，按优先级从高到低排序。
func get_icon_providers() -> Array[GFInputIconProvider]:
	var _pruned_count: int = _prune_entries(_icon_entries)
	_sort_entries(_icon_entries)
	var result: Array[GFInputIconProvider] = []
	for entry: Dictionary in _icon_entries:
		var provider: GFInputIconProvider = _get_icon_provider_from_entry(entry)
		if provider != null:
			result.append(provider)
	return result


## 裁剪拥有者已经释放的 provider 注册。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被裁剪的注册数量。
func prune_invalid_provider_owners() -> int:
	return _prune_entries(_text_entries) + _prune_entries(_icon_entries)


## 清理 registry 中的所有 provider 注册。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	clear_text_providers()
	clear_icon_providers()


# --- 框架内部方法 ---

## 按注册句柄释放 provider。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param registration: 注册句柄。
## [br]
## @return 本次调用确实释放注册时返回 true。
func release_registration(registration: GFInputProviderRegistration) -> bool:
	if registration == null:
		return false
	var removed: bool = false
	if registration.provider_kind == _PROVIDER_KIND_TEXT:
		removed = _remove_registration(_text_entries, registration)
	elif registration.provider_kind == _PROVIDER_KIND_ICON:
		removed = _remove_registration(_icon_entries, registration)
	if removed:
		registration.mark_released()
	return removed


# --- 私有/辅助方法 ---

## 清理失效项，复用同 provider 的活动注册，或创建带 owner 弱引用的注册并排序。
## [br]
## @api private
## [br]
func _register_provider(
	entries: Array[Dictionary],
	provider_kind: StringName,
	provider: Resource,
	owner: Object
) -> GFInputProviderRegistration:
	var _pruned_count: int = _prune_entries(entries)
	if provider == null:
		return GFInputProviderRegistration.new()

	var existing: GFInputProviderRegistration = _find_registration_for_provider(entries, provider)
	if existing != null:
		return existing

	var registration: GFInputProviderRegistration = GFInputProviderRegistration.new()
	registration.setup_from_registry(self, provider_kind, provider)
	entries.append({
		&"provider": provider,
		&"owner_ref": weakref(owner) if owner != null else null,
		&"registration": registration,
		&"order": _next_order,
	})
	_next_order += 1
	_sort_entries(entries)
	return registration


## 按 provider 对象身份查找现有注册句柄，未找到时返回 null。
## [br]
## @api private
## [br]
func _find_registration_for_provider(entries: Array[Dictionary], provider: Resource) -> GFInputProviderRegistration:
	for entry: Dictionary in entries:
		var entry_provider: Resource = _get_provider_from_entry(entry)
		if entry_provider != provider:
			continue
		return _get_registration_from_entry(entry)
	return null


## 移除匹配 provider 的全部注册项，标记其句柄已释放并保留其他项。
## [br]
## @api private
## [br]
func _remove_provider(entries: Array[Dictionary], provider: Resource) -> bool:
	if provider == null:
		return false

	var removed: bool = false
	var kept_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var entry_provider: Resource = _get_provider_from_entry(entry)
		if entry_provider == provider:
			_mark_entry_registration_released(entry)
			removed = true
		else:
			kept_entries.append(entry)
	_replace_entries(entries, kept_entries)
	return removed


## 按注册句柄对象身份移除对应项并保留其余项。
## [br]
## @api private
## [br]
func _remove_registration(entries: Array[Dictionary], registration: GFInputProviderRegistration) -> bool:
	var removed: bool = false
	var kept_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var entry_registration: GFInputProviderRegistration = _get_registration_from_entry(entry)
		if entry_registration == registration:
			removed = true
		else:
			kept_entries.append(entry)
	_replace_entries(entries, kept_entries)
	return removed


## 把所有注册句柄标记为已释放后清空注册项数组。
## [br]
## @api private
## [br]
func _clear_entries(entries: Array[Dictionary]) -> void:
	for entry: Dictionary in entries:
		_mark_entry_registration_released(entry)
	entries.clear()


## 保留仍有效的 provider、注册句柄和 owner 项，释放并计数清除失效项。
## [br]
## @api private
## [br]
func _prune_entries(entries: Array[Dictionary]) -> int:
	var pruned_count: int = 0
	var kept_entries: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if _entry_is_live(entry):
			kept_entries.append(entry)
		else:
			_mark_entry_registration_released(entry)
			pruned_count += 1
	_replace_entries(entries, kept_entries)
	return pruned_count


## 要求 provider 与活动句柄有效，且 owner 弱引用为空或仍指向对象。
## [br]
## @api private
## [br]
func _entry_is_live(entry: Dictionary) -> bool:
	if _get_provider_from_entry(entry) == null:
		return false
	var registration: GFInputProviderRegistration = _get_registration_from_entry(entry)
	if registration == null or not registration.is_active():
		return false
	var owner_ref: WeakRef = _get_owner_ref_from_entry(entry)
	return owner_ref == null or owner_ref.get_ref() != null


## 按 provider 优先级降序、注册顺序升序稳定排序。
## [br]
## @api private
## [br]
func _sort_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = _get_entry_priority(left)
		var right_priority: int = _get_entry_priority(right)
		if left_priority == right_priority:
			return _get_entry_order(left) < _get_entry_order(right)
		return left_priority > right_priority
	)


## 用给定保留项重建注册数组。
## [br]
## @api private
## [br]
func _replace_entries(entries: Array[Dictionary], kept_entries: Array[Dictionary]) -> void:
	entries.clear()
	for entry: Dictionary in kept_entries:
		entries.append(entry)


## 读取文本或图标 provider 的优先级，未知资源类型返回 0。
## [br]
## @api private
## [br]
func _get_entry_priority(entry: Dictionary) -> int:
	var provider: Resource = _get_provider_from_entry(entry)
	if provider is GFInputTextProvider:
		var text_provider: GFInputTextProvider = provider
		return text_provider.get_priority()
	if provider is GFInputIconProvider:
		var icon_provider: GFInputIconProvider = provider
		return icon_provider.get_priority()
	return 0


## 从注册项读取注册序号。
## [br]
## @api private
## [br]
func _get_entry_order(entry: Dictionary) -> int:
	return GFVariantData.get_option_int(entry, &"order")


## 从注册项读取 Resource provider，类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_provider_from_entry(entry: Dictionary) -> Resource:
	var provider_value: Variant = GFVariantData.get_option_value(entry, &"provider")
	if provider_value is Resource:
		var provider: Resource = provider_value
		return provider
	return null


## 将注册项 provider 收窄为 GFInputTextProvider。
## [br]
## @api private
## [br]
func _get_text_provider_from_entry(entry: Dictionary) -> GFInputTextProvider:
	var provider: Resource = _get_provider_from_entry(entry)
	if provider is GFInputTextProvider:
		var text_provider: GFInputTextProvider = provider
		return text_provider
	return null


## 将注册项 provider 收窄为 GFInputIconProvider。
## [br]
## @api private
## [br]
func _get_icon_provider_from_entry(entry: Dictionary) -> GFInputIconProvider:
	var provider: Resource = _get_provider_from_entry(entry)
	if provider is GFInputIconProvider:
		var icon_provider: GFInputIconProvider = provider
		return icon_provider
	return null


## 将注册项句柄收窄为 GFInputProviderRegistration。
## [br]
## @api private
## [br]
func _get_registration_from_entry(entry: Dictionary) -> GFInputProviderRegistration:
	var registration_value: Variant = GFVariantData.get_option_value(entry, &"registration")
	if registration_value is GFInputProviderRegistration:
		var registration: GFInputProviderRegistration = registration_value
		return registration
	return null


## 将注册项 owner_ref 收窄为 WeakRef。
## [br]
## @api private
## [br]
func _get_owner_ref_from_entry(entry: Dictionary) -> WeakRef:
	var owner_ref_value: Variant = GFVariantData.get_option_value(entry, &"owner_ref")
	if owner_ref_value is WeakRef:
		var owner_ref: WeakRef = owner_ref_value
		return owner_ref
	return null


## 若注册项含有效句柄则调用 mark_released 清除关联状态。
## [br]
## @api private
## [br]
func _mark_entry_registration_released(entry: Dictionary) -> void:
	var registration: GFInputProviderRegistration = _get_registration_from_entry(entry)
	if registration != null:
		registration.mark_released()
