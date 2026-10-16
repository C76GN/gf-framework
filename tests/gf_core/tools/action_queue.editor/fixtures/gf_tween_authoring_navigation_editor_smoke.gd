@tool

# 原生编辑器专用：通过真实创建对话框、官方 Inspector 控件和原生历史验收作者导航。
extends EditorPlugin

const _ACTIONS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")
const _STEPS_EDITOR_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_steps_editor_property.gd")
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")
var _actions: _ACTIONS_SCRIPT = null
var _config: GFTweenActionConfig = null
var _phase: int = -1
var _started_usec: int = 0
var _done: bool = false
var _stable_frames: int = 0
var _finishing: bool = false
var _exit_code: int = 0
var _cleanup_stage: int = 0
var _cleanup_started_usec: int = 0
var _cleanup_timeout_reported: bool = false
var _owned_files: Array[String] = []
var _retired_controls: Array[WeakRef] = []
var _history: UndoRedo = null
var _before_count: int = 0
var _saved_source: String = "res://navigation_named_roundtrip.tres"
var _duration_plan: GFTweenPreviewPlan = null
var _duration_time: float = 0.0
var _duration_probe_plan: GFTweenPreviewPlan = null
var _duration_probe_numeric: bool = false
var _duration_probe_registration: GFTweenPreviewRegistration = null
var _navigation_layout_frames: int = 0
var _navigation_retired_editor: WeakRef = null
var _recipe_snapshot: Dictionary = {}
var _runtime_target: Node2D = null
var _runtime_initial: Color = Color(
	0.2,
	0.3,
	0.4,
	0.7
)


func _enter_tree() -> void:
	_started_usec = Time.get_ticks_usec()
	set_process(true)


func _process(_delta: float) -> void:
	if _done:
		return
	if _finishing:
		_advance_cleanup()
		return
	if Time.get_ticks_usec() - _started_usec > 60_000_000:
		_reject("Timed out while waiting for the official Inspector authoring controls.")
		return
	if EditorInterface.get_resource_filesystem().is_scanning():
		_stable_frames = 0
		return
	if _phase < 0:
		_stable_frames += 1
		if _stable_frames < 3:
			return
		if not _check(
			GFExtensionSettings.is_extension_enabled("gf.action_queue"),
			"The isolated project did not statically enable the official action_queue contribution."
		):
			return
		_actions = _ACTIONS_SCRIPT.new()
		_phase = 0
		# Run from a process frame, not the deferred-message flush that can reject Creator.scan().
		_open_creation(1, "res://navigation_created_ui.tres")
		return
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var edited: Object = inspector.get_edited_object()
	if not edited is GFTweenActionConfig:
		return
	var config: GFTweenActionConfig = edited
	var panel: GFTweenPreviewPanel = _find_panel(inspector)
	var editor: EditorProperty = _find_editor(inspector, config)
	if panel == null or editor == null:
		return
	match _phase:
		0:
			if not _check_created(
				panel,
				config,
				"res://navigation_created_ui.tres",
				&"gf.preview.ui"
			):
				return
			_phase = 1
			_open_creation(0, "res://navigation_created_2d.tres")
		1:
			if config.resource_path != "res://navigation_created_2d.tres":
				return
			if not _check_created(
				panel,
				config,
				"res://navigation_created_2d.tres",
				&"gf.preview.2d"
			):
				return
			_config = GFTweenActionConfig.new()
			var first: GFTweenActionStep = _config.add_property_step(
				^"position:x",
				10.0,
				1.0
			)
			first.resource_name = "展开标题"
			first.transition_type = Tween.TRANS_LINEAR
			var parallel: GFTweenActionStep = _config.add_property_step(
				^"scale",
				Vector2.ONE * 1.2,
				0.5
			)
			parallel.parallel = true
			parallel.resource_name = "同步放大"
			var final_step: GFTweenActionStep = _config.add_property_step(
				^"position:y",
				20.0,
				0.25
			)
			final_step.resource_name = "落位"
			if not _check(
				_ACTIONS_SCRIPT.remember_created_preview(_config, 0),
				"Could not explicitly select the authoring fixture target."
			):
				return
			_phase = 2
			EditorInterface.edit_resource(_config)
		2:
			if config != _config:
				return
			var picker: OptionButton = _picker(editor)
			var field: GFEditorValueField = _field(editor, "Field_resource_name")
			if picker == null or field == null:
				return
			if not _check_names(
				editor,
				picker,
				field
			):
				return
			var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
			_history = manager.get_history_undo_redo(manager.get_object_history_id(_config))
			_before_count = _history.get_history_count()
			var input: LineEdit = _line_edit(field)
			if not _check(
				input != null,
				"The Resource name must have an editable native text field."
			):
				return
			_phase = 3
			input.text = "标题出现"
			input.text_changed.emit(input.text)
		3:
			if not _check(
				_config.steps[0].resource_name == "标题出现",
				"The name edit did not reach the copied native step."
			):
				return
			if not _check(
				_history.get_history_count() == _before_count + 1,
				"A name edit must add exactly one native history action."
			):
				return
			_phase = 4
			if not _check(
				_history.undo(),
				"Native Undo rejected the name action."
			):
				return
		4:
			if not _check(
				_config.steps[0].resource_name == "展开标题",
				"Native Undo did not restore the original name."
			):
				return
			_phase = 5
			if not _check(
				_history.redo(),
				"Native Redo rejected the name action."
			):
				return
		5:
			if not _check(
				_config.steps[0].resource_name == "标题出现",
				"Native Redo did not restore the new name."
			):
				return
			var timeline_node: Node = panel.find_child(
				"StepTimeline",
				true,
				false
			)
			if not timeline_node is Control:
				return
			var timeline: Control = timeline_node
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(
				82.0 + maxf(
					1.0,
					timeline.size.x - 90.0
				) * 0.2,
				33.0
			)
			_phase = 6
			timeline.gui_input.emit(click)
		6:
			var picker: OptionButton = _picker(editor)
			if not _check(
				picker != null and picker.selected == 1,
				"Clicking the parallel block must select its existing Steps form."
			):
				return
			_config.steps[2].target_value = "invalid"
			_config.emit_changed()
			_phase = 7
		7:
			var location_node: Node = panel.find_child(
				"LocateError",
				true,
				false
			)
			if not location_node is Button:
				return
			var location: Button = location_node
			if not _check(not location.disabled, "The structured value type error must offer field navigation."):
				return
			inspector.scroll_vertical = 0
			_navigation_layout_frames = 0
			_phase = 8
			location.pressed.emit()
		8:
			if not _navigation_layout_ready():
				return
			var picker: OptionButton = _picker(editor)
			var field: GFEditorValueField = _field(editor, "Field_target_value")
			if not _check(
				picker != null
				and picker.selected == 2
				and field != null,
				"The error must select step 3 and its value field."
			):
				return
			var focus: Control = get_viewport().gui_get_focus_owner()
			if not _check(
				focus != null and field.is_ancestor_of(focus),
				"The actual native value input must receive focus."
			):
				return
			if not _check(
				field.tooltip_text.contains("target_value"),
				"The selected field must show location feedback."
			):
				return
			if not _check(
				_visible_rect_in_inspector(field, inspector).has_area() and _control_fully_visible_in_inspector(focus, inspector),
				"Error navigation must reveal the field and the complete focused input after layout, not only assign offscreen focus."
			):
				return
			print("GF_TWEEN_ERROR_FIELD_VISIBLE_OK")
			var source_value: Variant = _config.steps[2].target_value
			var preserved: bool = false
			if source_value is String:
				var source_text: String = source_value
				preserved = source_text == "invalid"
			if not _check(preserved, "Error navigation must not rewrite the invalid source value."):
				return
			_config.steps[2].target_value = 20.0
			if not _claim_output(_saved_source):
				return
			if not _check(
				ResourceSaver.save(_config, _saved_source) == OK,
				"Could not save the named authoring resource."
			):
				return
			var loaded: Resource = ResourceLoader.load(
				_saved_source,
				"",
				ResourceLoader.CACHE_MODE_IGNORE_DEEP
			)
			if not loaded is GFTweenActionConfig:
				_reject("The saved resource did not reopen as a native Tween config.")
				return
			var restored: GFTweenActionConfig = loaded
			if not _check(
				restored.steps[0].resource_name == "标题出现"
				and restored.steps[1].resource_name == "同步放大"
				and restored.steps[2].resource_name == "落位",
				"Resource names were lost during the independent save/reopen."
			):
				return
			_config.steps[2].resource_name = "这是一段用于验证窄栏显示的较长中文步骤名称".repeat(4)
			_config.emit_changed()
			editor.update_property()
			_phase = 9
		9:
			var picker: OptionButton = _picker(editor)
			if not _check(
				picker != null
				and picker.clip_text
				and not picker.fit_to_longest_item,
				"The selected caption must not make the Inspector grow to the longest item."
			):
				return
			if not _check(
				picker.get_item_text(2).contains("…") and picker.get_item_tooltip(2).length() <= 256,
				"A long Chinese name must use bounded display and tooltip text."
			):
				return
			var group_node: Node = editor.find_child(
				"GroupStep_2",
				true,
				false
			)
			if not group_node is Button:
				_reject("The named group navigation button is missing.")
				return
			var group_button: Button = group_node
			if not _check(
				group_button.clip_text
				and group_button.text.length() < 64
				and group_button.tooltip_text.length() <= 256,
				"The compact group button must not use the full long name as its minimum width."
			):
				return
			if not _check(
				editor.get_combined_minimum_size().x <= 480.0,
				"Long names expanded the standard Inspector authoring minimum width."
			):
				return
			if not _save_view("res://navigation_inspector_names.png"):
				return
			var viewport_node: Node = panel.find_child(
				"PreviewViewport",
				true,
				false
			)
			if not viewport_node is GFTweenPreviewViewport:
				_reject("The official duration preview is missing.")
				return
			var preview: GFTweenPreviewViewport = viewport_node
			_duration_plan = preview.get_preview_plan()
			_duration_time = preview.get_time_seconds()
			var seconds_node: Node = panel.find_child(
				"TargetDurationSeconds",
				true,
				false
			)
			var apply_node: Node = panel.find_child(
				"ApplyDuration",
				true,
				false
			)
			if not seconds_node is SpinBox or not apply_node is Button:
				_reject("The complete duration editing controls are missing.")
				return
			var seconds: SpinBox = seconds_node
			var apply_button: Button = apply_node
			if not _check(not apply_button.disabled, "A current finite plan must allow a complete duration edit."):
				return
			seconds.set_value_no_signal(2.5)
			_before_count = _history.get_history_count()
			_phase = 10
			apply_button.pressed.emit()
		10:
			if not _check(
				_config.duration_scale == 2.0 and _history.get_history_count() == _before_count + 1,
				"The duration edit must submit exactly one native scale action."
			):
				return
			var viewport_node: Node = panel.find_child(
				"PreviewViewport",
				true,
				false
			)
			if not viewport_node is GFTweenPreviewViewport:
				_reject("Duration editing lost the official preview.")
				return
			var preview: GFTweenPreviewViewport = viewport_node
			if not _check(
				preview.get_preview_plan() == _duration_plan
				and preview.get_time_seconds() == _duration_time
				and preview.get_state() == &"paused",
				"Changing total duration must preserve the already inspected frozen session."
			):
				return
			_phase = 11
			if not _check(
				_history.undo(),
				"Native Undo rejected the total duration action."
			):
				return
		11:
			if not _check(
				_config.duration_scale == 1.0,
				"Native Undo did not restore the root scale."
			):
				return
			_phase = 12
			if not _check(
				_history.redo(),
				"Native Redo rejected the total duration action."
			):
				return
		12:
			if not _check(
				_config.duration_scale == 2.0,
				"Native Redo did not restore the new root scale."
			):
				return
			var presets_node: Node = editor.find_child(
				"TweenPresets",
				true,
				false
			)
			if not presets_node is OptionButton:
				_reject("The official recipe selector is missing.")
				return
			var presets: OptionButton = presets_node
			var fade_index: int = -1
			for index: int in range(presets.item_count):
				var id_value: Variant = presets.get_item_metadata(index)
				if id_value is String and id_value == "fade_in":
					fade_index = index
			if not _check(
				fade_index > 0 and not presets.disabled,
				"The current 2D authoring target must offer fade_in."
			):
				return
			_runtime_target = Node2D.new()
			_runtime_target.name = "RuntimeInitialWitness"
			_runtime_target.modulate = _runtime_initial
			_runtime_target.hide()
			add_child(_runtime_target)
			_before_count = _history.get_history_count()
			_phase = 13
			presets.select(fade_index)
			presets.item_selected.emit(fade_index)
		13:
			var confirmation: ConfirmationDialog = null
			for child: Node in editor.find_children(
				"*",
				"ConfirmationDialog",
				true,
				false
			):
				if child is ConfirmationDialog:
					var candidate: ConfirmationDialog = child
					if candidate.visible:
						confirmation = candidate
			if confirmation == null:
				return
			_phase = 14
			confirmation.get_ok_button().pressed.emit()
		14:
			var recipe_matches: bool = false
			if _config.steps.size() == 1:
				var recipe_step: GFTweenActionStep = _config.steps[0]
				if recipe_step != null and recipe_step.property_name == ^"modulate:a":
					var target_value: Variant = recipe_step.target_value
					if target_value is float:
						var target_number: float = target_value
						recipe_matches = target_number == 1.0
					elif target_value is int:
						var target_number: int = target_value
						recipe_matches = target_number == 1
			if not _check(recipe_matches, "Confirming fade_in must replace the steps through the actual recipe selector."):
				return
			if not _check(
				_config.duration_scale == 2.0 and _history.get_history_count() == _before_count + 1,
				"Recipe replacement must preserve root fields and add one native history action."
			):
				return
			var viewport_node: Node = panel.find_child(
				"PreviewViewport",
				true,
				false
			)
			if not viewport_node is GFTweenPreviewViewport:
				_reject("The recipe preview is missing.")
				return
			var preview: GFTweenPreviewViewport = viewport_node
			if not _check(
				_sample_alpha(preview.get_initial_values()) == 1.0,
				"Selecting fade_in must not silently apply the suggested sample initial value."
			):
				return
			var apply_node: Node = editor.find_child(
				"ApplyRecipeInitial",
				true,
				false
			)
			if not apply_node is Button:
				_reject("The explicit sample initial-value button is missing.")
				return
			var apply_button: Button = apply_node
			if not _check(not apply_button.disabled, "The sample initial value must be an explicit available UI action."):
				return
			_recipe_snapshot = _SNAPSHOT_SCRIPT.capture_editing(_config)
			_before_count = _history.get_history_count()
			_phase = 15
			apply_button.pressed.emit()
		15:
			var viewport_node: Node = panel.find_child(
				"PreviewViewport",
				true,
				false
			)
			if not viewport_node is GFTweenPreviewViewport:
				_reject("Applying sample initials lost the official preview.")
				return
			var preview: GFTweenPreviewViewport = viewport_node
			if not _check(
				_sample_alpha(preview.get_initial_values()) == 0.0
				and _sample_alpha(preview.get_current_values()) == 0.0
				and preview.get_state() == &"ready",
				"The actual explicit initial-value button must prepare the isolated fade_in sample with alpha zero."
			):
				return
			if not _check(
				_SNAPSHOT_SCRIPT.capture_editing(_config) == _recipe_snapshot and _history.get_history_count() == _before_count,
				"Sample initials must not modify the config or its native resource history."
			):
				return
			if not _check(
				is_instance_valid(_runtime_target) and _runtime_target.modulate == _runtime_initial,
				"Applying sample initials must not alter a real target's independently established runtime baseline."
			):
				return
			_open_duration_probe(false)
		16:
			if config != _config or not _check_duration_probe(
				panel,
				1.25,
				1.25,
				&"ready",
				true
			):
				return
			var seconds_node: Node = panel.find_child(
				"TargetDurationSeconds",
				true,
				false
			)
			var time_node: Node = panel.find_child(
				"PreviewTimeInput",
				true,
				false
			)
			if not seconds_node is SpinBox or not time_node is SpinBox:
				_reject("The prepared duration probe has no native duration or seek field.")
				return
			var seconds: SpinBox = seconds_node
			var time_input: SpinBox = time_node
			_phase = 17
			seconds.value = 3.75
			time_input.value = 0.625
		17:
			if config != _config or not _check_duration_probe(
				panel,
				1.25,
				3.75,
				&"paused"
			):
				return
			_config.steps[0].duration = 2.5
			_phase = 18
			_config.emit_changed()
		18:
			if config != _config or not _check_duration_probe(
				panel,
				1.25,
				3.75,
				&"paused",
				false,
				false
			):
				return
			var recapture_node: Node = panel.find_child(
				"Recapture",
				true,
				false
			)
			if not recapture_node is Button:
				_reject("The duration probe cannot explicitly prepare its changed source.")
				return
			var recapture: Button = recapture_node
			_phase = 19
			recapture.pressed.emit()
		19:
			if config != _config or not _check_duration_probe(
				panel,
				2.5,
				2.5,
				&"ready",
				true
			):
				return
			print("GF_TWEEN_DURATION_INITIAL_VALUE_OK %s" % ("numeric" if _duration_probe_numeric else "native"))
			_duration_probe_plan = null
			if _duration_probe_numeric:
				_open_navigation_visibility_probe()
			else:
				_open_duration_probe(true)
		20:
			if config != _config:
				return
			var location: Button = _location_button(panel)
			var picker: OptionButton = _picker(editor)
			if (
				location == null
				or picker == null
				or location.disabled
			):
				return
			location.pressed.emit()
			picker = _picker(editor)
			if picker == null:
				return
			picker.select(0)
			picker.item_selected.emit(0)
			inspector.grab_focus()
			inspector.scroll_vertical = 0
			_navigation_layout_frames = 0
			_phase = 21
		21:
			if config != _config or not _navigation_layout_ready():
				return
			var picker: OptionButton = _picker(editor)
			if not _check(
				picker != null
				and picker.selected == 0
				and inspector.scroll_vertical == 0
				and get_viewport().gui_get_focus_owner() == inspector,
				"A newer step selection must revoke the old deferred field reveal and preserve the current scroll and focus."
			):
				return
			var location: Button = _location_button(panel)
			if location == null or location.disabled:
				return
			location.pressed.emit()
			_config = _navigation_visibility_config()
			_phase = 22
			_navigation_layout_frames = 0
			EditorInterface.edit_resource(_config)
			inspector.grab_focus()
			inspector.scroll_vertical = 0
		22:
			if config != _config or not _navigation_layout_ready():
				return
			if not _check(
				inspector.scroll_vertical == 0 and get_viewport().gui_get_focus_owner() == inspector,
				"A retired source must not reveal its field or take focus in the replacement resource's Inspector."
			):
				return
			var location: Button = _location_button(panel)
			if location == null or location.disabled:
				return
			location.pressed.emit()
			_navigation_retired_editor = weakref(editor)
			_retired_controls.append(weakref(editor))
			_retired_controls.append(weakref(panel))
			# Native Inspector restores scroll per Resource after reopening; establish the expected cache before closing.
			inspector.scroll_vertical = 0
			inspector.edit(null)
			inspector.edit(_config)
			inspector.grab_focus()
			inspector.scroll_vertical = 0
			_navigation_layout_frames = 0
			_phase = 23
		23:
			if config != _config or not _navigation_layout_ready():
				return
			var retired_released: bool = _navigation_retired_editor != null and _navigation_retired_editor.get_ref() == null
			var scroll_preserved: bool = inspector.scroll_vertical == 0
			var focus_preserved: bool = get_viewport().gui_get_focus_owner() == inspector
			var retirement_state: Dictionary = {
				"retired_released": retired_released,
				"scroll_preserved": scroll_preserved,
				"focus_preserved": focus_preserved,
				"scroll_vertical": inspector.scroll_vertical,
			}
			print("GF_TWEEN_FIELD_REVEAL_RETIREMENT_STATE %s" % JSON.stringify(retirement_state))
			var retired_ok: bool = _check(retired_released, "Closing and reopening the same resource must release the retired step editor.")
			var scroll_ok: bool = _check(scroll_preserved, "The retired reveal callback must preserve the replacement form's explicit zero scroll.")
			var focus_ok: bool = _check(focus_preserved, "The retired reveal callback must preserve the replacement Inspector's focus.")
			if (
				not retired_ok
				or not scroll_ok
				or not focus_ok
			):
				return
			_navigation_retired_editor = null
			print("GF_TWEEN_FIELD_REVEAL_LIFECYCLE_OK")
			_begin_cleanup(0)


func _exit_tree() -> void:
	if _actions != null:
		_actions.cleanup()
	_actions = null
	_config = null
	_history = null
	_duration_plan = null
	_duration_probe_plan = null
	_navigation_retired_editor = null
	if _duration_probe_registration != null:
		_duration_probe_registration.release()
	_duration_probe_registration = null
	_recipe_snapshot.clear()
	if is_instance_valid(_runtime_target):
		_runtime_target.free()
	_runtime_target = null


func _navigation_visibility_config() -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var first: GFTweenActionStep = config.add_property_step(
		^"position:x",
		1.0,
		0.5
	)
	first.resource_name = "First navigation step"
	var second: GFTweenActionStep = config.add_property_step(
		^"position:y",
		1.0,
		0.5
	)
	second.resource_name = "Error navigation step"
	var selected: bool = _ACTIONS_SCRIPT.remember_created_preview(config, 0)
	if not _check(selected, "The navigation lifecycle probe requires an explicit native 2D purpose."):
		return null
	second.target_value = "invalid"
	return config


func _open_navigation_visibility_probe() -> void:
	_config = _navigation_visibility_config()
	if _config == null:
		return
	_phase = 20
	EditorInterface.edit_resource(_config)


func _navigation_layout_ready() -> bool:
	_navigation_layout_frames += 1
	return _navigation_layout_frames >= 3


func _location_button(panel: GFTweenPreviewPanel) -> Button:
	var node: Node = panel.find_child(
		"LocateError",
		true,
		false
	)
	if node is Button:
		var button: Button = node
		return button
	return null


func _control_fully_visible_in_inspector(control: Control, inspector: EditorInspector) -> bool:
	if not is_instance_valid(control):
		return false
	var original_rect: Rect2 = control.get_global_rect()
	return original_rect.has_area() and _visible_rect_in_inspector(control, inspector).encloses(original_rect)


func _visible_rect_in_inspector(control: Control, inspector: EditorInspector) -> Rect2:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return Rect2()
	var visible_rect: Rect2 = control.get_global_rect()
	if not visible_rect.has_area():
		return Rect2()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control: Control = ancestor
			if ancestor_control.clip_contents or ancestor_control == inspector:
				visible_rect = visible_rect.intersection(ancestor_control.get_global_rect())
				if not visible_rect.has_area():
					return Rect2()
		if ancestor == inspector:
			return visible_rect
		ancestor = ancestor.get_parent()
	return Rect2()


func _open_duration_probe(numeric: bool) -> void:
	_duration_probe_numeric = numeric
	_duration_probe_plan = null
	_config = GFTweenActionConfig.new()
	_config.enable_playback_control = numeric
	var property_name: NodePath = ^"duration_probe_progress" if numeric else ^"position:x"
	var step: GFTweenActionStep = _config.add_property_step(
		property_name,
		1.0,
		1.25
	)
	step.transition_type = Tween.TRANS_LINEAR
	if numeric:
		_duration_probe_registration = GFTweenPreviewRegistry.get_shared().register_adapter(
			self,
			{
				"id": "duration_initial_value_fixture",
				"revision": 1,
				"label": "Duration initial-value fixture",
				"properties": [
					{
						"name": "duration_probe_progress",
						"type": TYPE_FLOAT,
						"initial": 0.0,
						"minimum": 0.0,
						"maximum": 1.0,
					},
				],
			},
			DurationPreviewAdapter.new()
		)
		if not _check(
			_duration_probe_registration != null,
			"The numeric duration probe could not register its bounded isolated sample."
		):
			return
	elif not _check(
		_ACTIONS_SCRIPT.remember_created_preview(_config, 0),
		"The native duration probe lost its explicit 2D purpose."
	):
		return
	_phase = 16
	EditorInterface.edit_resource(_config)


func _check_duration_probe(
	panel: GFTweenPreviewPanel,
	plan_seconds: float,
	draft_seconds: float,
	expected_state: StringName,
	accept_new_plan: bool = false,
	source_current: bool = true
) -> bool:
	var seconds_node: Node = panel.find_child(
		"TargetDurationSeconds",
		true,
		false
	)
	var apply_node: Node = panel.find_child(
		"ApplyDuration",
		true,
		false
	)
	var viewport_node: Node = panel.find_child(
		"PreviewViewport",
		true,
		false
	)
	if (
		not seconds_node is SpinBox
		or not apply_node is Button
		or not viewport_node is GFTweenPreviewViewport
	):
		_reject("The duration probe is missing its official controls or preview.")
		return false
	var seconds: SpinBox = seconds_node
	var apply_button: Button = apply_node
	var preview: GFTweenPreviewViewport = viewport_node
	if not _check(
		preview.has_session()
		and preview.get_state() == expected_state
		and apply_button.disabled != source_current
		and seconds.editable == source_current,
		"The accepted duration draft must stay visible; only a current source may apply it."
	):
		return false
	if not _check(
		preview.get_duration_seconds() == plan_seconds,
		"The duration probe lost its actual accepted plan length."
	):
		return false
	if not _check(
		seconds.value == draft_seconds,
		"The initial/new plan must fill its actual duration; a same-plan refresh must retain the unapplied draft."
	):
		return false
	var plan: GFTweenPreviewPlan = preview.get_preview_plan()
	if not _check(
		plan != null,
		"The duration controls must correspond to a real accepted plan."
	):
		return false
	if _duration_probe_plan != null:
		var matches_plan: bool = plan == _duration_probe_plan
		if accept_new_plan:
			matches_plan = plan != _duration_probe_plan
		if not _check(matches_plan, "The duration draft check must distinguish the current frozen plan from a newly prepared plan."):
			return false
	if accept_new_plan:
		_duration_probe_plan = plan
	return _check(
		_config.duration_scale == 1.0,
		"Drafting or preparing must not apply a duration scale to the source config."
	)


func _open_creation(kind: int, path: String) -> void:
	if not _claim_output(path):
		return
	_actions.handle_menu_action(&"create_tween_config")
	var node: Node = EditorInterface.get_base_control().find_child(
		"GFTweenCreateDialog",
		true,
		false
	)
	if not node is EditorFileDialog:
		_reject("The official action did not create its native resource dialog.")
		return
	var dialog: EditorFileDialog = node
	var picker: OptionButton = null
	for child: Node in dialog.get_vbox().get_children():
		if child is OptionButton:
			var option: OptionButton = child
			if option.item_count == 3 and option.get_item_text(0) == "2D 移动偏移":
				picker = option
	if not _check(
		picker != null,
		"The real creation kind selector is missing."
	):
		return
	picker.select(kind)
	dialog.hide()
	dialog.file_selected.emit(path)


func _check_created(
	panel: GFTweenPreviewPanel,
	config: GFTweenActionConfig,
	path: String,
	target_id: StringName
) -> bool:
	if not _check(
		config.resource_path == path and FileAccess.file_exists(path),
		"The dialog did not save and inspect its new resource."
	):
		return false
	var node: Node = panel.find_child(
		"TargetKind",
		true,
		false
	)
	if not node is OptionButton:
		_reject("The official preview target selector is missing.")
		return false
	var picker: OptionButton = node
	var selected_value: Variant = picker.get_item_metadata(picker.selected)
	var matches_target: bool = false
	if selected_value is StringName:
		var selected_id: StringName = selected_value
		matches_target = selected_id == target_id
	if not _check(matches_target, "The explicit creation kind was lost before entering the Inspector."):
		return false
	var viewport_node: Node = panel.find_child(
		"PreviewViewport",
		true,
		false
	)
	if not viewport_node is GFTweenPreviewViewport:
		_reject("The official preview viewport is missing.")
		return false
	var preview: GFTweenPreviewViewport = viewport_node
	return _check(
		preview.has_session() and preview.get_state() == &"ready",
		"The created resource must be prepared without a second target selection or Play."
	)


func _check_names(
	editor: EditorProperty,
	picker: OptionButton,
	field: GFEditorValueField
) -> bool:
	if not _check(
		picker.item_count == 3
		and picker.get_item_text(0).contains("展开标题")
		and picker.get_item_text(1).contains("同步放大"),
		"Existing Resource names must appear in the step summaries."
	):
		return false
	if not _check(
		picker.get_item_text(0).contains("组 1")
		and picker.get_item_text(1).contains("组 1")
		and picker.get_item_text(2).contains("组 2"),
		"Serial groups and their parallel members are not explicit."
	):
		return false
	if not _check(
		editor.find_child(
			"StepGroups",
			true,
			false
		) != null,
		"The grouped navigation overview is missing."
	):
		return false
	var value: Variant = field.get_value()
	var matches_name: bool = false
	if value is String:
		var text_value: String = value
		matches_name = text_value == "展开标题"
	return _check(matches_name, "The name field must display the existing Resource.resource_name.")


func _find_editor(node: Node, config: Resource) -> EditorProperty:
	if node is EditorProperty and node.get_script() == _STEPS_EDITOR_SCRIPT:
		var editor: EditorProperty = node
		if editor.get_edited_object() == config:
			return editor
	for child: Node in node.get_children():
		var found: EditorProperty = _find_editor(child, config)
		if found != null:
			return found
	return null


func _find_panel(node: Node) -> GFTweenPreviewPanel:
	if node is GFTweenPreviewPanel:
		var panel: GFTweenPreviewPanel = node
		return panel
	for child: Node in node.get_children():
		var found: GFTweenPreviewPanel = _find_panel(child)
		if found != null:
			return found
	return null


func _picker(editor: EditorProperty) -> OptionButton:
	var node: Node = editor.find_child(
		"StepPicker",
		true,
		false
	)
	if node is OptionButton:
		var picker: OptionButton = node
		return picker
	_reject("The official step selector is missing.")
	return null


func _field(editor: EditorProperty, node_name: String) -> GFEditorValueField:
	var node: Node = editor.find_child(
		node_name,
		true,
		false
	)
	if node is GFEditorValueField:
		var field: GFEditorValueField = node
		return field
	_reject("The required official field is missing: %s." % node_name)
	return null


func _line_edit(field: GFEditorValueField) -> LineEdit:
	for child: Node in field.find_children(
		"*",
		"LineEdit",
		true,
		false
	):
		if child is LineEdit:
			var input: LineEdit = child
			return input
	return null


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_reject(message)
	return condition


func _sample_alpha(values: Dictionary) -> float:
	var color_value: Variant = values.get("modulate")
	if not color_value is Color:
		_reject("The isolated sample must expose its actual Color modulate value.")
		return NAN
	var color: Color = color_value
	return color.a


func _save_view(path: String) -> bool:
	var output_path: String = path
	var capture_path: String = OS.get_environment("GF_TWEEN_AUTHORING_SMOKE_CAPTURE_PATH")
	if not capture_path.is_empty():
		if not _check(
			capture_path == "res://ai_analysis/godot_logs/tween_authoring_editor_fixture/editor.png",
			"The Inspector capture must use the runner's fixed owned artifact path."
		):
			return false
		if not _check(
			not FileAccess.file_exists(capture_path) and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(capture_path.get_base_dir())),
			"The Inspector capture directory must be pre-created and its output must be fresh."
		):
			return false
		output_path = capture_path
	var texture: ViewportTexture = EditorInterface.get_base_control().get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("GF_TWEEN_AUTHORING_SCREENSHOT_UNAVAILABLE")
		return true
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("GF_TWEEN_AUTHORING_SCREENSHOT_UNAVAILABLE")
		return true
	if (
		capture_path.is_empty()
		and (
			not _claim_output(path)
			or not _claim_output(path + ".import")
		)
	):
		return false
	var saved: Error = image.save_png(output_path)
	if saved != OK:
		_reject("Could not save the owned Inspector screenshot.")
		return false
	return true


func _claim_output(path: String) -> bool:
	if not _check(
		not FileAccess.file_exists(path),
		"The fixture must never replace an existing output: %s." % path
	):
		return false
	# These exact fresh paths belong to the private validation project; failed writes are cleaned too.
	_owned_files.append(path)
	return true


func _begin_cleanup(exit_code: int) -> void:
	if _finishing:
		return
	_finishing = true
	_exit_code = exit_code
	_stable_frames = 0
	_cleanup_started_usec = Time.get_ticks_usec()
	print(
		"GF_TWEEN_AUTHORING_CLEANUP_BEGIN phase=%d exit=%d"
		% [_phase, _exit_code]
	)


func _advance_cleanup() -> void:
	if Time.get_ticks_usec() - _cleanup_started_usec > 15_000_000 and not _cleanup_timeout_reported:
		_cleanup_timeout_reported = true
		_exit_code = 1
		print("GF_TWEEN_AUTHORING_CLEANUP_DEADLINE %s" % JSON.stringify(_cleanup_state()))
		push_error("Tween authoring navigation smoke could not prove idle scanning and complete owned cleanup before its deadline.")
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning():
		_stable_frames = 0
		return
	_stable_frames += 1
	if _stable_frames < 3:
		return
	if _cleanup_stage == 0:
		var inspector: EditorInspector = EditorInterface.get_inspector()
		var panel: GFTweenPreviewPanel = _find_panel(inspector)
		if panel != null:
			_retired_controls.append(weakref(panel))
		var edited: Object = inspector.get_edited_object()
		if edited is Resource:
			var resource: Resource = edited
			var editor: EditorProperty = _find_editor(inspector, resource)
			if editor != null:
				_retired_controls.append(weakref(editor))
		var dialog: Node = EditorInterface.get_base_control().find_child(
			"GFTweenCreateDialog",
			true,
			false
		)
		if dialog != null:
			_retired_controls.append(weakref(dialog))
		# edit_resource(null) is ignored by InspectorDock; this public method clears the real old tree.
		inspector.edit(null)
		if _history != null:
			_history.clear_history()
		_history = null
		_duration_plan = null
		_duration_probe_plan = null
		if _duration_probe_registration != null:
			_duration_probe_registration.release()
		_duration_probe_registration = null
		_config = null
		_recipe_snapshot.clear()
		if is_instance_valid(_runtime_target):
			_runtime_target.free()
		_runtime_target = null
		if _actions != null:
			_actions.cleanup()
			_actions = null
		_cleanup_stage = 1
		_stable_frames = 0
		return
	if _cleanup_stage == 1:
		for reference: WeakRef in _retired_controls:
			if reference.get_ref() != null:
				return
		for path: String in _owned_files:
			if not FileAccess.file_exists(path):
				continue
			var removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if removed != OK:
				_exit_code = 1
				push_error(
					"Could not remove owned authoring fixture output %s: %s."
					% [path, error_string(removed)]
				)
		_cleanup_stage = 2
		_stable_frames = 0
		filesystem.scan()
		return
	for path: String in _owned_files:
		if FileAccess.file_exists(path):
			_exit_code = 1
			push_error("Owned authoring fixture output survived cleanup: %s." % path)
	_retired_controls.clear()
	_done = true
	if _exit_code == 0:
		print("GF_TWEEN_AUTHORING_NAVIGATION_EDITOR_OK")
	get_tree().quit(_exit_code)


func _cleanup_state() -> Dictionary:
	var alive: Array[String] = []
	for reference: WeakRef in _retired_controls:
		var value: Variant = reference.get_ref()
		if value is Node:
			var control: Node = value
			alive.append(
				"%s:%s"
				% [control.get_class(), String(control.name).substr(0, 64)]
			)
	return {
		"phase": _phase,
		"cleanup_stage": _cleanup_stage,
		"exit_code": _exit_code,
		"is_scanning": EditorInterface.get_resource_filesystem().is_scanning(),
		"alive": alive,
	}


func _reject(message: String) -> void:
	if _done or _finishing:
		return
	print(
		"GF_TWEEN_AUTHORING_PRIMARY_FAILURE phase=%d reason=%s"
		% [_phase, message]
	)
	push_error("Tween authoring navigation smoke failed: %s" % message)
	_begin_cleanup(1)


# --- 内部类 ---

class DurationPreviewAdapter:
	extends GFTweenPreviewAdapter


	# --- 可重写钩子 / 虚方法 ---

	func _create_sample() -> Control:
		var sample: Control = Control.new()
		sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return sample


	func _apply_sample(sample: Control, values: Dictionary) -> void:
		var value: Variant = values.get("duration_probe_progress")
		if value is float:
			var progress: float = value
			sample.modulate = Color(
				1.0,
				1.0,
				1.0,
				progress
			)
