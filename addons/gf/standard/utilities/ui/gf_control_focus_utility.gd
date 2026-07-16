## GFControlFocusUtility: Control 焦点顺序工具。
##
## 收集可聚焦 Control，按显式顺序写入 Tab 顺序和方向邻居，并提供焦点步进 helper。
## 该工具只处理 Godot Control 焦点属性，不规定具体 UI 控件、视觉样式或业务流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFControlFocusUtility
extends RefCounted


# --- 常量 ---

## 不写入方向邻居，只处理 focus_next / focus_previous。
## [br]
## @api public
## [br]
## @since 8.0.0
const AXIS_NONE: StringName = &"none"

## 按顺序写入 focus_neighbor_left / focus_neighbor_right。
## [br]
## @api public
## [br]
## @since 8.0.0
const AXIS_HORIZONTAL: StringName = &"horizontal"

## 按顺序写入 focus_neighbor_top / focus_neighbor_bottom。
## [br]
## @api public
## [br]
## @since 8.0.0
const AXIS_VERTICAL: StringName = &"vertical"

## 同时写入水平和垂直方向邻居。
## [br]
## @api public
## [br]
## @since 8.0.0
const AXIS_BOTH: StringName = &"both"


# --- 公共方法 ---

## 从节点树中按场景树顺序收集可聚焦 Control。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 查询根节点。
## [br]
## @param options: 收集选项，支持 include_root、include_hidden、include_disabled、include_internal、max_depth 和 limit。
## [br]
## @return 可聚焦控件数组。
## [br]
## @schema options: Dictionary，include_root 默认 true，include_hidden 默认 false，include_disabled 默认 false，include_internal 默认 false，max_depth 默认 -1，limit 默认 -1。
static func collect_focusable_controls(root: Node, options: Dictionary = {}) -> Array[Control]:
	var result: Array[Control] = []
	if root == null:
		return result

	var include_root: bool = GFVariantData.get_option_bool(options, "include_root", true)
	var include_internal: bool = GFVariantData.get_option_bool(options, "include_internal", false)
	var max_depth: int = GFVariantData.get_option_int(options, "max_depth", -1)
	var limit: int = GFVariantData.get_option_int(options, "limit", -1)
	var nodes: Array[Node] = GFNodeTreeOps.collect_descendants(
		root,
		"Control",
		include_root,
		include_internal,
		max_depth,
		-1
	)
	for node: Node in nodes:
		if limit >= 0 and result.size() >= limit:
			break
		if node is Control:
			var control: Control = node
			if _is_focusable_control(control, options):
				result.append(control)
	return result


## 从节点树收集可聚焦 Control，并按收集顺序应用焦点顺序。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root: 查询根节点。
## [br]
## @param options: 收集与应用选项。
## [br]
## @return 应用报告。
## [br]
## @schema options: Dictionary，支持 collect_focusable_controls() 的选项，以及 wrap、axis、wire_tab_order 和 wire_directional_neighbors。
## [br]
## @schema return: Dictionary，包含 ok、control_count、wired_count、wrap、axis、wire_tab_order、wire_directional_neighbors、entries 和 issues。
static func apply_focus_order_from_root(root: Node, options: Dictionary = {}) -> Dictionary:
	return apply_focus_order(collect_focusable_controls(root, options), options)


## 按显式数组顺序写入 Control 焦点顺序。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param controls: 目标控件顺序。
## [br]
## @param options: 应用选项，支持 wrap、axis、wire_tab_order、wire_directional_neighbors、include_hidden 和 include_disabled。
## [br]
## @return 应用报告。
## [br]
## @schema options: Dictionary，wrap 默认 true；axis 可为 none、horizontal、vertical 或 both，默认 both；wire_tab_order 默认 true；wire_directional_neighbors 默认 true；preserve_unwired_directional_neighbors 默认 false；include_hidden 默认 false；include_disabled 默认 false。
## [br]
## @schema return: Dictionary，包含 ok、control_count、wired_count、wrap、axis、wire_tab_order、wire_directional_neighbors、preserve_unwired_directional_neighbors、entries 和 issues。entries 每项包含 index、name、path、previous 和 next；issues 每项包含 code、message 和 index。
static func apply_focus_order(controls: Array[Control], options: Dictionary = {}) -> Dictionary:
	var ordered_controls: Array[Control] = _normalize_controls(controls, options)
	var issues: Array[Dictionary] = []
	var entries: Array[Dictionary] = []
	var wrap_enabled: bool = GFVariantData.get_option_bool(options, "wrap", true)
	var raw_axis: StringName = GFVariantData.get_option_string_name(options, "axis", AXIS_BOTH)
	var axis: StringName = _normalize_axis(raw_axis)
	var wire_tab_order: bool = GFVariantData.get_option_bool(options, "wire_tab_order", true)
	var wire_directional_neighbors: bool = GFVariantData.get_option_bool(options, "wire_directional_neighbors", true)
	var preserve_unwired_directional_neighbors: bool = GFVariantData.get_option_bool(
		options,
		"preserve_unwired_directional_neighbors",
		false
	)
	if axis != raw_axis:
		issues.append(_make_issue(
			&"invalid_axis",
			"未知焦点方向轴，已回退为 both。",
			-1
		))

	for control_index: int in range(ordered_controls.size()):
		var control: Control = ordered_controls[control_index]
		var previous_control: Control = _get_order_neighbor(ordered_controls, control_index, -1, wrap_enabled)
		var next_control: Control = _get_order_neighbor(ordered_controls, control_index, 1, wrap_enabled)
		var previous_path: NodePath = _get_relative_focus_path(control, previous_control, control_index, &"previous", issues)
		var next_path: NodePath = _get_relative_focus_path(control, next_control, control_index, &"next", issues)

		if wire_tab_order:
			control.focus_previous = previous_path
			control.focus_next = next_path
		if wire_directional_neighbors:
			_apply_directional_focus_paths(
				control,
				previous_path,
				next_path,
				axis,
				preserve_unwired_directional_neighbors
			)

		entries.append({
			"index": control_index,
			"name": String(control.name),
			"path": _get_node_path_text(control),
			"previous": _get_node_path_text(previous_control),
			"next": _get_node_path_text(next_control),
		})

	return {
		"ok": issues.is_empty(),
		"control_count": ordered_controls.size(),
		"wired_count": ordered_controls.size(),
		"wrap": wrap_enabled,
		"axis": axis,
		"wire_tab_order": wire_tab_order,
		"wire_directional_neighbors": wire_directional_neighbors,
		"preserve_unwired_directional_neighbors": preserve_unwired_directional_neighbors,
		"entries": entries,
		"issues": issues,
	}


## 按顺序数组计算下一次应聚焦的 Control。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param controls: 目标控件顺序。
## [br]
## @param current: 当前控件；为空或不在列表中时，从列表起点或终点开始。
## [br]
## @param step: 步进数量，正数向后，负数向前，0 返回当前有效控件。
## [br]
## @param wrap_enabled: 是否允许在两端循环。
## [br]
## @return 目标控件；没有可用目标时返回 null。
static func get_next_focus_control(
	controls: Array[Control],
	current: Control,
	step: int = 1,
	wrap_enabled: bool = true
) -> Control:
	var ordered_controls: Array[Control] = _normalize_controls(controls, {})
	if ordered_controls.is_empty():
		return null

	var current_index: int = ordered_controls.find(current)
	if current_index < 0:
		return ordered_controls[0] if step >= 0 else ordered_controls[ordered_controls.size() - 1]
	if step == 0:
		return current if _is_focusable_control(current, {}) else null

	var target_index: int = current_index + step
	if wrap_enabled:
		return ordered_controls[_wrap_index(target_index, ordered_controls.size())]
	if target_index < 0 or target_index >= ordered_controls.size():
		return null
	return ordered_controls[target_index]


## 计算并抓取下一次焦点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param controls: 目标控件顺序。
## [br]
## @param current: 当前控件；为空或不在列表中时，从列表起点或终点开始。
## [br]
## @param step: 步进数量，正数向后，负数向前。
## [br]
## @param wrap_enabled: 是否允许在两端循环。
## [br]
## @return 实际抓取焦点的控件；没有可用目标时返回 null。
static func grab_next_focus(
	controls: Array[Control],
	current: Control,
	step: int = 1,
	wrap_enabled: bool = true
) -> Control:
	var target: Control = get_next_focus_control(controls, current, step, wrap_enabled)
	if target != null:
		target.grab_focus()
	return target


# --- 私有/辅助方法 ---

static func _normalize_controls(controls: Array[Control], options: Dictionary) -> Array[Control]:
	var result: Array[Control] = []
	for control: Control in controls:
		if control == null or not is_instance_valid(control):
			continue
		if result.has(control):
			continue
		if not _is_focusable_control(control, options):
			continue
		result.append(control)
	return result


static func _is_focusable_control(control: Control, options: Dictionary) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if not GFVariantData.get_option_bool(options, "include_hidden", false) and not _is_visible_for_focus(control):
		return false
	if not GFVariantData.get_option_bool(options, "include_disabled", false) and _is_disabled_for_focus(control):
		return false
	return true


static func _is_visible_for_focus(control: Control) -> bool:
	if control.is_inside_tree():
		return control.is_visible_in_tree()
	return control.visible


static func _is_disabled_for_focus(control: Control) -> bool:
	if control is BaseButton:
		var button: BaseButton = control
		return button.disabled
	return false


static func _normalize_axis(axis: StringName) -> StringName:
	match axis:
		AXIS_NONE, AXIS_HORIZONTAL, AXIS_VERTICAL, AXIS_BOTH:
			return axis
	return AXIS_BOTH


static func _get_order_neighbor(
	controls: Array[Control],
	index: int,
	offset: int,
	wrap_enabled: bool
) -> Control:
	if controls.size() <= 1:
		return null

	var neighbor_index: int = index + offset
	if wrap_enabled:
		return controls[_wrap_index(neighbor_index, controls.size())]
	if neighbor_index < 0 or neighbor_index >= controls.size():
		return null
	return controls[neighbor_index]


static func _wrap_index(index: int, size: int) -> int:
	if size <= 0:
		return 0
	var wrapped_index: int = index % size
	if wrapped_index < 0:
		wrapped_index += size
	return wrapped_index


static func _get_relative_focus_path(
	source: Control,
	target: Control,
	source_index: int,
	slot: StringName,
	issues: Array[Dictionary]
) -> NodePath:
	if source == null or target == null:
		return NodePath("")
	if not _has_common_ancestor(source, target):
		issues.append(_make_issue(
			&"no_common_ancestor",
			"控件之间没有共同祖先，无法写入相对焦点路径。",
			source_index,
			slot
		))
		return NodePath("")
	return source.get_path_to(target)


static func _apply_directional_focus_paths(
	control: Control,
	previous_path: NodePath,
	next_path: NodePath,
	axis: StringName,
	preserve_unwired_directional_neighbors: bool
) -> void:
	if axis == AXIS_VERTICAL or axis == AXIS_BOTH:
		control.focus_neighbor_top = previous_path
		control.focus_neighbor_bottom = next_path
	elif not preserve_unwired_directional_neighbors:
		control.focus_neighbor_top = NodePath("")
		control.focus_neighbor_bottom = NodePath("")
	if axis == AXIS_HORIZONTAL or axis == AXIS_BOTH:
		control.focus_neighbor_left = previous_path
		control.focus_neighbor_right = next_path
	elif not preserve_unwired_directional_neighbors:
		control.focus_neighbor_left = NodePath("")
		control.focus_neighbor_right = NodePath("")


static func _has_common_ancestor(a: Node, b: Node) -> bool:
	var a_current: Node = a
	while a_current != null:
		var b_current: Node = b
		while b_current != null:
			if a_current == b_current:
				return true
			b_current = b_current.get_parent()
		a_current = a_current.get_parent()
	return false


static func _get_node_path_text(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if node.is_inside_tree():
		return String(node.get_path())
	return String(node.get_path()) if node.get_parent() != null else String(node.name)


static func _make_issue(
	code: StringName,
	message: String,
	index: int,
	slot: StringName = &""
) -> Dictionary:
	return {
		"code": code,
		"message": message,
		"index": index,
		"slot": slot,
	}
