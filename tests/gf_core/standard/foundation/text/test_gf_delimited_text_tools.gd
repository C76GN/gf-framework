## 测试顶层分隔符扫描工具。
extends GutTest


func test_split_top_level_ignores_nested_quotes_and_brackets() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level(
		"a, call(1, 2), 'x,y', [z,{w,q}]",
		",",
		{ "trim_parts": true }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "匹配的引号和括号不应产生错误。")
	var parts: Array[String] = _get_string_array(report, "parts")
	assert_eq(
		parts,
		["a", "call(1, 2)", "'x,y'", "[z,{w,q}]"],
		"只应在顶层逗号处分割。"
	)


func test_split_top_level_supports_multi_character_delimiter() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level(
		"a || b || func(c || d)",
		"||",
		{ "trim_parts": true }
	)
	var parts: Array[String] = _get_string_array(report, "parts")

	assert_eq(
		parts,
		["a", "b", "func(c || d)"],
		"多字符分隔符也应遵守顶层规则。"
	)


func test_split_top_level_can_drop_empty_parts() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level(
		"a,, b,",
		",",
		{
			"trim_parts": true,
			"allow_empty": false,
		}
	)
	var parts: Array[String] = _get_string_array(report, "parts")

	assert_eq(parts, ["a", "b"], "禁用空片段时应过滤连续或尾部分隔符。")


func test_split_top_level_whitespace_mode_groups_outer_whitespace() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level(
		"run  call(\"a b\")\tfinal [x y]",
		"",
		{
			"delimiter_mode": GFDelimitedTextTools.DELIMITER_MODE_WHITESPACE,
			"allow_empty": false,
		}
	)
	var parts: Array[String] = _get_string_array(report, "parts")

	assert_eq(
		parts,
		["run", "call(\"a b\")", "final", "[x y]"],
		"空白分隔模式不应拆开引号或括号内空白。"
	)


func test_split_top_level_reports_unmatched_opening() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level("a, func(1, 2", ",")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未闭合括号应进入结构化错误。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "error"),
		GFDelimitedTextTools.ERROR_UNMATCHED_OPENING,
		"错误类型应指出存在未闭合开启符。"
	)


func test_split_top_level_reports_unmatched_closing() -> void:
	var report: Dictionary = GFDelimitedTextTools.split_top_level("a, b]", ",")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "多余关闭符应进入结构化错误。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "error"),
		GFDelimitedTextTools.ERROR_UNMATCHED_CLOSING,
		"错误类型应指出关闭符没有匹配开启符。"
	)


func test_find_top_level_delimiters_returns_spans() -> void:
	var report: Dictionary = GFDelimitedTextTools.find_top_level_delimiters("a,(b,c),d", ",")
	var delimiter_spans: Array[Vector2i] = _get_vector2i_array(report, "delimiter_spans")

	assert_eq(
		delimiter_spans,
		[Vector2i(1, 2), Vector2i(7, 8)],
		"扫描报告应只返回顶层分隔符位置。"
	)


func _get_string_array(report: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw_value: Variant = report.get(key, [])
	if not raw_value is Array:
		return result
	var raw_array: Array = raw_value
	for item: Variant in raw_array:
		if item is String:
			var text: String = item
			result.append(text)
	return result


func _get_vector2i_array(report: Dictionary, key: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw_value: Variant = report.get(key, [])
	if not raw_value is Array:
		return result
	var raw_array: Array = raw_value
	for item: Variant in raw_array:
		if item is Vector2i:
			var span: Vector2i = item
			result.append(span)
	return result
