@tool
extends GutTest

const _DOCK = preload("res://addons/gf/tools/ui_review/editor/gf_ui_review_dock.gd")
const _WORKER = preload("res://addons/gf/tools/ui_review/editor/gf_ui_review_worker.gd")


func test_page_review_builds_reproducible_cases_without_an_animation_recipe() -> void:
	# 游戏测试进程中只使用原生输入控件，编辑器资源选择器由编辑器实播覆盖。
	var dock: _DOCK = _DOCK.new()
	autofree(dock)
	dock._sizes = LineEdit.new()
	dock._state = LineEdit.new()
	dock._locales = LineEdit.new()
	dock._scales = LineEdit.new()
	dock._time = SpinBox.new()
	for field: Control in [
		dock._sizes,
		dock._state,
		dock._locales,
		dock._scales,
		dock._time,
	]:
		dock.add_child(field)
	dock._sizes.text = "480x270,640×360"
	dock._locales.text = "zh,en"
	dock._scales.text = "100,125"
	dock._state.text = "archive"
	dock._time.value = 1
	var cases: Array[Dictionary] = dock._cases()
	assert_eq(
		cases.size(),
		8
	)
	var expected: Array[Dictionary] = []
	for size: Vector2i in [Vector2i(480, 270), Vector2i(640, 360)]:
		for locale: String in ["zh", "en"]:
			for percent: int in [100, 125]:
				expected.append(
					{
						"width": size.x,
						"height": size.y,
						"locale": locale,
						"scale": percent,
						"state": "archive",
						"seconds": 1.0,
						"seed": 1,
					}
				)
	assert_eq(cases, expected)
	dock._scales.text = "0"
	assert_true(dock._cases().is_empty())


func test_interactive_launch_failure_reaches_the_dock() -> void:
	var dock: _DOCK = autofree(_DOCK.new())
	dock._status = Label.new()
	dock.add_child(dock._status)
	dock._folder = "user://gf-review-%s" % Time.get_ticks_usec()
	assert_eq(
		DirAccess.make_dir_recursive_absolute(dock._folder),
		OK
	)
	var path: String = dock._folder.path_join("report.json")
	var report: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var failure: String = "实播在场景就绪前结束"
	var written: bool = report.store_string(
		JSON.stringify(
			{
				"interactive": true,
				"message": "",
				"results": [
					{ "index": 0, "error": failure },
				],
			}
		)
	)
	report.close()
	assert_true(written)
	dock._process(0.0)
	assert_string_contains(dock._status.text, failure)
	assert_false(dock._status.text.contains("实播已结束"))
	assert_eq(
		DirAccess.remove_absolute(path),
		OK
	)
	assert_eq(
		DirAccess.remove_absolute(dock._folder),
		OK
	)


func test_label_measurement_respects_automatic_translation() -> void:
	var translation: Translation = Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(&"GF_UI_REVIEW_LABEL", &"Translated sample")
	TranslationServer.add_translation(translation)
	var label: Label = add_child_autofree(Label.new())
	label.text = "GF_UI_REVIEW_LABEL"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	var rows: Array[Dictionary] = []
	_WORKER._measure(
		label,
		label,
		rows
	)
	assert_eq(
		str(rows[0].source_text),
		"GF_UI_REVIEW_LABEL"
	)
	assert_eq(
		str(rows[0].text),
		"Translated sample"
	)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rows.clear()
	_WORKER._measure(
		label,
		label,
		rows
	)
	assert_eq(
		str(rows[0].text),
		"GF_UI_REVIEW_LABEL"
	)
	TranslationServer.remove_translation(translation)
