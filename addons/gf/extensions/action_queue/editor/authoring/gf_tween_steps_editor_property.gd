@tool

# 原生 steps 属性编辑器；每次操作复制数组和被编辑步骤，交由 Inspector 管理 Undo。
extends EditorProperty


# --- 常量 ---

## 预设来源验证、独立步骤复制和恢复共用的编辑器入口。
## [br]
## @api private
const _PRESETS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/presets/gf_tween_authoring_presets.gd")

## 原生步骤的精确脚本身份；自定义子脚本保留原值，仅允许转到原生 Inspector 编辑。
## [br]
## @api private
const _STEP_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd")

## 根据步骤属性元数据构造类型化输入控件，不直接修改步骤资源。
## [br]
## @api private
const _VALUE_FIELD_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_value_field.gd")

## 表单允许展示和扩充的步骤数上限；超限资源保留原值并引导使用原生编辑。
## [br]
## @api private
const _MAX_STEPS: int = 128


# --- 私有变量 ---

## Inspector 底部编辑区的子树根；重建时移除旧控件并排队释放。
## [br]
## @api private
var _root: VBoxContainer = null

## 独立外层数组中的当前资源步骤引用；编辑前复制被修改步骤，刷新或离树只清空本地数组。
## [br]
## @api private
var _steps: Array[GFTweenActionStep] = []

## 当前编辑资格的代次；刷新、结构修改、切换视图或离树后令旧控件及确认回调失效。
## [br]
## @api private
var _generation: int = 0

## 预设和新步骤采用的样机种类，0/1/2 分别为 2D、UI、3D，不改配置根字段。
## [br]
## @api private
var _kind: int = 0

## 仅首次从当前步骤的原生 Vector3 目标值推断样机，之后保留用户选择。
## [br]
## @api private
var _kind_initialized: bool = false

## 原生 Inspector 的只读状态；控件禁用之外，提交入口还会重新检查它。
## [br]
## @api private
var _read_only: bool = false

## 控制延迟、相对量、并行和标记等字段的显示，不修改步骤数据。
## [br]
## @api private
var _advanced: bool = false

## 当前本地步骤索引；属性刷新时收窄到有效范围，空数组不允许进入步骤编辑路径。
## [br]
## @api private
var _selected: int = 0

## 作为本属性编辑器子节点持有的预设替换确认框，确认时仍须重新验证编辑资格。
## [br]
## @api private
var _confirmation: ConfirmationDialog = null

## 待确认的预设 ID；不代表已获写入资格，离树或接受有效确认后清空。
## [br]
## @api private
var _pending_preset: String = ""

## 打开确认框时捕获的编辑代次；属性或选择改变后拒绝原确认结果。
## [br]
## @api private
var _pending_generation: int = -1


# --- Godot 生命周期方法 ---

## 将表单根和确认框归属本属性编辑器，确认信号统一经过待确认代次检查。
## [br]
## @api private
func _init() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)
	set_bottom_editor(_root)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "应用 Tween 预设"
	add_child(_confirmation)
	var _connected: int = _confirmation.confirmed.connect(_on_preset_confirmed)


# --- Godot 回调方法 ---

## 作废旧控件代次并重新读取步骤引用到独立外层数组；仅首次推断样机种类。
## 非步骤值不进入本地数组，因此后续值相等校验也会阻止用不完整草稿覆盖来源。
## [br]
## @api private
func _update_property() -> void:
	_generation += 1
	_steps.clear()
	var target: Object = get_edited_object()
	if not is_instance_valid(target):
		_rebuild()
		return
	var value: Variant = target.get(get_edited_property())
	if value is Array:
		var values: Array = value
		for step_value: Variant in values:
			if step_value == null:
				_steps.append(null)
			elif step_value is GFTweenActionStep:
				_steps.append(step_value)
	if not _kind_initialized:
		_kind_initialized = true
		for step: GFTweenActionStep in _steps.slice(0, _MAX_STEPS):
			if step != null and step.get_script() == _STEP_SCRIPT and step.target_value is Vector3:
				_kind = 2
				break
	_selected = clampi(_selected, 0, maxi(0, _steps.size() - 1))
	_rebuild()


## 同步 Inspector 只读状态并作废旧代次，使此前控件和确认框不能继续提交。
## [br]
## @api private
func _set_read_only(read_only_enabled: bool) -> void:
	_read_only = read_only_enabled
	_generation += 1
	_rebuild()


## 撤销全部待处理编辑资格并释放本地步骤引用；不清空配置资源中的步骤数组。
## [br]
## @api private
func _exit_tree() -> void:
	_generation += 1
	_pending_preset = ""
	_steps.clear()


# --- 私有/辅助方法 ---

## 按当前草稿重建工具栏和选中步骤表单，旧子控件先离树再排队释放。
## 写操作回调绑定当前代次；空、超限或非原生步骤只呈现对应提示与允许的操作。
## [br]
## @api private
func _rebuild() -> void:
	if _root == null:
		return
	for child: Node in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	var toolbar: HBoxContainer = HBoxContainer.new()
	_root.add_child(toolbar)
	var kind_picker: OptionButton = OptionButton.new()
	for kind_label: String in ["2D", "UI", "3D"]:
		kind_picker.add_item(kind_label)
	kind_picker.select(_kind)
	kind_picker.disabled = _read_only
	toolbar.add_child(kind_picker)
	var _kind_connected: int = kind_picker.item_selected.connect(_on_kind_selected)
	var presets: OptionButton = OptionButton.new()
	presets.add_item("选择预设…")
	for record: Dictionary in _PRESETS_SCRIPT.get_records(_kind):
		var preset_label: String = record["label"]
		presets.add_item(preset_label)
		presets.set_item_metadata(presets.item_count - 1, record["id"])
	presets.disabled = _read_only
	toolbar.add_child(presets)
	var _preset_connected: int = presets.item_selected.connect(_on_preset_selected.bind(presets, _generation))
	_add_button(toolbar, "添加", _on_add_step.bind(_generation), _steps.size() >= _MAX_STEPS)
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "高级步骤字段"
	toggle.button_pressed = _advanced
	_root.add_child(toggle)
	var _advanced_connected: int = toggle.toggled.connect(_on_advanced_toggled)
	if _steps.is_empty():
		_add_label(_root, "从预设开始，或添加一个步骤。循环和时间策略沿用下方原生配置字段。")
		return
	if _steps.size() > _MAX_STEPS:
		_add_label(_root, "此创作界面最多编辑 128 个步骤；请使用原生资源或代码编辑。")
		return
	var picker: OptionButton = OptionButton.new()
	picker.name = "StepPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index: int in range(_steps.size()):
		var step: GFTweenActionStep = _steps[index]
		var step_label: String = "%d · %s" % [index + 1, "空步骤" if step == null else "自定义步骤"]
		if step != null and step.get_script() == _STEP_SCRIPT:
			step_label = "%d · %s · %s · %.2fs" % [index + 1, String(step.property_name), "并行" if step.parallel else "串行", step.duration]
		picker.add_item(step_label)
	picker.select(_selected)
	_root.add_child(picker)
	var _selection_connected: int = picker.item_selected.connect(_on_step_selected)
	var current: GFTweenActionStep = _steps[_selected]
	var unsupported_step: bool = current == null or current.get_script() != _STEP_SCRIPT
	var actions: HBoxContainer = HBoxContainer.new()
	_root.add_child(actions)
	_add_button(actions, "上移", _on_move.bind(-1, _generation), _selected == 0)
	_add_button(actions, "下移", _on_move.bind(1, _generation), _selected == _steps.size() - 1)
	_add_button(actions, "复制", _on_duplicate.bind(_generation), _steps.size() >= _MAX_STEPS or unsupported_step, "只支持复制原生 GFTweenActionStep，且步骤数不能超过 128。")
	_add_button(actions, "删除", _on_remove.bind(_generation))
	if unsupported_step:
		_add_label(_root, "该步骤为空或使用自定义脚本，无法在此复制；保留原值，可删除或在原生 Inspector 中编辑。原生编辑会影响共享此步骤的其他资源。")
		if current != null:
			_add_button(_root, "原生编辑共享步骤", _on_inspect.bind(_generation))
		return
	var provenance: Dictionary = _PRESETS_SCRIPT.get_provenance(current)
	if not provenance.is_empty():
		var overrides: Array[StringName] = _PRESETS_SCRIPT.get_overrides(current)
		_add_label(_root, "%s v%d · %s" % [provenance["preset_id"], provenance["preset_version"], "预设值" if overrides.is_empty() else "覆盖：" + ", ".join(overrides)], "PresetSource")
		_add_button(_root, "恢复此步骤受管字段", _on_restore.bind(&"", _generation), overrides.is_empty(), "", "RestoreAll")
	elif current.has_meta(&"_gf_tween_preset"):
		_add_label(_root, "预设来源版本未知或记录无效；可继续编辑，恢复预设不可用。")
	var fields: Array[StringName] = [&"property_name", &"target_value", &"duration", &"transition_type", &"ease_type"]
	if _advanced:
		fields.append_array([&"delay", &"as_relative", &"parallel", &"marker_id"])
	for field: StringName in fields:
		_add_field(current, field)
	if _advanced:
		_add_label(_root, "原生入口直接编辑当前步骤和 Curve，会影响共享引用。步骤表单的“复制”会生成独立步骤与曲线。修改曲线后重新预览。")
		_add_button(_root, "原生编辑共享步骤 / Curve", _on_inspect.bind(_generation))


## 从原生步骤元数据构造一个表单字段；target_value 使用当前值的实际类型，提交绑定当前代次。
## 有有效预设来源时附加单字段恢复按钮，控件交由表单子树释放。
## [br]
## @api private
func _add_field(step: GFTweenActionStep, field_name: StringName) -> void:
	var info: Dictionary = {}
	for property: Dictionary in step.get_property_list():
		if property.get("name") == String(field_name):
			info = property.duplicate()
			break
	var value: Variant = step.get(field_name)
	if field_name == &"target_value":
		info["type"] = typeof(value) if value != null else TYPE_FLOAT
		info["hint"] = PROPERTY_HINT_NONE
		info["hint_string"] = ""
		if value == null:
			value = 0.0
	var row: HBoxContainer = HBoxContainer.new()
	_root.add_child(row)
	var field: GFEditorValueField = _VALUE_FIELD_SCRIPT.new()
	field.name = "Field_%s" % field_name
	field.configure(info, value)
	field.set_editable(not _read_only)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var _connected: int = field.value_changed.connect(_on_field_changed.bind(field_name, _generation))
	if not _PRESETS_SCRIPT.get_provenance(step).is_empty():
		_add_button(row, "恢复", _on_restore.bind(field_name, _generation), not _PRESETS_SCRIPT.get_overrides(step).has(field_name), "", "Restore_%s" % field_name)


## 将按钮归属指定父节点并连接回调；局部禁用条件与编辑器只读状态共同决定可用性。
## [br]
## @api private
func _add_button(parent: Node, text: String, callback: Callable, disabled: bool = false, tooltip: String = "", node_name: String = "") -> void:
	var button: Button = Button.new()
	if not node_name.is_empty():
		button.name = node_name
	button.text = text
	button.disabled = disabled or _read_only
	button.tooltip_text = tooltip
	parent.add_child(button)
	var _connected: int = button.pressed.connect(callback)


## 在指定父节点下创建自动换行提示，可指定稳定名称供后续反馈刷新查找。
## [br]
## @api private
func _add_label(parent: Node, text: String, node_name: String = "") -> void:
	var message_label: Label = Label.new()
	if not node_name.is_empty():
		message_label.name = node_name
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(message_label)


## 同时检查代次、只读、树内状态、编辑对象存活及其当前 steps 值，拒绝外部替换后的旧草稿。
## 数组采用值相等比较，不承诺数组对象身份相同；调用方须在每次写入前检查。
## [br]
## @api private
func _can_edit(generation: int) -> bool:
	if _read_only or generation != _generation or not is_inside_tree() or not is_instance_valid(get_edited_object()):
		return false
	# 外部替换 steps 后、Inspector 尚未刷新的间隙也不能提交旧草稿。
	return get_edited_object().get(get_edited_property()) == _steps


## 将独立步骤数组交给 Inspector 的 Undo 管理；连续输入保留控件并复制本地数组，结构提交先递增代次。
## emit_changed 可同步重建属性编辑器，因此发送后不再写本次草稿或来源资源。
## [br]
## @api private
func _submit(next_steps: Array[GFTweenActionStep], changing: bool = false) -> void:
	if changing:
		# 草稿外层数组仍独立；_update_property() 清理时不能清空资源数组。
		_steps = next_steps.duplicate()
		_refresh_field_feedback(_steps[_selected])
	else:
		_generation += 1
	# 连续字段输入保留原生控件和焦点；结构操作仍触发 Inspector 刷新。
	emit_changed(get_edited_property(), next_steps, &"", changing)
	# Inspector 可同步重建控件；提交后不再写本次草稿或资源。


## 在复制的外层数组中替换当前步骤并提交；null 不产生编辑，调用方负责先验证索引与编辑资格。
## [br]
## @api private
func _replace_selected(step: GFTweenActionStep, changing: bool = false) -> void:
	if step == null:
		return
	var next_steps: Array[GFTweenActionStep] = _steps.duplicate()
	next_steps[_selected] = step
	_submit(next_steps, changing)


## 连续输入期间原地更新步骤摘要、预设覆盖提示和恢复按钮，避免重建表单丢失焦点。
## 仅在目标值类型改变时重新配置对应输入字段，其余控件保持当前实例。
## [br]
## @api private
func _refresh_field_feedback(step: GFTweenActionStep) -> void:
	var picker_node: Node = _root.find_child("StepPicker", true, false)
	if picker_node is OptionButton:
		var picker: OptionButton = picker_node
		picker.set_item_text(_selected, "%d · %s · %s · %.2fs" % [_selected + 1, String(step.property_name), "并行" if step.parallel else "串行", step.duration])
	var provenance: Dictionary = _PRESETS_SCRIPT.get_provenance(step)
	var overrides: Array[StringName] = _PRESETS_SCRIPT.get_overrides(step)
	var status_node: Node = _root.find_child("PresetSource", true, false)
	if status_node is Label and not provenance.is_empty():
		var status_label: Label = status_node
		status_label.text = "%s v%d · %s" % [provenance["preset_id"], provenance["preset_version"], "预设值" if overrides.is_empty() else "覆盖：" + ", ".join(overrides)]
	var restore_all_node: Node = _root.find_child("RestoreAll", true, false)
	if restore_all_node is Button:
		var restore_all: Button = restore_all_node
		restore_all.disabled = _read_only or overrides.is_empty()
	for restore_node: Node in _root.find_children("Restore_*", "Button", true, false):
		if not restore_node is Button:
			continue
		var restore_button: Button = restore_node
		var field_name: StringName = String(restore_button.name).trim_prefix("Restore_")
		restore_button.disabled = _read_only or not overrides.has(field_name)
	var target_node: Node = _root.find_child("Field_target_value", true, false)
	if target_node is GFEditorValueField:
		var target_field: GFEditorValueField = target_node
		var info: Dictionary = target_field.get_property_info()
		var target_value: Variant = step.target_value if step.target_value != null else 0.0
		if info.get("type") != typeof(target_value):
			info["type"] = typeof(target_value)
			target_field.configure(info, target_value)
		elif target_field.get_value() != target_value:
			target_field.set_value(target_value)


# --- 信号处理函数 ---

## 切换预设采用的样机种类并作废旧代次回调，不重写已有步骤。
## [br]
## @api private
func _on_kind_selected(index: int) -> void:
	_kind = index
	_generation += 1
	_rebuild()


## 切换高级字段可见性并重建表单，使旧字段和待确认操作的代次失效。
## [br]
## @api private
func _on_advanced_toggled(enabled: bool) -> void:
	_advanced = enabled
	_generation += 1
	_rebuild()


## 切换当前步骤并递增代次，防止上一选择的字段或确认回调继续写入。
## [br]
## @api private
func _on_step_selected(index: int) -> void:
	_selected = index
	_generation += 1
	_rebuild()


## 验证控件代次后记录待确认的预设与代次，仅打开替换确认框，不修改步骤数组。
## [br]
## @api private
func _on_preset_selected(index: int, picker: OptionButton, generation: int) -> void:
	if index == 0 or not _can_edit(generation):
		return
	var value: Variant = picker.get_item_metadata(index)
	if not value is String:
		return
	_pending_preset = value
	_pending_generation = generation
	_confirmation.dialog_text = "将替换全部 %d 个步骤（含自定义 Curve）。循环和其他根配置字段保持当前值。此操作可撤销。" % _steps.size()
	_confirmation.popup_centered()


## 重新校验确认框捕获的编辑资格；有效时创建独立预设步骤并整体提交，空结果不修改资源。
## [br]
## @api private
func _on_preset_confirmed() -> void:
	if not _can_edit(_pending_generation):
		return
	var steps: Array[GFTweenActionStep] = _PRESETS_SCRIPT.create_steps(_pending_preset, _kind)
	_pending_preset = ""
	if not steps.is_empty():
		_selected = 0
		_submit(steps)


## 在仍可编辑且未达上限时追加独立原生步骤；默认目标按样机选 Vector2 或 Vector3。
## [br]
## @api private
func _on_add_step(generation: int) -> void:
	if not _can_edit(generation) or _steps.size() >= _MAX_STEPS:
		return
	var next_steps: Array[GFTweenActionStep] = _steps.duplicate()
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.target_value = Vector2.ZERO
	if _kind == 2:
		step.target_value = Vector3.ZERO
	next_steps.append(step)
	_selected = next_steps.size() - 1
	_submit(next_steps)


## 验证当前代次后从复制的数组删除选中项，由 Inspector 刷新重新收窄选中索引。
## [br]
## @api private
func _on_remove(generation: int) -> void:
	if not _can_edit(generation):
		return
	var next_steps: Array[GFTweenActionStep] = _steps.duplicate()
	next_steps.remove_at(_selected)
	_submit(next_steps)


## 将含独立曲线的原生步骤副本插到原项之后；超限、过期或复制不支持时保持原资源。
## [br]
## @api private
func _on_duplicate(generation: int) -> void:
	if not _can_edit(generation) or _steps.size() >= _MAX_STEPS:
		return
	var copied: GFTweenActionStep = _PRESETS_SCRIPT.copy_step(_steps[_selected])
	if copied == null:
		return
	var next_steps: Array[GFTweenActionStep] = _steps.duplicate()
	var _inserted: int = next_steps.insert(_selected + 1, copied)
	_selected += 1
	_submit(next_steps)


## 仅在目标索引有效时重排复制的外层数组；复用步骤引用，不原地修改共享步骤。
## [br]
## @api private
func _on_move(offset: int, generation: int) -> void:
	if not _can_edit(generation):
		return
	var destination: int = _selected + offset
	if destination < 0 or destination >= _steps.size():
		return
	var next_steps: Array[GFTweenActionStep] = _steps.duplicate()
	var moved: GFTweenActionStep = next_steps[_selected]
	next_steps.remove_at(_selected)
	var _inserted: int = next_steps.insert(destination, moved)
	_selected = destination
	_submit(next_steps)


## 在独立步骤副本上应用字段输入；属性路径改变时同步目标值形状，再以连续编辑方式提交。
## 此处只调整值类型，属性路径是否可预览仍由预览准入检查决定。
## [br]
## @api private
func _on_field_changed(value: Variant, field: StringName, generation: int) -> void:
	if not _can_edit(generation):
		return
	var step: GFTweenActionStep = _PRESETS_SCRIPT.copy_step(_steps[_selected])
	if step == null:
		return
	step.set(field, value)
	if field == &"property_name" and value is NodePath:
		var path: NodePath = value
		var properties: Dictionary = GFTweenPreviewPlan.get_properties(_kind)
		if properties.has(String(path)):
			var baseline: Variant = properties[String(path)]
			if typeof(step.target_value) != typeof(baseline):
				step.target_value = baseline
		elif path.get_name_count() == 1 and path.get_subname_count() == 1 and properties.has(String(path.get_name(0))):
			# 向量与颜色分量是标量；属性路径仍由预览准入逐项校验。
			step.target_value = 0.0
	_replace_selected(step, true)


## 仅在当前编辑资格有效时用独立恢复副本替换选中步骤；空字段表示恢复全部受管字段。
## [br]
## @api private
func _on_restore(field: StringName, generation: int) -> void:
	if _can_edit(generation):
		_replace_selected(_PRESETS_SCRIPT.restore_step(_steps[_selected], field))


## 将仍属于当前选择的共享步骤交给原生 Inspector；该入口不会先复制资源，编辑会影响其他引用者。
## [br]
## @api private
func _on_inspect(generation: int) -> void:
	if _can_edit(generation) and is_instance_valid(_steps[_selected]):
		EditorInterface.edit_resource(_steps[_selected])
