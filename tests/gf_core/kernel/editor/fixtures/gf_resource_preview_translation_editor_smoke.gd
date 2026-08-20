@tool

# 验证 CSV Translation 资源不会被 GF 通用 Resource 预览器截获。
extends EditorPlugin


# --- 枚举 ---

enum SmokePhase {
	WAIT_EDITOR_IDLE,
	WAIT_PREVIEW,
}


# --- 常量 ---

const _GF_RESOURCE_PREVIEW_GENERATOR_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_preview_generator.gd")
const _CSV_PATH: String = "res://preview_translation.csv"
const _EN_TRANSLATION_PATH: String = "res://preview_translation.en.translation"
const _ZH_TRANSLATION_PATH: String = "res://preview_translation.zh.translation"
const _MESSAGE_KEY: StringName = &"GF_PREVIEW_SMOKE"
const _PREVIEW_USERDATA: StringName = &"gf_resource_preview_translation_editor_smoke"
const _EN_MESSAGE: String = "Preview"
const _ZH_MESSAGE: String = "Preview zh"
const _STABLE_FRAME_COUNT: int = 5
const _DEADLINE_MSEC: int = 60_000


# --- 私有变量 ---

var _phase: SmokePhase = SmokePhase.WAIT_EDITOR_IDLE
var _remaining_stable_frames: int = _STABLE_FRAME_COUNT
var _deadline_msec: int = 0
var _finished: bool = false


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_deadline_msec = Time.get_ticks_msec() + _DEADLINE_MSEC
	var connect_error: int = get_tree().process_frame.connect(_on_process_frame)
	if connect_error != OK:
		_fail("editor process frame signal could not be connected")


func _exit_tree() -> void:
	var process_frame_signal: Signal = get_tree().process_frame
	if process_frame_signal.is_connected(_on_process_frame):
		process_frame_signal.disconnect(_on_process_frame)


# --- 私有/辅助方法 ---

func _validate_imports_and_queue_preview(resource_filesystem: EditorFileSystem) -> void:
	var csv_type: String = resource_filesystem.get_file_type(_CSV_PATH)
	if csv_type != "Translation":
		_fail("CSV import type changed: %s" % csv_type)
		return

	var en_translation: Translation = _load_translation(
		_EN_TRANSLATION_PATH,
		"en",
		_EN_MESSAGE
	)
	if en_translation == null:
		return
	var zh_translation: Translation = _load_translation(
		_ZH_TRANSLATION_PATH,
		"zh",
		_ZH_MESSAGE
	)
	if zh_translation == null:
		return

	var translation_types: PackedStringArray = PackedStringArray([
		"Translation",
		String(en_translation.get_class()),
		String(zh_translation.get_class()),
	])
	if not _validate_generator_declines_types(translation_types):
		return

	var resource_previewer: EditorResourcePreview = EditorInterface.get_resource_previewer()
	if resource_previewer == null:
		_fail("editor resource preview singleton was unavailable")
		return

	_phase = SmokePhase.WAIT_PREVIEW
	resource_previewer.queue_resource_preview(
		_CSV_PATH,
		self,
		&"_on_resource_preview_ready",
		_PREVIEW_USERDATA
	)


func _load_translation(
	translation_path: String,
	expected_locale: String,
	expected_message: String
) -> Translation:
	var resource: Resource = ResourceLoader.load(translation_path)
	if not resource is Translation:
		_fail("imported locale is not a Translation: %s" % translation_path)
		return null
	var translation: Translation = resource
	if translation.get_locale() != expected_locale:
		_fail(
			"imported locale changed: %s=%s"
			% [translation_path, translation.get_locale()]
		)
		return null
	var translated_message: String = String(translation.get_message(_MESSAGE_KEY))
	if translated_message != expected_message:
		_fail(
			"imported message changed: %s=%s"
			% [translation_path, translated_message]
		)
		return null
	return translation


func _validate_generator_declines_types(resource_types: PackedStringArray) -> bool:
	var generator_value: Variant = _GF_RESOURCE_PREVIEW_GENERATOR_SCRIPT.new()
	if not generator_value is EditorResourcePreviewGenerator:
		_fail("GF resource preview generator could not be instantiated")
		return false
	var preview_generator: EditorResourcePreviewGenerator = generator_value
	for resource_type: String in resource_types:
		var handles_value: Variant = preview_generator.call(&"_handles", resource_type)
		if not handles_value is bool:
			_fail("GF resource preview type policy returned a non-bool value")
			return false
		var handles_type: bool = handles_value
		if handles_type:
			_fail("GF resource preview generator claimed translation type: %s" % resource_type)
			return false
	return true


func _fail(message: String) -> void:
	push_error("GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_FAILED: %s" % message)
	_finish(1)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	get_tree().call_deferred(&"quit", exit_code)


# --- 信号回调方法 ---

func _on_process_frame() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() >= _deadline_msec:
		_fail("editor smoke deadline expired during phase %d" % _phase)
		return
	if _phase != SmokePhase.WAIT_EDITOR_IDLE:
		return

	var resource_filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if resource_filesystem == null:
		return
	if resource_filesystem.is_scanning() or resource_filesystem.is_importing():
		_remaining_stable_frames = _STABLE_FRAME_COUNT
		return

	_remaining_stable_frames -= 1
	if _remaining_stable_frames > 0:
		return
	_validate_imports_and_queue_preview(resource_filesystem)


func _on_resource_preview_ready(
	preview_path: String,
	_preview: Texture2D,
	_thumbnail_preview: Texture2D,
	userdata: Variant
) -> void:
	if _finished:
		return
	if _phase != SmokePhase.WAIT_PREVIEW:
		_fail("resource preview callback arrived in an unexpected phase")
		return
	if preview_path != _CSV_PATH:
		_fail("resource preview callback path changed: %s" % preview_path)
		return
	if userdata != _PREVIEW_USERDATA:
		_fail("resource preview callback userdata changed")
		return

	print("GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK")
	_finish(0)
