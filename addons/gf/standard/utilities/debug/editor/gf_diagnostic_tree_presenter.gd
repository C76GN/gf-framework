@tool

# GF 编辑器诊断树的无状态展示辅助。
extends RefCounted


# --- 框架内部方法 ---

## 把诊断字典填入三列 Tree，并为每个顶层字典值展开一层子项。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/debug/editor
## [br]
## @param tree: 接收诊断行的三列 Tree。
## [br]
## @param source: 待展示的诊断字典。
## [br]
## @schema source: Dictionary whose top-level keys become diagnostic tree rows.
static func populate_dictionary(tree: Tree, source: Dictionary) -> void:
	if tree == null:
		return
	var root_item: TreeItem = tree.create_item()
	_append_dictionary_items(tree, root_item, source, true)


## 返回诊断值的展示类型。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/debug/editor
## [br]
## @param value: 待分类的诊断值。
## [br]
## @schema value: Any diagnostic Variant accepted by the presenter.
## [br]
## @return: 稳定的展示类型名称。
static func get_value_kind(value: Variant) -> String:
	if value is Dictionary:
		return "Dictionary"
	if value is Array:
		return "Array"
	if value is PackedStringArray:
		return "PackedStringArray"
	return type_string(typeof(value))


## 返回诊断值的有界单行摘要。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/debug/editor
## [br]
## @param value: 待摘要的诊断值。
## [br]
## @schema value: Any diagnostic Variant accepted by the presenter.
## [br]
## @return: 不超过既定展示预算的单行摘要。
static func make_value_summary(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		return "%d keys" % dictionary.size()
	if value is Array:
		var array: Array = GFVariantData.as_array(value)
		return "%d items" % array.size()
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return "%d items" % packed_strings.size()
	var text: String = str(value)
	return text.substr(0, 120) if text.length() > 120 else text


## 返回经过 debug 脱敏策略处理的 JSON 文本。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/debug/editor
## [br]
## @param value: 待编码并执行 debug 脱敏的诊断值。
## [br]
## @schema value: Any diagnostic Variant accepted by the debug redaction codec.
## [br]
## @return: 已脱敏的 JSON 文本。
static func safe_json(value: Variant) -> String:
	return GFReportValueCodec.stringify_json_compatible(
		value,
		"\t",
		false,
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_DEBUG
		)
	)


## 返回经过 debug 脱敏策略处理的展示值。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/debug/editor
## [br]
## @param value: 待投影为安全展示值的诊断值。
## [br]
## @schema value: Any diagnostic Variant accepted by the debug redaction codec.
## [br]
## @return: 可安全显示并可由 JSON 编码的投影值。
## [br]
## @schema return: A JSON-compatible redacted Variant projection.
static func sanitize_for_display(value: Variant) -> Variant:
	return GFReportValueCodec.to_json_compatible(
		value,
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_DEBUG
		)
	)


# --- 私有/辅助方法 ---

static func _append_dictionary_items(
	tree: Tree,
	parent: TreeItem,
	source: Dictionary,
	include_children: bool
) -> void:
	for key_text: String in _get_sorted_keys(source):
		var value: Variant = source[key_text]
		var item: TreeItem = tree.create_item(parent)
		item.set_text(0, key_text)
		item.set_text(1, get_value_kind(value))
		item.set_text(2, make_value_summary(value))
		item.set_metadata(0, sanitize_for_display(value))
		if include_children and value is Dictionary:
			_append_dictionary_items(
				tree,
				item,
				GFVariantData.as_dictionary(value),
				false
			)


static func _get_sorted_keys(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		var _key_appended: bool = keys.append(GFVariantData.to_text(key))
	keys.sort()
	return keys
