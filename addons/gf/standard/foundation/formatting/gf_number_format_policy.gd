## GFNumberFormatPolicy: 冻结的数字显示政策。
##
## 小数位与有效位共同限定显示精度，舍入只影响展示，不改变原始数值或交易判定。
## 单位缩放、整数分组、分隔符和自动记法分别配置；默认保留科学计数法回退。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFNumberFormatPolicy
extends RefCounted


# --- 私有变量 ---

## 已验证的封闭显示政策。
## [br]
## @api private
var _record: Dictionary = {}


# --- 公共方法 ---

## 创建政策并复制单位表，不接受隐式类型转换。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 显示政策。
## [br]
## @schema options: 封闭 Dictionary，可选 notation:String（auto/full/compact/scientific/engineering，默认auto）、group_base:int（1000或10000，默认1000）、suffixes:PackedStringArray（默认对应单位表）、decimal_places:int[0,18]（默认2）、significant_digits:int[0,18]（0关闭）、rounding:String（half_up/half_even/toward_zero/floor/ceiling，默认half_up）、trim_zeroes:bool（默认true）、use_grouping:bool（默认false）、scientific_style:String（e/E/power，默认e）。grouping_size:int[1,8192] 默认按group_base取3或4；group_separator:String默认逗号、0..4字符；decimal_separator:String默认句点、1..4字符，分隔符不含控制字符且只影响展示。auto_scientific_below:int[-1000000,0]默认-4，auto_compact_from:int[0,1000000]默认0，按原始非零值的绝对十进制数量级选择，先判断科学下限，再判断紧凑下限，其余full。fallback_notation:String为scientific（默认）或error。后缀1..64项，每项最多32字符，第一项为空，其余非空且不重复。
## [br]
## @return 冻结政策；无效输入返回 null。
static func create(options: Dictionary = {}) -> GFNumberFormatPolicy:
	var result: Dictionary = try_create(options)
	var candidate: Variant = result.get("policy")
	return candidate if candidate is GFNumberFormatPolicy else null


## 创建政策并返回具体失败字段；失败不产生政策，也不输出日志。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 与 create 相同的显示声明。
## [br]
## @schema options: Dictionary，字段、默认值与预算见 create.options。
## [br]
## @return 政策或可解释的失败结果，修改结果字典不影响已创建政策。
## [br]
## @schema return: 封闭 Dictionary，ok:bool、policy:GFNumberFormatPolicy或null、error_kind:String、path:String；成功时后两项为空，失败为invalid_type/unknown_option/invalid_value及options字段路径，不回显配置值。
static func try_create(options: Dictionary = {}) -> Dictionary:
	var text_fields: Array[String] = [
		"notation",
		"rounding",
		"scientific_style",
		"group_separator",
		"decimal_separator",
		"fallback_notation",
	]
	var integer_fields: Array[String] = [
		"group_base",
		"decimal_places",
		"significant_digits",
		"grouping_size",
		"auto_scientific_below",
		"auto_compact_from",
	]
	var bool_fields: Array[String] = ["trim_zeroes", "use_grouping"]
	for key: Variant in options:
		if not key is String:
			return _creation_result(
				null,
				"invalid_type",
				"options"
			)
		var field: String = key
		var path: String = "options." + field.left(128)
		if key in text_fields:
			if not options[key] is String:
				return _creation_result(
					null,
					"invalid_type",
					path
				)
		elif key in integer_fields:
			if not options[key] is int:
				return _creation_result(
					null,
					"invalid_type",
					path
				)
		elif key in bool_fields:
			if not options[key] is bool:
				return _creation_result(
					null,
					"invalid_type",
					path
				)
		elif key == "suffixes":
			if not options[key] is PackedStringArray:
				return _creation_result(
					null,
					"invalid_type",
					path
				)
		else:
			return _creation_result(
				null,
				"unknown_option",
				path
			)
	var notation: String = GFVariantData.get_option_string(
		options,
		"notation",
		"auto"
	)
	var base: int = GFVariantData.get_option_int(
		options,
		"group_base",
		1000
	)
	var places: int = GFVariantData.get_option_int(
		options,
		"decimal_places",
		2
	)
	var significant: int = GFVariantData.get_option_int(options, "significant_digits")
	var rounding: String = GFVariantData.get_option_string(
		options,
		"rounding",
		"half_up"
	)
	var style: String = GFVariantData.get_option_string(
		options,
		"scientific_style",
		"e"
	)
	if notation not in [
		"auto",
		"full",
		"compact",
		"scientific",
		"engineering",
	]:
		return _creation_result(
			null,
			"invalid_value",
			"options.notation"
		)
	if base not in [1000, 10000]:
		return _creation_result(
			null,
			"invalid_value",
			"options.group_base"
		)
	if places < 0 or places > 18:
		return _creation_result(
			null,
			"invalid_value",
			"options.decimal_places"
		)
	if significant < 0 or significant > 18:
		return _creation_result(
			null,
			"invalid_value",
			"options.significant_digits"
		)
	if rounding not in [
		"half_up",
		"half_even",
		"toward_zero",
		"floor",
		"ceiling",
	]:
		return _creation_result(
			null,
			"invalid_value",
			"options.rounding"
		)
	if style not in [
		"e",
		"E",
		"power",
	]:
		return _creation_result(
			null,
			"invalid_value",
			"options.scientific_style"
		)
	var grouping_size: int = GFVariantData.get_option_int(
		options,
		"grouping_size",
		4 if base == 10000 else 3
	)
	if grouping_size < 1 or grouping_size > 8192:
		return _creation_result(
			null,
			"invalid_value",
			"options.grouping_size"
		)
	var scientific_below: int = GFVariantData.get_option_int(
		options,
		"auto_scientific_below",
		-4
	)
	var compact_from: int = GFVariantData.get_option_int(
		options,
		"auto_compact_from",
		0
	)
	if scientific_below < -1000000 or scientific_below > 0:
		return _creation_result(
			null,
			"invalid_value",
			"options.auto_scientific_below"
		)
	if compact_from < 0 or compact_from > 1000000:
		return _creation_result(
			null,
			"invalid_value",
			"options.auto_compact_from"
		)
	var group_separator: String = GFVariantData.get_option_string(
		options,
		"group_separator",
		","
	)
	var decimal_separator: String = GFVariantData.get_option_string(
		options,
		"decimal_separator",
		"."
	)
	if not _valid_separator(group_separator, true):
		return _creation_result(
			null,
			"invalid_value",
			"options.group_separator"
		)
	if not _valid_separator(decimal_separator, false):
		return _creation_result(
			null,
			"invalid_value",
			"options.decimal_separator"
		)
	var fallback: String = GFVariantData.get_option_string(
		options,
		"fallback_notation",
		"scientific"
	)
	if fallback not in ["scientific", "error"]:
		return _creation_result(
			null,
			"invalid_value",
			"options.fallback_notation"
		)
	var suffixes: PackedStringArray = get_default_suffixes(base)
	if options.has("suffixes"):
		suffixes = options["suffixes"]
	if (
		suffixes.is_empty()
		or suffixes.size() > 64
		or suffixes[0] != ""
	):
		return _creation_result(
			null,
			"invalid_value",
			"options.suffixes"
		)
	var seen: Dictionary = {}
	for index: int in range(suffixes.size()):
		var suffix: String = suffixes[index]
		if (
			suffix.length() > 32
			or (
				index > 0
				and suffix.is_empty()
			)
			or seen.has(suffix)
		):
			return _creation_result(
				null,
				"invalid_value",
				"options.suffixes[%d]" % index
			)
		seen[suffix] = true
	var policy: GFNumberFormatPolicy = GFNumberFormatPolicy.new()
	policy._record = {
		"notation": notation,
		"group_base": base,
		"suffixes": suffixes.duplicate(),
		"decimal_places": places,
		"significant_digits": significant,
		"rounding": rounding,
		"trim_zeroes": GFVariantData.get_option_bool(
			options,
			"trim_zeroes",
			true
		),
		"use_grouping": GFVariantData.get_option_bool(options, "use_grouping"),
		"scientific_style": style,
		"grouping_size": grouping_size,
		"group_separator": group_separator,
		"decimal_separator": decimal_separator,
		"auto_scientific_below": scientific_below,
		"auto_compact_from": compact_from,
		"fallback_notation": fallback,
	}
	return _creation_result(
		policy,
		"",
		""
	)


## 获取框架单位表的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param group_base: 1000或10000；其他输入返回空数组。
## [br]
## @return 第0项为空的单位表。
static func get_default_suffixes(group_base: int = 1000) -> PackedStringArray:
	if group_base == 1000:
		return PackedStringArray(
			[
				"",
				"k",
				"M",
				"B",
				"T",
				"Qa",
				"Qi",
				"Sx",
				"Sp",
				"Oc",
				"No",
				"De",
				"Ud",
				"Dd",
				"Td",
				"Qad",
				"Qid",
			]
		)
	if group_base == 10000:
		return PackedStringArray(
			[
				"",
				"万",
				"亿",
				"兆",
				"京",
				"垓",
				"秭",
				"穰",
				"沟",
				"涧",
				"正",
				"载",
			]
		)
	return PackedStringArray()


## 获取完整政策副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完整实际政策；未经工厂创建的实例返回空字典。
## [br]
## @schema return: Dictionary，包含 create.options 的全部实际字段，省略的选项已填入默认值，容器与政策内部隔离。
func to_record() -> Dictionary:
	return _record.duplicate(true)


# --- 私有/辅助方法 ---

## 分隔符只用于有界展示，不允许注入换行或控制字符。
## [br]
## @api private
static func _valid_separator(value: String, allow_empty: bool) -> bool:
	if (
		value.length() > 4
		or (
			not allow_empty
			and value.is_empty()
		)
	):
		return false
	for index: int in range(value.length()):
		var character: int = value.unicode_at(index)
		if (
			character < 32
			or (
				character >= 127
				and character <= 159
			)
			or character == 8232
			or character == 8233
		):
			return false
	return true


## 统一工厂结果形状，失败不保留用户配置载荷。
## [br]
## @api private
static func _creation_result(
	policy: GFNumberFormatPolicy,
	error_kind: String,
	path: String
) -> Dictionary:
	return {
		"ok": policy != null,
		"policy": policy,
		"error_kind": error_kind,
		"path": path,
	}
