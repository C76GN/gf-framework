@tool

## GFNodeStateMachineValidator: 节点状态机结构校验工具。
##
## 只检查状态机、状态组和状态资源挂接是否自洽，不执行状态切换，
## 也不推断项目业务中的转移规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNodeStateMachineValidator
extends RefCounted


# --- 公共方法 ---

## 校验一个节点状态机的直接子状态、场景状态组和运行时注册状态组。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param machine: 要校验的节点状态机。
## [br]
## @param options: 可选校验选项，支持 check_state_resources、require_initial_state。
## [br]
## @schema options: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。
## [br]
## @return: 校验报告。
static func validate_machine(machine: GFNodeStateMachine, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("GFNodeStateMachine")
	if machine == null:
		_add_error(report, &"missing_state_machine", "State machine is null.")
		return report

	var internal_states: Array[GFNodeState] = []
	var groups: Array[GFNodeStateGroup] = []
	var seen_group_instance_ids: Dictionary = {}
	var scene_group_count: int = 0
	for child: Node in machine.get_children():
		if GFVariantData.to_bool(child.get_meta(GFNodeStateMachine.META_INTERNAL_GROUP, false)):
			continue
		if child is GFNodeStateGroup:
			var group_child: GFNodeStateGroup = child
			groups.append(group_child)
			seen_group_instance_ids[group_child.get_instance_id()] = true
			scene_group_count += 1
		elif child is GFNodeState:
			var state_child: GFNodeState = child
			internal_states.append(state_child)

	var registered_group_count: int = 0
	for registered_group: GFNodeStateGroup in machine.get_state_groups():
		registered_group_count += 1
		if registered_group == null:
			continue
		if seen_group_instance_ids.has(registered_group.get_instance_id()):
			continue
		if _get_group_name(registered_group) == GFNodeStateMachine.INTERNAL_GROUP_NAME and not internal_states.is_empty():
			continue
		groups.append(registered_group)
		seen_group_instance_ids[registered_group.get_instance_id()] = true

	var group_names: Dictionary = {}
	if not internal_states.is_empty():
		_validate_group_shape(
			report,
			GFNodeStateMachine.INTERNAL_GROUP_NAME,
			internal_states,
			_get_machine_initial_state(machine),
			_should_require_machine_initial_state(machine, options),
			_get_node_path_text(machine),
			options
		)
		group_names[GFNodeStateMachine.INTERNAL_GROUP_NAME] = _get_node_path_text(machine)

	for group: GFNodeStateGroup in groups:
		var group_name: StringName = _get_group_name(group)
		var group_path: String = _get_node_path_text(group)
		if group_names.has(group_name):
			_add_error(
				report,
				&"duplicate_state_group",
				"State group name is duplicated.",
				group_name,
				group_path,
				{ "first_path": GFVariantData.get_option_string(group_names, group_name) }
			)
		else:
			group_names[group_name] = group_path
		_merge_report(report, validate_group(group, options), false)

	if internal_states.is_empty() and groups.is_empty():
		_add_error(
			report,
			&"empty_state_machine",
			"State machine has no direct states or state groups.",
			null,
			_get_node_path_text(machine)
		)

	report.metadata["group_count"] = group_names.size()
	report.metadata["scene_group_count"] = scene_group_count
	report.metadata["registered_group_count"] = registered_group_count
	report.metadata["direct_state_count"] = internal_states.size()
	return report


## 校验一个节点状态组的直接子状态。
## [br]
## @api public
## [br]
## @param group: 要校验的状态组。
## [br]
## @param options: 可选校验选项，支持 check_state_resources、require_initial_state。
## [br]
## @schema options: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。
## [br]
## @return: 校验报告。
static func validate_group(group: GFNodeStateGroup, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("GFNodeStateGroup")
	if group == null:
		_add_error(report, &"missing_state_group", "State group is null.")
		return report

	var states: Array[GFNodeState] = _collect_group_states(group)
	_validate_group_shape(
		report,
		_get_group_name(group),
		states,
		_get_group_initial_state(group),
		_should_require_group_initial_state(group, options),
		_get_node_path_text(group),
		options
	)
	return report


## 校验一组状态名、初始状态和状态资源挂接。
## [br]
## @api public
## [br]
## @param states: 要校验的状态列表。
## [br]
## @schema states: 元素为 GFNodeState 的状态列表。
## [br]
## @param initial_state: 可选初始状态名。
## [br]
## @param subject: 报告主题。
## [br]
## @param options: 可选校验选项，支持 check_state_resources、require_initial_state。
## [br]
## @schema options: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。
## [br]
## @return: 校验报告。
static func validate_state_list(
	states: Array[GFNodeState],
	initial_state: StringName = &"",
	subject: String = "GFNodeStateList",
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(subject)
	_validate_group_shape(
		report,
		StringName(subject),
		states,
		initial_state,
		GFVariantData.get_option_bool(options, "require_initial_state"),
		"",
		options
	)
	return report


# --- 层内方法 ---

## 将状态机校验报告转换为 Godot Inspector 配置警告文本。
## [br]
## @api layer_internal
## [br]
## @layer standard/state_machine/node
## [br]
## @param report: 状态机校验报告。
## [br]
## @return Inspector 可显示的配置警告列表。
static func make_configuration_warnings(report: GFValidationReport) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if report == null:
		return result

	for issue: RefCounted in report.issues:
		if issue == null:
			continue
		var _warning_appended: bool = result.append(_format_configuration_warning_issue(issue))
	return result


# --- 私有/辅助方法 ---

static func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	if report == null:
		return
	var _issue: RefCounted = report.add_error(kind, message, key, path, metadata)


static func _add_warning(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	if report == null:
		return
	var _issue: RefCounted = report.add_warning(kind, message, key, path, metadata)


static func _merge_report(target: GFValidationReport, source: GFValidationReport, include_metadata: bool) -> void:
	if target == null or source == null:
		return
	var _merged_report: RefCounted = target.merge(source, include_metadata)


static func _variant_to_resource(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


static func _format_configuration_warning_issue(issue: RefCounted) -> String:
	var severity: String = "Error"
	if GFVariantData.to_bool(issue.call("is_warning")):
		severity = "Warning"
	elif GFVariantData.to_bool(issue.call("is_info")):
		severity = "Info"

	var kind: String = GFVariantData.to_text(issue.call("get_kind_key"))
	var message: String = GFVariantData.to_text(_read_property(issue, &"message")).strip_edges()
	var location: String = _get_issue_location_text(issue)
	if message.is_empty():
		message = "No message."
	if kind.is_empty():
		return "%s: %s%s" % [severity, message, location]
	return "%s [%s]: %s%s" % [severity, kind, message, location]


static func _get_issue_location_text(issue: RefCounted) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var path: String = GFVariantData.to_text(_read_property(issue, &"path")).strip_edges()
	if not path.is_empty():
		var _path_appended: bool = parts.append(path)

	var key: Variant = _read_property(issue, &"key")
	if key != null:
		var key_text: String = GFVariantData.to_text(key).strip_edges()
		if not key_text.is_empty():
			var _key_appended: bool = parts.append(key_text)

	if parts.is_empty():
		return ""
	return " (%s)" % " / ".join(parts)


static func _validate_group_shape(
	report: GFValidationReport,
	group_name: StringName,
	states: Array[GFNodeState],
	initial_state: StringName,
	require_initial_state: bool,
	group_path: String,
	options: Dictionary
) -> void:
	if states.is_empty():
		_add_error(
			report,
			&"empty_state_group",
			"State group has no states.",
			group_name,
			group_path
		)
		return

	var state_paths_by_name: Dictionary = {}
	for state: GFNodeState in states:
		_validate_state(report, group_name, state, state_paths_by_name, options)

	if require_initial_state and initial_state == &"":
		_add_warning(
			report,
			&"missing_initial_state",
			"State group has no initial state.",
			group_name,
			group_path
		)
	elif initial_state != &"" and not state_paths_by_name.has(initial_state):
		_add_error(
			report,
			&"invalid_initial_state",
			"Initial state does not exist in this state group.",
			initial_state,
			group_path,
			{ "group_name": group_name }
		)

	report.metadata["state_count"] = GFVariantData.get_option_int(report.metadata, "state_count") + states.size()


static func _validate_state(
	report: GFValidationReport,
	group_name: StringName,
	state: GFNodeState,
	state_paths_by_name: Dictionary,
	options: Dictionary
) -> void:
	if state == null:
		_add_error(report, &"missing_state", "State entry is null.", group_name)
		return

	var state_name: StringName = _get_state_name(state)
	var state_path: String = _get_node_path_text(state)
	if state_name == &"":
		_add_error(
			report,
			&"empty_state_name",
			"State name is empty.",
			group_name,
			state_path
		)
	elif state_paths_by_name.has(state_name):
		_add_error(
			report,
			&"duplicate_state_name",
			"State name is duplicated inside the group.",
			state_name,
			state_path,
			{
				"group_name": group_name,
				"first_path": GFVariantData.get_option_string(state_paths_by_name, state_name),
			}
		)
	else:
		state_paths_by_name[state_name] = state_path

	if GFVariantData.get_option_bool(options, "check_state_resources", true):
		_validate_resource_list(
			report,
			_get_resource_array_property(state, &"enter_conditions"),
			&"enter_conditions",
			&"evaluate",
			state_name,
			state_path
		)
		_validate_resource_list(
			report,
			_get_resource_array_property(state, &"exit_conditions"),
			&"exit_conditions",
			&"evaluate",
			state_name,
			state_path
		)
		_validate_behavior_resources(
			report,
			_get_resource_array_property(state, &"behaviors"),
			state_name,
			state_path
		)


static func _validate_resource_list(
	report: GFValidationReport,
	resources: Array[Resource],
	field_name: StringName,
	required_method: StringName,
	state_name: StringName,
	state_path: String
) -> void:
	var ids: Dictionary = {}
	for index: int in range(resources.size()):
		var resource: Resource = resources[index]
		var metadata: Dictionary = {
			"field": field_name,
			"index": index,
			"state_name": state_name,
		}
		if resource == null:
			_add_warning(
				report,
				&"missing_state_resource",
				"State resource slot is empty.",
				state_name,
				state_path,
				metadata
			)
			continue
		if not _resource_exposes_required_method(resource, field_name, required_method):
			_add_error(
				report,
				&"invalid_state_resource",
				"State resource does not expose the required method.",
				state_name,
				state_path,
				metadata.merged({ "required_method": required_method })
			)
		_track_duplicate_resource_id(report, resource, field_name, ids, state_name, state_path, metadata)


static func _validate_behavior_resources(
	report: GFValidationReport,
	behaviors: Array[Resource],
	state_name: StringName,
	state_path: String
) -> void:
	var ids: Dictionary = {}
	for index: int in range(behaviors.size()):
		var behavior: Resource = behaviors[index]
		var metadata: Dictionary = {
			"field": &"behaviors",
			"index": index,
			"state_name": state_name,
		}
		if behavior == null:
			_add_warning(
				report,
				&"missing_state_resource",
				"State behavior slot is empty.",
				state_name,
				state_path,
				metadata
			)
			continue
		if not _has_any_behavior_method(behavior):
			_add_warning(
				report,
				&"inert_state_behavior",
				"State behavior exposes no known lifecycle hook.",
				state_name,
				state_path,
				metadata
			)
		_track_duplicate_resource_id(report, behavior, &"behaviors", ids, state_name, state_path, metadata)


static func _track_duplicate_resource_id(
	report: GFValidationReport,
	resource: Resource,
	field_name: StringName,
	ids: Dictionary,
	state_name: StringName,
	state_path: String,
	metadata: Dictionary
) -> void:
	var id_value: StringName = _get_resource_id(resource, field_name)
	if id_value == &"":
		return
	if ids.has(id_value):
		_add_warning(
			report,
			&"duplicate_state_resource_id",
			"State resource id is duplicated inside the same resource list.",
			state_name,
			state_path,
			metadata.merged({
				"resource_id": id_value,
				"first_index": GFVariantData.get_option_int(ids, id_value, -1),
			})
		)
	else:
		ids[id_value] = GFVariantData.get_option_int(metadata, "index", -1)


static func _has_any_behavior_method(resource: Resource) -> bool:
	if resource is GFNodeStateBehavior:
		return true
	return (
		resource.has_method(&"initialize")
		or resource.has_method(&"enter")
		or resource.has_method(&"exit")
		or resource.has_method(&"pause")
		or resource.has_method(&"resume")
		or resource.has_method(&"handle_state_event")
	)


static func _resource_exposes_required_method(resource: Resource, field_name: StringName, required_method: StringName) -> bool:
	if resource == null:
		return false
	if field_name == &"enter_conditions" or field_name == &"exit_conditions":
		if resource is GFNodeStateCondition:
			return true
	return resource.has_method(required_method)


static func _get_resource_id(resource: Resource, field_name: StringName) -> StringName:
	if field_name == &"behaviors":
		var behavior_id: StringName = _get_string_name_property(resource, &"behavior_id", &"")
		if behavior_id != &"":
			return behavior_id

	var condition_id: StringName = _get_string_name_property(resource, &"condition_id", &"")
	if condition_id != &"":
		return condition_id
	var resource_id: StringName = _get_string_name_property(resource, &"resource_id", &"")
	if resource_id != &"":
		return resource_id
	return &""


static func _collect_direct_states(parent: Node) -> Array[GFNodeState]:
	var result: Array[GFNodeState] = []
	for child: Node in parent.get_children():
		if child is GFNodeState:
			var state: GFNodeState = child
			result.append(state)
	return result


static func _collect_group_states(group: GFNodeStateGroup) -> Array[GFNodeState]:
	var result: Array[GFNodeState] = []
	var seen_state_instance_ids: Dictionary = {}
	for state: GFNodeState in _collect_direct_states(group):
		result.append(state)
		seen_state_instance_ids[state.get_instance_id()] = true
	for registered_state: GFNodeState in group.get_states():
		if registered_state == null:
			continue
		if seen_state_instance_ids.has(registered_state.get_instance_id()):
			continue
		result.append(registered_state)
		seen_state_instance_ids[registered_state.get_instance_id()] = true
	return result


static func _get_machine_initial_state(machine: GFNodeStateMachine) -> StringName:
	var config: Resource = _variant_to_resource(_read_property(machine, &"config"))
	if config != null:
		return _get_string_name_property(config, &"initial_state", &"")
	return _get_string_name_property(machine, &"initial_state", &"")


static func _should_require_machine_initial_state(machine: GFNodeStateMachine, options: Dictionary) -> bool:
	if options.has("require_initial_state"):
		return GFVariantData.get_option_bool(options, "require_initial_state")
	var start_mode: int = GFVariantData.to_int(_read_property(machine, &"start_mode"), GFNodeStateMachine.StartMode.MANUAL)
	return start_mode != GFNodeStateMachine.StartMode.MANUAL


static func _should_require_group_initial_state(group: GFNodeStateGroup, options: Dictionary) -> bool:
	if options.has("require_initial_state"):
		return GFVariantData.get_option_bool(options, "require_initial_state")
	return _get_bool_property(group, &"auto_start", true)


static func _get_group_name(group: Node) -> StringName:
	return _get_string_name_property(group, &"group_name", StringName(group.name))


static func _get_group_initial_state(group: Node) -> StringName:
	return _get_string_name_property(group, &"initial_state", &"")


static func _get_state_name(state: Node) -> StringName:
	return _get_string_name_property(state, &"state_name", StringName(state.name))


static func _get_string_name_property(object: Object, property_name: StringName, fallback: StringName = &"") -> StringName:
	if object == null:
		return fallback

	var value: Variant = _read_property(object, property_name)
	if value is StringName:
		var string_name: StringName = value
		return fallback if string_name == &"" else string_name
	if value is String:
		var string_value: String = value
		var text: String = string_value.strip_edges()
		return fallback if text.is_empty() else StringName(text)
	return fallback


static func _get_bool_property(object: Object, property_name: StringName, fallback: bool = false) -> bool:
	if object == null:
		return fallback

	var value: Variant = _read_property(object, property_name)
	return GFVariantData.to_bool(value, fallback)


static func _get_resource_array_property(object: Object, property_name: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	if object == null:
		return result

	var value: Variant = _read_property(object, property_name)
	if not value is Array:
		return result

	var entries: Array = value
	for entry: Variant in entries:
		result.append(_variant_to_resource(entry))
	return result


static func _read_property(object: Object, property_name: StringName, fallback: Variant = null) -> Variant:
	return GFObjectPropertyTools.read_property(object, NodePath(property_name), fallback)


static func _get_node_path_text(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return String(node.get_path())
	return String(node.name)
