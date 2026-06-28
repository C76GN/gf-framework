@tool

# GF Capability Inspector: 在 Godot Inspector 中管理节点能力。
extends EditorInspectorPlugin


# --- 常量 ---

const _META_CAPABILITY_CONTAINER: StringName = &"_gf_capability_container"
const _META_CAPABILITY_ACTIVE: StringName = &"_gf_capability_active"
const _META_ORIGINAL_PROCESS_MODE: StringName = &"_gf_capability_original_process_mode"
const _CAPABILITY_EXTENSION_ID: String = "gf.capability"
const _GF_CAPABILITY_CONTAINER_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_capability_container.gd"
const _GF_NODE_CAPABILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_node_capability.gd"
const _GF_NODE_2D_CAPABILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_node_2d_capability.gd"
const _GF_NODE_3D_CAPABILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_node_3d_capability.gd"
const _GF_CONTROL_CAPABILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_control_capability.gd"
const _GF_CAPABILITY_RECIPE_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/recipes/gf_capability_recipe.gd"
const _DEFAULT_MAX_RECIPE_SCAN_DEPTH: int = 32
const _DEFAULT_MAX_RECIPE_CANDIDATES: int = 10000
const _GF_EXTENSION_SETTINGS_SCRIPT: Script = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _GF_EDITOR_TYPE_INDEX_SCRIPT: Script = preload("res://addons/gf/kernel/editor/gf_editor_type_index.gd")
const _GF_VALIDATION_REPORT_SCRIPT: Script = preload("res://addons/gf/standard/foundation/validation/gf_validation_report.gd")
const _SCRIPT_TYPE_INSPECTOR: Script = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	if not _is_capability_extension_enabled():
		return false

	var node: Node = _get_node_value(object)
	if node == null:
		return false
	if GFVariantData.to_bool(node.get_meta(_META_CAPABILITY_CONTAINER, false)):
		return false

	var container_script: Script = _get_capability_container_script()
	if container_script == null:
		return false

	var script: Script = _get_script_value(node.get_script())
	return script == null or not _script_extends_or_equals(script, container_script)


func _parse_begin(object: Object) -> void:
	var target: Node = _get_node_value(object)
	if target == null:
		return

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GFCapabilityInspector"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)

	var title: Label = Label.new()
	title.text = "GF Capabilities"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var add_button: MenuButton = MenuButton.new()
	add_button.text = "添加"
	add_button.tooltip_text = "添加 GF 节点能力"
	header.add_child(add_button)
	_populate_add_menu(add_button.get_popup(), target)

	var recipe_button: MenuButton = MenuButton.new()
	recipe_button.text = "Recipe"
	recipe_button.tooltip_text = "应用 GFCapabilityRecipe 中的节点能力条目"
	header.add_child(recipe_button)
	_populate_recipe_menu(recipe_button.get_popup(), target)

	var validate_button: Button = Button.new()
	validate_button.text = "校验"
	validate_button.tooltip_text = "检查节点能力依赖"
	_connect_signal_checked(validate_button.pressed, _on_validate_capabilities_pressed.bind(target), CONNECT_DEFERRED)
	header.add_child(validate_button)

	var capabilities: Array[Node] = _get_capability_nodes(target)
	if capabilities.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "未挂载节点能力"
		empty_label.modulate = Color(0.65, 0.65, 0.65)
		root.add_child(empty_label)
		add_custom_control(root)
		return

	for capability: Node in capabilities:
		if not is_instance_valid(capability):
			continue
		root.add_child(_create_capability_row(target, capability))

	add_custom_control(root)


# --- 框架内部方法 ---

## 读取能力节点导出的 required_capabilities，不调用能力脚本方法。
## [br]
## @api framework_internal
## [br]
## @param capability: 要检查的能力节点。
## [br]
## @param report: 可选校验报告对象，用于追加警告。
## [br]
## @param script_key: 报告中使用的能力脚本标识。
## [br]
## @return 能力依赖的脚本类型列表。
## [br]
## @schema report: Variant，可为 null 或 GFValidationReport 实例。
## [br]
## @schema return: Array[Script]，元素为能力脚本类型。
static func collect_required_capability_types(
	capability: Node,
	report: Variant,
	script_key: String
) -> Array[Script]:
	if capability == null or not "required_capabilities" in capability:
		return _empty_script_array()

	var raw_value: Variant = _read_property(capability, "required_capabilities")
	if raw_value == null:
		return _empty_script_array()
	if not raw_value is Array:
		_report_add_warning(
			_get_validation_report_value(report),
			&"invalid_required_capabilities",
			"required_capabilities must be an Array of Script values.",
			script_key
		)
		return _empty_script_array()

	var result: Array[Script] = []
	for item: Variant in GFVariantData.as_array(raw_value):
		var script: Script = _get_script_value(item)
		if script != null and not result.has(script):
			result.append(script)
		elif item != null:
			_report_add_warning(
				_get_validation_report_value(report),
				&"invalid_required_capability_type",
				"required_capabilities contains a non-Script value.",
				script_key
			)
	return result


# --- 私有/辅助方法 ---

static func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


static func _get_node_value(value: Variant) -> Node:
	if value is Node:
		return value
	return null


static func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		return value
	return null


static func _get_packed_scene_value(value: Variant) -> PackedScene:
	if value is PackedScene:
		return value
	return null


static func _get_editor_type_index_value(value: Variant) -> GFEditorTypeIndex:
	if value is GFEditorTypeIndex:
		return value
	return null


static func _get_validation_report_value(value: Variant) -> GFValidationReport:
	if value is GFValidationReport:
		return value
	return null


static func _get_process_mode_value(
	value: Variant,
	fallback: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
) -> Node.ProcessMode:
	if value is int:
		var int_value: int = value
		return _to_process_mode(int_value, fallback)
	return fallback


static func _to_process_mode(value: int, fallback: Node.ProcessMode = Node.PROCESS_MODE_INHERIT) -> Node.ProcessMode:
	match value:
		Node.PROCESS_MODE_INHERIT:
			return Node.PROCESS_MODE_INHERIT
		Node.PROCESS_MODE_PAUSABLE:
			return Node.PROCESS_MODE_PAUSABLE
		Node.PROCESS_MODE_WHEN_PAUSED:
			return Node.PROCESS_MODE_WHEN_PAUSED
		Node.PROCESS_MODE_ALWAYS:
			return Node.PROCESS_MODE_ALWAYS
		Node.PROCESS_MODE_DISABLED:
			return Node.PROCESS_MODE_DISABLED
		_:
			return fallback


static func _empty_script_array() -> Array[Script]:
	var result: Array[Script] = []
	return result


static func _read_property(object: Object, property_name: String, default_value: Variant = null) -> Variant:
	return GFObjectPropertyTools.read_property(object, NodePath(property_name), default_value)


static func _make_validation_report(subject: String) -> GFValidationReport:
	return _get_validation_report_value(_GF_VALIDATION_REPORT_SCRIPT.call("new", subject))


static func _make_editor_type_index() -> GFEditorTypeIndex:
	return _get_editor_type_index_value(_GF_EDITOR_TYPE_INDEX_SCRIPT.call("new"))


static func _connect_signal_checked(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	if source_signal.is_null() or not callback.is_valid():
		return
	if source_signal.is_connected(callback):
		return

	var error: int = source_signal.connect(callback, flags as Object.ConnectFlags)
	if error != OK:
		push_warning("[GFCapabilityInspector] Signal 连接失败：%s" % error_string(error))


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _report_add_warning(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> void:
	if report == null:
		return
	var issue: RefCounted = report.add_warning(kind, message, key, path, issue_metadata)
	if issue != null:
		return


static func _report_add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	issue_metadata: Dictionary = {}
) -> void:
	if report == null:
		return
	var issue: RefCounted = report.add_error(kind, message, key, path, issue_metadata)
	if issue != null:
		return


static func _report_to_dict(
	report: GFValidationReport,
	additional_fields: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	if report == null:
		return additional_fields.duplicate(true)
	return report.to_dict(additional_fields, options)


static func _script_extends_or_equals(script: Script, base_script: Script) -> bool:
	return GFVariantData.to_bool(_SCRIPT_TYPE_INSPECTOR.call("script_extends_or_equals", script, base_script))


static func _script_can_instantiate(script: Script) -> bool:
	return script != null and GFVariantData.to_bool(script.call("can_instantiate"))


static func _instantiate_script_node(script: Script) -> Node:
	if not _script_can_instantiate(script):
		return null
	return _get_node_value(script.call("new"))


static func _get_property_type_value(value: Variant) -> Variant.Type:
	match GFVariantData.to_int(value, TYPE_NIL):
		TYPE_BOOL:
			return TYPE_BOOL
		TYPE_INT:
			return TYPE_INT
		TYPE_FLOAT:
			return TYPE_FLOAT
		TYPE_STRING:
			return TYPE_STRING
		TYPE_VECTOR2:
			return TYPE_VECTOR2
		TYPE_VECTOR2I:
			return TYPE_VECTOR2I
		TYPE_RECT2:
			return TYPE_RECT2
		TYPE_RECT2I:
			return TYPE_RECT2I
		TYPE_VECTOR3:
			return TYPE_VECTOR3
		TYPE_VECTOR3I:
			return TYPE_VECTOR3I
		TYPE_TRANSFORM2D:
			return TYPE_TRANSFORM2D
		TYPE_VECTOR4:
			return TYPE_VECTOR4
		TYPE_VECTOR4I:
			return TYPE_VECTOR4I
		TYPE_PLANE:
			return TYPE_PLANE
		TYPE_QUATERNION:
			return TYPE_QUATERNION
		TYPE_AABB:
			return TYPE_AABB
		TYPE_BASIS:
			return TYPE_BASIS
		TYPE_TRANSFORM3D:
			return TYPE_TRANSFORM3D
		TYPE_PROJECTION:
			return TYPE_PROJECTION
		TYPE_COLOR:
			return TYPE_COLOR
		TYPE_STRING_NAME:
			return TYPE_STRING_NAME
		TYPE_NODE_PATH:
			return TYPE_NODE_PATH
		TYPE_RID:
			return TYPE_RID
		TYPE_OBJECT:
			return TYPE_OBJECT
		TYPE_CALLABLE:
			return TYPE_CALLABLE
		TYPE_SIGNAL:
			return TYPE_SIGNAL
		TYPE_DICTIONARY:
			return TYPE_DICTIONARY
		TYPE_ARRAY:
			return TYPE_ARRAY
		TYPE_PACKED_BYTE_ARRAY:
			return TYPE_PACKED_BYTE_ARRAY
		TYPE_PACKED_INT32_ARRAY:
			return TYPE_PACKED_INT32_ARRAY
		TYPE_PACKED_INT64_ARRAY:
			return TYPE_PACKED_INT64_ARRAY
		TYPE_PACKED_FLOAT32_ARRAY:
			return TYPE_PACKED_FLOAT32_ARRAY
		TYPE_PACKED_FLOAT64_ARRAY:
			return TYPE_PACKED_FLOAT64_ARRAY
		TYPE_PACKED_STRING_ARRAY:
			return TYPE_PACKED_STRING_ARRAY
		TYPE_PACKED_VECTOR2_ARRAY:
			return TYPE_PACKED_VECTOR2_ARRAY
		TYPE_PACKED_VECTOR3_ARRAY:
			return TYPE_PACKED_VECTOR3_ARRAY
		TYPE_PACKED_COLOR_ARRAY:
			return TYPE_PACKED_COLOR_ARRAY
		TYPE_PACKED_VECTOR4_ARRAY:
			return TYPE_PACKED_VECTOR4_ARRAY
		_:
			return TYPE_NIL


static func _get_property_hint_value(value: Variant) -> PropertyHint:
	match GFVariantData.to_int(value, PROPERTY_HINT_NONE):
		PROPERTY_HINT_RANGE:
			return PROPERTY_HINT_RANGE
		PROPERTY_HINT_ENUM:
			return PROPERTY_HINT_ENUM
		PROPERTY_HINT_ENUM_SUGGESTION:
			return PROPERTY_HINT_ENUM_SUGGESTION
		PROPERTY_HINT_EXP_EASING:
			return PROPERTY_HINT_EXP_EASING
		PROPERTY_HINT_LINK:
			return PROPERTY_HINT_LINK
		PROPERTY_HINT_FLAGS:
			return PROPERTY_HINT_FLAGS
		PROPERTY_HINT_LAYERS_2D_RENDER:
			return PROPERTY_HINT_LAYERS_2D_RENDER
		PROPERTY_HINT_LAYERS_2D_PHYSICS:
			return PROPERTY_HINT_LAYERS_2D_PHYSICS
		PROPERTY_HINT_LAYERS_2D_NAVIGATION:
			return PROPERTY_HINT_LAYERS_2D_NAVIGATION
		PROPERTY_HINT_LAYERS_3D_RENDER:
			return PROPERTY_HINT_LAYERS_3D_RENDER
		PROPERTY_HINT_LAYERS_3D_PHYSICS:
			return PROPERTY_HINT_LAYERS_3D_PHYSICS
		PROPERTY_HINT_LAYERS_3D_NAVIGATION:
			return PROPERTY_HINT_LAYERS_3D_NAVIGATION
		PROPERTY_HINT_FILE:
			return PROPERTY_HINT_FILE
		PROPERTY_HINT_DIR:
			return PROPERTY_HINT_DIR
		PROPERTY_HINT_GLOBAL_FILE:
			return PROPERTY_HINT_GLOBAL_FILE
		PROPERTY_HINT_GLOBAL_DIR:
			return PROPERTY_HINT_GLOBAL_DIR
		PROPERTY_HINT_RESOURCE_TYPE:
			return PROPERTY_HINT_RESOURCE_TYPE
		PROPERTY_HINT_MULTILINE_TEXT:
			return PROPERTY_HINT_MULTILINE_TEXT
		PROPERTY_HINT_EXPRESSION:
			return PROPERTY_HINT_EXPRESSION
		PROPERTY_HINT_PLACEHOLDER_TEXT:
			return PROPERTY_HINT_PLACEHOLDER_TEXT
		PROPERTY_HINT_COLOR_NO_ALPHA:
			return PROPERTY_HINT_COLOR_NO_ALPHA
		PROPERTY_HINT_OBJECT_ID:
			return PROPERTY_HINT_OBJECT_ID
		PROPERTY_HINT_TYPE_STRING:
			return PROPERTY_HINT_TYPE_STRING
		PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE:
			return PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE
		PROPERTY_HINT_NODE_PATH_VALID_TYPES:
			return PROPERTY_HINT_NODE_PATH_VALID_TYPES
		PROPERTY_HINT_SAVE_FILE:
			return PROPERTY_HINT_SAVE_FILE
		PROPERTY_HINT_GLOBAL_SAVE_FILE:
			return PROPERTY_HINT_GLOBAL_SAVE_FILE
		PROPERTY_HINT_INT_IS_OBJECTID:
			return PROPERTY_HINT_INT_IS_OBJECTID
		PROPERTY_HINT_INT_IS_POINTER:
			return PROPERTY_HINT_INT_IS_POINTER
		PROPERTY_HINT_ARRAY_TYPE:
			return PROPERTY_HINT_ARRAY_TYPE
		PROPERTY_HINT_LOCALE_ID:
			return PROPERTY_HINT_LOCALE_ID
		PROPERTY_HINT_LOCALIZABLE_STRING:
			return PROPERTY_HINT_LOCALIZABLE_STRING
		PROPERTY_HINT_NODE_TYPE:
			return PROPERTY_HINT_NODE_TYPE
		PROPERTY_HINT_HIDE_QUATERNION_EDIT:
			return PROPERTY_HINT_HIDE_QUATERNION_EDIT
		PROPERTY_HINT_PASSWORD:
			return PROPERTY_HINT_PASSWORD
		PROPERTY_HINT_TOOL_BUTTON:
			return PROPERTY_HINT_TOOL_BUTTON
		PROPERTY_HINT_ONESHOT:
			return PROPERTY_HINT_ONESHOT
		PROPERTY_HINT_GROUP_ENABLE:
			return PROPERTY_HINT_GROUP_ENABLE
		PROPERTY_HINT_INPUT_NAME:
			return PROPERTY_HINT_INPUT_NAME
		PROPERTY_HINT_FILE_PATH:
			return PROPERTY_HINT_FILE_PATH
		_:
			return PROPERTY_HINT_NONE


func _populate_add_menu(popup: PopupMenu, target: Node) -> void:
	popup.clear()
	if popup.id_pressed.is_connected(_on_add_menu_id_pressed):
		popup.id_pressed.disconnect(_on_add_menu_id_pressed)

	var candidates: Array[Dictionary] = _collect_node_capability_candidates()
	if candidates.is_empty():
		popup.add_item("未找到 GFNodeCapability")
		popup.set_item_disabled(0, true)
		return

	for i: int in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		popup.add_item(GFVariantData.get_option_string(candidate, "label", ""), i)
		popup.set_item_metadata(i, candidate)

	_connect_signal_checked(popup.id_pressed, _on_add_menu_id_pressed.bind(popup, target), CONNECT_DEFERRED)


func _populate_recipe_menu(popup: PopupMenu, target: Node) -> void:
	popup.clear()
	if popup.id_pressed.is_connected(_on_recipe_menu_id_pressed):
		popup.id_pressed.disconnect(_on_recipe_menu_id_pressed)

	var candidates: Array[Dictionary] = _collect_recipe_candidates()
	if candidates.is_empty():
		popup.add_item("未找到 GFCapabilityRecipe")
		popup.set_item_disabled(0, true)
		return

	for i: int in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		popup.add_item(GFVariantData.get_option_string(candidate, "label", ""), i)
		popup.set_item_metadata(i, candidate)

	_connect_signal_checked(popup.id_pressed, _on_recipe_menu_id_pressed.bind(popup, target), CONNECT_DEFERRED)


func _collect_node_capability_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not _is_capability_extension_enabled():
		return candidates

	var used_paths: Dictionary = {}
	var type_index: GFEditorTypeIndex = _make_editor_type_index()
	if type_index == null:
		return candidates

	var base_scripts: Array[Script] = _get_node_capability_base_scripts()
	var excluded_scripts: Array[Script] = base_scripts.duplicate()

	for base_script: Script in base_scripts:
		for record: Dictionary in type_index.collect_scripts_extending(base_script, excluded_scripts):
			var class_name_value: String = GFVariantData.get_option_string(record, "class_name", "")
			var path: String = GFVariantData.get_option_string(record, "path", "")
			if used_paths.has(path):
				continue

			used_paths[path] = true
			candidates.append({
				"kind": "script",
				"label": class_name_value,
				"path": path,
				"default_name": class_name_value,
			})

	for base_script: Script in base_scripts:
		for scene_record: Dictionary in type_index.collect_scene_roots_extending(base_script, used_paths):
			var display_name: String = GFVariantData.get_option_string(scene_record, "display_name", "")
			candidates.append({
				"kind": "scene",
				"label": "%s 场景" % display_name,
				"path": GFVariantData.get_option_string(scene_record, "path", ""),
				"default_name": display_name,
			})

	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "label", "") < GFVariantData.get_option_string(right, "label", "")
	)
	return candidates


func _collect_recipe_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not Engine.is_editor_hint() or not _is_capability_extension_enabled():
		return candidates

	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return candidates

	var root_dir: EditorFileSystemDirectory = filesystem.get_filesystem()
	if root_dir == null:
		return candidates

	var used_paths: Dictionary = {}
	var scan_state: Dictionary = _make_recipe_scan_state()
	_collect_recipe_candidates_recursive(root_dir, candidates, used_paths, 0, scan_state)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "label", "") < GFVariantData.get_option_string(right, "label", "")
	)
	return candidates


func _collect_recipe_candidates_recursive(
	directory: EditorFileSystemDirectory,
	candidates: Array[Dictionary],
	used_paths: Dictionary,
	depth: int,
	scan_state: Dictionary
) -> void:
	for i: int in range(directory.get_subdir_count()):
		var subdir: EditorFileSystemDirectory = directory.get_subdir(i)
		if _can_scan_recipe_deeper(subdir.get_path(), depth, scan_state):
			_collect_recipe_candidates_recursive(subdir, candidates, used_paths, depth + 1, scan_state)

	for i: int in range(directory.get_file_count()):
		if not _can_collect_more_recipe_candidates(candidates, scan_state):
			_warn_recipe_candidate_limit(scan_state)
			break

		var file_name: String = directory.get_file(i)
		if not _is_recipe_resource_file(file_name):
			continue

		var path: String = _join_resource_path(directory.get_path(), file_name)
		if used_paths.has(path):
			continue
		var recipe_base_script: Script = _get_capability_recipe_script()
		if recipe_base_script == null:
			return

		var recipe: Resource = _get_resource_value(load(path))
		if recipe == null or not _resource_extends_script(recipe, recipe_base_script):
			continue

		used_paths[path] = true
		candidates.append({
			"label": _get_recipe_display_label(recipe, path),
			"path": path,
			"recipe": recipe,
		})


func _can_scan_recipe_deeper(path: String, current_depth: int, scan_state: Dictionary) -> bool:
	if current_depth < _DEFAULT_MAX_RECIPE_SCAN_DEPTH:
		return true
	if GFVariantData.get_option_bool(scan_state, "depth_warning_emitted", false):
		return false
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFCapabilityInspector] Recipe 扫描已达到最大目录深度 %d，已跳过更深目录：%s。" % [
		_DEFAULT_MAX_RECIPE_SCAN_DEPTH,
		path,
	])
	return false


func _can_collect_more_recipe_candidates(candidates: Array[Dictionary], _scan_state: Dictionary) -> bool:
	return candidates.size() < _DEFAULT_MAX_RECIPE_CANDIDATES


func _make_recipe_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


func _warn_recipe_candidate_limit(scan_state: Dictionary) -> void:
	if GFVariantData.get_option_bool(scan_state, "count_warning_emitted", false):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFCapabilityInspector] Recipe 候选已达到最大数量 %d，后续资源已跳过。" % _DEFAULT_MAX_RECIPE_CANDIDATES)


func _get_node_capability_base_scripts() -> Array[Script]:
	var result: Array[Script] = []
	for path: String in [
		_GF_NODE_CAPABILITY_SCRIPT_PATH,
		_GF_NODE_2D_CAPABILITY_SCRIPT_PATH,
		_GF_NODE_3D_CAPABILITY_SCRIPT_PATH,
		_GF_CONTROL_CAPABILITY_SCRIPT_PATH,
	]:
		var script: Script = _load_script_or_null(path)
		if script != null:
			result.append(script)
	return result


static func _get_capability_container_script() -> Script:
	return _load_script_or_null(_GF_CAPABILITY_CONTAINER_SCRIPT_PATH)


func _get_capability_recipe_script() -> Script:
	return _load_script_or_null(_GF_CAPABILITY_RECIPE_SCRIPT_PATH)


static func _load_script_or_null(path: String) -> Script:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return _get_script_value(load(path))


func _is_capability_extension_enabled() -> bool:
	return GFVariantData.to_bool(_GF_EXTENSION_SETTINGS_SCRIPT.call("is_extension_enabled", _CAPABILITY_EXTENSION_ID))


func _resource_extends_script(resource: Resource, base_script: Script) -> bool:
	if resource == null or base_script == null:
		return false
	var script: Script = _get_script_value(resource.get_script())
	return script != null and _script_extends_or_equals(script, base_script)


func _is_recipe_resource_file(file_name: String) -> bool:
	var extension: String = file_name.get_extension().to_lower()
	return extension == "tres" or extension == "res"


func _join_resource_path(dir_path: String, file_name: String) -> String:
	if dir_path.ends_with("/"):
		return dir_path + file_name
	return "%s/%s" % [dir_path, file_name]


func _get_recipe_display_label(recipe: Resource, path: String) -> String:
	var display_name: String = GFVariantData.to_text(_read_property(recipe, "display_name")).strip_edges() if recipe != null else ""
	if display_name.is_empty() and recipe != null:
		var recipe_id: StringName = GFVariantData.to_string_name(_read_property(recipe, "recipe_id"))
		if recipe_id != &"":
			display_name = String(recipe_id)
	if display_name.is_empty():
		display_name = path.get_file().get_basename().to_pascal_case()
	return "%s (%s)" % [display_name, path]


func _is_recipe_entry_valid(entry: Resource) -> bool:
	if entry == null:
		return false
	var capability_type: Script = _get_script_value(_read_property(entry, "capability_type"))
	var scene: PackedScene = _get_packed_scene_value(_read_property(entry, "scene"))
	return capability_type != null or scene != null


func _script_is_node_capability(script: Script) -> bool:
	if script == null:
		return false
	for base_script: Script in _get_node_capability_base_scripts():
		if _script_extends_or_equals(script, base_script):
			return true
	return false


func _get_packed_scene_root_script(scene: PackedScene) -> Script:
	if scene == null:
		return null

	var state: SceneState = scene.get_state()
	if state == null:
		return null

	for node_index: int in range(state.get_node_count()):
		if not state.get_node_path(node_index, true).is_empty():
			continue

		for property_index: int in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) == &"script":
				return _get_script_value(state.get_node_property_value(node_index, property_index))
	return null


func _create_capability_row(target: Node, capability: Node) -> Control:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row)

	var active_check: CheckBox = CheckBox.new()
	active_check.button_pressed = _read_editor_capability_active(capability)
	active_check.tooltip_text = "启用或停用能力"
	_connect_signal_checked(active_check.toggled, _on_capability_active_toggled.bind(capability), CONNECT_DEFERRED)
	row.add_child(active_check)

	var label: Label = Label.new()
	label.text = _get_capability_display_name(capability)
	label.tooltip_text = capability.get_path()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var edit_button: Button = Button.new()
	edit_button.text = "编辑"
	edit_button.tooltip_text = "在 Inspector 中编辑该能力"
	_connect_signal_checked(edit_button.pressed, _on_capability_edit_pressed.bind(capability), CONNECT_DEFERRED)
	row.add_child(edit_button)

	var remove_button: Button = Button.new()
	remove_button.text = "移除"
	remove_button.tooltip_text = "移除该能力节点"
	_connect_signal_checked(remove_button.pressed, _on_capability_remove_pressed.bind(target, capability), CONNECT_DEFERRED)
	row.add_child(remove_button)

	var properties: Control = _create_capability_properties(capability)
	if properties.get_child_count() > 0:
		wrapper.add_child(properties)

	return wrapper


func _create_capability_properties(capability: Node) -> Control:
	var properties: VBoxContainer = VBoxContainer.new()
	properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for property_info: Dictionary in capability.get_property_list():
		if not _is_editable_capability_property(property_info):
			continue

		var property_name: String = GFVariantData.get_option_string(property_info, "name", "")
		var editor_property: EditorProperty = EditorInspector.instantiate_property_editor(
			capability,
			_get_property_type_value(GFVariantData.get_option_value(property_info, "type", TYPE_NIL)),
			property_name,
			_get_property_hint_value(GFVariantData.get_option_value(property_info, "hint", PROPERTY_HINT_NONE)),
			GFVariantData.get_option_string(property_info, "hint_string", ""),
			GFVariantData.get_option_int(property_info, "usage", PROPERTY_USAGE_DEFAULT),
			false
		)
		if editor_property != null:
			var row: HBoxContainer = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var label: Label = Label.new()
			label.text = _get_property_display_name(property_name)
			label.tooltip_text = property_name
			label.custom_minimum_size = Vector2(128, 0)
			row.add_child(label)

			editor_property.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(editor_property)
			properties.add_child(row)

	return properties


func _is_editable_capability_property(property_info: Dictionary) -> bool:
	var usage: int = GFVariantData.get_option_int(property_info, "usage", 0)
	if (usage & PROPERTY_USAGE_EDITOR) == 0:
		return false
	if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
		return false

	var property_name: String = GFVariantData.get_option_string(property_info, "name", "")
	return (
		not property_name.is_empty()
		and property_name != "script"
		and property_name != "active"
	)


func _get_property_display_name(property_name: String) -> String:
	if property_name.is_empty():
		return ""
	return property_name.capitalize()


func _get_capability_display_name(capability: Node) -> String:
	var script: Script = _get_script_value(capability.get_script())
	if script != null:
		var global_name: StringName = script.get_global_name()
		if global_name != &"":
			return String(global_name)
	return capability.name


static func _get_capability_containers(target: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in target.get_children(true):
		if _is_capability_container(child):
			result.append(child)
	return result


func _get_or_create_capability_container(target: Node, capability: Node) -> Node:
	var existing: Node = _find_capability_container(target, capability)
	if existing != null:
		return existing

	var container: Node = _make_capability_container(target, capability)
	target.add_child(container, true)
	_set_owner_recursive(container, EditorInterface.get_edited_scene_root())
	return container


static func _find_capability_container(target: Node, capability: Node) -> Node:
	for existing: Node in _get_capability_containers(target):
		if _container_matches_capability(existing, capability):
			return existing
	return null


static func _make_capability_container(target: Node, capability: Node) -> Node:
	var container: Node = _create_capability_container_node(target, capability)
	container.set_meta(_META_CAPABILITY_CONTAINER, true)
	_try_attach_capability_container_script(container)
	return container


static func _create_capability_container_node(target: Node, capability: Node) -> Node:
	var container: Node = null
	if target is Node3D and capability is Node3D:
		container = Node3D.new()
		container.name = "GFCapabilityContainer3D"
	elif target is Node2D and capability is Node2D:
		container = Node2D.new()
		container.name = "GFCapabilityContainer2D"
	elif target is Control and capability is Control:
		var control_container: Control = Control.new()
		control_container.name = "GFCapabilityContainerControl"
		_configure_control_container(control_container)
		container = control_container
	else:
		container = Node.new()
		container.name = "GFCapabilityContainer"
	return container


static func _try_attach_capability_container_script(container: Node) -> void:
	var container_script: Script = _get_capability_container_script()
	if container_script == null or not container_script.can_instantiate():
		push_warning("[GF Framework] 能力容器脚本不可用，已改用元数据标记容器。")
		return

	var base_type: String = GFVariantData.to_text(container_script.get_instance_base_type())
	if not base_type.is_empty() and not container.is_class(base_type):
		push_warning("[GF Framework] 能力容器节点类型与脚本基类不匹配，已改用元数据标记容器。")
		return

	container.set_script(container_script)


static func _configure_control_container(container: Control) -> void:
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = 0.0
	container.offset_bottom = 0.0


static func _container_matches_capability(container: Node, capability: Node) -> bool:
	if capability is Node3D:
		return container is Node3D
	if capability is Node2D:
		return container is Node2D
	if capability is Control:
		return container is Control
	return not (container is Node2D) and not (container is Node3D) and not (container is Control)


static func _is_capability_container(node: Node) -> bool:
	if GFVariantData.to_bool(node.get_meta(_META_CAPABILITY_CONTAINER, false)):
		return true

	var container_script: Script = _get_capability_container_script()
	var node_script: Script = _get_script_value(node.get_script())
	return (
		container_script != null
		and node_script != null
		and _script_extends_or_equals(node_script, container_script)
	)


func _get_capability_nodes(target: Node) -> Array[Node]:
	var result: Array[Node] = []
	for container: Node in _get_capability_containers(target):
		for child: Node in container.get_children(true):
			if child.get_script() != null:
				result.append(child)
	return result


func _create_capability_node(candidate: Dictionary) -> Node:
	var path: String = GFVariantData.get_option_string(candidate, "path", "")
	match GFVariantData.get_option_string(candidate, "kind", ""):
		"script":
			var script: Script = _get_script_value(load(path))
			if script == null:
				return null
			var instance: Node = _instantiate_script_node(script)
			if instance == null:
				push_error("[GF Framework] 能力脚本必须能实例化为 Node：%s" % path)
			return instance

		"scene":
			var packed_scene: PackedScene = _get_packed_scene_value(load(path))
			if packed_scene == null:
				return null
			return _get_node_value(packed_scene.instantiate())

	return null


func _add_capability_node(target: Node, candidate: Dictionary) -> void:
	if not is_instance_valid(target):
		return

	var node: Node = _create_capability_node(candidate)
	if node == null:
		return

	var plans: Array[Dictionary] = [
		_make_capability_add_plan(target, node, GFVariantData.get_option_string(candidate, "default_name", ""))
	]
	_commit_capability_add_plans("添加 GF 节点能力", target, plans, node)


static func _make_capability_add_plan(
	target: Node,
	node: Node,
	default_name: String,
	planned_additions: Array[Dictionary] = []
) -> Dictionary:
	var container: Node = _find_planned_capability_container(planned_additions, node)
	var container_is_new: bool = false
	if container == null:
		container = _find_capability_container(target, node)
	if container == null:
		container = _make_capability_container(target, node)
		container_is_new = true

	var used_names: Dictionary = _get_planned_child_names(container, planned_additions)
	node.name = _make_unique_child_name_with_used(container, default_name, used_names)
	return {
		"target": target,
		"container": container,
		"container_is_new": container_is_new,
		"container_index": _get_planned_container_index(target, planned_additions),
		"node": node,
		"node_index": _get_planned_node_index(container, planned_additions),
	}


static func _find_planned_capability_container(planned_additions: Array[Dictionary], capability: Node) -> Node:
	for plan: Dictionary in planned_additions:
		var container: Node = _get_node_value(plan.get("container", null))
		if container != null and _container_matches_capability(container, capability):
			return container
	return null


static func _get_planned_child_names(container: Node, planned_additions: Array[Dictionary]) -> Dictionary:
	var used_names: Dictionary = {}
	if container != null:
		for child: Node in container.get_children(true):
			used_names[String(child.name)] = true

	for plan: Dictionary in planned_additions:
		var planned_container: Node = _get_node_value(plan.get("container", null))
		if planned_container != container:
			continue
		var planned_node: Node = _get_node_value(plan.get("node", null))
		if planned_node != null:
			used_names[String(planned_node.name)] = true
	return used_names


static func _get_planned_container_index(target: Node, planned_additions: Array[Dictionary]) -> int:
	var index: int = target.get_child_count() if is_instance_valid(target) else 0
	for plan: Dictionary in planned_additions:
		if not GFVariantData.get_option_bool(plan, "container_is_new", false):
			continue
		var planned_target: Node = _get_node_value(plan.get("target", null))
		if planned_target == target:
			index += 1
	return index


static func _get_planned_node_index(container: Node, planned_additions: Array[Dictionary]) -> int:
	var index: int = container.get_child_count() if is_instance_valid(container) else 0
	for plan: Dictionary in planned_additions:
		var planned_container: Node = _get_node_value(plan.get("container", null))
		if planned_container == container:
			index += 1
	return index


static func _make_unique_child_name_with_used(parent: Node, base_name: String, used_names: Dictionary) -> String:
	var clean_name: String = base_name if not base_name.is_empty() else "Capability"
	if not parent.has_node(NodePath(clean_name)) and not used_names.has(clean_name):
		return clean_name

	var index: int = 2
	while parent.has_node(NodePath("%s%d" % [clean_name, index])) or used_names.has("%s%d" % [clean_name, index]):
		index += 1
	return "%s%d" % [clean_name, index]


func _commit_capability_add_plans(
	action_name: String,
	target: Node,
	plans: Array[Dictionary],
	selection_after_do: Node
) -> void:
	if plans.is_empty():
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		for plan: Dictionary in plans:
			_execute_capability_add_plan(plan)
		_select_and_inspect_node(selection_after_do)
		return

	undo_redo.create_action(action_name)
	for plan: Dictionary in plans:
		_add_capability_plan_to_undo(undo_redo, plan)
	undo_redo.add_do_method(self, "_select_and_inspect_node", selection_after_do)
	if is_instance_valid(target):
		undo_redo.add_undo_method(self, "_select_and_inspect_node", target)
	undo_redo.commit_action()


func _add_capability_plan_to_undo(undo_redo: EditorUndoRedoManager, plan: Dictionary) -> void:
	var target: Node = _get_node_value(plan.get("target", null))
	var container: Node = _get_node_value(plan.get("container", null))
	var node: Node = _get_node_value(plan.get("node", null))
	if not is_instance_valid(target) or container == null or node == null:
		return

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if GFVariantData.get_option_bool(plan, "container_is_new", false):
		undo_redo.add_do_method(
			self,
			"_add_child_at",
			target,
			container,
			GFVariantData.get_option_int(plan, "container_index", target.get_child_count()),
			true
		)
		undo_redo.add_do_method(self, "_set_owner_recursive", container, scene_root)

	undo_redo.add_do_method(
		self,
		"_add_child_at",
		container,
		node,
		GFVariantData.get_option_int(plan, "node_index", container.get_child_count()),
		true
	)
	undo_redo.add_do_method(self, "_set_owner_recursive", node, scene_root)
	if plan.has("active"):
		undo_redo.add_do_method(
			self,
			"_set_editor_capability_active",
			node,
			GFVariantData.get_option_bool(plan, "active", true)
		)

	undo_redo.add_undo_method(self, "_remove_child_if_parent", container, node)
	if GFVariantData.get_option_bool(plan, "container_is_new", false):
		undo_redo.add_undo_method(self, "_remove_child_if_parent", target, container)
		undo_redo.add_do_reference(container)
		undo_redo.add_undo_reference(container)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_reference(node)


func _execute_capability_add_plan(plan: Dictionary) -> void:
	var target: Node = _get_node_value(plan.get("target", null))
	var container: Node = _get_node_value(plan.get("container", null))
	var node: Node = _get_node_value(plan.get("node", null))
	if not is_instance_valid(target) or container == null or node == null:
		return

	if GFVariantData.get_option_bool(plan, "container_is_new", false):
		_add_child_at(target, container, GFVariantData.get_option_int(plan, "container_index", target.get_child_count()), true)
		_set_owner_recursive(container, EditorInterface.get_edited_scene_root())

	_add_child_at(container, node, GFVariantData.get_option_int(plan, "node_index", container.get_child_count()), true)
	_set_owner_recursive(node, EditorInterface.get_edited_scene_root())
	if plan.has("active"):
		_set_editor_capability_active(node, GFVariantData.get_option_bool(plan, "active", true))


func _apply_recipe_to_target(target: Node, recipe: Resource) -> Dictionary:
	var report: GFValidationReport = _make_validation_report("Capability recipe editor apply")
	var added: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	if not is_instance_valid(target):
		_report_add_error(report, &"invalid_target", "Target node is invalid.")
		return _recipe_apply_report_to_dict(report, recipe, added, skipped)
	if recipe == null:
		_report_add_error(report, &"invalid_recipe", "Capability recipe is null.")
		return _recipe_apply_report_to_dict(report, recipe, added, skipped)

	var entries: Array = GFVariantData.as_array(_read_property(recipe, "entries", []))
	var add_plans: Array[Dictionary] = []
	var planned_capability_keys: Dictionary = {}

	for index: int in range(entries.size()):
		var entry: Resource = _get_resource_value(entries[index])
		if entry == null:
			_report_add_warning(report, &"null_entry", "Recipe contains a null entry.", str(index))
			continue
		if not _is_recipe_entry_valid(entry):
			_report_add_error(report, &"invalid_entry", "Recipe entry requires capability_type or scene.", str(index))
			continue

		var node: Node = _create_capability_node_from_recipe_entry(entry, report, index)
		if node == null:
			skipped.append({
				"index": index,
				"kind": "not_node_capability",
			})
			continue

		var capability_script: Script = _get_script_value(_read_property(entry, "capability_type"))
		if capability_script == null:
			capability_script = _get_script_value(node.get_script())
		var capability_key: String = _get_script_key(capability_script)
		if capability_script != null and (
			_target_has_capability_script(target, capability_script)
			or planned_capability_keys.has(capability_key)
		):
			node.queue_free()
			skipped.append({
				"index": index,
				"kind": "already_exists",
				"type": capability_key,
			})
			continue

		var active: bool = GFVariantData.to_bool(_read_property(entry, "active", true), true)
		_set_editor_capability_active(node, active)
		var plan: Dictionary = _make_capability_add_plan(
			target,
			node,
			_get_recipe_entry_node_name(entry, node, index),
			add_plans
		)
		plan["active"] = active
		add_plans.append(plan)
		if capability_script != null:
			planned_capability_keys[capability_key] = true
		added.append({
			"index": index,
			"type": capability_key,
			"name": node.name,
			"active": active,
		})

	if not add_plans.is_empty():
		_commit_capability_add_plans("应用 GF Capability Recipe", target, add_plans, target)
	var result: Dictionary = _recipe_apply_report_to_dict(report, recipe, added, skipped)
	result["dependency_report"] = _build_editor_capability_report(target)
	_select_editor_node(target)
	EditorInterface.inspect_object(target)
	return result


func _create_capability_node_from_recipe_entry(
	entry: Resource,
	report: GFValidationReport,
	index: int
) -> Node:
	if entry == null:
		return null
	var entry_scene: PackedScene = _get_packed_scene_value(_read_property(entry, "scene"))
	if entry_scene != null:
		var scene_node: Node = _get_node_value(entry_scene.instantiate())
		if scene_node == null:
			_report_add_error(report, &"scene_root_not_node", "Recipe scene root must be a Node.", str(index))
			return null
		var scene_script: Script = _get_script_value(_read_property(entry, "capability_type"))
		if scene_script == null:
			scene_script = _get_script_value(scene_node.get_script())
		if not _script_is_node_capability(scene_script):
			_report_add_warning(report, &"not_node_capability", "Recipe scene root is not a GF node capability.", str(index))
			scene_node.queue_free()
			return null
		return scene_node

	var script: Script = _get_script_value(_read_property(entry, "capability_type"))
	if not _script_is_node_capability(script):
		_report_add_warning(report, &"not_node_capability", "Recipe entry is not a GF node capability.", str(index))
		return null
	if not _script_can_instantiate(script):
		_report_add_error(report, &"script_not_instantiable", "Recipe capability script cannot be instantiated.", str(index))
		return null

	var node: Node = _instantiate_script_node(script)
	if node == null:
		_report_add_error(report, &"script_not_node", "Recipe capability script must instantiate a Node.", str(index))
	return node


func _recipe_apply_report_to_dict(
	report: GFValidationReport,
	recipe: Resource,
	added: Array[Dictionary],
	skipped: Array[Dictionary]
) -> Dictionary:
	return _report_to_dict(
		report,
		{
			"recipe_id": _read_property(recipe, "recipe_id", &"") if recipe != null else &"",
			"added": added,
			"skipped": skipped,
			"added_count": added.size(),
			"skipped_count": skipped.size(),
		},
		{
			"include_subject": false,
			"include_metadata": false,
			"include_info_count": false,
			"include_issue_count": false,
			"next_actions": _get_editor_capability_next_actions(),
			"no_action": "No action required.",
			"fallback_action": "Review the first reported capability editor issue.",
		}
	)


func _get_recipe_entry_node_name(entry: Resource, node: Node, index: int) -> String:
	var capability_type: Script = null
	if entry != null:
		capability_type = _get_script_value(_read_property(entry, "capability_type"))
	if capability_type != null:
		var global_name: StringName = capability_type.get_global_name()
		if global_name != &"":
			return String(global_name)
	if node != null and not String(node.name).is_empty():
		return String(node.name)
	return "Capability%d" % (index + 1)


func _build_editor_capability_report(target: Node) -> Dictionary:
	var report: GFValidationReport = _make_validation_report("Capability inspector")
	if not is_instance_valid(target):
		_report_add_error(report, &"invalid_target", "Target node is invalid.")
		return _report_to_dict(report, {}, { "include_subject": false })

	var capabilities: Array[Node] = _get_capability_nodes(target)
	var capability_records: Array[Dictionary] = []
	var seen_scripts: Dictionary = {}
	for capability: Node in capabilities:
		var script: Script = _get_script_value(capability.get_script())
		var script_key: String = _get_script_key(script)
		if script == null:
			_report_add_warning(report, &"missing_capability_script", "Capability node has no script.", capability.get_path())
			continue
		if seen_scripts.has(script):
			_report_add_warning(report, &"duplicate_capability", "Target contains duplicate capability scripts.", script_key)
		seen_scripts[script] = true

		var required_types: Array[Script] = collect_required_capability_types(capability, report, script_key)
		var missing_dependencies: Array[Dictionary] = []
		for required_type: Script in required_types:
			if _capability_list_has_script(capabilities, required_type):
				continue
			var missing_entry: Dictionary = {
				"capability": script_key,
				"required": _get_script_key(required_type),
			}
			missing_dependencies.append(missing_entry)
			_report_add_error(
				report,
				&"missing_required_capability",
				"Capability is missing a required capability.",
				script_key,
				_get_script_key(required_type)
			)

		capability_records.append({
			"type": script_key,
			"name": capability.name,
			"active": _read_editor_capability_active(capability),
			"required": _script_array_to_keys(required_types),
			"missing_dependencies": missing_dependencies,
		})

	return _report_to_dict(
		report,
		{
			"target": target.get_path(),
			"capability_count": capability_records.size(),
			"capabilities": capability_records,
		},
		{
			"include_subject": false,
			"include_metadata": false,
			"include_info_count": false,
			"include_issue_count": false,
			"next_actions": _get_editor_capability_next_actions(),
			"no_action": "No action required.",
			"fallback_action": "Review the first reported capability editor issue.",
		}
	)


func _target_has_capability_script(target: Node, expected_script: Script) -> bool:
	return _capability_list_has_script(_get_capability_nodes(target), expected_script)


func _capability_list_has_script(capabilities: Array[Node], expected_script: Script) -> bool:
	if expected_script == null:
		return false

	for capability: Node in capabilities:
		var script: Script = _get_script_value(capability.get_script())
		if script == null:
			continue
		if script == expected_script:
			return true
		if _script_extends_or_equals(script, expected_script):
			return true
	return false


func _script_array_to_keys(scripts: Array[Script]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for script: Script in scripts:
		_append_packed_string(result, _get_script_key(script))
	result.sort()
	return result


func _get_script_key(script: Script) -> String:
	if script == null:
		return "<null>"

	var global_name: StringName = script.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script.resource_path.is_empty():
		return script.resource_path
	return str(script.get_instance_id())


func _show_editor_report(title: String, report: Dictionary) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title
	dialog.exclusive = false

	var text_edit: TextEdit = TextEdit.new()
	text_edit.editable = false
	text_edit.custom_minimum_size = Vector2(720, 420)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.text = _format_editor_report(report)
	dialog.add_child(text_edit)
	_connect_signal_checked(dialog.confirmed, dialog.queue_free, CONNECT_DEFERRED)
	_connect_signal_checked(dialog.close_requested, dialog.queue_free, CONNECT_DEFERRED)

	var base_control: Control = EditorInterface.get_base_control()
	if base_control != null:
		base_control.add_child(dialog)
		dialog.popup_centered(Vector2i(760, 460))


func _format_editor_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	_append_packed_string(lines, GFVariantData.get_option_string(report, "summary", "Capability report"))
	_append_packed_string(lines, "ok: %s" % str(GFVariantData.get_option_bool(report, "ok", false)))
	_append_packed_string(lines, "errors: %d, warnings: %d" % [
		GFVariantData.get_option_int(report, "error_count", 0),
		GFVariantData.get_option_int(report, "warning_count", 0),
	])
	if report.has("added_count"):
		_append_packed_string(lines, "added: %d, skipped: %d" % [
			GFVariantData.get_option_int(report, "added_count", 0),
			GFVariantData.get_option_int(report, "skipped_count", 0),
		])
	if report.has("capability_count"):
		_append_packed_string(lines, "capabilities: %d" % GFVariantData.get_option_int(report, "capability_count", 0))

	var issues: Array = GFVariantData.get_option_array(report, "issues")
	if not issues.is_empty():
		_append_packed_string(lines, "")
		_append_packed_string(lines, "Issues:")
		for issue_value: Variant in issues:
			var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
			if issue.is_empty():
				continue
			var kind: String = GFVariantData.get_option_string(issue, "kind", "unknown")
			var severity: String = GFVariantData.get_option_string(issue, "severity", "error")
			var message: String = GFVariantData.get_option_string(issue, "message", "")
			var key: String = GFVariantData.get_option_string(issue, "key", "")
			var path: String = GFVariantData.get_option_string(issue, "path", "")
			_append_packed_string(lines, "- [%s] %s: %s" % [severity, kind, message])
			if not key.is_empty() or not path.is_empty():
				_append_packed_string(lines, "  key=%s path=%s" % [key, path])

	_append_packed_string(lines, "")
	_append_packed_string(lines, "Next action: %s" % GFVariantData.get_option_string(report, "next_action", "No action required."))
	return "\n".join(lines)


func _get_editor_capability_next_actions() -> Dictionary:
	return {
		"invalid_target": "Select a valid Node before using the capability inspector.",
		"invalid_recipe": "Assign a valid GFCapabilityRecipe resource.",
		"invalid_entry": "Set capability_type or scene on every Recipe entry.",
		"null_entry": "Remove the null Recipe entry or replace it with a valid entry.",
		"not_node_capability": "Use a GFNodeCapability, GFNode2DCapability, GFNode3DCapability, or GFControlCapability entry.",
		"script_not_instantiable": "Use an instantiable capability script or a PackedScene entry.",
		"script_not_node": "Use node-based capabilities in the editor inspector.",
		"scene_root_not_node": "Use a scene whose root is a Node.",
		"missing_capability_script": "Attach a script to the capability node or remove it.",
		"duplicate_capability": "Remove duplicate capability nodes unless they intentionally use different registered types.",
		"missing_required_capability": "Add the required capability or adjust required_capabilities.",
		"invalid_required_capabilities": "Store an Array[Script] in required_capabilities.",
		"invalid_required_capability_type": "Only Script values should be stored in required_capabilities.",
	}


func _remove_capability_node(target: Node, capability: Node) -> void:
	if not is_instance_valid(capability):
		return

	var container: Node = capability.get_parent()
	if container == null:
		capability.queue_free()
		return

	var container_parent: Node = container.get_parent()
	var capability_index: int = capability.get_index()
	var container_index: int = container.get_index() if container_parent != null else -1
	var remove_container: bool = is_instance_valid(container_parent) and container.get_child_count(true) <= 1
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_remove_child_if_parent(container, capability)
		if remove_container:
			_remove_child_if_parent(container_parent, container)
		capability.queue_free()
		if remove_container:
			container.queue_free()
		_select_and_inspect_node(target)
		return

	undo_redo.create_action("移除 GF 节点能力")
	undo_redo.add_do_method(self, "_remove_child_if_parent", container, capability)
	if remove_container:
		undo_redo.add_do_method(self, "_remove_child_if_parent", container_parent, container)
	undo_redo.add_do_method(self, "_select_and_inspect_node", target)
	if remove_container:
		undo_redo.add_undo_method(self, "_add_child_at", container_parent, container, container_index, true)
		undo_redo.add_undo_method(self, "_set_owner_recursive", container, scene_root)
		undo_redo.add_do_reference(container)
		undo_redo.add_undo_reference(container)
	undo_redo.add_undo_method(self, "_add_child_at", container, capability, capability_index, true)
	undo_redo.add_undo_method(self, "_set_owner_recursive", capability, scene_root)
	undo_redo.add_undo_method(self, "_select_and_inspect_node", capability)
	undo_redo.add_do_reference(capability)
	undo_redo.add_undo_reference(capability)
	undo_redo.commit_action()


func _make_unique_child_name(parent: Node, base_name: String) -> String:
	var clean_name: String = base_name if not base_name.is_empty() else "Capability"
	if not parent.has_node(NodePath(clean_name)):
		return clean_name

	var index: int = 2
	while parent.has_node(NodePath("%s%d" % [clean_name, index])):
		index += 1
	return "%s%d" % [clean_name, index]


func _select_editor_node(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		return

	selection.clear()
	selection.add_node(node)


func _select_and_inspect_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_select_editor_node(node)
	EditorInterface.inspect_object(node)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if owner == null:
		return

	node.owner = owner
	for child: Node in node.get_children(true):
		_set_owner_recursive(child, owner)


func _add_child_at(parent: Node, child: Node, index: int, force_readable_name: bool = true) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(child):
		return

	var current_parent: Node = child.get_parent()
	if current_parent != null and current_parent != parent:
		current_parent.remove_child(child)
	if child.get_parent() == null:
		parent.add_child(child, force_readable_name)

	var max_index: int = maxi(parent.get_child_count() - 1, 0)
	parent.move_child(child, clampi(index, 0, max_index))


func _remove_child_if_parent(parent: Node, child: Node) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(child):
		return
	if child.get_parent() == parent:
		parent.remove_child(child)


func _read_editor_capability_active(capability: Node) -> bool:
	if "active" in capability:
		return GFVariantData.to_bool(_read_property(capability, "active", true), true)
	if capability.has_meta(_META_CAPABILITY_ACTIVE):
		return GFVariantData.to_bool(capability.get_meta(_META_CAPABILITY_ACTIVE), true)
	return true


func _set_editor_capability_active(capability: Node, active: bool) -> void:
	if "active" in capability:
		capability.set("active", active)
	capability.set_meta(_META_CAPABILITY_ACTIVE, active)
	_set_node_tree_active_state(capability, active)


func _set_node_tree_active_state(node: Node, active: bool) -> void:
	_set_node_active_state(node, active)
	for child: Node in node.get_children():
		_set_node_tree_active_state(child, active)


func _set_node_active_state(node: Node, active: bool) -> void:
	if active:
		if node.has_meta(_META_ORIGINAL_PROCESS_MODE):
			var original_process_mode: Node.ProcessMode = _get_process_mode_value(
				node.get_meta(_META_ORIGINAL_PROCESS_MODE),
				Node.PROCESS_MODE_INHERIT
			)
			if node.process_mode == Node.PROCESS_MODE_DISABLED:
				node.process_mode = original_process_mode
			node.remove_meta(_META_ORIGINAL_PROCESS_MODE)
		return

	if not node.has_meta(_META_ORIGINAL_PROCESS_MODE):
		node.set_meta(_META_ORIGINAL_PROCESS_MODE, node.process_mode)
	node.process_mode = Node.PROCESS_MODE_DISABLED as Node.ProcessMode


# --- 信号处理函数 ---

func _on_add_menu_id_pressed(id: int, popup: PopupMenu, target: Node) -> void:
	var index: int = popup.get_item_index(id)
	if index < 0:
		return

	var candidate: Dictionary = GFVariantData.as_dictionary(popup.get_item_metadata(index))
	if candidate.is_empty():
		return
	_add_capability_node(target, candidate)


func _on_recipe_menu_id_pressed(id: int, popup: PopupMenu, target: Node) -> void:
	var index: int = popup.get_item_index(id)
	if index < 0:
		return

	var candidate: Dictionary = GFVariantData.as_dictionary(popup.get_item_metadata(index))
	if candidate.is_empty():
		return

	var recipe: Resource = _get_resource_value(GFVariantData.get_option_value(candidate, "recipe", null))
	var report: Dictionary = _apply_recipe_to_target(target, recipe)
	_show_editor_report("GF Capability Recipe", report)


func _on_validate_capabilities_pressed(target: Node) -> void:
	_show_editor_report("GF Capability Validation", _build_editor_capability_report(target))


func _on_capability_active_toggled(active: bool, capability: Node) -> void:
	if not is_instance_valid(capability):
		return

	var old_active: bool = _read_editor_capability_active(capability)
	if old_active == active:
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_set_editor_capability_active(capability, active)
		return

	undo_redo.create_action("设置 GF 节点能力启用状态")
	undo_redo.add_do_method(self, "_set_editor_capability_active", capability, active)
	undo_redo.add_undo_method(self, "_set_editor_capability_active", capability, old_active)
	undo_redo.add_do_reference(capability)
	undo_redo.add_undo_reference(capability)
	undo_redo.commit_action()


func _on_capability_edit_pressed(capability: Node) -> void:
	if is_instance_valid(capability):
		EditorInterface.inspect_object(capability)


func _on_capability_remove_pressed(target: Node, capability: Node) -> void:
	_remove_capability_node(target, capability)
