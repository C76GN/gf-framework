## GFNumberFormatter: 由冻结政策控制的统一数字显示工具。
##
## int、十进制文本和 GFFixedDecimal 使用精确文本运算。float 与 GFBigNumber 的
## 尾数本身是近似值，格式化不会恢复它们已经丢失的精度。输出仅用于展示。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNumberFormatter
extends RefCounted


# --- 公共方法 ---

## 按政策格式化数值，不使用多组位置布尔参数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 要显示的数值。
## [br]
## @schema value: int、有限float、最多4096字符的String数值、GFBigNumber或GFFixedDecimal。文本支持严格逗号/下划线分隔和科学指数，输入及数量级范围±1000000；不接受bool或任意对象。
## [br]
## @param policy: 冻结显示政策；null 使用默认 auto 政策。
## [br]
## @return 格式化字符串；非法输入报告错误并返回稳定fallback 0。需要区分错误与真实零时使用 try_format。
static func format_number(value: Variant, policy: GFNumberFormatPolicy = null) -> String:
	var result: Dictionary = try_format(value, policy)
	if not GFVariantData.get_option_bool(result, "ok"):
		push_error("[GFNumberFormatter][number_formatter.invalid_input] Cannot format number: %s." % GFVariantData.get_option_string(result, "error"))
		return "0"
	return GFVariantData.get_option_string(result, "text")


## 返回可检查的格式化结果，不输出日志也不把非法输入当作零。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 与 format_number 相同的数值域。
## [br]
## @schema value: int、有限float、String数值、GFBigNumber或GFFixedDecimal；预算与format_number.value相同。
## [br]
## @param policy: 冻结政策；null 使用默认政策。
## [br]
## @return 有界显示结果。
## [br]
## @schema return: 封闭 Dictionary，ok:bool、text:String、error:String、notation_used:String、fallback_reason:String、policy_error_kind:String、path:String。成功文本最多8192字符，失败文本为空；notation_used为实际full/compact/scientific/engineering，失败为空；fallback_reason为output_budget/suffix_exhausted或空。默认科学回退，fallback_notation=error时拒绝回退。error为稳定原因标识；policy_error_kind/path由try_format_options报告政策错误，其余为空，不包含输入载荷。
static func try_format(value: Variant, policy: GFNumberFormatPolicy = null) -> Dictionary:
	var selected: GFNumberFormatPolicy = policy if policy != null else GFNumberFormatPolicy.create()
	var options: Dictionary = selected.to_record()
	if options.is_empty():
		return _result(
			false,
			"",
			"invalid_policy"
		)
	var components: Dictionary = _to_components(value)
	if not GFVariantData.get_option_bool(components, "ok"):
		return _result(
			false,
			"",
			GFVariantData.get_option_string(
				components,
				"error",
				"invalid_value"
			)
		)
	var digits: String = GFVariantData.get_option_string(components, "digits")
	var magnitude: int = digits.length() + GFVariantData.get_option_int(components, "exponent") - 1
	var notation: String = GFVariantData.get_option_string(options, "notation")
	if digits == "0":
		return _format_full(
			components,
			selected,
			options
		)
	if notation == "auto":
		if magnitude < GFVariantData.get_option_int(options, "auto_scientific_below"):
			notation = "scientific"
		elif magnitude >= GFVariantData.get_option_int(options, "auto_compact_from"):
			notation = "compact"
		else:
			notation = "full"
	match notation:
		"full":
			return _format_full(
				components,
				selected,
				options
			)
		"compact":
			return _format_compact(
				components,
				selected,
				options,
				magnitude
			)
		"scientific", "engineering":
			return _format_scientific(
				components,
				selected,
				options,
				magnitude,
				notation == "engineering"
			)
	return _result(
		false,
		"",
		"invalid_policy"
	)


## 直接验收显示声明后格式化，避免把政策创建失败的null解释成默认政策。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: 与format_number相同的精确值或近似值。
## [br]
## @schema value: int、有限float、String数值、GFBigNumber或GFFixedDecimal；范围见format_number.value。
## [br]
## @param options: 本次显示声明；空字典采用默认政策。
## [br]
## @schema options: 封闭Dictionary，见GFNumberFormatPolicy.create.options。
## [br]
## @return 不记录日志的格式化结果；政策无效时不解析数值。
## [br]
## @schema return: 与try_format.return相同；政策错误时ok=false、error=invalid_policy、policy_error_kind/path来自GFNumberFormatPolicy.try_create，text为空。
static func try_format_options(value: Variant, options: Dictionary = {}) -> Dictionary:
	var creation: Dictionary = GFNumberFormatPolicy.try_create(options)
	var candidate: Variant = creation.get("policy")
	if candidate is GFNumberFormatPolicy:
		var selected: GFNumberFormatPolicy = candidate
		return try_format(value, selected)
	var failure: Dictionary = _result(
		false,
		"",
		"invalid_policy"
	)
	failure["policy_error_kind"] = GFVariantData.get_option_string(creation, "error_kind")
	failure["path"] = GFVariantData.get_option_string(creation, "path")
	return failure


# --- 私有/辅助方法 ---

## 保持精确类型的原始十进制数值，近似类型只展开其实际浮点尾数。
## [br]
## @api private
static func _to_components(value: Variant) -> Dictionary:
	if value is int:
		return GFDecimalStringFormatter.parse_components(str(value))
	if value is String:
		var text: String = value
		return GFDecimalStringFormatter.parse_components(text)
	if value is float:
		var floating: float = value
		if is_nan(floating) or is_inf(floating):
			return _result(
				false,
				"",
				"non_finite"
			)
		return GFDecimalStringFormatter.parse_components(
			JSON.stringify(
				floating,
				"",
				false,
				true
			)
		)
	if value is GFFixedDecimal:
		var fixed_value: GFFixedDecimal = value
		return GFDecimalStringFormatter.parse_components(fixed_value.to_decimal_string(false))
	if value is GFBigNumber:
		var big_value: GFBigNumber = value
		if is_nan(big_value.mantissa) or is_inf(big_value.mantissa):
			return _result(
				false,
				"",
				"non_finite"
			)
		if big_value.exponent < -1000000 or big_value.exponent > 1000000:
			return _result(
				false,
				"",
				"exponent_out_of_range"
			)
		var components: Dictionary = GFDecimalStringFormatter.parse_components(
			JSON.stringify(
				big_value.mantissa,
				"",
				false,
				true
			)
		)
		if not GFVariantData.get_option_bool(components, "ok") or GFVariantData.get_option_string(components, "digits") == "0":
			return components
		var exponent: int = GFVariantData.get_option_int(components, "exponent") + big_value.exponent
		var magnitude: int = exponent + GFVariantData.get_option_string(components, "digits").length() - 1
		if magnitude < -1000000 or magnitude > 1000000:
			return _result(
				false,
				"",
				"exponent_out_of_range"
			)
		components["exponent"] = exponent
		return components
	return _result(
		false,
		"",
		"unsupported_type"
	)


## 输出普通小数，超出预算时回退科学计数法，不生成无界零串。
## [br]
## @api private
static func _format_full(
	components: Dictionary,
	policy: GFNumberFormatPolicy,
	options: Dictionary
) -> Dictionary:
	var formatted: Dictionary = GFDecimalStringFormatter.format_components(
		components,
		0,
		policy
	)
	var magnitude: int = GFVariantData.get_option_int(components, "exponent") + GFVariantData.get_option_string(components, "digits").length() - 1
	if not GFVariantData.get_option_bool(formatted, "ok"):
		if GFVariantData.get_option_string(formatted, "error") == "output_budget":
			return _fallback(
				components,
				policy,
				options,
				magnitude,
				"output_budget"
			)
		return _result(
			false,
			"",
			GFVariantData.get_option_string(formatted, "error")
		)
	var text: String = _display_number(
		GFVariantData.get_option_string(formatted, "text"),
		options,
		GFVariantData.get_option_bool(options, "use_grouping")
	)
	if text.is_empty():
		return _fallback(
			components,
			policy,
			options,
			magnitude,
			"output_budget"
		)
	return _result(
		true,
		text,
		"",
		"full"
	)


## 对原数值按单位缩放，进位后重新对原始分量舍入。
## [br]
## @api private
static func _format_compact(
	components: Dictionary,
	policy: GFNumberFormatPolicy,
	options: Dictionary,
	magnitude: int
) -> Dictionary:
	var width: int = _group_width(options)
	var index: int = maxi(
		0,
		floori(float(magnitude) / float(width))
	)
	var suffixes: PackedStringArray = options["suffixes"]
	if index >= suffixes.size():
		return _fallback(
			components,
			policy,
			options,
			magnitude,
			"suffix_exhausted"
		)
	var formatted: Dictionary = GFDecimalStringFormatter.format_components(
		components,
		index * width,
		policy
	)
	if not GFVariantData.get_option_bool(formatted, "ok"):
		return _result(
			false,
			"",
			GFVariantData.get_option_string(formatted, "error")
		)
	if GFVariantData.get_option_int(formatted, "display_exponent") >= width:
		index += 1
		if index >= suffixes.size():
			return _fallback(
				components,
				policy,
				options,
				magnitude,
				"suffix_exhausted"
			)
		formatted = GFDecimalStringFormatter.format_components(
			components,
			index * width,
			policy
		)
	if not GFVariantData.get_option_bool(formatted, "ok"):
		return _result(
			false,
			"",
			GFVariantData.get_option_string(formatted, "error")
		)
	if index == 0 and GFVariantData.get_option_bool(options, "use_grouping"):
		return _format_full(
			components,
			policy,
			options
		)
	return _result(
		true,
		_display_number(
			GFVariantData.get_option_string(formatted, "text"),
			options,
			false
		) + suffixes[index],
		"",
		"compact" if index > 0 else "full"
	)


## 科学或工程计数使用同一文本量化机制，单位进位不经 float 比较。
## [br]
## @api private
static func _format_scientific(
	components: Dictionary,
	policy: GFNumberFormatPolicy,
	options: Dictionary,
	magnitude: int,
	engineering: bool
) -> Dictionary:
	var width: int = 3 if engineering else 1
	var output_exponent: int = magnitude - posmod(magnitude, width)
	var formatted: Dictionary = GFDecimalStringFormatter.format_components(
		components,
		output_exponent,
		policy
	)
	if not GFVariantData.get_option_bool(formatted, "ok"):
		return _result(
			false,
			"",
			GFVariantData.get_option_string(formatted, "error")
		)
	if GFVariantData.get_option_int(formatted, "display_exponent") >= width:
		output_exponent += width
		formatted = GFDecimalStringFormatter.format_components(
			components,
			output_exponent,
			policy
		)
	if not GFVariantData.get_option_bool(formatted, "ok"):
		return _result(
			false,
			"",
			GFVariantData.get_option_string(formatted, "error")
		)
	var text: String = _display_number(
		GFVariantData.get_option_string(formatted, "text"),
		options,
		false
	)
	match GFVariantData.get_option_string(options, "scientific_style"):
		"E":
			text += "E" + str(output_exponent)
		"power":
			text += " x 10^" + str(output_exponent)
		_:
			text += "e" + str(output_exponent)
	return _result(
		true,
		text,
		"",
		"engineering" if engineering else "scientific"
	)


## 回退只改变显示方式；拒绝模式不创建超预算字符串。
## [br]
## @api private
static func _fallback(
	components: Dictionary,
	policy: GFNumberFormatPolicy,
	options: Dictionary,
	magnitude: int,
	reason: String
) -> Dictionary:
	if GFVariantData.get_option_string(options, "fallback_notation") == "error":
		return _result(
			false,
			"",
			reason,
			"",
			reason
		)
	var result: Dictionary = _format_scientific(
		components,
		policy,
		options,
		magnitude,
		false
	)
	result["fallback_reason"] = reason
	return result


## 仅渲染已量化的数值部分，单位和指数不参与分隔符替换。
## [br]
## @api private
static func _display_number(
	text: String,
	options: Dictionary,
	grouping: bool
) -> String:
	var point: int = text.find(".")
	var integer_text: String = text if point < 0 else text.left(point)
	var decimal_separator: String = GFVariantData.get_option_string(options, "decimal_separator")
	var group_separator: String = GFVariantData.get_option_string(options, "group_separator")
	var width: int = GFVariantData.get_option_int(options, "grouping_size")
	var digits: int = integer_text.length()
	if integer_text.begins_with("-") or integer_text.begins_with("+"):
		digits -= 1
	var groups: int = ceili(float(digits) / float(width)) - 1 if grouping else 0
	var length: int = text.length() + groups * group_separator.length()
	if point >= 0:
		length += decimal_separator.length() - 1
	if length > 8192:
		return ""
	if grouping:
		integer_text = _group_integer_part(
			integer_text,
			width,
			group_separator
		)
	return integer_text if point < 0 else integer_text + decimal_separator + text.substr(point + 1)


## 从分组基数取得十进制宽度。
## [br]
## @api private
static func _group_width(options: Dictionary) -> int:
	return 4 if GFVariantData.get_option_int(options, "group_base") == 10000 else 3


## 保留整数符号，按独立宽度插入展示分隔符；调用方已检查总长度。
## [br]
## @api private
static func _group_integer_part(
	text: String,
	width: int,
	separator: String
) -> String:
	var sign_text: String = ""
	var body: String = text
	if body.begins_with("-") or body.begins_with("+"):
		sign_text = body.left(1)
		body = body.substr(1)
	var groups: PackedStringArray = PackedStringArray()
	var first_size: int = body.length() % width
	if first_size == 0:
		first_size = width
	var _appended_first: bool = groups.append(body.left(first_size))
	for index: int in range(
		first_size,
		body.length(),
		width
	):
		var _appended: bool = groups.append(body.substr(index, width))
	return sign_text + separator.join(groups)


## 创建稳定的公开结果记录。
## [br]
## @api private
static func _result(
	ok: bool,
	text: String,
	error: String,
	notation_used: String = "",
	fallback_reason: String = ""
) -> Dictionary:
	return {
		"ok": ok,
		"text": text,
		"error": error,
		"notation_used": notation_used,
		"fallback_reason": fallback_reason,
		"policy_error_kind": "",
		"path": "",
	}
