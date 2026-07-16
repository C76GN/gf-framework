extends GutTest


# --- 常量 ---

const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_empty_builder_builds_empty_source() -> void:
	var builder: GFSourceBuilder = GFSourceBuilder.new()

	assert_eq(builder.build(), "", "空 SourceBuilder 不应生成孤立换行。")


func test_builder_formats_docs_sections_and_indentation() -> void:
	var builder: GFSourceBuilder = GFSourceBuilder.new()

	builder.doc("Example: generated source.")
	builder.doc()
	builder.section("公共方法")
	builder.line("static func run() -> void:")
	builder.indent()
	builder.line("if true:")
	builder.indent()
	builder.line("return")
	builder.dedent(2)
	var source: String = builder.build()

	assert_eq(
		source,
		"## Example: generated source.\n##\n# --- 公共方法 ---\n\nstatic func run() -> void:\n\tif true:\n\t\treturn\n",
		"SourceBuilder 应稳定生成文档注释、section、空行和 tab 缩进。"
	)


func test_builder_splits_multiline_documentation_comments() -> void:
	var builder: GFSourceBuilder = GFSourceBuilder.new()

	builder.doc("First line.\n\nSecond line.\r\nThird line.")
	var source: String = builder.build()

	assert_eq(source, "## First line.\n##\n## Second line.\n## Third line.\n", "多行文档注释应逐行生成合法 GDScript 注释。")


func test_builder_clear_resets_source_and_indent() -> void:
	var builder: GFSourceBuilder = GFSourceBuilder.new()

	builder.line("func old() -> void:")
	builder.indent()
	builder.line("pass")
	builder.clear()
	builder.line("func fresh() -> void:")
	builder.indent()
	builder.line("pass")
	var source: String = builder.build()

	assert_eq(source, "func fresh() -> void:\n\tpass\n", "clear() 应清空旧内容并重置缩进。")


func test_variant_access_json_compatible_replaces_non_finite_floats() -> void:
	var sanitized: Variant = GF_VARIANT_ACCESS.to_json_compatible({
		"nan": NAN,
		"inf": INF,
		"items": [-INF],
	})
	var text: String = JSON.stringify(sanitized)

	assert_false(text.contains(":null"), "JSON 兼容清洗不应把非有限 float 交给 JSON.stringify 替换成 null。")
	assert_true(text.contains("\"NaN\""), "NaN 应使用稳定文本。")
	assert_true(text.contains("\"INF\""), "INF 应使用稳定文本。")
