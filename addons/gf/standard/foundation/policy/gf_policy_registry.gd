## GFPolicyRegistry: 通用策略 Provider 注册表。
##
## 管理 GFPolicyProvider 集合，并按 artifact kind 对输入 artifact 执行匹配策略。
## 注册表只负责协议分发和结果汇总，不解释具体业务字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFPolicyRegistry
extends Resource


# --- 导出变量 ---

## 已注册 Provider 列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema providers: Array[GFPolicyProvider] policy providers.
@export var providers: Array[GFPolicyProvider] = []


# --- 公共方法 ---

## 注册或替换 Provider。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param provider: 策略 Provider。
## [br]
## @return 注册成功返回 true。
func register_provider(provider: GFPolicyProvider) -> bool:
	if provider == null or provider.provider_id == &"":
		return false
	for index: int in range(providers.size()):
		var existing: GFPolicyProvider = providers[index]
		if existing != null and existing.provider_id == provider.provider_id:
			providers[index] = provider
			_sort_providers()
			return true
	providers.append(provider)
	_sort_providers()
	return true


## 注销 Provider。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param provider_id: Provider 稳定标识。
## [br]
## @return 注销成功返回 true。
func unregister_provider(provider_id: StringName) -> bool:
	for index: int in range(providers.size() - 1, -1, -1):
		var provider: GFPolicyProvider = providers[index]
		if provider != null and provider.provider_id == provider_id:
			providers.remove_at(index)
			return true
	return false


## 清空 Provider。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	providers.clear()


## 获取 Provider。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param provider_id: Provider 稳定标识。
## [br]
## @return Provider；不存在时返回 null。
func get_provider(provider_id: StringName) -> GFPolicyProvider:
	for provider: GFPolicyProvider in providers:
		if provider != null and provider.provider_id == provider_id:
			return provider
	return null


## 获取支持 artifact 的 Provider 列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param artifact: artifact 字典。
## [br]
## @schema artifact: Dictionary with optional kind or artifact_kind.
## [br]
## @return Provider 列表。
func get_providers_for_artifact(artifact: Dictionary) -> Array[GFPolicyProvider]:
	var result: Array[GFPolicyProvider] = []
	for provider: GFPolicyProvider in _get_sorted_provider_snapshot():
		if provider != null and provider.supports_artifact(artifact):
			result.append(provider)
	return result


## 对 artifact 执行匹配策略。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param artifact: artifact 字典。
## [br]
## @param context: 调用方上下文。
## [br]
## @schema artifact: Dictionary policy input artifact.
## [br]
## @schema context: Dictionary caller-defined policy context.
## [br]
## @return 汇总结果。
## [br]
## @schema return: Dictionary with ok, provider_count, result_count, results, issues, and artifact.
func evaluate_artifact(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:
	var matching_providers: Array[GFPolicyProvider] = get_providers_for_artifact(artifact)
	var results: Array[Dictionary] = []
	var issues: Array = []
	var ok: bool = true
	for provider: GFPolicyProvider in matching_providers:
		var result: Dictionary = provider.evaluate(artifact, context)
		results.append(result)
		if not GFVariantData.get_option_bool(result, "ok", true):
			ok = false
		issues.append_array(GFVariantData.get_option_array(result, "issues"))
	return {
		"ok": ok,
		"provider_count": matching_providers.size(),
		"result_count": results.size(),
		"results": results,
		"issues": issues,
		"artifact": artifact.duplicate(true),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing provider_count and provider_ids.
func get_debug_snapshot() -> Dictionary:
	var provider_ids: PackedStringArray = PackedStringArray()
	for provider: GFPolicyProvider in providers:
		if provider == null:
			continue
		var _append_provider_id: bool = provider_ids.append(String(provider.provider_id))
	return {
		"provider_count": providers.size(),
		"provider_ids": provider_ids,
	}


# --- 私有/辅助方法 ---

func _sort_providers() -> void:
	providers.sort_custom(func(left: GFPolicyProvider, right: GFPolicyProvider) -> bool:
		return _compare_providers(left, right)
	)


func _get_sorted_provider_snapshot() -> Array[GFPolicyProvider]:
	var snapshot: Array[GFPolicyProvider] = []
	for provider: GFPolicyProvider in providers:
		if provider != null:
			snapshot.append(provider)
	snapshot.sort_custom(func(left: GFPolicyProvider, right: GFPolicyProvider) -> bool:
		return _compare_providers(left, right)
	)
	return snapshot


func _compare_providers(left: GFPolicyProvider, right: GFPolicyProvider) -> bool:
	var left_priority: int = left.priority if left != null else 0
	var right_priority: int = right.priority if right != null else 0
	if left_priority == right_priority:
		var left_id: String = String(left.provider_id) if left != null else ""
		var right_id: String = String(right.provider_id) if right != null else ""
		return left_id < right_id
	return left_priority < right_priority
