@tool

# 编辑独立工作草稿中的 Schema；所有控件共用标准 Resource 字段，不另建规则模型。
extends VBoxContainer


# --- 信号 ---

## 草稿中的结构或字段已改变。
## [br]
## @api framework_internal
signal changed()


# --- 私有变量 ---

var _profile: GFConfigPipelineProfile
var _source: GFConfigPipelineTableSource
var _kind: OptionButton
var _list: ItemList
var _form: VBoxContainer
var _status: Label


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "SchemaEditor"
	var toolbar: HBoxContainer = HBoxContainer.new()
	add_child(toolbar)
	_kind = OptionButton.new()
	_kind.name = "SchemaSection"
	for label: String in ["Fields / 字段", "Indexes / 索引", "References / 引用"]:
		_kind.add_item(label)
	toolbar.add_child(_kind)
	var _kind_connection: int = _kind.item_selected.connect(func(_index: int) -> void: _refresh_list())
	_button(toolbar, "CreateSchema", "创建空 Schema", _create_schema)
	_button(toolbar, "AddDefinition", "新增", _add_definition)
	_button(toolbar, "RemoveDefinition", "删除选中", _remove_definition)
	_status = Label.new()
	add_child(_status)
	_list = ItemList.new()
	_list.name = "Definitions"
	_list.custom_minimum_size.y = 100
	add_child(_list)
	var _list_connection: int = _list.item_selected.connect(_show_definition)
	_form = VBoxContainer.new()
	add_child(_form)


# --- 框架内部方法 ---

## 绑定独立草稿的当前表；不会读取或保存来源文件。
## [br]
## @api framework_internal
## [br]
## @param profile: 草稿 Profile。
## [br]
## @param source: 当前来源。
func configure(profile: GFConfigPipelineProfile, source: GFConfigPipelineTableSource) -> void:
	_profile = profile
	_source = source
	_refresh_list()


# --- 私有/辅助方法 ---

func _can_edit(control: Node) -> bool:
	return _source != null and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and is_ancestor_of(control)


func _refresh_list() -> void:
	_list.clear()
	_clear_form()
	var definitions: Array = _definitions()
	for index: int in range(definitions.size()):
		var resource: Resource = definitions[index]
		var property_name: String = ["field_name", "index_id", "reference_id"][_kind.selected]
		var _list_index: int = _list.add_item("%d. %s" % [index + 1, str(resource.get(property_name)) if resource != null else "空定义，请删除或替换"])
	_status.text = "没有显式 Schema。先校验并复制推导结果，或创建空 Schema。" if _source == null or _source.schema == null else "显式 Schema 优先于推导；更改仅写入工作草稿。"
	if _source != null and _source.schema != null:
		for property_name: String in ["id_field", "require_unique_id", "allow_extra_fields", "coerce_values", "fail_on_coerce_error"]:
			_add_property(_source.schema, property_name)


func _definitions() -> Array:
	if _source == null or _source.schema == null:
		return []
	match _kind.selected:
		0:
			return _source.schema.columns
		1:
			return _source.schema.indexes
		_:
			return _source.schema.references


func _show_definition(index: int) -> void:
	_clear_form()
	var definitions: Array = _definitions()
	if index < 0 or index >= definitions.size():
		return
	var resource: Resource = definitions[index]
	if resource == null:
		_status.text = "当前声明为空，可删除后重新创建。"
		return
	if resource is GFConfigTableColumn:
		for property_name: String in ["field_name", "value_type", "required", "allow_null"]:
			_add_property(resource, property_name)
		_add_json_default(resource)
		var column: GFConfigTableColumn = resource
		_button(_form, "AddRangeRule", "新增范围规则", func() -> void:
			column.validation_rules.append(GFConfigRangeValidationRule.new())
			changed.emit()
			_show_definition(index)
		)
		for rule: GFConfigValidationRule in column.validation_rules:
			if rule is GFConfigRangeValidationRule:
				for property_name: String in ["enabled", "has_minimum", "minimum", "inclusive_minimum", "has_maximum", "maximum", "inclusive_maximum"]:
					_add_property(rule, property_name)
			else:
				var rule_label: Label = Label.new()
				rule_label.text = "保留自定义规则：%s（可在 Profile Inspector 编辑）" % (rule.get_class() if rule != null else "空规则")
				_form.add_child(rule_label)
	elif resource is GFConfigTableIndexDefinition:
		for property_name: String in ["index_id", "field_names", "unique", "allow_null_values"]:
			_add_property(resource, property_name)
	elif resource is GFConfigTableReference:
		var reference: GFConfigTableReference = resource
		for property_name: String in ["reference_id", "source_fields", "source_mode"]:
			_add_property(resource, property_name)
		_add_target_picker(reference)
		for property_name: String in ["target_fields", "required", "allow_null_values"]:
			_add_property(resource, property_name)


func _add_property(resource: Resource, property_name: String) -> void:
	for property_info: Dictionary in resource.get_property_list():
		if GFVariantData.get_option_string(property_info, "name") != property_name:
			continue
		var field: GFEditorValueField = GFEditorValueField.new()
		field.name = property_name.to_pascal_case()
		_form.add_child(field)
		var initial: Variant = resource.get(property_name)
		if initial is PackedStringArray:
			var words: PackedStringArray = initial
			field.configure({ "name": property_name + " (comma separated)", "type": TYPE_STRING }, ",".join(words))
			var _words_connection: int = field.value_changed.connect(func(value: Variant) -> void:
				if not _can_edit(field):
					return
				var parts: PackedStringArray = GFVariantData.to_text(value).split(",", false)
				for part_index: int in range(parts.size()):
					parts[part_index] = parts[part_index].strip_edges()
				resource.set(property_name, parts)
				changed.emit()
			)
		else:
			field.configure(property_info, initial)
			var _value_connection: int = field.value_changed.connect(func(value: Variant) -> void:
				if not _can_edit(field):
					return
				resource.set(property_name, value)
				changed.emit()
			)
		return


func _add_json_default(resource: Resource) -> void:
	var label: Label = Label.new()
	label.text = "默认值（JSON；Enter 应用到草稿）"
	_form.add_child(label)
	var field: LineEdit = LineEdit.new()
	field.name = "DefaultValue"
	field.placeholder_text = "default_value (JSON)"
	field.text = JSON.stringify(resource.get("default_value"))
	_form.add_child(field)
	var _default_connection: int = field.text_submitted.connect(func(text: String) -> void:
		if not _can_edit(field):
			return
		var parser: JSON = JSON.new()
		if parser.parse(text) != OK:
			_status.text = "默认值不是有效 JSON，草稿保持旧值。"
			return
		resource.set("default_value", parser.data)
		changed.emit()
		_status.text = "默认值已应用到草稿。"
	)
	field.tooltip_text = "输入 JSON 并按 Enter 应用；null 表示空默认值。"


func _add_target_picker(reference: GFConfigTableReference) -> void:
	var picker: OptionButton = OptionButton.new()
	picker.name = "TargetTable"
	picker.add_item("选择目标表")
	for source: GFConfigPipelineTableSource in _profile.sources:
		if source == null:
			continue
		picker.add_item(String(source.get_table_key()))
		if source.get_table_key() == reference.target_table_name:
			picker.select(picker.item_count - 1)
	_form.add_child(picker)
	var _target_connection: int = picker.item_selected.connect(func(index: int) -> void:
		if not _can_edit(picker):
			return
		if index > 0:
			reference.target_table_name = StringName(picker.get_item_text(index))
			changed.emit()
			var selected: PackedInt32Array = _list.get_selected_items()
			if not selected.is_empty():
				_show_definition(selected[0])
	)
	var field_picker: OptionButton = OptionButton.new()
	field_picker.name = "TargetFieldSuggestion"
	field_picker.add_item("选择目标字段（复合字段可在下方编辑）")
	for source: GFConfigPipelineTableSource in _profile.sources:
		if source != null and source.get_table_key() == reference.target_table_name and source.schema != null:
			for column: GFConfigTableColumn in source.schema.columns:
				if column != null:
					field_picker.add_item(String(column.field_name))
	_form.add_child(field_picker)
	var _field_connection: int = field_picker.item_selected.connect(func(index: int) -> void:
		if not _can_edit(field_picker):
			return
		if index > 0:
			reference.target_fields = PackedStringArray([field_picker.get_item_text(index)])
			changed.emit()
			var selected: PackedInt32Array = _list.get_selected_items()
			if not selected.is_empty():
				_show_definition(selected[0])
	)


func _create_schema() -> void:
	if _source == null or _source.schema != null:
		return
	_source.schema = GFConfigTableSchema.new()
	_source.schema.table_name = _source.get_table_key()
	_source.schema.require_unique_id = true
	_source.schema.coerce_values = true
	changed.emit()
	_refresh_list()


func _add_definition() -> void:
	if _source == null or _source.schema == null:
		return
	match _kind.selected:
		0:
			_source.schema.columns.append(GFConfigTableColumn.new())
		1:
			_source.schema.indexes.append(GFConfigTableIndexDefinition.new())
		2:
			_source.schema.references.append(GFConfigTableReference.new())
	changed.emit()
	_refresh_list()
	_list.select(_list.item_count - 1)
	_show_definition(_list.item_count - 1)


func _remove_definition() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		return
	_definitions().remove_at(selected[0])
	changed.emit()
	_refresh_list()


func _clear_form() -> void:
	for child: Node in _form.get_children():
		_form.remove_child(child)
		child.queue_free()


func _button(parent: Node, node_name: String, text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	parent.add_child(button)
	var _connection: int = button.pressed.connect(func() -> void:
		if _can_edit(button):
			callback.call()
	)
