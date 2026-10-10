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

## 选择器与预览准入、初值共用有限目录，不枚举场景或递归对象。
## [br]
## @api private
const _RECORDS_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_property_records.gd")

## 连续提交复用既有有界纯值签名，避免共享步骤原位改写后误保留旧字段。
## [br]
## @api private
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")


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

## 属性目录的显式项目适配器 ID；空名使用当前原生样机目录。
## [br]
## @api private
var _property_adapter_id: StringName = &""

## 本控件观察的原生历史弱引用；切换历史或离树时断开版本信号，不延长历史生命。
## [br]
## @api private
var _undo_history: WeakRef = null

## 上次拥有连续合并资格的资源弱引用及属性；资格不跨绑定或控件共享。
## [br]
## @api private
var _undo_target: WeakRef = null

## 上次拥有连续合并资格的属性名。
## [br]
## @api private
var _undo_property: StringName = &""

## 原生历史 ID，仅用于检查当前资源仍由同一历史路由；不出现在用户动作名称中。
## [br]
## @api private
var _undo_history_id: int = -1

## 观察每次 version_changed 的单调代次；原生 merge、Undo/Redo 与新分支可能复用版本数值。
## [br]
## @api private
var _undo_epoch: int = 0

## 最近一次确认由本控件独占提交的历史事件代次和实际版本。
## [br]
## @api private
var _undo_owned_epoch: int = -1

## 最近一次确认由本控件独占提交的实际原生版本。
## [br]
## @api private
var _undo_version: int = -1

## 最近一次确认由本控件独占提交的表单代次。
## [br]
## @api private
var _undo_generation: int = -1

## 仅同一控件和绑定、无其他历史事件的连续输入允许原生 MERGE_ENDS。
## [br]
## @api private
var _undo_can_merge: bool = false

## 一次已确认连续提交引起的待处理 Inspector 刷新可保留当前字段控件。
## [br]
## @api private
var _keep_owned_controls: bool = false

## 最近一次已交付字段及经过验证的预设来源纯值，不保存资源引用。
## [br]
## @api private
var _undo_payload: Array = []


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
	var _registry_connected: int = GFTweenPreviewRegistry.get_shared().changed.connect(_on_property_registry_changed, CONNECT_DEFERRED)


# --- Godot 回调方法 ---

## 作废旧控件代次并重新读取步骤引用到独立外层数组；仅首次推断样机种类。
## 非步骤值不进入本地数组，因此后续值相等校验也会阻止用不完整草稿覆盖来源。
## [br]
## @api private
func _update_property() -> void:
	var target: Object = get_edited_object()
	if _keep_owned_controls and _owns_native_merge(target) and target.get(get_edited_property()) == _steps:
		_keep_owned_controls = false
		return
	_undo_can_merge = false
	_keep_owned_controls = false
	_generation += 1
	_steps.clear()
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
	_undo_can_merge = false
	_keep_owned_controls = false
	_read_only = read_only_enabled
	_generation += 1
	_rebuild()


## 撤销全部待处理编辑资格并释放本地步骤引用；不清空配置资源中的步骤数组。
## [br]
## @api private
func _exit_tree() -> void:
	_observe_native_history(null, -1)
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
	_add_property_picker(current)
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


## 构造显式目录与有限搜索选项；原始 property_name 字段继续保留不支持的合法运行时路径。
## [br]
## @api private
func _add_property_picker(step: GFTweenActionStep) -> void:
	var source: OptionButton = OptionButton.new()
	source.name = "PropertySource"
	source.add_item("当前原生样机属性")
	source.set_item_metadata(0, &"")
	for descriptor: Dictionary in GFTweenPreviewRegistry.get_shared().get_descriptors():
		var descriptor_label: String = descriptor["label"]
		var id: String = descriptor["id"]
		source.add_item("数值 · " + descriptor_label)
		source.set_item_metadata(source.item_count - 1, StringName(id))
		if StringName(id) == _property_adapter_id:
			source.select(source.item_count - 1)
	source.disabled = _read_only
	_root.add_child(source)
	var _source_connected: int = source.item_selected.connect(_on_property_source_selected.bind(source, _generation))
	var search: LineEdit = LineEdit.new()
	search.name = "PropertySearch"
	search.placeholder_text = "搜索可预览属性（保留上方手动路径）"
	search.max_length = 128
	search.editable = not _read_only
	_root.add_child(search)
	var choices: OptionButton = OptionButton.new()
	choices.name = "PropertyChoices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.disabled = _read_only
	_root.add_child(choices)
	_refresh_property_choices("", choices)
	var _search_connected: int = search.text_changed.connect(_on_property_search_changed.bind(search, choices, _generation))
	var _choice_connected: int = choices.item_selected.connect(_on_property_choice_selected.bind(choices, _generation))
	_add_label(_root, "", "PropertySupport")
	_refresh_property_support(step)


## 手动路径连续编辑后也立即刷新目录支持说明，不改变来源字段或搜索结果。
## [br]
## @api private
func _refresh_property_support(step: GFTweenActionStep) -> void:
	var support_node: Node = _root.find_child("PropertySupport", true, false)
	if not support_node is Label:
		return
	var supported: bool = false
	for record: Dictionary in _property_records(""):
		if record["name"] == String(step.property_name):
			supported = true
			break
	var support: Label = support_node
	support.text = "当前路径在此有限目录中。" if supported else "当前路径不在此预览目录中；保留原值，可继续手动编辑并绑定真实运行时目标。"


## 从已声明的原生或适配器记录搜索，绝不获取真实场景属性。
## [br]
## @api private
func _property_records(query: String) -> Array[Dictionary]:
	if _property_adapter_id != &"":
		return GFTweenPreviewRegistry.get_shared().get_property_records(_property_adapter_id, query)
	return _RECORDS_SCRIPT.search(_RECORDS_SCRIPT.get_native_records(_kind), query)


## 替换选项快照；metadata 仅持有独立纯值记录，不持有目标或来源资源。
## [br]
## @api private
func _refresh_property_choices(query: String, choices: OptionButton) -> void:
	choices.clear()
	var records: Array[Dictionary] = _property_records(query)
	choices.add_item("选择属性…" if not records.is_empty() else "无匹配属性")
	choices.set_item_disabled(0, true)
	for record: Dictionary in records:
		var property_name: String = record["name"]
		choices.add_item(property_name)
		choices.set_item_metadata(choices.item_count - 1, record)
	choices.select(0)


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
	if not _has_native_binding(get_edited_object()):
		return false
	# 外部替换 steps 后、Inspector 尚未刷新的间隙也不能提交旧草稿。
	return get_edited_object().get(get_edited_property()) == _steps


## 将独立步骤数组交给 Inspector；离散编辑不合并，连续输入仅合并本控件独占的同一绑定和历史。
## 嵌套原生属性提交保留共享引用及刷新操作；结束后通过弱引用重新取得仍有效的控件，再确认合并资格。
## [br]
## @api private
func _submit(next_steps: Array[GFTweenActionStep], changing: bool = false) -> void:
	var target: Object = get_edited_object()
	var property_name: StringName = get_edited_property()
	var undo_manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not is_instance_valid(target) or not _has_native_binding(target) or undo_manager == null or undo_manager.is_committing_action():
		return
	var history_id: int = undo_manager.get_object_history_id(target)
	var merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE
	var before_count: int = -1
	if changing and history_id == _undo_history_id and _owns_native_merge(target):
		merge_mode = UndoRedo.MERGE_ENDS
		var previous_history_value: Variant = _undo_history.get_ref()
		if previous_history_value is UndoRedo:
			var previous_history: UndoRedo = previous_history_value
			before_count = previous_history.get_history_count()
	_undo_can_merge = false
	_keep_owned_controls = false
	if changing:
		# 草稿外层数组仍独立；_update_property() 清理时不能清空资源数组。
		_steps = next_steps.duplicate()
		_refresh_field_feedback(_steps[_selected])
	else:
		_generation += 1
	# 外层动作界定当前提交；Inspector 作为嵌套动作添加完整原生属性及刷新操作。
	undo_manager.create_action("修改 GF Tween 步骤", merge_mode, target)
	var history: UndoRedo = undo_manager.get_history_undo_redo(history_id)
	_observe_native_history(history, history_id)
	var epoch: int = _undo_epoch
	var generation: int = _generation
	var before_version: int = history.get_version()
	var editor_reference: WeakRef = weakref(self)
	emit_changed(property_name, next_steps, &"", changing)
	undo_manager.commit_action()
	# 提交可能同步释放、换绑或重建控件；不通过失效 self 继续访问草稿。
	var editor_value: Variant = editor_reference.get_ref()
	if editor_value is EditorProperty:
		var editor: EditorProperty = editor_value
		editor.call(&"_confirm_owned_native_commit", target, property_name, history, epoch, generation, before_version, before_count, changing)


## 检查连续合并资格的完整绑定与历史事件代次；版本相同本身不代表同一写入者。
## [br]
## @api private
func _owns_native_merge(target: Object) -> bool:
	if not _undo_can_merge or _read_only or not is_inside_tree() or _undo_generation != _generation:
		return false
	if not is_instance_valid(target) or not _has_native_binding(target) or _undo_target == null or _undo_target.get_ref() != target or _undo_property != get_edited_property():
		return false
	var history_value: Variant = _undo_history.get_ref() if _undo_history != null else null
	if not (history_value is UndoRedo):
		return false
	var history: UndoRedo = history_value
	return _undo_owned_epoch == _undo_epoch and history.get_version() == _undo_version and not _undo_payload.is_empty() and _capture_native_merge_payload(target) == _undo_payload


## 只观察当前历史；断连或换历史时撤销全部连续资格，避免历史 ID 或版本重用产生 ABA。
## [br]
## @api private
func _observe_native_history(history: UndoRedo, history_id: int) -> void:
	var old_value: Variant = _undo_history.get_ref() if _undo_history != null else null
	if old_value == history and _undo_history_id == history_id:
		return
	if old_value is UndoRedo:
		var old_history: UndoRedo = old_value
		if old_history.version_changed.is_connected(_on_native_history_version_changed):
			old_history.version_changed.disconnect(_on_native_history_version_changed)
	_undo_history = weakref(history) if history != null else null
	_undo_history_id = history_id
	_undo_target = null
	_undo_payload.clear()
	_undo_epoch += 1
	_undo_can_merge = false
	_keep_owned_controls = false
	if history != null:
		var _connected: int = history.version_changed.connect(_on_native_history_version_changed)


## 只有一次原生版本脉冲、预期实际版本和完整弱绑定仍有效的连续提交可获得下一次合并资格。
## [br]
## @api private
func _confirm_owned_native_commit(
	target: Object, property_name: StringName, history: UndoRedo, epoch: int,
	generation: int, before_version: int, before_count: int, changing: bool
) -> void:
	if not changing or not is_inside_tree() or _read_only or _generation != generation or _undo_epoch != epoch + 1:
		return
	if not is_instance_valid(target) or not _has_native_binding(target) or get_edited_object() != target or get_edited_property() != property_name:
		return
	if _undo_history == null or _undo_history.get_ref() != history or target.get(property_name) != _steps:
		return
	# 原生合并保持版本，800ms 窗口过期则建立新动作；只用公开计数验证实际发生的结果。
	var expected_version: int = before_version + 1
	if before_count >= 0:
		var actual_count: int = history.get_history_count()
		if actual_count == before_count:
			expected_version = before_version
		elif actual_count != before_count + 1:
			return
	if history.get_version() != expected_version:
		return
	var payload: Array = _capture_native_merge_payload(target)
	if payload.is_empty():
		return
	_undo_target = weakref(target)
	_undo_property = property_name
	_undo_version = expected_version
	_undo_owned_epoch = _undo_epoch
	_undo_generation = generation
	_undo_payload = payload
	_undo_can_merge = true
	_keep_owned_controls = true


## 捕获有界字段及恢复 UI 所需来源；拒绝签名中的任何 String 标记，不能把不支持值视为相同负载。
## [br]
## @api private
func _capture_native_merge_payload(target: Object) -> Array:
	if not (target is Resource):
		return []
	var config: Resource = target
	var payload: Array = _SNAPSHOT_SCRIPT.capture(config)
	var pending: Array[Array] = [payload]
	while not pending.is_empty():
		var values: Array = pending.pop_back()
		for value: Variant in values:
			if value is String:
				return []
			if value is Array:
				pending.append(value)
	var provenance: Array[Dictionary] = []
	for step: GFTweenActionStep in _steps:
		provenance.append(_PRESETS_SCRIPT.get_provenance(step))
	payload.append(provenance)
	return payload


## emit_changed 由最近的原生 Inspector 写入；手工只重绑 EditorProperty 时不能误写其仍在编辑的另一资源。
## [br]
## @api private
func _has_native_binding(target: Object) -> bool:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is EditorInspector:
			var inspector: EditorInspector = ancestor
			return inspector.get_edited_object() == target
		ancestor = ancestor.get_parent()
	return false


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
	_refresh_property_support(step)
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

## 每个原生历史事件都撤权，包含版本值不变的合并以及 Undo/Redo 后的版本 ABA。
## [br]
## @api private
func _on_native_history_version_changed() -> void:
	_undo_epoch += 1
	_undo_can_merge = false
	_keep_owned_controls = false


## 目录变化作废旧控件代次；失效 ID 保留为空搜索，要求宿主明确重新选择。
## [br]
## @api private
func _on_property_registry_changed() -> void:
	if is_inside_tree():
		_generation += 1
		_rebuild()


## 显式切换有限属性目录，只更换工具 UI，不改配置字段。
## [br]
## @api private
func _on_property_source_selected(index: int, source: OptionButton, generation: int) -> void:
	if not _can_edit(generation) or not is_instance_valid(source) or source.is_queued_for_deletion():
		return
	var value: Variant = source.get_item_metadata(index)
	if value is StringName:
		_property_adapter_id = value
		_generation += 1
		_rebuild()


## 搜索输入必须仍属于当前表单代次，退役控件不能覆盖新目录。
## [br]
## @api private
func _on_property_search_changed(query: String, search: LineEdit, choices: OptionButton, generation: int) -> void:
	if generation != _generation or not is_instance_valid(search) or not is_instance_valid(choices) or search.get_parent() != _root or choices.get_parent() != _root:
		return
	_refresh_property_choices(query, choices)


## 选择声明属性沿用独立步骤复制与 Inspector Undo；必要时同步目标值类型。
## [br]
## @api private
func _on_property_choice_selected(index: int, choices: OptionButton, generation: int) -> void:
	if index < 1 or not _can_edit(generation) or not is_instance_valid(choices) or choices.get_parent() != _root:
		return
	var value: Variant = choices.get_item_metadata(index)
	if not (value is Dictionary):
		return
	var record: Dictionary = value
	var current_records: Array[Dictionary] = _property_records("")
	if generation != _generation or not current_records.has(record):
		return
	var step: GFTweenActionStep = _PRESETS_SCRIPT.copy_step(_steps[_selected])
	if step == null:
		return
	var property_name: String = record["name"]
	step.property_name = NodePath(property_name)
	if typeof(step.target_value) != record["type"]:
		step.target_value = record["initial"]
	_replace_selected(step)

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
