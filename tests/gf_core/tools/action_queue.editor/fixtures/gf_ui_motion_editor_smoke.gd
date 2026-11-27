@tool
extends EditorPlugin

const WORKBENCH = preload("res://addons/gf/extensions/action_queue/editor/gf_ui_motion_workbench.gd")


func _enter_tree() -> void:
	if OS.get_cmdline_user_args().has("--motion-editor-smoke"):
		call_deferred("_verify")


func _verify() -> void:
	var panel: WORKBENCH = WORKBENCH.new()
	EditorInterface.get_base_control().add_child(panel)
	var preview: Control = panel.get("_preview")
	var empty: GFUIMotionRecipe = preview.get("recipe")
	if empty == null or not empty.tracks.is_empty():
		_fail("workbench did not open with a blank recipe")
		return
	panel.call("_add_track")
	if empty.tracks.size() != 1 or not empty.tracks[0].effect is GFUIPropertyMotion:
		_fail("cannot author an independent property track")
		return
	var history_id: int = get_undo_redo().get_object_history_id(empty)
	var edit_history: UndoRedo = get_undo_redo().get_history_undo_redo(history_id)
	if (
		not edit_history.undo()
		or not empty.tracks.is_empty()
		or not edit_history.redo()
	):
		_fail("track edit is not reversible")
		return
	panel.call(
		"_open",
		load("res://tests/gf_core/extensions/action_queue/fixtures/independent_tracks.tres")
	)
	var recipe: GFUIMotionRecipe = preview.get("recipe")
	if recipe == null or recipe.tracks.size() != 5:
		_fail("combined sample missing")
		return
	var stage: Control = preview.get("_stage")
	var player: GFUIMotionPlayer = stage.get("player")
	if not player.is_active() or not player.seek(0.2):
		_fail(player.get_diagnostic())
		return
	var slide: GFUIPropertyMotion = recipe.tracks[1].effect
	slide.start_value = Vector2(0.24, 1.0)
	recipe.tracks[2].at = 0.35
	recipe.tracks[2].stagger_seconds = 0.09
	panel.call("_store", "res://tests/gf_core/extensions/action_queue/fixtures/reviewed_motion.tres")
	var stored: Resource = ResourceLoader.load(
		"res://tests/gf_core/extensions/action_queue/fixtures/reviewed_motion.tres",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if not stored is GFUIMotionRecipe:
		_fail("saved resource type")
		return
	var reopened: GFUIMotionRecipe = stored
	if not is_equal_approx(
		reopened.tracks[2].at,
		0.35
	):
		_fail("saved resource could not be reopened")
		return
	preview.call("open_recipe", reopened)
	preview.call("_seek", 0.34)
	if not player.is_active() or not is_equal_approx(
		player.get_time_seconds(),
		0.34
	):
		_fail("runtime and authoring seek diverged")
		return
	var mixed: GFUIMotionRecipe = load("res://tests/gf_core/extensions/action_queue/fixtures/route_illumination_recipe.tres")
	preview.call("open_recipe", mixed)
	var undo_manager: EditorUndoRedoManager = get_undo_redo()
	var history: int = undo_manager.get_object_history_id(mixed)
	undo_manager.create_action(
		"Retiming route",
		UndoRedo.MERGE_DISABLE,
		mixed
	)
	undo_manager.add_do_property(
		mixed.tracks[0],
		&"at",
		0.48
	)
	undo_manager.add_undo_property(
		mixed.tracks[0],
		&"at",
		0.35
	)
	undo_manager.commit_action()
	var stack: UndoRedo = undo_manager.get_history_undo_redo(history)
	if (
		stack == null
		or not stack.undo()
		or not is_equal_approx(
			mixed.tracks[0].at,
			0.35
		)
	):
		_fail("project resource undo")
		return
	if not stack.redo() or not is_equal_approx(
		mixed.tracks[0].at,
		0.48
	):
		_fail("project resource redo")
		return
	panel.call("_store", "res://tests/gf_core/extensions/action_queue/fixtures/reviewed_routes.tres")
	var mixed_copy: GFUIMotionRecipe = load("res://tests/gf_core/extensions/action_queue/fixtures/reviewed_routes.tres")
	if mixed_copy == null or mixed_copy.tracks[0].effect.get_script() != mixed.tracks[0].effect.get_script():
		_fail("external effect lost on save")
		return
	panel.set("_template_mode", true)
	panel.call("_store", "res://tests/gf_core/extensions/action_queue/fixtures/project_wave.gd")
	if not ResourceLoader.load("res://tests/gf_core/extensions/action_queue/fixtures/project_wave.tres") is GFUIMotionEffect:
		_fail("no project template")
		return
	print("GF_UI_EDITOR_SMOKE PASS")
	panel.queue_free()
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
