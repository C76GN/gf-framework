@tool
# 为资源表格构建单列粘贴预览，只读取目标和属性声明。
extends RefCounted


# --- 常量 ---

## 提供属性元数据与可写性检查。
## [br]
## @api private
const _PROPERTIES = preload("res://addons/gf/kernel/core/gf_object_property_tools.gd")

## 读取 Godot 属性提示中的类型和范围。
## [br]
## @api private
const _ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 框架内部方法 ---

## 按可见选择逐行解析，保留原值、目标和属性声明供确认时核对。
## [br]
## @api framework_internal
## [br]
## @param targets: 依可见顺序排列的选中资源。
## [br]
## @param property: 属性选择器中的直接属性名。
## [br]
## @param clipboard: 一列原始文本。
## [br]
## @return 预览或输入错误。
## [br]
## @schema return: Dictionary 含 error:String、rows:Array[Dictionary]，每行含 target、property_name、schema、old_value、new_value、input 和 error。
static func build(
	targets: Array[Resource],
	property: StringName,
	clipboard: String
) -> Dictionary:
	var rows: Array[Dictionary] = []
	var result: Dictionary = { "error": "", "rows": rows }
	if targets.is_empty() or property == &"":
		result["error"] = "请先选择资源行和属性。"
		return result
	var normalized: String = clipboard.replace("\r\n", "\n").replace("\r", "\n")
	if normalized.contains("\t"):
		result["error"] = "检测到制表符，请只复制一列。"
		return result
	var lines: PackedStringArray = normalized.split("\n", true)
	if lines.size() == targets.size() + 1 and lines[-1].is_empty():
		var _resized: int = lines.resize(targets.size())
	if lines.size() != targets.size():
		result["error"] = (
			"文本有 %d 行，已选择 %d 行。"
			% [lines.size(), targets.size()]
		)
		return result
	var first_schema: Array = []
	var seen: Dictionary = {}
	for index: int in range(targets.size()):
		var target: Resource = targets[index]
		var info: Dictionary = _PROPERTIES.get_property_info(target, property)
		var type_id: int = _ACCESS.get_option_int(
			info,
			"type",
			TYPE_NIL
		)
		var hint: int = _ACCESS.get_option_int(
			info,
			"hint",
			PROPERTY_HINT_NONE
		)
		var hint_string: String = _ACCESS.get_option_string(info, "hint_string")
		var schema: Array = [
			type_id,
			hint,
			hint_string,
		]
		var old_value: Variant = target.get(property) if not info.is_empty() else null
		var row: Dictionary = {
			"target": target,
			"property_name": property,
			"schema": schema,
			"old_value": old_value,
			"new_value": null,
			"input": lines[index],
			"error": "",
		}
		rows.append(row)
		if index == 0:
			first_schema = schema
		if seen.has(target):
			row["error"] = "多行指向同一资源。"
		elif info.is_empty() or not _PROPERTIES.is_property_writable(info):
			row["error"] = "属性缺失或只读。"
		elif schema != first_schema or typeof(old_value) != type_id:
			row["error"] = "所选属性的类型或编辑提示不同。"
		else:
			row["new_value"] = _parse_value(
				lines[index],
				type_id,
				hint,
				hint_string
			)
			if row["new_value"] == null:
				row["error"] = "输入与属性类型、范围或步长不符，或该提示不支持列粘贴。"
		seen[target] = true
		if row["error"] != "":
			result["error"] = "请检查预览中标出的行。"
	return result


# --- 私有/辅助方法 ---

## 保留字符串原文；数值须可完整转换，且符合已支持的范围提示。
## [br]
## @api private
static func _parse_value(
	input: String,
	type_id: int,
	hint: int,
	hint_string: String
) -> Variant:
	if hint == PROPERTY_HINT_NONE and type_id == TYPE_STRING:
		return input
	if hint not in [PROPERTY_HINT_NONE, PROPERTY_HINT_RANGE]:
		return null
	var number: String = input.strip_edges()
	var value: Variant
	if type_id == TYPE_INT:
		value = _parse_integer(number)
	elif type_id == TYPE_FLOAT:
		value = _parse_float(number)
	if value == null or hint == PROPERTY_HINT_NONE:
		return value
	var parts: PackedStringArray = hint_string.split(",")
	if parts.size() < 2 or parts.size() > 3:
		return null
	if type_id == TYPE_INT:
		var low: Variant = _parse_integer(parts[0].strip_edges())
		var high: Variant = _parse_integer(parts[1].strip_edges())
		var step: Variant = _parse_integer(parts[2].strip_edges()) if parts.size() == 3 else 1
		if (
			low is int
			and high is int
			and step is int
			and value is int
		):
			var int_min: int = low
			var int_max: int = high
			var int_step: int = step
			var int_value: int = value
			if (
				int_step > 0
				and int_value >= int_min
				and int_value <= int_max
			):
				if posmod(int_value, int_step) == posmod(int_min, int_step):
					return int_value
		return null
	for part: String in parts:
		if not part.strip_edges().is_valid_float() or not is_finite(part.to_float()):
			return null
	if not value is float:
		return null
	var float_value: float = value
	var minimum: float = parts[0].to_float()
	if float_value < minimum or float_value > parts[1].to_float():
		return null
	if parts.size() == 3:
		var increment: float = parts[2].to_float()
		if increment <= 0.0:
			return null
		var units: float = (float_value - minimum) / increment
		if not is_finite(units) or absf(units - roundf(units)) > 0.000001:
			return null
	return float_value


## 把有效十进制浮点文本归一为科学计数法，在转换前检查指数边界。
## [br]
## @api private
static func _parse_float(number: String) -> Variant:
	if not number.is_valid_float():
		return null
	var parts: PackedStringArray = number.to_lower().split("e")
	var mantissa: String = parts[0].trim_prefix("-").trim_prefix("+")
	var point: int = mantissa.find(".")
	var digits: String = mantissa.replace(".", "")
	var significant: String = digits.lstrip("0")
	if significant.is_empty():
		return -0.0 if number.begins_with("-") else 0.0
	var exponent: Variant = _parse_integer(parts[1]) if parts.size() == 2 else 0
	if not exponent is int:
		return null
	var power: int = exponent
	if power > number.length() + 324 or power < -number.length() - 324:
		return null
	power += (digits.length() if point < 0 else point) - (digits.length() - significant.length()) - 1
	if power > 308 or power < -324:
		return null
	var normalized: String = significant.left(1) + "." + significant.substr(1) + "e" + str(power)
	var value: float = normalized.to_float()
	if not is_finite(value):
		return null
	return -value if number.begins_with("-") else value


## 通过十进制往返检查有符号 64 位整数溢出，接受符号和前导零。
## [br]
## @api private
static func _parse_integer(number: String) -> Variant:
	if not number.is_valid_int():
		return null
	var digits: String = number.trim_prefix("-").trim_prefix("+").lstrip("0")
	if digits.is_empty():
		return 0
	var canonical: String = ("-" if number.begins_with("-") else "") + digits
	var value: int = number.to_int()
	if str(value) != canonical:
		return null
	return value
