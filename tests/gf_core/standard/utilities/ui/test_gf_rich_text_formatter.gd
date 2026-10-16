## 测试 GFRichTextFormatter 的 BBCode 转义、Markdown 子集转换与占位符替换。
extends GutTest


# --- 测试方法 ---

## 验证普通文本模式会转义 BBCode 控制字符。
func test_plain_markup_escapes_bbcode() -> void:
	var result: String = GFRichTextFormatter.to_bbcode(
		"[b]Hello[/b]",
		{ "markup": GFRichTextFormatter.MARKUP_PLAIN, }
	)

	assert_eq(
		result,
		"[lb]b[rb]Hello[lb]/b[rb]",
		"普通文本不应被 RichTextLabel 当作 BBCode 执行。"
	)


## 验证 Markdown 子集会转换为 BBCode，未识别的 BBCode 会保持转义。
func test_markdown_to_bbcode_converts_supported_subset_safely() -> void:
	var result: String = GFRichTextFormatter.markdown_to_bbcode("**Bold** *It* [Link](https://example.com) ![Alt](res://icon.png) `code [x]` ~~Gone~~ [raw]")

	assert_eq(
		result,
		"[b]Bold[/b] [i]It[/i] [url=https://example.com]Link[/url] [img]res://icon.png[/img] [code]code [lb]x[rb][/code] [s]Gone[/s] [lb]raw[rb]",
		"Markdown 转换只应生成受支持的 BBCode 标签。"
	)


## 验证变量替换默认会转义变量值。
func test_replace_variables_escapes_values_by_default() -> void:
	var result: String = GFRichTextFormatter.to_bbcode(
		"Hello {{name}}",
		{
			"markup": GFRichTextFormatter.MARKUP_PLAIN,
			"variables": { "name": "[Ada]", },
		}
	)

	assert_eq(
		result,
		"Hello [lb]Ada[rb]",
		"变量值默认应安全嵌入 BBCode 文本。"
	)


## 验证变量解析回调和缺失变量占位文本。
func test_replace_variables_uses_resolver_and_missing_text() -> void:
	var resolver: Callable = func(variable_name: String) -> Variant:
		if variable_name == "known":
			return "ok"
		return null

	var result: String = GFRichTextFormatter.replace_variables(
		"{{known}}/{{missing}}",
		{},
		resolver,
		{ "missing_variable_text": "-", }
	)

	assert_eq(
		result,
		"ok/-",
		"resolver 应可提供变量值，缺失变量应使用配置文本。"
	)


## 验证 token 替换只处理安全 token。
func test_replace_tokens_ignores_unsafe_token_names() -> void:
	var resolver: Callable = func(token: String) -> String:
		return "[img]res://icons/%s.png[/img]" % token

	var result: String = GFRichTextFormatter.replace_tokens("Press :confirm: and :bad token:", resolver)

	assert_eq(
		result,
		"Press [img]res://icons/confirm.png[/img] and :bad token:",
		"包含空格的 token 不应被交给 resolver 生成 BBCode。"
	)


## 验证错误类型的回调配置会安全退化，token 空值保持原文。
func test_invalid_callable_options_and_null_tokens_are_safe() -> void:
	var null_resolver: Callable = func(_token: String) -> Variant:
		return null

	var ignored_options_result: String = GFRichTextFormatter.to_bbcode(
		"Hello {{name}} :confirm:",
		{
			"markup": GFRichTextFormatter.MARKUP_PLAIN,
			"variables": { "name": "Ada", },
			"variable_resolver": "not_callable",
			"token_resolver": ["not_callable"],
		}
	)
	var null_token_result: String = GFRichTextFormatter.replace_tokens(":missing:", null_resolver)

	assert_eq(
		ignored_options_result,
		"Hello Ada :confirm:",
		"错误类型的 resolver 配置不应影响普通格式化。"
	)
	assert_eq(
		null_token_result,
		":missing:",
		"resolver 返回 null 时应保留原 token。"
	)


## 验证移除 BBCode 标签时保留已转义的字面量方括号。
func test_strip_bbcode_preserves_escaped_brackets() -> void:
	var escaped: String = GFRichTextFormatter.escape_bbcode("[value]")
	var result: String = GFRichTextFormatter.strip_bbcode("[b]Hi[/b] %s" % escaped)

	assert_eq(
		result,
		"Hi [value]",
		"strip_bbcode 应移除标签但保留 [lb]/[rb] 表达的字面量括号。"
	)
