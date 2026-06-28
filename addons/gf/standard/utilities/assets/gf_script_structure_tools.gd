@tool

## GFScriptStructureTools: 脚本结构扫描和契约检查工具。
##
## 面向编辑器工具、导入器、测试和构建脚本复用；它只描述脚本公开的
## 常量、方法、属性、信号和继承关系，不实例化对象，也不规定组件架构、数据库或业务层模型。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.1.0
class_name GFScriptStructureTools
extends RefCounted


# --- 常量 ---

## GDScript 扩展名白名单，不包含点号。
## [br]
## @api public
## [br]
## @since 6.1.0
const SCRIPT_EXTENSIONS: PackedStringArray = ["gd"]

## 默认脚本继承链扫描深度上限。
## [br]
## @api public
## [br]
## @since 6.1.0
const DEFAULT_MAX_BASE_CHAIN_DEPTH: int = 32


# --- 公共方法 ---

## 扫描脚本路径，并按目录深度优先、同层字典序排序。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param root_path: 扫描起点，通常是 res:// 下的目录。
## [br]
## @param options: 可选项，支持 GFResourceRegistryTools.scan_resource_paths() 的扫描选项，extensions 默认固定为 gd。
## [br]
## @return 排序后的脚本路径。
## [br]
## @schema options: Dictionary，可包含 recursive、include_addons、excluded_paths、include_patterns、exclude_patterns、pattern_base_path、include_hidden、max_scan_depth、max_resource_paths 和 extensions 字段。
static func scan_script_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var scan_options: Dictionary = GFVariantData.to_dictionary(options)
	if not scan_options.has("extensions") and not scan_options.has(&"extensions"):
		scan_options["extensions"] = SCRIPT_EXTENSIONS
	var paths: PackedStringArray = GFResourceRegistryTools.scan_resource_paths(root_path, scan_options)
	return _sort_paths_by_depth(paths)


## 描述脚本公开结构。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param target_script: 待描述脚本。
## [br]
## @param options: 可选项，支持 include_private_members、include_constants、include_methods、include_properties、include_signals、include_base_chain、include_constant_values 和 max_base_chain_depth。
## [br]
## @return 脚本结构描述报告。
## [br]
## @schema options: Dictionary，可控制成员、继承链和常量值是否写入描述报告。
## [br]
## @schema return: Dictionary，包含 ok、script_path、global_name、instance_base_type、can_instantiate、constants、methods、properties、signals、base_chain、counts、issues 与 summary 字段。
static func describe_script(target_script: Script, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_description_report(target_script)
	if target_script == null:
		_append_issue(report, "error", "invalid_script", "", "", "Script is null.")
		return _finalize_report(report)

	var include_private_members: bool = GFVariantData.get_option_bool(options, "include_private_members", false)
	if GFVariantData.get_option_bool(options, "include_constants", true):
		report["constants"] = _describe_constants(target_script, options, include_private_members)
	if GFVariantData.get_option_bool(options, "include_methods", true):
		report["methods"] = _describe_method_records(target_script.get_script_method_list(), include_private_members)
	if GFVariantData.get_option_bool(options, "include_properties", true):
		report["properties"] = _describe_property_records(target_script.get_script_property_list(), include_private_members)
	if GFVariantData.get_option_bool(options, "include_signals", true):
		report["signals"] = _describe_signal_records(target_script.get_script_signal_list(), include_private_members)
	if GFVariantData.get_option_bool(options, "include_base_chain", true):
		report["base_chain"] = _describe_base_chain(target_script, options)

	return _finalize_report(report)


## 将 Godot 方法元数据格式化为 GDScript 函数签名。
##
## method 通常来自 Script.get_script_method_list()、ClassDB.class_get_method_list()
## 或 describe_script() 返回的 methods 条目。该方法只生成文本片段，不读取或修改脚本源码。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param method: 方法元数据。
## [br]
## @param options: 可选项，支持 include_func_keyword、include_return_type、include_void_return 和 include_variant_type_for_untyped。
## [br]
## @return 方法签名格式化报告。
## [br]
## @schema method: Dictionary，可包含 name、args、arguments、default_args、return、return_type、return_class_name、return_hint 和 return_hint_string 字段。
## [br]
## @schema options: Dictionary，可控制是否输出 func 关键字、返回类型、void 返回类型和未标注参数的 Variant 类型。
## [br]
## @schema return: Dictionary，包含 ok、name、signature、stub、argument_count、return_type、return_type_name、issues、counts 与 summary 字段。
static func format_method_signature(method: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_method_format_report(method)
	var method_name: String = GFVariantData.get_option_string(method, "name").strip_edges()
	if method_name.is_empty():
		_append_issue(report, "error", "missing_method_name", "name", "", "Method metadata is missing a name.")
		return _finalize_report(report)

	var normalized_method_name: String = _normalize_identifier(method_name, "method")
	if normalized_method_name != method_name:
		_append_issue(
			report,
			"warning",
			"normalized_method_name",
			"name",
			method_name,
			"Method name was normalized for GDScript output."
		)

	var args: Array = _get_method_arguments(method)
	var default_args: Array = GFVariantData.get_option_array(method, "default_args")
	var argument_signatures: PackedStringArray = PackedStringArray()
	for index: int in range(args.size()):
		var argument: Dictionary = GFVariantData.as_dictionary(args[index])
		var _argument_appended: bool = argument_signatures.append(
			_format_argument_signature(argument, index, args.size(), default_args, options)
		)

	var include_func_keyword: bool = GFVariantData.get_option_bool(options, "include_func_keyword", true)
	var include_return_type: bool = GFVariantData.get_option_bool(options, "include_return_type", true)
	var prefix: String = "func " if include_func_keyword else ""
	var signature: String = "%s%s(%s)" % [prefix, normalized_method_name, ", ".join(argument_signatures)]
	var return_info: Dictionary = _get_method_return_info(method)
	var return_type: int = GFVariantData.get_option_int(return_info, "type", TYPE_NIL)
	var return_type_name: String = _format_return_type_name(return_info, options)
	if include_return_type and not return_type_name.is_empty():
		signature += " -> %s" % return_type_name

	report["name"] = normalized_method_name
	report["signature"] = signature
	report["argument_count"] = args.size()
	report["return_type"] = return_type
	report["return_type_name"] = return_type_name
	return _finalize_report(report)


## 将 Godot 方法元数据格式化为可插入生成器输出的 GDScript 方法桩。
##
## 默认主体会为有返回值的方法生成安全默认返回值；无返回值或无法判断返回值时生成 pass。
## 调用方可通过 body_lines 提供自定义主体行。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param method: 方法元数据。
## [br]
## @param options: 可选项，支持 format_method_signature() 的选项，以及 indent、body_lines 和 include_trailing_newline。
## [br]
## @return 方法桩格式化报告。
## [br]
## @schema method: Dictionary，可包含 name、args、arguments、default_args、return、return_type、return_class_name、return_hint 和 return_hint_string 字段。
## [br]
## @schema options: Dictionary，可控制签名输出、缩进文本、自定义主体行和是否追加末尾换行；body_lines 可为 Array、PackedStringArray 或单行 String。
## [br]
## @schema return: Dictionary，包含 ok、name、signature、stub、argument_count、return_type、return_type_name、issues、counts 与 summary 字段。
static func format_method_stub(method: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = format_method_signature(method, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		return report

	var signature: String = GFVariantData.get_option_string(report, "signature")
	if signature.is_empty():
		_append_issue(report, "error", "missing_method_signature", "signature", "", "Method signature is empty.")
		return _finalize_report(report)

	var indent_text: String = GFVariantData.get_option_string(options, "indent", "\t")
	if indent_text.is_empty():
		indent_text = "\t"

	var lines: PackedStringArray = PackedStringArray()
	var _signature_appended: bool = lines.append("%s:" % signature)
	var body_lines: PackedStringArray = _get_method_stub_body_lines(report, options)
	for body_line: String in body_lines:
		if body_line.is_empty():
			var _empty_appended: bool = lines.append("")
		else:
			var _body_appended: bool = lines.append("%s%s" % [indent_text, body_line])

	var stub: String = "\n".join(lines)
	if GFVariantData.get_option_bool(options, "include_trailing_newline", true):
		stub += "\n"
	report["stub"] = stub
	return _finalize_report(report)


## 检查脚本是否满足结构声明。
##
## structure 可声明 base_script、base_class、can_instantiate、required_constants、
## required_methods、required_properties 与 required_signals。required_* 条目可使用名称字符串，
## 也可使用包含 name、type、class_name、usage、argument_count 或 min_argument_count 的 Dictionary。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param target_script: 待检查脚本。
## [br]
## @param structure: 结构声明。
## [br]
## @param options: 传给 describe_script() 的可选项。
## [br]
## @return 结构检查报告。
## [br]
## @schema structure: Dictionary，可包含 base_script、base_class、can_instantiate 和 required_* 成员声明。
## [br]
## @schema options: Dictionary，可控制成员描述与检查细节。
## [br]
## @schema return: Dictionary，包含 ok、script_path、description、issues、counts 与 summary 字段。
static func check_script_structure(
	target_script: Script,
	structure: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var description_options: Dictionary = GFVariantData.to_dictionary(options)
	description_options["include_constants"] = true
	description_options["include_methods"] = true
	description_options["include_properties"] = true
	description_options["include_signals"] = true
	description_options["include_base_chain"] = true
	var description: Dictionary = describe_script(target_script, description_options)
	var report: Dictionary = _make_check_report(target_script, description)
	if target_script == null:
		_append_issue(report, "error", "invalid_script", "", "", "Script is null.")
		return _finalize_report(report)

	_check_base_script(report, target_script, structure)
	_check_base_class(report, target_script, structure)
	_check_can_instantiate(report, target_script, structure)
	_check_required_records(report, "constant", "required_constants", GFVariantData.get_option_array(description, "constants"), structure)
	_check_required_records(report, "method", "required_methods", GFVariantData.get_option_array(description, "methods"), structure)
	_check_required_records(report, "property", "required_properties", GFVariantData.get_option_array(description, "properties"), structure)
	_check_required_records(report, "signal", "required_signals", GFVariantData.get_option_array(description, "signals"), structure)
	return _finalize_report(report)


# --- 私有/辅助方法 ---

static func _make_description_report(target_script: Script) -> Dictionary:
	return {
		"ok": true,
		"script_path": _get_script_path(target_script),
		"global_name": _get_script_global_name(target_script),
		"instance_base_type": _get_script_instance_base_type(target_script),
		"can_instantiate": target_script.can_instantiate() if target_script != null else false,
		"constants": [],
		"methods": [],
		"properties": [],
		"signals": [],
		"base_chain": [],
		"counts": {},
		"issues": [],
		"summary": "",
	}


static func _make_check_report(target_script: Script, description: Dictionary) -> Dictionary:
	return {
		"ok": GFVariantData.get_option_bool(description, "ok", true),
		"script_path": _get_script_path(target_script),
		"description": description,
		"counts": {},
		"issues": [],
		"summary": "",
	}


static func _make_method_format_report(method: Dictionary) -> Dictionary:
	var return_info: Dictionary = _get_method_return_info(method)
	return {
		"ok": true,
		"name": GFVariantData.get_option_string(method, "name"),
		"signature": "",
		"stub": "",
		"argument_count": _get_method_arguments(method).size(),
		"return_type": GFVariantData.get_option_int(return_info, "type", TYPE_NIL),
		"return_type_name": "",
		"counts": {},
		"issues": [],
		"summary": "",
	}


static func _get_method_arguments(method: Dictionary) -> Array:
	var args: Array = GFVariantData.get_option_array(method, "args")
	if args.is_empty():
		args = GFVariantData.get_option_array(method, "arguments")
	return args


static func _get_method_return_info(method: Dictionary) -> Dictionary:
	var return_info: Dictionary = GFVariantData.get_option_dictionary(method, "return")
	if not return_info.is_empty():
		return return_info
	return {
		"type": GFVariantData.get_option_int(method, "return_type", TYPE_NIL),
		"class_name": GFVariantData.get_option_string(method, "return_class_name"),
		"hint": GFVariantData.get_option_int(method, "return_hint"),
		"hint_string": GFVariantData.get_option_string(method, "return_hint_string"),
	}


static func _format_argument_signature(
	argument: Dictionary,
	index: int,
	argument_count: int,
	default_args: Array,
	options: Dictionary
) -> String:
	var argument_name: String = _normalize_identifier(
		GFVariantData.get_option_string(argument, "name"),
		"arg_%d" % index
	)
	var result: String = argument_name
	var type_name: String = _format_type_name(
		argument,
		GFVariantData.get_option_bool(options, "include_variant_type_for_untyped", false)
	)
	if not type_name.is_empty():
		result += ": %s" % type_name

	var default_start_index: int = argument_count - default_args.size()
	if default_start_index >= 0 and index >= default_start_index:
		var default_index: int = index - default_start_index
		result += " = %s" % _variant_literal(default_args[default_index])
	return result


static func _format_return_type_name(return_info: Dictionary, options: Dictionary) -> String:
	var return_type: int = GFVariantData.get_option_int(return_info, "type", TYPE_NIL)
	if return_type == TYPE_NIL:
		if GFVariantData.get_option_bool(options, "include_void_return", false):
			return "void"
		if GFVariantData.get_option_bool(options, "include_variant_return", false):
			return "Variant"
		return ""
	return _format_type_name(return_info, false)


static func _format_type_name(type_info: Dictionary, include_variant_for_nil: bool) -> String:
	var type_index: int = GFVariantData.get_option_int(type_info, "type", TYPE_NIL)
	if type_index == TYPE_NIL:
		return "Variant" if include_variant_for_nil else ""
	if type_index == TYPE_OBJECT:
		var resolved_class_name: String = GFVariantData.get_option_string(type_info, "class_name")
		return resolved_class_name if not resolved_class_name.is_empty() else "Object"
	if type_index == TYPE_ARRAY:
		var hint_string: String = GFVariantData.get_option_string(type_info, "hint_string").strip_edges()
		if hint_string.begins_with("Array[") and hint_string.ends_with("]"):
			return hint_string
		return "Array"
	return type_string(type_index)


static func _get_method_stub_body_lines(report: Dictionary, options: Dictionary) -> PackedStringArray:
	var explicit_body_lines: PackedStringArray = _to_packed_string_lines(GFVariantData.get_option_value(options, "body_lines"))
	if not explicit_body_lines.is_empty():
		return explicit_body_lines

	var return_type: int = GFVariantData.get_option_int(report, "return_type", TYPE_NIL)
	var return_type_name: String = GFVariantData.get_option_string(report, "return_type_name")
	var return_literal: String = _default_return_literal(return_type, return_type_name)
	if not return_literal.is_empty():
		return PackedStringArray(["return %s" % return_literal])
	return PackedStringArray(["pass"])


static func _default_return_literal(return_type: int, return_type_name: String) -> String:
	if return_type == TYPE_NIL or return_type_name == "void":
		return ""
	match return_type:
		TYPE_BOOL:
			return "false"
		TYPE_INT:
			return "0"
		TYPE_FLOAT:
			return "0.0"
		TYPE_STRING:
			return "\"\""
		TYPE_STRING_NAME:
			return "&\"\""
		TYPE_VECTOR2:
			return "Vector2.ZERO"
		TYPE_VECTOR2I:
			return "Vector2i.ZERO"
		TYPE_RECT2:
			return "Rect2()"
		TYPE_RECT2I:
			return "Rect2i()"
		TYPE_VECTOR3:
			return "Vector3.ZERO"
		TYPE_VECTOR3I:
			return "Vector3i.ZERO"
		TYPE_TRANSFORM2D:
			return "Transform2D()"
		TYPE_VECTOR4:
			return "Vector4.ZERO"
		TYPE_VECTOR4I:
			return "Vector4i.ZERO"
		TYPE_PLANE:
			return "Plane()"
		TYPE_QUATERNION:
			return "Quaternion.IDENTITY"
		TYPE_AABB:
			return "AABB()"
		TYPE_BASIS:
			return "Basis.IDENTITY"
		TYPE_TRANSFORM3D:
			return "Transform3D.IDENTITY"
		TYPE_PROJECTION:
			return "Projection()"
		TYPE_COLOR:
			return "Color.WHITE"
		TYPE_NODE_PATH:
			return "NodePath()"
		TYPE_CALLABLE:
			return "Callable()"
		TYPE_SIGNAL:
			return "Signal()"
		TYPE_DICTIONARY:
			return "{}"
		TYPE_ARRAY:
			return "[]"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray()"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array()"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array()"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array()"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array()"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray()"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array()"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array()"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray()"
		TYPE_PACKED_VECTOR4_ARRAY:
			return "PackedVector4Array()"
		_:
			return "null"


static func _variant_literal(value: Variant) -> String:
	if value == null:
		return "null"
	match typeof(value):
		TYPE_BOOL:
			return "true" if GFVariantData.to_bool(value) else "false"
		TYPE_INT:
			return str(GFVariantData.to_int(value))
		TYPE_FLOAT:
			return _float_literal(GFVariantData.to_float(value))
		TYPE_STRING:
			return "\"%s\"" % GFVariantData.to_text(value).c_escape()
		TYPE_STRING_NAME:
			return "&\"%s\"" % GFVariantData.to_text(value).c_escape()
		TYPE_VECTOR2:
			var vector2: Vector2 = GFVariantData.to_vector2(value)
			return "Vector2(%s, %s)" % [_float_literal(vector2.x), _float_literal(vector2.y)]
		TYPE_VECTOR3:
			var vector3: Vector3 = GFVariantData.to_vector3(value)
			return "Vector3(%s, %s, %s)" % [
				_float_literal(vector3.x),
				_float_literal(vector3.y),
				_float_literal(vector3.z),
			]
		TYPE_VECTOR2I:
			var vector2i: Vector2i = Vector2i.ZERO
			if value is Vector2i:
				vector2i = value
			return "Vector2i(%d, %d)" % [vector2i.x, vector2i.y]
		TYPE_COLOR:
			var color: Color = Color.WHITE
			if value is Color:
				color = value
			return "Color(%s, %s, %s, %s)" % [
				_float_literal(color.r),
				_float_literal(color.g),
				_float_literal(color.b),
				_float_literal(color.a),
			]
		TYPE_NODE_PATH:
			return "NodePath(\"%s\")" % GFVariantData.to_text(value).c_escape()
		_:
			return var_to_str(value)


static func _float_literal(value: float) -> String:
	var text: String = str(value)
	return text if text.contains(".") else text + ".0"


static func _to_packed_string_lines(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed
	if value is String or value is StringName:
		var _line_appended: bool = result.append(GFVariantData.to_text(value))
		return result
	if value is Array:
		var values: Array = value
		for line_value: Variant in values:
			var _appended: bool = result.append(GFVariantData.to_text(line_value))
	return result


static func _normalize_identifier(value: String, fallback: String) -> String:
	var trimmed: String = value.strip_edges()
	if _is_valid_identifier(trimmed) and not _is_gdscript_reserved_word(trimmed):
		return trimmed

	var snake: String = trimmed.to_snake_case().to_lower()
	var result: String = ""
	var previous_was_separator: bool = false
	for index: int in range(snake.length()):
		var character: String = snake.substr(index, 1)
		var code: int = character.unicode_at(0)
		var is_letter: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if is_letter or is_digit or is_underscore:
			result += character
			previous_was_separator = is_underscore
		elif not previous_was_separator:
			result += "_"
			previous_was_separator = true

	result = result.trim_prefix("_").trim_suffix("_")
	if result.is_empty() or result.substr(0, 1).is_valid_int() or _is_gdscript_reserved_word(result):
		return fallback
	return result


static func _is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		var code: int = character.to_lower().unicode_at(0)
		var is_letter: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = character == "_"
		if index == 0:
			if not (is_letter or is_underscore):
				return false
		elif not (is_letter or is_digit or is_underscore):
			return false
	return true


static func _is_gdscript_reserved_word(value: String) -> bool:
	match value.to_lower():
		"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue", "elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "not", "null", "or", "pass", "preload", "return", "self", "signal", "static", "super", "true", "var", "void", "while", "yield":
			return true
		_:
			return false


static func _describe_constants(target_script: Script, options: Dictionary, include_private_members: bool) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var include_constant_values: bool = GFVariantData.get_option_bool(options, "include_constant_values", false)
	var constant_map: Dictionary = target_script.get_script_constant_map()
	for constant_key: Variant in constant_map.keys():
		var constant_name: String = GFVariantData.to_text(constant_key)
		if _should_skip_private_name(constant_name, include_private_members):
			continue
		var constant_value: Variant = constant_map[constant_key]
		var record: Dictionary = {
			"name": constant_name,
			"type": typeof(constant_value),
			"type_name": type_string(typeof(constant_value)),
		}
		if include_constant_values:
			record["value"] = GFVariantData.duplicate_variant(constant_value)
		records.append(record)
	records.sort_custom(Callable(GFScriptStructureTools, "_compare_named_records"))
	return records


static func _describe_method_records(method_list: Array, include_private_members: bool) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for method_value: Variant in method_list:
		var method: Dictionary = GFVariantData.as_dictionary(method_value)
		var method_name: String = GFVariantData.get_option_string(method, "name")
		if method_name.is_empty() or _should_skip_private_name(method_name, include_private_members):
			continue
		var args: Array = GFVariantData.get_option_array(method, "args")
		var return_info: Dictionary = GFVariantData.get_option_dictionary(method, "return")
		records.append({
			"name": method_name,
			"argument_count": args.size(),
			"arguments": _describe_argument_records(args),
			"flags": GFVariantData.get_option_int(method, "flags"),
			"return_type": GFVariantData.get_option_int(return_info, "type", TYPE_NIL),
			"return_class_name": GFVariantData.get_option_string(return_info, "class_name"),
			"return_hint": GFVariantData.get_option_int(return_info, "hint"),
			"return_hint_string": GFVariantData.get_option_string(return_info, "hint_string"),
		})
	records.sort_custom(Callable(GFScriptStructureTools, "_compare_named_records"))
	return records


static func _describe_property_records(property_list: Array, include_private_members: bool) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for property_value: Variant in property_list:
		var property: Dictionary = GFVariantData.as_dictionary(property_value)
		var property_name: String = GFVariantData.get_option_string(property, "name")
		if property_name.is_empty() or _should_skip_private_name(property_name, include_private_members):
			continue
		records.append({
			"name": property_name,
			"type": GFVariantData.get_option_int(property, "type", TYPE_NIL),
			"class_name": GFVariantData.get_option_string(property, "class_name"),
			"hint": GFVariantData.get_option_int(property, "hint"),
			"hint_string": GFVariantData.get_option_string(property, "hint_string"),
			"usage": GFVariantData.get_option_int(property, "usage"),
		})
	records.sort_custom(Callable(GFScriptStructureTools, "_compare_named_records"))
	return records


static func _describe_signal_records(signal_list: Array, include_private_members: bool) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for signal_value: Variant in signal_list:
		var signal_record: Dictionary = GFVariantData.as_dictionary(signal_value)
		var signal_name: String = GFVariantData.get_option_string(signal_record, "name")
		if signal_name.is_empty() or _should_skip_private_name(signal_name, include_private_members):
			continue
		var args: Array = GFVariantData.get_option_array(signal_record, "args")
		records.append({
			"name": signal_name,
			"argument_count": args.size(),
			"arguments": _describe_argument_records(args),
			"flags": GFVariantData.get_option_int(signal_record, "flags"),
		})
	records.sort_custom(Callable(GFScriptStructureTools, "_compare_named_records"))
	return records


static func _describe_argument_records(args: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in range(args.size()):
		var argument: Dictionary = GFVariantData.as_dictionary(args[index])
		records.append({
			"name": GFVariantData.get_option_string(argument, "name"),
			"index": index,
			"type": GFVariantData.get_option_int(argument, "type", TYPE_NIL),
			"class_name": GFVariantData.get_option_string(argument, "class_name"),
			"hint": GFVariantData.get_option_int(argument, "hint"),
			"hint_string": GFVariantData.get_option_string(argument, "hint_string"),
			"usage": GFVariantData.get_option_int(argument, "usage"),
		})
	return records


static func _describe_base_chain(target_script: Script, options: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var max_depth: int = maxi(
		GFVariantData.get_option_int(options, "max_base_chain_depth", DEFAULT_MAX_BASE_CHAIN_DEPTH),
		0
	)
	var current: Script = target_script
	var depth: int = 0
	while current != null and (max_depth <= 0 or depth < max_depth):
		records.append({
			"path": _get_script_path(current),
			"global_name": _get_script_global_name(current),
			"instance_base_type": _get_script_instance_base_type(current),
			"depth": depth,
		})
		current = current.get_base_script()
		depth += 1
	return records


static func _check_base_script(report: Dictionary, target_script: Script, structure: Dictionary) -> void:
	var expected_value: Variant = GFVariantData.get_option_value(structure, "base_script")
	if not (expected_value is Script):
		return
	var expected_script: Script = expected_value
	if not _script_extends_or_equals(target_script, expected_script):
		_append_issue(
			report,
			"error",
			"base_script_mismatch",
			"base_script",
			"",
			"Script does not extend the required base script."
		)


static func _check_base_class(report: Dictionary, target_script: Script, structure: Dictionary) -> void:
	if not structure.has("base_class") and not structure.has(&"base_class"):
		return
	var expected_base_class: String = GFVariantData.get_option_string(structure, "base_class")
	var actual_base_class: String = _get_script_instance_base_type(target_script)
	if expected_base_class.is_empty():
		return
	if actual_base_class != expected_base_class:
		_append_issue(
			report,
			"error",
			"base_class_mismatch",
			"base_class",
			expected_base_class,
			"Script instance base type is %s, expected %s." % [actual_base_class, expected_base_class]
		)


static func _check_can_instantiate(report: Dictionary, target_script: Script, structure: Dictionary) -> void:
	if not structure.has("can_instantiate") and not structure.has(&"can_instantiate"):
		return
	var expected_can_instantiate: bool = GFVariantData.get_option_bool(structure, "can_instantiate")
	if target_script.can_instantiate() == expected_can_instantiate:
		return
	_append_issue(
		report,
		"error",
		"can_instantiate_mismatch",
		"can_instantiate",
		str(expected_can_instantiate),
		"Script instantiation capability does not match the structure requirement."
	)


static func _check_required_records(
	report: Dictionary,
	record_kind: String,
	structure_key: String,
	records: Array,
	structure: Dictionary
) -> void:
	var requirements: Array = _get_requirement_list(structure, structure_key)
	for requirement_value: Variant in requirements:
		var requirement: Dictionary = _normalize_requirement(requirement_value)
		var required_name: String = GFVariantData.get_option_string(requirement, "name")
		if required_name.is_empty():
			_append_issue(
				report,
				"error",
				"empty_%s_requirement" % record_kind,
				structure_key,
				"",
				"Required %s name is empty." % record_kind
			)
			continue
		var record: Dictionary = _find_named_record(records, required_name)
		if record.is_empty():
			_append_issue(
				report,
				"error",
				"missing_%s" % record_kind,
				structure_key,
				required_name,
				"Required %s '%s' is missing." % [record_kind, required_name]
			)
			continue
		_check_record_constraints(report, record_kind, structure_key, record, requirement)


static func _check_record_constraints(
	report: Dictionary,
	record_kind: String,
	structure_key: String,
	record: Dictionary,
	requirement: Dictionary
) -> void:
	if requirement.has("type") or requirement.has(&"type"):
		var expected_type: int = GFVariantData.get_option_int(requirement, "type", TYPE_NIL)
		var actual_type: int = GFVariantData.get_option_int(record, "type", TYPE_NIL)
		if actual_type != expected_type:
			_append_issue(
				report,
				"error",
				"%s_type_mismatch" % record_kind,
				structure_key,
				GFVariantData.get_option_string(record, "name"),
				"%s type is %s, expected %s." % [record_kind.capitalize(), actual_type, expected_type]
			)
	if requirement.has("class_name") or requirement.has(&"class_name"):
		var expected_class_name: String = GFVariantData.get_option_string(requirement, "class_name")
		var actual_class_name: String = GFVariantData.get_option_string(record, "class_name")
		if actual_class_name != expected_class_name:
			_append_issue(
				report,
				"error",
				"%s_class_name_mismatch" % record_kind,
				structure_key,
				GFVariantData.get_option_string(record, "name"),
				"%s class_name is '%s', expected '%s'." % [record_kind.capitalize(), actual_class_name, expected_class_name]
			)
	if requirement.has("usage") or requirement.has(&"usage"):
		var expected_usage: int = GFVariantData.get_option_int(requirement, "usage")
		var actual_usage: int = GFVariantData.get_option_int(record, "usage")
		if actual_usage != expected_usage:
			_append_issue(
				report,
				"error",
				"%s_usage_mismatch" % record_kind,
				structure_key,
				GFVariantData.get_option_string(record, "name"),
				"%s usage is %s, expected %s." % [record_kind.capitalize(), actual_usage, expected_usage]
			)
	_check_argument_constraints(report, record_kind, structure_key, record, requirement)


static func _check_argument_constraints(
	report: Dictionary,
	record_kind: String,
	structure_key: String,
	record: Dictionary,
	requirement: Dictionary
) -> void:
	if requirement.has("argument_count") or requirement.has(&"argument_count"):
		var expected_count: int = GFVariantData.get_option_int(requirement, "argument_count")
		var actual_count: int = GFVariantData.get_option_int(record, "argument_count")
		if actual_count != expected_count:
			_append_issue(
				report,
				"error",
				"%s_argument_count_mismatch" % record_kind,
				structure_key,
				GFVariantData.get_option_string(record, "name"),
				"%s argument count is %s, expected %s." % [record_kind.capitalize(), actual_count, expected_count]
			)
	if requirement.has("min_argument_count") or requirement.has(&"min_argument_count"):
		var expected_min_count: int = GFVariantData.get_option_int(requirement, "min_argument_count")
		var actual_min_count: int = GFVariantData.get_option_int(record, "argument_count")
		if actual_min_count < expected_min_count:
			_append_issue(
				report,
				"error",
				"%s_min_argument_count_mismatch" % record_kind,
				structure_key,
				GFVariantData.get_option_string(record, "name"),
				"%s argument count is %s, expected at least %s." % [record_kind.capitalize(), actual_min_count, expected_min_count]
			)


static func _get_requirement_list(structure: Dictionary, key: String) -> Array:
	var value: Variant = GFVariantData.get_option_value(structure, key, [])
	if value is PackedStringArray:
		var names: Array = []
		for item: String in value:
			names.append(item)
		return names
	if value is Array:
		var array_value: Array = value
		return array_value
	if value is String or value is StringName:
		return [value]
	return []


static func _normalize_requirement(value: Variant) -> Dictionary:
	if value is Dictionary:
		var requirement: Dictionary = value
		return requirement
	return {
		"name": GFVariantData.to_text(value),
	}


static func _find_named_record(records: Array, required_name: String) -> Dictionary:
	for record_value: Variant in records:
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if GFVariantData.get_option_string(record, "name") == required_name:
			return record
	return {}


static func _append_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	field: String,
	member_name: String,
	message: String
) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	issues.append({
		"severity": severity,
		"kind": kind,
		"field": field,
		"member_name": member_name,
		"message": message,
	})
	report["issues"] = issues


static func _finalize_report(report: Dictionary) -> Dictionary:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var error_count: int = 0
	var warning_count: int = 0
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "severity") == "error":
			error_count += 1
		elif GFVariantData.get_option_string(issue, "severity") == "warning":
			warning_count += 1
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "counts")
	counts["issue_count"] = issues.size()
	counts["error_count"] = error_count
	counts["warning_count"] = warning_count
	if report.has("constants"):
		counts["constant_count"] = GFVariantData.get_option_array(report, "constants").size()
	if report.has("methods"):
		counts["method_count"] = GFVariantData.get_option_array(report, "methods").size()
	if report.has("properties"):
		counts["property_count"] = GFVariantData.get_option_array(report, "properties").size()
	if report.has("signals"):
		counts["signal_count"] = GFVariantData.get_option_array(report, "signals").size()
	report["counts"] = counts
	report["ok"] = GFVariantData.get_option_bool(report, "ok", true) and error_count == 0
	report["summary"] = "ok" if GFVariantData.get_option_bool(report, "ok") else "issues=%s errors=%s warnings=%s" % [
		issues.size(),
		error_count,
		warning_count,
	]
	return report


static func _sort_paths_by_depth(paths: PackedStringArray) -> PackedStringArray:
	var path_array: Array[String] = []
	for path: String in paths:
		path_array.append(path)
	path_array.sort_custom(Callable(GFScriptStructureTools, "_compare_paths_by_depth"))
	var result: PackedStringArray = PackedStringArray()
	for path: String in path_array:
		var _appended: bool = result.append(path)
	return result


static func _compare_paths_by_depth(left: String, right: String) -> bool:
	var left_depth: int = left.count("/")
	var right_depth: int = right.count("/")
	if left_depth == right_depth:
		return left < right
	return left_depth < right_depth


static func _compare_named_records(left: Dictionary, right: Dictionary) -> bool:
	return GFVariantData.get_option_string(left, "name") < GFVariantData.get_option_string(right, "name")


static func _script_extends_or_equals(candidate: Script, expected: Script) -> bool:
	if candidate == null or expected == null:
		return false
	var current: Script = candidate
	while current != null:
		if current == expected:
			return true
		current = current.get_base_script()
	return false


static func _get_script_path(target_script: Script) -> String:
	if target_script == null:
		return ""
	return target_script.resource_path


static func _get_script_global_name(target_script: Script) -> String:
	if target_script == null:
		return ""
	if target_script.has_method("get_global_name"):
		return GFVariantData.to_text(target_script.call("get_global_name"))
	return ""


static func _get_script_instance_base_type(target_script: Script) -> String:
	if target_script == null:
		return ""
	return target_script.get_instance_base_type()


static func _should_skip_private_name(member_name: String, include_private_members: bool) -> bool:
	return not include_private_members and member_name.begins_with("_")
