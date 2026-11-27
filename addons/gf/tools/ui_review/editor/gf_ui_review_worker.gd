# 专用实际游戏进程。以宿主项目的完整配置运行一次显式选择的场景和显示条件。
extends SceneTree


# --- Godot 生命周期方法 ---

func _initialize() -> void:
	call_deferred("_capture")


# --- 私有/辅助方法 ---

## 应用真实窗口、语言与缩放，运行指定的项目样例并记录图片及布局。
## [br]
## @api private
func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Dictionary:
		quit(2)
		return
	var job: Dictionary = parsed
	var cases: Array = job.cases
	var index: int = args[1].to_int()
	if index < 0 or index >= cases.size():
		quit(2)
		return
	var folder: String = args[0].get_base_dir()
	var options: Dictionary = cases[index]
	var width: int = options.width
	var height: int = options.height
	var locale: String = options.locale
	var scale: float = options.scale
	var seconds: float = options.seconds
	var scene_path: String = job.scene
	var fixture_seed: int = options.seed
	var private_dir: String = str(job.private_dir).path_join("case_%03d" % index).replace("\\", "/").simplify_path()
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not user_dir.to_lower().begins_with(private_dir.to_lower() + "/"):
		_fail(
			folder,
			index,
			"运行目录未隔离：" + user_dir
		)
		return
	root.size = Vector2i(width, height)
	TranslationServer.set_locale(locale)
	var baseline_scale: float = root.content_scale_factor
	root.content_scale_factor = baseline_scale * scale / 100.0
	seed(fixture_seed)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_fail(
			folder,
			index,
			"无法载入样例 " + scene_path
		)
		return
	var fixture: Node = packed.instantiate()
	if fixture == null:
		_fail(
			folder,
			index,
			"无法创建样例"
		)
		return
	if fixture.has_method(&"configure_ui_review"):
		fixture.call(
			&"configure_ui_review",
			options.duplicate(true)
		)
	root.add_child(fixture)
	current_scene = fixture
	for frame: int in 3:
		await process_frame
	if fixture.has_method(&"prepare_ui_review"):
		await fixture.call(
			&"prepare_ui_review",
			options.duplicate(true)
		)
	else:
		root.content_scale_factor = baseline_scale * scale / 100.0
		TranslationServer.set_locale(locale)
	if job.get("interactive", false):
		if not _write(
			folder.path_join("case_%03d.json" % index),
			{ "played": true }
		):
			quit(1)
		return
	if root.size != Vector2i(width, height):
		_fail(
			folder,
			index,
			"游戏窗口与要求的采样尺寸不同"
		)
		return
	if TranslationServer.get_locale() != TranslationServer.standardize_locale(locale):
		_fail(
			folder,
			index,
			"实际游戏语言与要求的采样语言不同"
		)
		return
	if fixture.has_method(&"sample_ui_review"):
		fixture.call(&"sample_ui_review", seconds)
	elif seconds > 0.0:
		await create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail(
			folder,
			index,
			"当前图形后端没有输出画面"
		)
		return
	var filename: String = "case_%03d.png" % index
	if image.save_png(folder.path_join(filename)) != OK:
		_fail(
			folder,
			index,
			"无法保存 " + filename
		)
		return
	var controls: Array[Dictionary] = []
	_measure(
		fixture,
		fixture,
		controls
	)
	var result: Dictionary = {
		"case": options,
		"image": filename,
		"actual_locale": TranslationServer.get_locale(),
		"window_size": [root.size.x, root.size.y],
		"content_scale": root.content_scale_factor,
		"controls": controls,
	}
	var written: bool = _write(
		folder.path_join("case_%03d.json" % index),
		result
	)
	quit(0 if written else 1)


## 保存真实可见控件的布局、文本和输入属性，供窗口间复核。
## [br]
## @api private
static func _measure(
	node: Node,
	scene: Node,
	output: Array[Dictionary]
) -> void:
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			return
		var rect: Rect2 = control.get_global_rect()
		var record: Dictionary = {
			"path": String(scene.get_path_to(control)),
			"rect": [
				rect.position.x,
				rect.position.y,
				rect.size.x,
				rect.size.y,
			],
			"focus": control.focus_mode,
			"mouse_filter": control.mouse_filter,
			"clips": control.clip_contents,
		}
		if control is Label:
			var label: Label = control as Label
			record.source_text = label.text
			record.text = label.atr(label.text)
			record.lines = label.get_line_count()
		output.append(record)
	for child: Node in node.get_children():
		_measure(
			child,
			scene,
			output
		)


## 保存错误供编辑器定位到当前组合。
## [br]
## @api private
func _fail(
	folder: String,
	index: int,
	message: String
) -> void:
	var written: bool = _write(
		folder.path_join("case_%03d.json" % index),
		{ "error": message }
	)
	quit(1 if written else 2)


## 每个进程只写自己的用例结果。
## [br]
## @api private
func _write(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	return file != null and file.store_string(JSON.stringify(value, "\t"))
