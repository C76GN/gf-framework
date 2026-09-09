@tool

## GFEditorMultiPropertyField: 编辑器中多个对象的单属性暂存输入。
##
## 显示一致、混合、缺失与不兼容状态。标量整值编辑，Vector2/3/4 及其整数类型按分量编辑。
## 输入不写对象；调用方将 prepare_changes 的结果交给 GFEditorPropertyBatchCommand。
## 目标在暂存期间使用弱引用，取消、重新配置和离树均丢弃草稿。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since unreleased
## [br]
## @layer kernel/editor
class_name GFEditorMultiPropertyField
extends VBoxContainer


# --- 信号 ---

## 草稿或选择状态变化后发出，不表示对象已写入。
## [br]
## @api public
## [br]
## @since unreleased
signal draft_changed()


# --- 常量 ---

const _PROPERTY_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_object_property_tools.gd")
const _VALUE_FIELD_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_value_field.gd")
const _VECTOR_COMPONENTS: Array[String] = ["x", "y", "z", "w"]
const _SUPPORTED_TYPES: Array[int] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I,
]
const _VECTOR_TYPES: Array[int] = [
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I,
]


# --- 私有变量 ---

var _targets: Array[WeakRef] = []
var _property: StringName = &""
var _property_info: Dictionary = {}
var _status: String = "empty"
var _components: Dictionary = {}
var _draft: Dictionary = {}
var _status_label: Label = null
var _updating: bool = false
var _ui_generation: int = 0
var _accepting_input: bool = true


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_reset_component_inputs()
	_accepting_input = true


func _exit_tree() -> void:
	_accepting_input = false
	_draft.clear()
	_reset_component_inputs()
	draft_changed.emit()


# --- 公共方法 ---

## 以去重后的目标重新建立选择，丢弃此前草稿；不保活目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param targets: 要共同编辑的对象；失效目标使整组不可编辑。
## [br]
## @param property: 直接属性名。
func configure(targets: Array[Object], property: StringName) -> void:
	_targets.clear()
	_property = property
	var seen: Dictionary = {}
	for target: Object in targets:
		if not is_instance_valid(target):
			_targets.append(null)
			continue
		var instance_id: int = target.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		_targets.append(weakref(target))
	cancel_edit()


## 取消草稿并重新读取仍然有效的选中对象，不写入任何属性。
## [br]
## @api public
## [br]
## @since unreleased
func cancel_edit() -> void:
	_draft.clear()
	_components.clear()
	var selection: Dictionary = _inspect_selection()
	_status = _string_field(selection, "status")
	_property_info = _dictionary_field(selection, "property_info")
	var values: Array = _array_field(selection, "values")
	if _status == "uniform" or _status == "mixed":
		var first_components: Array = _split_value(values[0])
		for index: int in range(first_components.size()):
			var component: String = "value" if first_components.size() == 1 else _VECTOR_COMPONENTS[index]
			var mixed: bool = false
			for value: Variant in values:
				var parts: Array = _split_value(value)
				if parts[index] != first_components[index]:
					mixed = true
			_components[component] = {"value": first_components[index], "mixed": mixed}
	_rebuild_controls()
	draft_changed.emit()


## 返回选择与暂存状态的独立副本；状态在配置、取消或准备提交时重新检查。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 选择摘要，不包含对象引用。
## [br]
## @schema return: Dictionary 包含 status（empty/invalid/missing/incompatible/readonly/unsupported/uniform/mixed）、property: StringName、target_count: int、dirty: bool、components: Dictionary；各分量包含 value: Variant 标量值、mixed: bool、edited: bool。
func get_snapshot() -> Dictionary:
	var components: Dictionary = _components.duplicate(true)
	for key: Variant in components:
		var entry: Dictionary = _dictionary_field(components, key)
		entry["edited"] = _draft.has(key)
		components[key] = entry
	return {
		"status": _status,
		"property": _property,
		"target_count": _targets.size(),
		"dirty": not _draft.is_empty(),
		"components": components,
	}


## 再次验证目标和属性声明，生成只包含已编辑分量的批量命令输入，不执行写入。
## 未编辑分量在执行时由命令读取当前值；任一失效、缺失或不兼容目标使整批失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 准备结果。返回 changes 的目标引用由调用方负责释放或移交给命令历史。
## [br]
## @schema return: Dictionary 包含 ok: bool、error: Error、status: String、changes: Array[Dictionary]；每项包含 target: Object、new_value: Variant，及 property_name: StringName 或 property_path: NodePath。
func prepare_changes() -> Dictionary:
	var selection: Dictionary = _inspect_selection()
	var status: String = _string_field(selection, "status")
	var info: Dictionary = _dictionary_field(selection, "property_info")
	if status not in ["uniform", "mixed"] or not _same_schema(info, _property_info):
		if status in ["uniform", "mixed"]:
			status = "incompatible"
		_status = status
		_rebuild_controls()
		draft_changed.emit()
		return {
			"ok": false, "error": ERR_INVALID_DATA, "status": status, "changes": [],
		}
	var changes: Array[Dictionary] = []
	for reference: WeakRef in _targets:
		var target_value: Variant = reference.get_ref()
		if not target_value is Object or not is_instance_valid(target_value):
			return {
				"ok": false, "error": ERR_INVALID_DATA, "status": "invalid", "changes": [],
			}
		var target: Object = target_value
		for component: String in _components:
			if not _draft.has(component):
				continue
			var change: Dictionary = {"target": target, "new_value": _draft[component]}
			if component == "value":
				change["property_name"] = _property
			else:
				change["property_path"] = NodePath(String(_property) + ":" + component)
			changes.append(change)
	return {"ok": true, "error": OK, "status": status, "changes": changes}


# --- 私有/辅助方法 ---

func _inspect_selection() -> Dictionary:
	var result: Dictionary = {"status": "empty", "property_info": {}, "values": []}
	if _targets.is_empty() or _property == &"":
		return result
	var values: Array = []
	var first_info: Dictionary = {}
	var state: String = "uniform"
	for reference: WeakRef in _targets:
		if reference == null:
			result["status"] = "invalid"
			return result
		var value: Variant = reference.get_ref()
		if not value is Object or not is_instance_valid(value):
			result["status"] = "invalid"
			return result
		var target: Object = value
		var info: Dictionary = _PROPERTY_TOOLS_SCRIPT.get_property_info(target, _property)
		if info.is_empty():
			result["status"] = "missing"
			return result
		if not _PROPERTY_TOOLS_SCRIPT.is_property_writable(info):
			result["status"] = "readonly"
			return result
		if first_info.is_empty():
			first_info = info
		elif not _same_schema(first_info, info):
			result["status"] = "incompatible"
			return result
		var property_value: Variant = target.get(_property)
		if typeof(property_value) != _int_field(info, "type"):
			result["status"] = "incompatible"
			return result
		if not values.is_empty() and values[0] != property_value:
			state = "mixed"
		values.append(property_value)
	var value_type: int = _int_field(first_info, "type")
	var indexed_name_unsupported: bool = String(_property).contains(":") or String(_property).contains("/")
	if value_type not in _SUPPORTED_TYPES or (value_type in _VECTOR_TYPES and indexed_name_unsupported):
		state = "unsupported"
	return {"status": state, "property_info": first_info, "values": values}


func _same_schema(first: Dictionary, second: Dictionary) -> bool:
	for key: String in ["type", "hint", "hint_string"]:
		if first.get(key) != second.get(key):
			return false
	return not first.is_empty() and not second.is_empty()


func _rebuild_controls() -> void:
	_updating = true
	_ui_generation += 1
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_status_label = Label.new()
	_status_label.name = "MultiPropertyStatus"
	_status_label.text = _status_text()
	add_child(_status_label)
	if _status in ["uniform", "mixed"]:
		for component: String in _components:
			var entry: Dictionary = _dictionary_field(_components, component)
			var row: HBoxContainer = HBoxContainer.new()
			var enabled: CheckBox = CheckBox.new()
			enabled.name = "Edit_" + component
			enabled.text = "修改"
			enabled.button_pressed = _draft.has(component)
			row.add_child(enabled)
			var field: GFEditorValueField = _VALUE_FIELD_SCRIPT.new()
			field.name = "Component_" + component
			var info: Dictionary = _property_info.duplicate(true)
			var component_value: Variant = entry.get("value")
			if component != "value":
				info = {"name": component, "type": typeof(component_value)}
			field.configure(info, _draft.get(component, component_value))
			field.set_label(component if component != "value" else String(_property))
			row.add_child(field)
			var label: Label = Label.new()
			label.text = "混合" if entry.get("mixed") == true else "一致"
			row.add_child(label)
			add_child(row)
			var _value_connection: int = field.value_changed.connect(
				_on_component_value_changed.bind(component, enabled, _ui_generation)
			)
			var _toggle_connection: int = enabled.toggled.connect(
				_on_component_toggled.bind(component, field, _ui_generation)
			)
	_updating = false


func _reset_component_inputs() -> void:
	_updating = true
	for component: String in _components:
		var entry: Dictionary = _dictionary_field(_components, component)
		var field_node: Node = find_child("Component_" + component, true, false)
		if field_node is GFEditorValueField:
			var field: GFEditorValueField = field_node
			field.set_value(entry.get("value"))
		var checkbox_node: Node = find_child("Edit_" + component, true, false)
		if checkbox_node is CheckBox:
			var checkbox: CheckBox = checkbox_node
			checkbox.set_pressed_no_signal(false)
	_updating = false


func _status_text() -> String:
	match _status:
		"empty": return "请选择资源和属性。"
		"invalid": return "选择包含失效目标，无法编辑。"
		"missing": return "部分目标缺失此属性，无法编辑。"
		"incompatible": return "属性类型或编辑提示不兼容，无法编辑。"
		"readonly": return "属性只读，无法编辑。"
		"unsupported": return "此类型仅展示；多选编辑支持标量和向量。"
		"mixed": return "混合值 · 仅应用勾选的值或分量。"
		_: return "一致值 · 仅应用勾选的值或分量。"


func _split_value(value: Variant) -> Array:
	if value is Vector2:
		var vector: Vector2 = value
		return [vector.x, vector.y]
	if value is Vector2i:
		var vector: Vector2i = value
		return [vector.x, vector.y]
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	if value is Vector3i:
		var vector: Vector3i = value
		return [vector.x, vector.y, vector.z]
	if value is Vector4:
		var vector: Vector4 = value
		return [vector.x, vector.y, vector.z, vector.w]
	if value is Vector4i:
		var vector: Vector4i = value
		return [vector.x, vector.y, vector.z, vector.w]
	return [value]


func _dictionary_field(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _array_field(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key)
	if value is Array:
		var array: Array = value
		return array
	return []


func _string_field(source: Dictionary, key: String) -> String:
	var value: Variant = source.get(key)
	if value is String:
		var text: String = value
		return text
	return ""


func _int_field(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key)
	if value is int:
		var number: int = value
		return number
	return -1


# --- 信号处理函数 ---

func _on_component_value_changed(
	value: Variant, component: String, enabled: CheckBox, generation: int
) -> void:
	if _updating or not _accepting_input or generation != _ui_generation:
		return
	_draft[component] = value
	enabled.set_pressed_no_signal(true)
	draft_changed.emit()


func _on_component_toggled(
	enabled: bool, component: String, field: GFEditorValueField, generation: int
) -> void:
	if _updating or not _accepting_input or generation != _ui_generation:
		return
	if enabled:
		_draft[component] = field.get_value()
	else:
		var _erased: bool = _draft.erase(component)
	draft_changed.emit()
