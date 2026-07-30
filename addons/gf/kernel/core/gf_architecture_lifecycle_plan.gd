## GFArchitectureLifecyclePlan: GFArchitecture 的确定性生命周期依赖计划。
##
## 从本地 Model、Utility、System 注册快照构建依赖 DAG，并保存激活顺序、
## 严格逆序的关闭快照与有界诊断。父架构解析到的依赖仅视为外部满足项，
## 不会成为本地 DAG 节点。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
## [br]
## @layer kernel/core
class_name GFArchitectureLifecyclePlan
extends RefCounted


# --- 常量 ---

const _DIAGNOSTIC_LIMIT: int = 64
const _MAX_CYCLE_MEMBERS_PER_DIAGNOSTIC: int = 32

const _GF_SCRIPT_TYPE_INSPECTOR_SCRIPT = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")

const _KIND_MODEL: StringName = &"Model"
const _KIND_UTILITY: StringName = &"Utility"
const _KIND_SYSTEM: StringName = &"System"

const _REGISTRY_MODELS: StringName = &"models"
const _REGISTRY_UTILITIES: StringName = &"utilities"
const _REGISTRY_SYSTEMS: StringName = &"systems"
const _REGISTRY_FACTORIES: StringName = &"factories"

const _HOOK_REQUIRED_MODELS: StringName = &"get_required_models"
const _HOOK_REQUIRED_UTILITIES: StringName = &"get_required_utilities"
const _HOOK_REQUIRED_SYSTEMS: StringName = &"get_required_systems"
const _HOOK_REQUIRED_FACTORIES: StringName = &"get_required_factories"

const _STATUS_LOCAL: StringName = &"local"
const _STATUS_EXTERNAL: StringName = &"external"
const _STATUS_MISSING: StringName = &"missing"
const _STATUS_STALE_ALIAS: StringName = &"stale_alias"
const _STATUS_AMBIGUOUS: StringName = &"ambiguous"
const _STATUS_PARENT_CYCLE: StringName = &"parent_cycle"
const _STATUS_INVALID: StringName = &"invalid"


# --- 私有变量 ---

var _valid: bool = false
var _activation_order: Array[Object] = []
var _shutdown_order: Array[Object] = []
var _diagnostics: Array[Dictionary] = []
var _diagnostics_truncated: bool = false
var _external_dependency_count: int = 0
var _node_id_by_instance: Dictionary = {}
var _local_dependencies_by_instance: Dictionary = {}
var _dependency_snapshot: Array[Dictionary] = []
var _dependency_records: Array[Dictionary] = []


# --- 框架内部方法 ---

## 编译当前注册快照的生命周期依赖计划。
## [br]
## 权威 resolver 应采用 GFArchitecture 的 exact、alias、唯一 assignable 与
## parent lookup 规则，并返回结构化 status。Model、Utility、System 的 local
## 结果会建立 DAG 边；external 结果只记录为外部满足项。Factory 只校验
## binding availability，不会建立 DAG 边或触发实例化。未提供 resolver 时，
## 模块依赖仅使用注册快照进行 exact / 唯一 assignable 本地解析，Factory
## 依赖按 missing 处理。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param model_instances: 本地 Model 注册快照。
## [br]
## @schema model_instances: Dictionary keyed by Script, storing GFModel instances in registration order.
## [br]
## @param utility_instances: 本地 Utility 注册快照。
## [br]
## @schema utility_instances: Dictionary keyed by Script, storing GFUtility instances in registration order.
## [br]
## @param system_instances: 本地 System 注册快照。
## [br]
## @schema system_instances: Dictionary keyed by Script, storing GFSystem instances in registration order.
## [br]
## @param dependency_resolvers: 按依赖类别提供的权威解析 Callable。
## [br]
## @schema dependency_resolvers: Dictionary with models, utilities, systems, and factories Callable values. Each Callable receives a required Script and returns a Dictionary with status plus optional instance, scope, architecture_depth, resolution_kind, registered_script, and parent-cycle fields.
## [br]
## @param validity_guard: 可选同步有效性检查；返回 false 后立即停止调用后续依赖 Hook。
## [br]
## @return: 计划有效且可用于激活时返回 true。
func compile(
	model_instances: Dictionary,
	utility_instances: Dictionary,
	system_instances: Dictionary,
	dependency_resolvers: Dictionary = {},
	validity_guard: Callable = Callable()
) -> bool:
	_reset()
	var nodes: Array[Dictionary] = []
	var node_ids_by_kind: Dictionary = {
		_REGISTRY_MODELS: {},
		_REGISTRY_UTILITIES: {},
		_REGISTRY_SYSTEMS: {},
	}
	_collect_registry_nodes(model_instances, _KIND_MODEL, _REGISTRY_MODELS, nodes, node_ids_by_kind)
	_collect_registry_nodes(utility_instances, _KIND_UTILITY, _REGISTRY_UTILITIES, nodes, node_ids_by_kind)
	_collect_registry_nodes(system_instances, _KIND_SYSTEM, _REGISTRY_SYSTEMS, nodes, node_ids_by_kind)

	if not _is_compilation_valid(validity_guard):
		return false
	if not _collect_dependency_declarations(nodes, validity_guard):
		return false
	if not _collect_dependency_edges(
		nodes,
		node_ids_by_kind,
		dependency_resolvers,
		validity_guard
	):
		return false
	if not _is_compilation_valid(validity_guard):
		return false
	var ordered_node_ids: Array[int] = _build_kahn_order(nodes)
	if ordered_node_ids.size() != nodes.size():
		_append_cycle_diagnostics(nodes, ordered_node_ids)

	_valid = _diagnostics.is_empty() and ordered_node_ids.size() == nodes.size()
	if not _valid:
		_activation_order.clear()
		_shutdown_order.clear()
		return false

	for node_id: int in ordered_node_ids:
		var instance: Object = _get_node_instance(nodes[node_id])
		if instance != null:
			_activation_order.append(instance)
	_shutdown_order = _activation_order.duplicate()
	_shutdown_order.reverse()
	return true


## 返回计划是否有效。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 计划可用于生命周期执行时返回 true。
func is_valid() -> bool:
	return _valid


## 返回激活顺序的防御性副本。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return compile 时冻结的激活顺序副本。
func get_activation_order() -> Array[Object]:
	return _activation_order.duplicate()


## 返回 compile 时保存的严格逆序关闭快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return compile 时冻结的严格逆序关闭顺序副本。
func get_shutdown_order() -> Array[Object]:
	return _shutdown_order.duplicate()


## 返回本地传递依赖的 identity set。
## 父架构或其它 external 依赖不会进入结果；未知实例返回空字典。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param instance: 要查询的本地模块实例。
## [br]
## @param include_self: 是否把 instance 本身加入结果。
## [br]
## @return: 新建的 Object identity set。
## [br]
## @schema return: Dictionary keyed by local module Object, storing true.
func get_dependency_closure(instance: Object, include_self: bool = true) -> Dictionary:
	var result: Dictionary = {}
	if instance == null or not _node_id_by_instance.has(instance):
		return result
	var pending: Array[Object] = [instance]
	while not pending.is_empty():
		var current: Object = pending.pop_back()
		if current == null or result.has(current):
			continue
		result[current] = true
		var dependencies: Array[Object] = _get_object_array(
			_local_dependencies_by_instance.get(current, [])
		)
		for dependency: Object in dependencies:
			if dependency != null and not result.has(dependency):
				pending.append(dependency)
	if not include_self:
		var _removed_self: bool = result.erase(instance)
	return result


## 返回有界诊断的深拷贝。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 有界依赖诊断的深层容器副本。
## [br]
## @schema return: Array of Dictionary entries describing missing, invalid, ambiguous, stale alias, parent cycle, or local cycle dependency failures.
func get_diagnostics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for diagnostic: Dictionary in _diagnostics:
		result.append(diagnostic.duplicate(true))
	return result


## 返回诊断是否因数量上限而截断。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 诊断超过容量并被截断时返回 true。
func were_diagnostics_truncated() -> bool:
	return _diagnostics_truncated


## 返回由父架构或其它 resolver 外部实例满足的声明数量。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 由父架构或其它外部 resolver 满足的声明数量。
func get_external_dependency_count() -> int:
	return _external_dependency_count


## 返回 compile 时捕获的模块依赖声明快照。
## 每次读取都会返回新的深层容器副本；Script 与模块 Object 只作为身份引用保留。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 每个本地模块及其四类声明的稳定快照。
## [br]
## @schema return: Array of Dictionaries with module_kind, module_script, module_instance, module_key, and dependencies. dependencies contains models, utilities, systems, and factories Array[Script] values.
func get_dependency_snapshot() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_dependency_snapshot)


## 返回 compile 时捕获的扁平依赖解析记录。
## invalid plan 同样保留记录，供诊断层渲染具体失败原因。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 防御性复制后的依赖解析记录。
## [br]
## @schema return: Array of Dictionaries with module identity, dependency_kind, dependency_script, status, resolved, scope, resolved_instance, architecture_depth, resolution_kind, registered_script, and parent-cycle fields.
func get_dependency_records() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_dependency_records)


# --- 私有/辅助方法 ---

func _reset() -> void:
	_valid = false
	_activation_order.clear()
	_shutdown_order.clear()
	_diagnostics.clear()
	_diagnostics_truncated = false
	_external_dependency_count = 0
	_node_id_by_instance.clear()
	_local_dependencies_by_instance.clear()
	_dependency_snapshot.clear()
	_dependency_records.clear()


func _collect_registry_nodes(
	registry: Dictionary,
	kind: StringName,
	registry_key: StringName,
	nodes: Array[Dictionary],
	node_ids_by_kind: Dictionary
) -> void:
	var ordinal: int = 0
	for script_variant: Variant in registry.keys():
		if not script_variant is Script:
			_append_diagnostic(
				&"invalid_registration_script",
				kind,
				"%s[%d]" % [kind, ordinal],
				&"",
				"",
				"Registration key must be a Script."
			)
			ordinal += 1
			continue
		var script_cls: Script = script_variant
		var instance: Object = _as_object(registry.get(script_cls))
		var module_key: String = _make_module_key(kind, script_cls, ordinal)
		if instance == null or not _is_expected_module_kind(instance, kind):
			_append_diagnostic(
				&"invalid_registration_instance",
				kind,
				module_key,
				&"",
				"",
				"Registration value does not match its module kind."
			)
			ordinal += 1
			continue
		if _node_id_by_instance.has(instance):
			_append_diagnostic(
				&"duplicate_registration_instance",
				kind,
				module_key,
				&"",
				"",
				"The same instance appears in more than one registration entry."
			)
			ordinal += 1
			continue

		var node_id: int = nodes.size()
		var node: Dictionary = {
			"id": node_id,
			"kind": kind,
			"kind_rank": _get_kind_rank(kind),
			"registry_key": registry_key,
			"script": script_cls,
			"instance": instance,
			"module_key": module_key,
			"priority": _get_lifecycle_priority(instance),
			"ordinal": ordinal,
			"declarations": _make_dependency_map(),
			"dependencies": [],
			"dependents": [],
		}
		nodes.append(node)
		_node_id_by_instance[instance] = node_id
		_local_dependencies_by_instance[instance] = []
		var ids_for_kind: Dictionary = _get_dictionary(node_ids_by_kind, registry_key)
		ids_for_kind[script_cls] = node_id
		ordinal += 1


func _collect_dependency_declarations(
	nodes: Array[Dictionary],
	validity_guard: Callable
) -> bool:
	for node: Dictionary in nodes:
		if not _is_compilation_valid(validity_guard):
			return false
		var declarations: Dictionary = _make_dependency_map()
		_capture_dependency_hook(
			node,
			declarations,
			_REGISTRY_MODELS,
			_HOOK_REQUIRED_MODELS
		)
		if not _is_compilation_valid(validity_guard):
			return false
		_capture_dependency_hook(
			node,
			declarations,
			_REGISTRY_SYSTEMS,
			_HOOK_REQUIRED_SYSTEMS
		)
		if not _is_compilation_valid(validity_guard):
			return false
		_capture_dependency_hook(
			node,
			declarations,
			_REGISTRY_UTILITIES,
			_HOOK_REQUIRED_UTILITIES
		)
		if not _is_compilation_valid(validity_guard):
			return false
		_capture_dependency_hook(
			node,
			declarations,
			_REGISTRY_FACTORIES,
			_HOOK_REQUIRED_FACTORIES
		)
		if not _is_compilation_valid(validity_guard):
			return false
		node["declarations"] = declarations
		_dependency_snapshot.append({
			"module_kind": _registry_key_to_module_kind(
				_get_node_registry_key(node)
			),
			"module_script": _get_node_script(node),
			"module_instance": _get_node_instance(node),
			"module_key": _get_node_key(node),
			"dependencies": _duplicate_dependency_map(declarations),
		})
	return true


func _capture_dependency_hook(
	node: Dictionary,
	declarations: Dictionary,
	dependency_kind: StringName,
	hook: StringName
) -> void:
	var instance: Object = _get_node_instance(node)
	if instance == null:
		return
	var raw_dependencies: Variant = instance.call(hook)
	if not raw_dependencies is Array:
		_append_diagnostic(
			&"invalid_dependency_hook_return",
			_get_node_kind(node),
			_get_node_key(node),
			dependency_kind,
			"",
			"%s() must return an Array of Script values." % hook
		)
		return

	var dependencies: Array[Script] = []
	var seen_scripts: Dictionary = {}
	var raw_array: Array = raw_dependencies
	for dependency_variant: Variant in raw_array:
		if not dependency_variant is Script:
			_append_diagnostic(
				&"invalid_dependency_type",
				_get_node_kind(node),
				_get_node_key(node),
				dependency_kind,
				"",
				"%s() contains a non-Script dependency." % hook
			)
			continue
		var dependency_script: Script = dependency_variant
		if seen_scripts.has(dependency_script):
			continue
		seen_scripts[dependency_script] = true
		dependencies.append(dependency_script)
	declarations[dependency_kind] = dependencies


func _collect_dependency_edges(
	nodes: Array[Dictionary],
	node_ids_by_kind: Dictionary,
	resolvers: Dictionary,
	validity_guard: Callable
) -> bool:
	var dependency_kinds: Array[StringName] = [
		_REGISTRY_MODELS,
		_REGISTRY_SYSTEMS,
		_REGISTRY_UTILITIES,
		_REGISTRY_FACTORIES,
	]
	for node: Dictionary in nodes:
		if not _is_compilation_valid(validity_guard):
			return false
		var declarations: Dictionary = _get_dictionary(node, "declarations")
		for dependency_kind: StringName in dependency_kinds:
			var dependency_scripts: Array[Script] = _get_script_array(
				declarations.get(dependency_kind, [])
			)
			for dependency_script: Script in dependency_scripts:
				if not _is_compilation_valid(validity_guard):
					return false
				var resolution: Dictionary = _resolve_dependency(
					dependency_script,
					dependency_kind,
					nodes,
					node_ids_by_kind,
					resolvers
				)
				if not _is_compilation_valid(validity_guard):
					return false
				_dependency_records.append(
					_make_dependency_record(
						node,
						dependency_kind,
						dependency_script,
						resolution
					)
				)
				var status: StringName = _get_resolution_status(resolution)
				if status == _STATUS_LOCAL:
					if dependency_kind != _REGISTRY_FACTORIES:
						_add_local_edge(
							nodes,
							node,
							_get_resolution_node_id(resolution)
						)
					continue
				if status == _STATUS_EXTERNAL:
					_external_dependency_count += 1
					continue
				_append_resolution_diagnostic(
					node,
					dependency_kind,
					dependency_script,
					resolution
				)
	return true


func _is_compilation_valid(validity_guard: Callable) -> bool:
	if not validity_guard.is_valid():
		return true
	return _to_bool(validity_guard.call(), false)


func _resolve_dependency(
	dependency_script: Script,
	dependency_kind: StringName,
	nodes: Array[Dictionary],
	node_ids_by_kind: Dictionary,
	resolvers: Dictionary
) -> Dictionary:
	if resolvers.has(dependency_kind):
		var resolver_variant: Variant = resolvers.get(dependency_kind)
		if not resolver_variant is Callable:
			return _make_invalid_resolution(
				"Dependency resolver must be a valid Callable."
			)
		var resolver: Callable = resolver_variant
		if not resolver.is_valid():
			return _make_invalid_resolution(
				"Dependency resolver Callable is not valid."
			)
		return _normalize_dependency_resolution(
			resolver.call(dependency_script),
			dependency_kind,
			nodes
		)

	if dependency_kind == _REGISTRY_FACTORIES:
		return _make_resolution(_STATUS_MISSING)
	var ids_for_kind: Dictionary = _get_dictionary(
		node_ids_by_kind,
		dependency_kind
	)
	return _resolve_local_dependency(
		dependency_script,
		dependency_kind,
		nodes,
		ids_for_kind
	)


func _resolve_local_dependency(
	dependency_script: Script,
	dependency_kind: StringName,
	nodes: Array[Dictionary],
	ids_by_script: Dictionary
) -> Dictionary:
	if ids_by_script.has(dependency_script):
		var exact_id: int = _to_int(
			ids_by_script.get(dependency_script),
			-1
		)
		return _make_local_resolution(
			nodes,
			exact_id,
			dependency_kind,
			dependency_script,
			&"exact"
		)

	var match_ids: Array[int] = []
	for registered_variant: Variant in ids_by_script.keys():
		if not registered_variant is Script:
			continue
		var registered_script: Script = registered_variant
		if _GF_SCRIPT_TYPE_INSPECTOR_SCRIPT.script_extends_or_equals(
			registered_script,
			dependency_script
		):
			match_ids.append(
				_to_int(ids_by_script.get(registered_script), -1)
			)
	if match_ids.size() > 1:
		return _make_resolution(
			_STATUS_AMBIGUOUS,
			{
				"reason": "More than one local registration is assignable to the dependency.",
			}
		)
	if match_ids.size() == 1:
		var match_id: int = match_ids[0]
		return _make_local_resolution(
			nodes,
			match_id,
			dependency_kind,
			_get_node_script(nodes[match_id]),
			&"assignable"
		)
	return _make_resolution(_STATUS_MISSING)


func _make_local_resolution(
	nodes: Array[Dictionary],
	node_id: int,
	dependency_kind: StringName,
	registered_script: Script,
	resolution_kind: StringName
) -> Dictionary:
	if node_id < 0 or node_id >= nodes.size():
		return _make_invalid_resolution(
			"Local dependency resolver returned an invalid node id."
		)
	var resolved_node: Dictionary = nodes[node_id]
	if _get_node_registry_key(resolved_node) != dependency_kind:
		return _make_invalid_resolution(
			"Local dependency resolver returned a module from the wrong registry."
		)
	return _make_resolution(
		_STATUS_LOCAL,
		{
			"instance": _get_node_instance(resolved_node),
			"node_id": node_id,
			"registered_script": registered_script,
			"resolution_kind": resolution_kind,
			"scope": _STATUS_LOCAL,
		}
	)


func _normalize_dependency_resolution(
	raw_resolution: Variant,
	dependency_kind: StringName,
	nodes: Array[Dictionary]
) -> Dictionary:
	if not raw_resolution is Dictionary:
		return _make_invalid_resolution(
			"Dependency resolver must return a Dictionary."
		)
	var source: Dictionary = raw_resolution
	var status: StringName = _to_string_name(source.get("status"))
	if status not in [
		_STATUS_LOCAL,
		_STATUS_EXTERNAL,
		_STATUS_MISSING,
		_STATUS_STALE_ALIAS,
		_STATUS_AMBIGUOUS,
		_STATUS_PARENT_CYCLE,
	]:
		return _make_invalid_resolution(
			"Dependency resolver returned an unknown status."
		)

	var resolution: Dictionary = _make_resolution(
		status,
		{
			"scope": _to_string_name(
				source.get("scope"),
				status
			),
			"architecture_depth": _to_int(
				source.get("architecture_depth"),
				0
			),
			"resolution_kind": _to_string_name(
				source.get("resolution_kind")
			),
			"parent_chain_cycle_detected": _to_bool(
				source.get("parent_chain_cycle_detected"),
				status == _STATUS_PARENT_CYCLE
			),
			"cycle_architecture": _variant_to_string(
				source.get("cycle_architecture")
			),
			"cycle_depth": _to_int(source.get("cycle_depth"), -1),
			"cycle_start_depth": _to_int(
				source.get("cycle_start_depth"),
				-1
			),
			"reason": _variant_to_string(source.get("reason")),
		}
	)
	var registered_script: Script = _as_script(
		source.get("registered_script")
	)
	if registered_script != null:
		resolution["registered_script"] = registered_script
	var resolved_instance: Object = _as_object(source.get("instance"))
	if resolved_instance != null:
		resolution["instance"] = resolved_instance

	if status == _STATUS_LOCAL:
		if dependency_kind == _REGISTRY_FACTORIES:
			return resolution
		if resolved_instance == null or not _node_id_by_instance.has(
			resolved_instance
		):
			return _make_invalid_resolution(
				"Local dependency resolution must identify a local module instance."
			)
		var node_id: int = _to_int(
			_node_id_by_instance.get(resolved_instance),
			-1
		)
		if node_id < 0 or node_id >= nodes.size():
			return _make_invalid_resolution(
				"Local dependency resolution points outside the plan snapshot."
			)
		if _get_node_registry_key(nodes[node_id]) != dependency_kind:
			return _make_invalid_resolution(
				"Local dependency resolution returned a module from the wrong registry."
			)
		resolution["node_id"] = node_id
	elif status == _STATUS_EXTERNAL and dependency_kind != _REGISTRY_FACTORIES:
		if (
			resolved_instance != null
			and (
				_node_id_by_instance.has(resolved_instance)
				or not _is_expected_dependency_kind(
					resolved_instance,
					dependency_kind
				)
			)
		):
			return _make_invalid_resolution(
				"External dependency resolution returned an invalid module instance."
			)
	return resolution


func _make_resolution(
	status: StringName,
	fields: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"status": status,
		"scope": status,
		"architecture_depth": 0,
		"resolution_kind": &"",
		"parent_chain_cycle_detected": status == _STATUS_PARENT_CYCLE,
		"cycle_architecture": "",
		"cycle_depth": -1,
		"cycle_start_depth": -1,
		"reason": "",
	}
	result.merge(fields, true)
	return result


func _make_invalid_resolution(reason: String) -> Dictionary:
	return _make_resolution(
		_STATUS_INVALID,
		{
			"scope": _STATUS_INVALID,
			"reason": reason,
		}
	)


func _make_dependency_record(
	node: Dictionary,
	dependency_kind: StringName,
	dependency_script: Script,
	resolution: Dictionary
) -> Dictionary:
	var status: StringName = _get_resolution_status(resolution)
	return {
		"module_kind": _registry_key_to_module_kind(
			_get_node_registry_key(node)
		),
		"module_script": _get_node_script(node),
		"module_instance": _get_node_instance(node),
		"module_key": _get_node_key(node),
		"dependency_kind": dependency_kind,
		"dependency_script": dependency_script,
		"resolved": status == _STATUS_LOCAL or status == _STATUS_EXTERNAL,
		"status": status,
		"scope": _to_string_name(resolution.get("scope"), status),
		"resolved_instance": _as_object(resolution.get("instance")),
		"architecture_depth": _to_int(
			resolution.get("architecture_depth"),
			0
		),
		"resolution_kind": _to_string_name(
			resolution.get("resolution_kind")
		),
		"registered_script": _as_script(
			resolution.get("registered_script")
		),
		"parent_chain_cycle_detected": _to_bool(
			resolution.get("parent_chain_cycle_detected"),
			status == _STATUS_PARENT_CYCLE
		),
		"cycle_architecture": _variant_to_string(
			resolution.get("cycle_architecture")
		),
		"cycle_depth": _to_int(resolution.get("cycle_depth"), -1),
		"cycle_start_depth": _to_int(
			resolution.get("cycle_start_depth"),
			-1
		),
		"reason": _variant_to_string(resolution.get("reason")),
	}


func _append_resolution_diagnostic(
	node: Dictionary,
	dependency_kind: StringName,
	dependency_script: Script,
	resolution: Dictionary
) -> void:
	var status: StringName = _get_resolution_status(resolution)
	var code: StringName = &"missing_dependency"
	var message: String = "Declared dependency could not be resolved."
	match status:
		_STATUS_STALE_ALIAS:
			code = &"stale_alias_dependency"
			message = "Declared dependency is blocked by a stale local alias."
		_STATUS_AMBIGUOUS:
			code = &"ambiguous_dependency"
			message = "Declared dependency matches more than one local registration."
		_STATUS_PARENT_CYCLE:
			code = &"parent_dependency_cycle"
			message = "Declared dependency resolution encountered a parent cycle."
		_STATUS_INVALID:
			code = &"invalid_dependency_resolution"
			message = "Declared dependency resolver returned an invalid result."
	_append_diagnostic(
		code,
		_get_node_kind(node),
		_get_node_key(node),
		dependency_kind,
		_get_script_key(dependency_script),
		message,
		{
			"resolution_status": status,
			"reason": _variant_to_string(resolution.get("reason")),
			"architecture_depth": _to_int(
				resolution.get("architecture_depth"),
				0
			),
			"parent_chain_cycle_detected": _to_bool(
				resolution.get("parent_chain_cycle_detected"),
				false
			),
			"cycle_architecture": _variant_to_string(
				resolution.get("cycle_architecture")
			),
			"cycle_depth": _to_int(
				resolution.get("cycle_depth"),
				-1
			),
			"cycle_start_depth": _to_int(
				resolution.get("cycle_start_depth"),
				-1
			),
		}
	)


func _get_resolution_status(resolution: Dictionary) -> StringName:
	return _to_string_name(resolution.get("status"), _STATUS_INVALID)


func _get_resolution_node_id(resolution: Dictionary) -> int:
	return _to_int(resolution.get("node_id"), -1)


func _add_local_edge(nodes: Array[Dictionary], node: Dictionary, dependency_id: int) -> void:
	if dependency_id < 0 or dependency_id >= nodes.size():
		return
	var dependencies: Array[int] = _get_int_array(node.get("dependencies", []))
	if dependencies.has(dependency_id):
		return
	dependencies.append(dependency_id)
	node["dependencies"] = dependencies
	var dependent_id: int = _to_int(node.get("id"), -1)
	var dependency_node: Dictionary = nodes[dependency_id]
	var dependents: Array[int] = _get_int_array(dependency_node.get("dependents", []))
	dependents.append(dependent_id)
	dependency_node["dependents"] = dependents
	var instance: Object = _get_node_instance(node)
	var dependency_instance: Object = _get_node_instance(dependency_node)
	var local_dependencies: Array[Object] = _get_object_array(
		_local_dependencies_by_instance.get(instance, [])
	)
	local_dependencies.append(dependency_instance)
	_local_dependencies_by_instance[instance] = local_dependencies


func _build_kahn_order(nodes: Array[Dictionary]) -> Array[int]:
	var indegrees: Array[int] = []
	var ready: Array[int] = []
	for node_id: int in range(nodes.size()):
		var dependencies: Array[int] = _get_int_array(nodes[node_id].get("dependencies", []))
		indegrees.append(dependencies.size())
		if dependencies.is_empty():
			ready.append(node_id)

	var result: Array[int] = []
	while not ready.is_empty():
		ready.sort_custom(func(left_id: int, right_id: int) -> bool:
			return _node_precedes(nodes[left_id], nodes[right_id])
		)
		var current_id: int = ready.pop_front()
		result.append(current_id)
		var dependents: Array[int] = _get_int_array(nodes[current_id].get("dependents", []))
		for dependent_id: int in dependents:
			indegrees[dependent_id] -= 1
			if indegrees[dependent_id] == 0:
				ready.append(dependent_id)
	return result


func _node_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_kind_rank: int = _to_int(left.get("kind_rank"))
	var right_kind_rank: int = _to_int(right.get("kind_rank"))
	if left_kind_rank != right_kind_rank:
		return left_kind_rank < right_kind_rank
	var left_priority: int = _to_int(left.get("priority"))
	var right_priority: int = _to_int(right.get("priority"))
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_ordinal: int = _to_int(left.get("ordinal"))
	var right_ordinal: int = _to_int(right.get("ordinal"))
	if left_ordinal != right_ordinal:
		return left_ordinal < right_ordinal
	return _get_node_key(left) < _get_node_key(right)


func _append_cycle_diagnostics(nodes: Array[Dictionary], ordered_node_ids: Array[int]) -> void:
	var remaining: Dictionary = {}
	for node_id: int in range(nodes.size()):
		remaining[node_id] = true
	for node_id: int in ordered_node_ids:
		var _removed_ordered: bool = remaining.erase(node_id)
	var remaining_ids: Array[int] = []
	for node_id_variant: Variant in remaining.keys():
		if node_id_variant is int:
			var remaining_node_id: int = node_id_variant
			remaining_ids.append(remaining_node_id)
	remaining_ids.sort_custom(func(left_id: int, right_id: int) -> bool:
		return _node_precedes(nodes[left_id], nodes[right_id])
	)

	var assigned: Dictionary = {}
	for seed_id: int in remaining_ids:
		if assigned.has(seed_id):
			continue
		var component: Array[int] = []
		for candidate_id: int in remaining_ids:
			if assigned.has(candidate_id):
				continue
			if (
				_is_reachable(seed_id, candidate_id, nodes, remaining)
				and _is_reachable(candidate_id, seed_id, nodes, remaining)
			):
				component.append(candidate_id)
		var is_self_cycle: bool = (
			component.size() == 1
			and _get_int_array(nodes[seed_id].get("dependencies", [])).has(seed_id)
		)
		if component.size() <= 1 and not is_self_cycle:
			continue
		component.sort_custom(func(left_id: int, right_id: int) -> bool:
			return _node_precedes(nodes[left_id], nodes[right_id])
		)
		for component_id: int in component:
			assigned[component_id] = true
		var cycle_members: Array[String] = []
		var member_limit: int = mini(component.size(), _MAX_CYCLE_MEMBERS_PER_DIAGNOSTIC)
		for member_index: int in range(member_limit):
			cycle_members.append(_get_node_key(nodes[component[member_index]]))
		var seed_node: Dictionary = nodes[component[0]]
		_append_diagnostic(
			&"dependency_cycle",
			_get_node_kind(seed_node),
			_get_node_key(seed_node),
			&"",
			"",
			"Local lifecycle dependency cycle detected.",
			{
				"cycle_members": cycle_members,
				"cycle_member_count": component.size(),
				"cycle_members_truncated": component.size() > member_limit,
			}
		)


func _is_reachable(
	from_id: int,
	target_id: int,
	nodes: Array[Dictionary],
	allowed_ids: Dictionary
) -> bool:
	if from_id == target_id:
		return true
	var visited: Dictionary = {from_id: true}
	var pending: Array[int] = [from_id]
	while not pending.is_empty():
		var current_id: int = pending.pop_back()
		var dependencies: Array[int] = _get_int_array(nodes[current_id].get("dependencies", []))
		for dependency_id: int in dependencies:
			if not allowed_ids.has(dependency_id) or visited.has(dependency_id):
				continue
			if dependency_id == target_id:
				return true
			visited[dependency_id] = true
			pending.append(dependency_id)
	return false


func _append_diagnostic(
	code: StringName,
	module_kind: StringName,
	module_key: String,
	dependency_kind: StringName,
	dependency_key: String,
	message: String,
	details: Dictionary = {}
) -> void:
	if _diagnostics.size() >= _DIAGNOSTIC_LIMIT:
		_diagnostics_truncated = true
		return
	var diagnostic: Dictionary = {
		"code": code,
		"severity": &"error",
		"module_kind": module_kind,
		"module_key": module_key,
		"dependency_kind": dependency_kind,
		"dependency_key": dependency_key,
		"message": message,
	}
	diagnostic.merge(details, true)
	_diagnostics.append(diagnostic)


func _is_expected_module_kind(instance: Object, kind: StringName) -> bool:
	match kind:
		_KIND_MODEL:
			return instance is GFModel
		_KIND_UTILITY:
			return instance is GFUtility
		_KIND_SYSTEM:
			return instance is GFSystem
		_:
			return false


func _is_expected_dependency_kind(
	instance: Object,
	dependency_kind: StringName
) -> bool:
	match dependency_kind:
		_REGISTRY_MODELS:
			return instance is GFModel
		_REGISTRY_UTILITIES:
			return instance is GFUtility
		_REGISTRY_SYSTEMS:
			return instance is GFSystem
		_:
			return false


func _get_kind_rank(kind: StringName) -> int:
	match kind:
		_KIND_MODEL:
			return 0
		_KIND_UTILITY:
			return 1
		_KIND_SYSTEM:
			return 2
		_:
			return 3


func _get_lifecycle_priority(instance: Object) -> int:
	if instance is GFModel:
		var model: GFModel = instance
		return model.lifecycle_priority
	if instance is GFUtility:
		var utility: GFUtility = instance
		return utility.lifecycle_priority
	if instance is GFSystem:
		var system: GFSystem = instance
		return system.lifecycle_priority
	return 0


func _make_module_key(kind: StringName, script_cls: Script, ordinal: int) -> String:
	return "%s[%d]:%s" % [kind, ordinal, _get_script_key(script_cls)]


func _get_script_key(script_cls: Script) -> String:
	if script_cls == null:
		return "<null>"
	var global_name: StringName = script_cls.get_global_name()
	if not global_name.is_empty():
		return String(global_name)
	if not script_cls.resource_path.is_empty():
		return script_cls.resource_path
	return "<anonymous>"


func _get_node_instance(node: Dictionary) -> Object:
	return _as_object(node.get("instance"))


func _get_node_kind(node: Dictionary) -> StringName:
	return _to_string_name(node.get("kind"))


func _get_node_registry_key(node: Dictionary) -> StringName:
	return _to_string_name(node.get("registry_key"))


func _get_node_script(node: Dictionary) -> Script:
	return _as_script(node.get("script"))


func _get_node_key(node: Dictionary) -> String:
	return _variant_to_string(node.get("module_key"))


func _registry_key_to_module_kind(registry_key: StringName) -> StringName:
	match registry_key:
		_REGISTRY_MODELS:
			return &"model"
		_REGISTRY_UTILITIES:
			return &"utility"
		_REGISTRY_SYSTEMS:
			return &"system"
		_:
			return &""


func _make_dependency_map() -> Dictionary:
	return {
		_REGISTRY_MODELS: [],
		_REGISTRY_SYSTEMS: [],
		_REGISTRY_UTILITIES: [],
		_REGISTRY_FACTORIES: [],
	}


func _duplicate_dependency_map(source: Dictionary) -> Dictionary:
	return {
		_REGISTRY_MODELS: _get_script_array(
			source.get(_REGISTRY_MODELS, [])
		),
		_REGISTRY_SYSTEMS: _get_script_array(
			source.get(_REGISTRY_SYSTEMS, [])
		),
		_REGISTRY_UTILITIES: _get_script_array(
			source.get(_REGISTRY_UTILITIES, [])
		),
		_REGISTRY_FACTORIES: _get_script_array(
			source.get(_REGISTRY_FACTORIES, [])
		),
	}


func _duplicate_dictionary_array(
	source: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source:
		result.append(entry.duplicate(true))
	return result


func _as_object(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _as_script(value: Variant) -> Script:
	if value is Script:
		var script_value: Script = value
		return script_value
	return null


func _to_string_name(
	value: Variant,
	default_value: StringName = &""
) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	return default_value


func _variant_to_string(
	value: Variant,
	default_value: String = ""
) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return default_value


func _to_int(value: Variant, default_value: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	return default_value


func _to_bool(value: Variant, default_value: bool = false) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return default_value


func _get_dictionary(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _get_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	var source: Array = value
	for item: Variant in source:
		if item is int:
			result.append(item)
	return result


func _get_object_array(value: Variant) -> Array[Object]:
	var result: Array[Object] = []
	if not value is Array:
		return result
	var source: Array = value
	for item: Variant in source:
		var object_value: Object = _as_object(item)
		if object_value != null:
			result.append(object_value)
	return result


func _get_script_array(value: Variant) -> Array[Script]:
	var result: Array[Script] = []
	if not value is Array:
		return result
	var source: Array = value
	for item: Variant in source:
		if item is Script:
			var script_value: Script = item
			result.append(script_value)
	return result
