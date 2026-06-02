@tool

# GF Audio Bank Inspector: 在 Inspector 中辅助检查音频集合。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_AUDIO_BANK_BASE = preload("res://addons/gf/standard/utilities/audio/gf_audio_bank.gd")
const _GF_AUDIO_BANK_TOOLS = preload("res://addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd")
const _GF_VALIDATION_DIAGNOSTIC_ADAPTER = preload("res://addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return object is _GF_AUDIO_BANK_BASE


func _parse_begin(object: Object) -> void:
	if not (object is GFAudioBank):
		return
	var bank: GFAudioBank = object

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GFAudioBankInspector"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_custom_control(root)

	var header: Label = Label.new()
	header.text = "GF Audio Bank"
	header.modulate = Color(0.4, 0.8, 1.0)
	root.add_child(header)

	var validate_button: Button = Button.new()
	validate_button.text = "验证播放配置"
	validate_button.tooltip_text = "检查音频片段、资源路径和音频总线。"
	root.add_child(validate_button)

	var scan_root_input: LineEdit = LineEdit.new()
	scan_root_input.text = "res://audio"
	scan_root_input.placeholder_text = "扫描目录，例如 res://audio"
	root.add_child(scan_root_input)

	var import_options: HBoxContainer = HBoxContainer.new()
	root.add_child(import_options)

	var id_mode_option: OptionButton = OptionButton.new()
	id_mode_option.tooltip_text = "选择导入后生成 clip_id 的方式。"
	id_mode_option.add_item("文件名", _GF_AUDIO_BANK_TOOLS.ClipIdMode.BASENAME)
	id_mode_option.add_item("相对路径", _GF_AUDIO_BANK_TOOLS.ClipIdMode.RELATIVE_PATH)
	id_mode_option.add_item("完整路径", _GF_AUDIO_BANK_TOOLS.ClipIdMode.FULL_PATH)
	id_mode_option.select(1)
	import_options.add_child(id_mode_option)

	var overwrite_check: CheckBox = CheckBox.new()
	overwrite_check.text = "覆盖"
	overwrite_check.tooltip_text = "开启后，同 ID 的现有片段会被扫描结果替换。"
	import_options.add_child(overwrite_check)

	var include_addons_check: CheckBox = CheckBox.new()
	include_addons_check.text = "含 addons"
	include_addons_check.tooltip_text = "默认跳过 addons，避免误导入插件资源。"
	import_options.add_child(include_addons_check)

	var bus_input: LineEdit = LineEdit.new()
	bus_input.placeholder_text = "默认 Bus，可空"
	root.add_child(bus_input)

	var import_button: Button = Button.new()
	import_button.text = "扫描并导入"
	import_button.tooltip_text = "把目录中的音频资源加入当前 GFAudioBank。"
	root.add_child(import_button)

	var report_label: Label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	report_label.modulate = Color(0.8, 0.8, 0.8)
	root.add_child(report_label)
	var _validate_connected: int = validate_button.pressed.connect(
		_on_validate_pressed.bind(report_label, bank),
		CONNECT_DEFERRED as Object.ConnectFlags
	)
	var _import_connected: int = import_button.pressed.connect(
		_on_import_pressed.bind(
			report_label,
			bank,
			scan_root_input,
			id_mode_option,
			overwrite_check,
			include_addons_check,
			bus_input
		),
		CONNECT_DEFERRED as Object.ConnectFlags
	)


# --- 框架内部方法 ---

## 将校验报告压缩为 Inspector tooltip 文本。
## [br]
## @api framework_internal
## [br]
## @param report: GFValidationReport 实例。
## [br]
## @return: 适合 Inspector tooltip 展示的短文本。
static func format_report_tooltip(report: RefCounted) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var diagnostics: Array = _GF_VALIDATION_DIAGNOSTIC_ADAPTER.report_to_diagnostics(report)
	for diagnostic: Dictionary in diagnostics:
		var kind: String = GFVariantData.get_option_string(diagnostic, "kind", "unknown")
		var message: String = GFVariantData.get_option_string(diagnostic, "message")
		_append_packed_string(lines, "%s: %s" % [kind, message])
		if lines.size() >= 8:
			_append_packed_string(lines, "...")
			break
	return "\n".join(lines)


# --- 私有/辅助方法 ---

func _update_validation_report(label: Label, bank: GFAudioBank) -> void:
	if label == null or bank == null:
		return

	var report: GFValidationReport = _GF_AUDIO_BANK_TOOLS.validate_bank_playback(bank, {
		"check_resource_exists": true,
		"check_bus_exists": true,
	})
	label.text = report.make_summary("GFAudioBank")
	label.tooltip_text = format_report_tooltip(report)
	if report.get_error_count() > 0:
		label.modulate = Color(1.0, 0.45, 0.35)
	elif report.get_warning_count() > 0:
		label.modulate = Color(1.0, 0.78, 0.35)
	else:
		label.modulate = Color(0.45, 0.9, 0.55)


func _update_import_report(
	label: Label,
	bank: GFAudioBank,
	root_input: LineEdit,
	id_mode_option: OptionButton,
	overwrite_check: CheckBox,
	include_addons_check: CheckBox,
	bus_input: LineEdit
) -> void:
	if label == null or bank == null:
		return

	var root_path: String = root_input.text.strip_edges() if root_input != null else "res://audio"
	if root_path.is_empty():
		root_path = "res://audio"
	var options: Dictionary = {
		"id_mode": id_mode_option.get_selected_id() if id_mode_option != null else _GF_AUDIO_BANK_TOOLS.ClipIdMode.RELATIVE_PATH,
		"base_path": root_path,
		"overwrite": overwrite_check.button_pressed if overwrite_check != null else false,
		"include_addons": include_addons_check.button_pressed if include_addons_check != null else false,
		"bus_name": bus_input.text.strip_edges() if bus_input != null else "",
	}
	var report: GFValidationReport = _GF_AUDIO_BANK_TOOLS.sync_bank_from_scan(bank, root_path, options)
	bank.emit_changed()
	label.text = "%s\n扫描: %d, 新增/覆盖: %d, 跳过: %d" % [
		report.make_summary("GFAudioBank Import"),
		GFVariantData.get_option_int(report.metadata, "scanned_count", 0),
		GFVariantData.get_option_int(report.metadata, "added_count", 0),
		GFVariantData.get_option_int(report.metadata, "skipped_count", 0),
	]
	label.tooltip_text = format_report_tooltip(report)
	if report.get_error_count() > 0:
		label.modulate = Color(1.0, 0.45, 0.35)
	elif report.get_warning_count() > 0:
		label.modulate = Color(1.0, 0.78, 0.35)
	else:
		label.modulate = Color(0.45, 0.9, 0.55)


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


# --- 信号处理函数 ---

func _on_validate_pressed(label: Label, bank: GFAudioBank) -> void:
	_update_validation_report(label, bank)


func _on_import_pressed(
	label: Label,
	bank: GFAudioBank,
	root_input: LineEdit,
	id_mode_option: OptionButton,
	overwrite_check: CheckBox,
	include_addons_check: CheckBox,
	bus_input: LineEdit
) -> void:
	_update_import_report(label, bank, root_input, id_mode_option, overwrite_check, include_addons_check, bus_input)
