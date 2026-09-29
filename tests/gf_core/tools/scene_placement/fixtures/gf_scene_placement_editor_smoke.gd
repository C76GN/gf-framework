@tool

# 只能由隔离工程启用，验证真实 EditorPlugin、指针入口与 EditorUndoRedoManager。
extends EditorPlugin


# --- 常量 ---

const _FIXTURE_ROOT: String = "res://tests/gf_core/tools/scene_placement/fixtures/"
const _SCENE_A: String = _FIXTURE_ROOT + "placement_scene_a.tscn"
const _SCENE_B: String = _FIXTURE_ROOT + "placement_scene_b.tscn"
const _ASSET: String = _FIXTURE_ROOT + "placement_asset.tscn"
const _SCRIPTED_ASSET: String = _FIXTURE_ROOT + "placement_scripted_asset.tscn"
const _SAVED_SCENE: String = "res://scene_placement_saved.tscn"
const _CANARY_KEY: StringName = &"gf_placement_canary_instances"
const _PLUGIN_NAME: String = "gf/tools/scene_placement"
const _DEADLINE_MSEC: int = 90000
const _ASSET_WORKBENCH_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_dock.gd")
const _ASSET_QUEUE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_thumbnail_queue.gd")
const _BROWSER_MATERIAL: String = "res://asset_browser_material_smoke.tres"
const _WORKSPACE_SMOKE_SCRIPT = preload("res://tests/gf_core/tools/scene_placement/fixtures/gf_workspace_integration_smoke.gd")


# --- 私有变量 ---

var _phase: StringName = &"startup"
var _deadline: int = 0
var _frames: int = 0
var _finished: bool = false
var _assertions: int = 0
var _results: Dictionary = {}
var _placement_plugin: GFScenePlacementPlugin = null
var _panel: GFScenePlacementPanel = null
var _scene: Node3D = null
var _parent: Node3D = null
var _camera: Camera3D = null
var _history: UndoRedo = null
var _scene_history_id: int = 0
var _native_node: Node3D = null
var _native_node_id: int = 0
var _expected_world: Transform3D = Transform3D.IDENTITY
var _pointer_world: Vector3 = Vector3.ZERO
var _pointer_position: Vector2 = Vector2.ZERO
var _parent_count: int = 0
var _mesh_count: int = 0
var _plugin_ref: WeakRef = null
var _panel_ref: WeakRef = null
var _native_viewport: SubViewport = null
var _native_input_before: int = 0
var _launcher: GFScenePlacementLauncher = null
var _launcher_ref: WeakRef = null
var _asset_workbench: _ASSET_WORKBENCH_SCRIPT = null
var _asset_host: PanelContainer = null
var _asset_queue: _ASSET_QUEUE_SCRIPT = null
var _asset_preview_generation: int = 0
var _asset_previews: Array[Dictionary] = []
var _asset_lifecycle_failures: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_deadline = Time.get_ticks_msec() + _DEADLINE_MSEC
	Engine.set_meta(_CANARY_KEY, 0)
	var connect_error: int = get_tree().process_frame.connect(_on_frame)
	if connect_error != OK:
		_fail("Cannot observe the native editor lifecycle.")


func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_on_frame):
		get_tree().process_frame.disconnect(_on_frame)
	Engine.remove_meta(_CANARY_KEY)


# --- 私有/辅助方法 ---

func _startup() -> void:
	if not _require(Engine.is_editor_hint(), "The fixture requires a real editor."):
		return
	var private_root: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_PRIVATE_ROOT").replace("\\", "/").simplify_path()
	if not _require(not private_root.is_empty() and private_root.is_absolute_path(), "The private smoke root was not supplied."):
		return
	for directory: String in [OS.get_data_dir(), OS.get_config_dir(), OS.get_cache_dir(), OS.get_user_data_dir()]:
		var normalized: String = directory.replace("\\", "/").simplify_path()
		if not _require(normalized.to_lower().begins_with(private_root.to_lower() + "/"), "Native Godot data/config/cache/user directory escaped the smoke root: " + normalized):
			return
	_results["native_private_directories_verified"] = true
	for candidate: Node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate is GFScenePlacementPlugin:
			_placement_plugin = candidate
			break
	if not _require(_placement_plugin != null, "The declared native scene placement plugin was not activated."):
		return
	_panel = _placement_plugin.get_panel()
	if not _require(_panel != null and _panel.is_inside_tree(), "The native placement panel is missing."):
		return
	if not _require(not _panel.is_continuous_placement_enabled(), "Placement must remain single-use by default."):
		return
	_phase = &"scene_a"
	EditorInterface.open_scene_from_path(_SCENE_A)


func _wait_scene_a() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_A:
		return
	_phase = &"running"
	_scene = _node_3d(root)
	if not _require(_scene != null, "Scene A must expose a 3D root."):
		return
	_parent = _node_3d(_scene.get_node_or_null(^"PlacementParent"))
	var camera_value: Node = _scene.get_node_or_null(^"PointerCamera")
	if not _require(_parent != null and camera_value is Camera3D, "Scene A is missing its parent or pointer camera."):
		return
	if camera_value is Camera3D:
		_camera = camera_value
	_camera.current = true
	var manager: EditorUndoRedoManager = get_undo_redo()
	_scene_history_id = manager.get_object_history_id(_scene)
	_history = manager.get_history_undo_redo(_scene_history_id)
	if not _require(_scene_history_id > 0 and _history != null, "The actual edited scene did not receive a native history."):
		return
	_results["scene_history_id"] = _scene_history_id
	_asset_workbench = _ASSET_WORKBENCH_SCRIPT.new()
	_asset_workbench.set_editor_context(GFEditorToolContext.from_plugin(self))
	_asset_host = PanelContainer.new()
	EditorInterface.get_base_control().add_child(_asset_host)
	_asset_host.add_child(_asset_workbench)
	_asset_host.position = Vector2(40.0, 100.0)
	_asset_host.size = Vector2(1000.0, 820.0)
	if DisplayServer.get_name() != "headless":
		_asset_queue = _ASSET_QUEUE_SCRIPT.new()
		_asset_queue.setup(EditorInterface.get_resource_previewer())
		var _preview_connection: int = _asset_queue.preview_ready.connect(_on_asset_preview)
		var _initial_generation: int = _asset_queue.request_visible(PackedStringArray([_ASSET]))
		await get_tree().process_frame
		_asset_queue.invalidate()
		_asset_queue.pause()
		_asset_previews.clear()
		_asset_preview_generation = _asset_queue.request_visible(PackedStringArray([_BROWSER_MATERIAL]))
	_phase = &"asset_workbench"


func _check_asset_workbench() -> void:
	var snapshot: Dictionary = _asset_workbench.get_snapshot()
	if _bool(snapshot, "stale") or _bool(snapshot, "query_pending") or (_asset_queue != null and _asset_previews.is_empty()):
		return
	_phase = &"running"
	for delivery: Dictionary in _asset_previews:
		if not _require(GFVariantData.get_option_string(delivery, "path") == _BROWSER_MATERIAL and _int(delivery, "generation") == _asset_preview_generation, "An invalidated native thumbnail reached the current view."):
			return
	if _asset_queue != null:
		_asset_queue.dispose()
		_asset_queue = null
		_results["asset_browser_native_preview_generation"] = true
	else:
		_results["asset_browser_native_preview_not_exercised"] = "headless"
	_asset_host.size = Vector2(1000.0, minf(820.0, EditorInterface.get_base_control().size.y - 100.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_results["asset_browser_page_size"] = str(_asset_workbench.size)
	_results["asset_browser_page_minimum"] = str(_asset_workbench.get_combined_minimum_size())
	if not _require(_asset_host.get_global_rect().end.y <= EditorInterface.get_base_control().size.y, "The resource workbench minimum height escaped the available editor surface."):
		return
	var image_directory: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR")
	if not image_directory.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		var frame: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		if not _require(frame != null and not frame.is_empty(), "The asset workbench returned no rendered editor image."):
			return
		var image_path: String = image_directory.path_join("asset_workbench.png")
		if not _require(frame.save_png(image_path) == OK, "Cannot save the asset workbench render evidence."):
			return
		_results["asset_browser_rendered_image"] = image_path
	if not _require(_int(snapshot, "entry_count") > 0 and _int(snapshot, "visible_count") <= 100, "The default project source did not publish a bounded complete page."):
		return
	var grid_value: Node = _asset_workbench.find_child("AssetGrid", true, false)
	if not _require(grid_value is ItemList, "Asset Browser did not expose its native grid."):
		return
	var grid: ItemList = grid_value
	if not _select_browser_path(grid, _ASSET):
		return
	var paths: PackedStringArray = _asset_workbench.get_selected_resource_paths()
	if not _require(paths == PackedStringArray([_ASSET]), "The resource action context disagrees with the grid selection."):
		return
	var drag_paths: PackedStringArray = GFScenePlacementPanel.get_drag_resource_paths({"type": "files", "files": paths})
	var received: Dictionary = _panel.receive_resource_paths(drag_paths)
	if not _require(_bool(received, "ok") and _panel.get_source_scene().resource_path == _ASSET and not _bool(_placement_plugin.get_snapshot(), "active") and _canary_count() == 0, "Receiving a browser scene must select it without creating a placement session or instance."):
		return
	var catalog_directory_error: Error = DirAccess.make_dir_recursive_absolute("res://tests/gf_core/generated_asset_browser")
	if not _require(catalog_directory_error == OK, "Cannot create the isolated test-owned Catalog output directory."):
		return
	if not _press_browser_button("新建共享目录"):
		return
	var dialog: EditorFileDialog = null
	for child: Node in _asset_workbench.get_children():
		if child is EditorFileDialog:
			dialog = child
	if not _require(dialog != null, "Creating a shared catalog must ask for an explicit project path."):
		return
	dialog.hide()
	dialog.file_selected.emit("res://tests/gf_core/generated_asset_browser/shared.tres")
	if not await _wait_browser_page_ready("creating the shared Catalog"):
		return
	# 已有共享条目拥有项目扫描不会提供的字段；接下来的标签编辑必须完整保留这些字段。
	var seed_value: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/shared.tres")
	var shared_value: Variant = _asset_workbench.get("_shared_catalog")
	var visible_value: Variant = _asset_workbench.get("_catalog")
	if not _require(seed_value is GFAssetCatalog and shared_value is GFAssetCatalog and visible_value is GFAssetCatalog, "The loaded and visible shared Catalog values must retain their Resource types."):
		return
	var seed_catalog: GFAssetCatalog = seed_value
	var shared_catalog: GFAssetCatalog = shared_value
	var visible_catalog: GFAssetCatalog = visible_value
	if not _require(shared_catalog == seed_catalog, "The loaded Catalog must be the same Resource owned by the shared Catalog editor."):
		return
	var curated: GFAssetCatalogEntry = null
	for entry: GFAssetCatalogEntry in visible_catalog.entries:
		if entry != null and entry.primary_path == _ASSET:
			curated = entry.duplicate_entry()
			break
	if not _require(curated != null, "The project scene entry is missing before shared-field editing."):
		return
	curated.title = "Curated scene title"
	curated.category = &"curated_scene"
	curated.preview_path = _BROWSER_MATERIAL
	curated.resource_entry_ids = PackedStringArray(["curated.primary", "curated.related"])
	curated.source_id = &"curated_library"
	curated.metadata["custom"] = {"review_owner": "artist", "weights": [1, 2, 3]}
	curated.tags = PackedStringArray(["before"])
	curated.description = "Curated notes"
	var curated_before: Dictionary = curated.to_dict()
	seed_catalog.entries = [curated]
	seed_catalog.mark_index_dirty()
	seed_catalog.emit_changed()
	if not _require(_asset_workbench.has_unsaved_workspace_changes(), "Seeding the live shared Catalog must mark its actual editor draft dirty."):
		return
	if not _press_browser_button("保存共享目录"):
		return
	var saved_seed: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/shared.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _require(saved_seed is GFAssetCatalog, "The seeded shared Catalog must be explicitly saved to disk."):
		return
	var saved_seed_catalog: GFAssetCatalog = saved_seed
	if not _require(saved_seed_catalog.entries.size() == 1 and saved_seed_catalog.entries[0].to_dict() == curated_before and not _asset_workbench.has_unsaved_workspace_changes(), "Explicit save must preserve every seeded field and establish the shared Catalog baseline."):
		return
	if not await _wait_browser_page_ready("saving the seeded shared Catalog"):
		return
	# 使用未缓存的新路径模拟下次编辑器会话，避免复用手动 new 出来的可执行实例。
	var save_as_error: Error = ResourceSaver.save(saved_seed_catalog, "res://tests/gf_core/generated_asset_browser/reopened.tres")
	if not _require(save_as_error == OK, "Cannot save the detached Catalog to an uncached test-owned path."):
		return
	var original_catalog_uid: int = ResourceLoader.get_resource_uid("res://tests/gf_core/generated_asset_browser/shared.tres")
	var reopened_catalog_uid: int = ResourceLoader.get_resource_uid("res://tests/gf_core/generated_asset_browser/reopened.tres")
	if not _require(original_catalog_uid >= 0 and reopened_catalog_uid >= 0 and reopened_catalog_uid != original_catalog_uid, "Saving the detached Catalog must assign a distinct UID instead of duplicating the source file header."):
		return
	var fresh_value: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/reopened.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _require(fresh_value is GFAssetCatalog and fresh_value != seed_catalog and not ResourceLoader.has_cached("res://tests/gf_core/generated_asset_browser/reopened.tres"), "The reopen regression must start from disk without a cached manually constructed Catalog."):
		return
	var fresh_catalog: GFAssetCatalog = fresh_value
	if not _require(fresh_catalog.get_all_ids() == PackedStringArray([String(curated.asset_id)]) and fresh_catalog.entries[0].to_dict() == curated_before, "Freshly loaded Catalog and Entry instance methods must execute in the editor."):
		return
	if not _press_browser_button("打开共享目录"):
		return
	if not _require(dialog.visible and dialog.file_mode == EditorFileDialog.FILE_MODE_OPEN_FILE, "Reopening a saved Catalog must use the actual Open Catalog dialog."):
		return
	dialog.hide()
	dialog.file_selected.emit("res://tests/gf_core/generated_asset_browser/reopened.tres")
	if not await _wait_browser_page_ready("reopening the saved shared Catalog"):
		return
	var reopened_value: Variant = _asset_workbench.get("_shared_catalog")
	if not _require(reopened_value is GFAssetCatalog, "The Open Catalog action must own a Catalog Resource."):
		return
	var reopened_catalog: GFAssetCatalog = reopened_value
	if not _require(reopened_catalog != seed_catalog and reopened_catalog != fresh_catalog, "The Open Catalog action must own a freshly loaded Resource rather than either fixture instance."):
		return
	if not _require(reopened_catalog.resource_path == "res://tests/gf_core/generated_asset_browser/reopened.tres" and reopened_catalog.entries.size() == 1 and reopened_catalog.entries[0].to_dict() == curated_before and not _asset_workbench.has_unsaved_workspace_changes(), "The reopened shared Catalog must retain its complete saved baseline."):
		return
	_results["asset_browser_uncached_catalog_reopened"] = true
	if not _select_browser_path(grid, _ASSET):
		return
	_results["asset_browser_before_shared_apply"] = _asset_workbench.get_snapshot()
	if not _require(_asset_workbench.get_selected_resource_paths() == PackedStringArray([_ASSET]), "Shared-field Apply requires a current selectable project scene, not a stale card."):
		return
	var tags_value: Node = _asset_workbench.find_child("SharedAssetTags", true, false)
	if not _require(tags_value is LineEdit, "Shared tag editor is missing."):
		return
	var tags: LineEdit = tags_value
	tags.text = "smoke, scene"
	if not _press_browser_button("应用到所选"):
		return
	if not _require(_asset_workbench.has_unsaved_workspace_changes(), "Unsaved shared Catalog edits must request Workspace retention."):
		return
	if not _press_browser_button("保存共享目录"):
		return
	if not _require(not _asset_workbench.has_unsaved_workspace_changes(), "Explicit shared Catalog save must release its dirty-retention request."):
		return
	var loaded_catalog: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/reopened.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _require(loaded_catalog is GFAssetCatalog, "The shared catalog was not saved as a standard catalog resource."):
		return
	var catalog: GFAssetCatalog = loaded_catalog
	if not _require(catalog.entries.size() == 1 and catalog.entries[0].tags == PackedStringArray(["smoke", "scene"]), "Shared tags did not round-trip independently of the source scene."):
		return
	var curated_after: GFAssetCatalogEntry = curated.duplicate_entry()
	curated_after.tags = PackedStringArray(["smoke", "scene"])
	if not _require(catalog.entries[0].to_dict() == curated_after.to_dict() and curated.to_dict() == curated_before, "Project-view tag editing replaced existing shared metadata or mutated its original entry."):
		return
	var live_catalog_value: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/reopened.tres")
	if not _require(live_catalog_value is GFAssetCatalog and live_catalog_value == reopened_catalog, "The reopened shared catalog must retain its native resource identity."):
		return
	var live_catalog: GFAssetCatalog = live_catalog_value
	var catalog_history: UndoRedo = get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(live_catalog))
	_results["asset_browser_catalog_loaded_history"] = get_undo_redo().get_object_history_id(live_catalog)
	_results["asset_browser_scene_last_action"] = _history.get_current_action_name()
	if not _require(catalog_history != null and catalog_history.has_undo(), "Shared tags must have an actual native history."):
		return
	_record_asset_lifecycle(catalog_history != _history, "Shared Catalog edits entered the current scene history.")
	if not _press_browser_button("刷新"):
		return
	var _catalog_undone: bool = catalog_history.undo()
	_record_asset_lifecycle(live_catalog.entries.size() == 1 and live_catalog.entries[0].to_dict() == curated_before, "Native shared Catalog Undo lost the original complete entry.")
	_record_asset_lifecycle(_asset_workbench.has_unsaved_workspace_changes(), "Undo away from the saved Catalog baseline must request draft retention.")
	_record_asset_lifecycle(_bool(_asset_workbench.get_snapshot(), "stale"), "Catalog Undo revived a project snapshot while its refresh was still pending.")
	var _catalog_redone: bool = catalog_history.redo()
	_record_asset_lifecycle(live_catalog.entries.size() == 1 and live_catalog.entries[0].to_dict() == curated_after.to_dict(), "Native shared Catalog Redo lost preserved fields.")
	var saved_after_replay: Resource = ResourceLoader.load("res://tests/gf_core/generated_asset_browser/reopened.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if saved_after_replay is GFAssetCatalog:
		var saved_after_catalog: GFAssetCatalog = saved_after_replay
		_record_asset_lifecycle(saved_after_catalog.entries.size() == 1 and saved_after_catalog.entries[0].to_dict() == curated_after.to_dict(), "Native history replay unexpectedly changed the explicitly saved Catalog bytes.")
	else:
		_record_asset_lifecycle(false, "The explicitly saved Catalog disappeared during native history replay.")
	await get_tree().process_frame
	while not _finished and (_bool(_asset_workbench.get_snapshot(), "stale") or _bool(_asset_workbench.get_snapshot(), "query_pending")):
		await get_tree().process_frame
	if _finished:
		return
	_asset_host.hide()
	var _hidden_undo: bool = catalog_history.undo()
	_record_asset_lifecycle(_bool(_asset_workbench.get_snapshot(), "stale"), "Catalog Undo revived a hidden asset page.")
	var _hidden_redo: bool = catalog_history.redo()
	_asset_host.show()
	await get_tree().process_frame
	while not _finished and (_bool(_asset_workbench.get_snapshot(), "stale") or _bool(_asset_workbench.get_snapshot(), "query_pending")):
		await get_tree().process_frame
	if _finished:
		return
	if not _select_browser_path(grid, _BROWSER_MATERIAL) or not _press_browser_button("表格编辑"):
		return
	var table: GFResourceTableEditor = null
	for candidate: Node in _asset_workbench.find_children("*", "", true, false):
		if candidate is GFResourceTableEditor:
			table = candidate
	if not _require(table != null and table.get_resources().size() == 1, "Explicit source selection did not reach the existing resource table."):
		return
	var edit_report: Dictionary = table.commit_cell_values([{"row_index": 0, "property": &"roughness", "new_value": 0.25}])
	if not _require(_bool(edit_report, "ok"), "The selected source resource did not accept an undoable table edit."):
		return
	if not _press_browser_button("保存表格中的源资源"):
		return
	var saved_material: Resource = ResourceLoader.load(_BROWSER_MATERIAL, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _require(saved_material is StandardMaterial3D, "The resource table did not preserve the source resource type."):
		return
	var material: StandardMaterial3D = saved_material
	if not _require(is_equal_approx(material.roughness, 0.25), "The explicit source save did not persist the edited property."):
		return
	var unsaved_report: Dictionary = table.commit_cell_values([{"row_index": 0, "property": &"roughness", "new_value": 0.5}])
	if not _require(_bool(unsaved_report, "ok"), "The revoke case requires an unsaved source edit."):
		return
	if not _press_browser_button("新建共享目录"):
		return
	dialog.hide()
	var catalog_digest: String = FileAccess.get_sha256("res://tests/gf_core/generated_asset_browser/reopened.tres")
	_results["asset_browser_project_source_catalog_table_and_receiver"] = true
	_asset_workbench.set_editor_context(null)
	if not _press_browser_button("保存表格中的源资源"):
		return
	var after_revoke_value: Resource = ResourceLoader.load(_BROWSER_MATERIAL, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _require(after_revoke_value is StandardMaterial3D, "The revoke check lost its source material."):
		return
	var after_revoke: StandardMaterial3D = after_revoke_value
	_record_asset_lifecycle(is_equal_approx(after_revoke.roughness, 0.25), "A queued table Save wrote to disk after context revocation.")
	live_catalog.entries[0].description = "Late catalog callback after revoke"
	live_catalog.emit_changed()
	_record_asset_lifecycle(_bool(_asset_workbench.get_snapshot(), "stale"), "A late Catalog callback revived a revoked asset page.")
	if not _press_browser_button("保存共享目录"):
		return
	_record_asset_lifecycle(FileAccess.get_sha256("res://tests/gf_core/generated_asset_browser/reopened.tres") == catalog_digest, "A queued shared Catalog Save wrote after context revocation.")
	dialog.file_selected.emit("res://tests/gf_core/generated_asset_browser/after_revoke.tres")
	_record_asset_lifecycle(not FileAccess.file_exists("res://tests/gf_core/generated_asset_browser/after_revoke.tres"), "A late file_selected callback created a Catalog after context revocation.")
	if not _require(_asset_lifecycle_failures.is_empty(), "Asset lifecycle regressions: " + " | ".join(_asset_lifecycle_failures)):
		return
	_results["asset_browser_freshness_and_revocation"] = true
	_asset_host.free()
	_asset_host = null
	_asset_workbench = null
	var workspace_smoke: _WORKSPACE_SMOKE_SCRIPT = _WORKSPACE_SMOKE_SCRIPT.new()
	var workspace_report: Dictionary = await workspace_smoke.run(self, _placement_plugin, _ASSET, _BROWSER_MATERIAL)
	_assertions += GFVariantData.get_option_int(workspace_report, "assertions")
	if not _require(_bool(workspace_report, "ok"), "Workspace integration: " + GFVariantData.get_option_string(workspace_report, "message")):
		return
	for key: String in workspace_report:
		if key.begins_with("workspace_"):
			_results[key] = workspace_report[key]
	_run_native_operation_cases()


func _select_browser_path(grid: ItemList, path: String) -> bool:
	grid.deselect_all()
	for index: int in range(grid.item_count):
		if grid.get_item_metadata(index) == path:
			grid.select(index)
			grid.multi_selected.emit(index, true)
			return true
	return _require(false, "The default project index omitted fixture " + path)


func _wait_browser_page_ready(operation: String) -> bool:
	var deadline: int = mini(_deadline, Time.get_ticks_msec() + 10_000)
	while not _finished:
		var snapshot: Dictionary = _asset_workbench.get_snapshot()
		_results["asset_browser_last_ready_wait"] = {"operation": operation, "snapshot": snapshot}
		# 文件系统失效也会取消查询，不能把 pending=false 当成旧卡片已经可操作。
		if not _bool(snapshot, "stale") and not _bool(snapshot, "query_pending") and _bool(snapshot, "page_ready"):
			return true
		if Time.get_ticks_msec() >= deadline:
			return _require(false, "The asset page did not become ready after " + operation + ": " + JSON.stringify(snapshot))
		await get_tree().process_frame
	return false


func _on_asset_preview(path: String, _texture: Texture2D, generation: int) -> void:
	_asset_previews.append({"path": path, "generation": generation})


func _record_asset_lifecycle(condition: bool, failure: String) -> void:
	if not condition:
		var _appended: bool = _asset_lifecycle_failures.append(failure)


func _press_browser_button(caption: String) -> bool:
	for candidate: Node in _asset_workbench.find_children("*", "Button", true, false):
		if candidate is Button:
			var button: Button = candidate
			if button.text == caption:
				button.pressed.emit()
				return true
	return _require(false, "Asset Browser action is missing: " + caption)


func _run_native_operation_cases() -> void:
	var parent_count: int = _parent.get_child_count()
	var history_version: int = _history.get_version()
	var rejected: GFScenePlacementOperation = _operation(_SCRIPTED_ASSET)
	if rejected == null:
		return
	if not _require(rejected.pick(_ray(Vector3(3.0, 10.0, 4.0))) == GFEditorPickOperation.State.READY, "Scripted source preview did not become ready."):
		return
	if not _require(_canary_count() == 0 and _parent.get_child_count() == parent_count and _history.get_version() == history_version, "Preview instantiated a source script, changed the scene, or wrote history."):
		return
	rejected.cancel()
	if not _require(not rejected.can_apply() and _canary_count() == 0, "Cancellation executed source code or left a ready operation."):
		return
	rejected = null
	var anchor: Vector3 = Vector3(1.0, 0.5, -2.0)
	var operation: GFScenePlacementOperation = _operation(_ASSET, {
		"anchor": anchor, "yaw_degrees": 90.0, "scale": Vector3(2.0, 3.0, 4.0),
	})
	if operation == null:
		return
	if not _require(operation.pick(_ray(Vector3(5.0, 10.0, 7.0))) == GFEditorPickOperation.State.READY, "Native placement did not produce a ready preview."):
		return
	_expected_world = _transform(operation.get_preview(), "world_transform")
	if not _require((_expected_world * anchor).is_equal_approx(Vector3(5.0, 0.0, 7.0)), "The transformed explicit local anchor missed the plane hit."):
		return
	_parent.position += Vector3(2.0, 3.0, 4.0)
	var applied: Dictionary = operation.apply()
	if not _require(_bool(applied, "ok"), "Native manager confirmation failed: " + str(applied)):
		return
	_native_node = _node_3d(applied.get("node"))
	if not _require(_native_node != null, "Native confirmation did not expose the actual created node."):
		return
	_native_node_id = _native_node.get_instance_id()
	if not _require(_native_node.get_parent() == _parent and _native_node.owner == _scene, "The created instance has wrong parent or scene owner."):
		return
	if not _require(_native_node.global_transform.is_equal_approx(_expected_world), "Confirmation did not recompute local space after the non-unit parent moved."):
		return
	if not _require(_history.get_version() != history_version and _parent.get_child_count() == parent_count + 1, "Confirmation did not create exactly one native action and instance."):
		return
	var operation_ref: WeakRef = weakref(operation)
	operation = null
	if not _require(operation_ref.get_ref() == null, "Native history retained the interactive operation/context."):
		return
	if not _require(_history.undo() and _native_node.get_parent() == null and _parent.get_child_count() == parent_count, "Native undo did not remove the instance."):
		return
	if not _require(_history.redo() and _native_node.get_instance_id() == _native_node_id and _native_node.get_parent() == _parent, "Native redo did not reattach the same instance."):
		return
	if not _require(_native_node.owner == _scene and _native_node.global_transform.is_equal_approx(_expected_world), "Redo lost the saved owner or world transform."):
		return
	if not _save_and_reload():
		return
	_results["native_undo_redo_anchor_parent_transform_save_reload"] = true
	_begin_native_forward()


func _begin_native_forward() -> void:
	EditorInterface.set_main_screen_editor("3D")
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(0)
	if not _start_placement():
		return
	_native_viewport = EditorInterface.get_editor_viewport_3d(0)
	if not _require(_native_viewport != null, "The actual editor 3D SubViewport is unavailable."):
		return
	_results["editor_viewport_path"] = str(_native_viewport.get_path())
	_native_input_before = _int(_placement_plugin.get_snapshot(), "input_count")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(_native_viewport.size) * 0.5
	_native_viewport.push_input(motion, true)
	_phase = &"native_forward_wait"
	_frames = 0


func _check_native_forward() -> void:
	_phase = &"running"
	if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
		_results["native_input_route"] = "Editor 3D SubViewport.push_input"
	else:
		var container_root: Node = _native_viewport.get_parent().get_parent()
		var candidates: Array[String] = []
		for node: Node in container_root.find_children("*", "Control", true, false):
			if not node is Control:
				continue
			var control: Control = node
			for connection: Dictionary in control.get_signal_connection_list(&"gui_input"):
				var callback_value: Variant = connection.get("callable")
				if not callback_value is Callable:
					continue
				var callback: Callable = callback_value
				var receiver: Object = callback.get_object()
				if not is_instance_valid(receiver):
					continue
				candidates.append("%s -> %s.%s" % [control.get_path(), receiver.get_class(), callback.get_method()])
				if not String(receiver.get_class()).contains("Node3DEditorViewport"):
					continue
				var motion: InputEventMouseMotion = InputEventMouseMotion.new()
				motion.position = control.size * 0.5
				control.gui_input.emit(motion)
				if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
					_results["native_input_route"] = "Registered editor Control.gui_input -> native Node3DEditorViewport -> plugin forwarding"
					break
			if _int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before:
				break
		_results["editor_gui_connections"] = candidates
	if not _require(_int(_placement_plugin.get_snapshot(), "input_count") > _native_input_before, "Native editor GUI input did not reach the registered _forward_3d_gui_input callback."):
		return
	if not _require(_bool(_placement_plugin.get_snapshot(), "preview_visible"), "Forwarded editor input did not create a visible preview candidate."):
		return
	_results["native_gui_forwarded"] = true
	_phase = &"native_render_wait"
	_frames = 0


func _complete_native_forward() -> void:
	_phase = &"running"
	var image_directory: String = OS.get_environment("GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR")
	if not image_directory.is_empty():
		RenderingServer.force_draw(false)
		var texture: Texture2D = _native_viewport.get_texture()
		var frame: Image = texture.get_image() if texture != null else null
		if not _require(frame != null and not frame.is_empty(), "The rendered native editor viewport returned no image."):
			return
		var image_path: String = image_directory.path_join("scene_placement_preview.png")
		if not _require(frame.save_png(image_path) == OK, "Could not save the native placement preview image."):
			return
		_results["rendered_preview_image"] = image_path
	_placement_plugin.cancel_placement()
	_begin_pointer_plane()


func _begin_pointer_plane() -> void:
	_panel.set_source_scene(_load_scene(_SCRIPTED_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(0)
	_parent_count = _parent.get_child_count()
	_mesh_count = _scene.find_children("*", "MeshInstance3D", true, false).size()
	if not _start_placement():
		return
	_pointer_position = _camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = _camera.project_ray_origin(_pointer_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(_pointer_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if not _require(hit is Vector3, "Fixture camera does not point at the placement plane."):
		return
	if hit is Vector3:
		_pointer_world = hit
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var consumed: int = _placement_plugin.process_pointer(_camera, move)
	if not _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Active native pointer motion bypassed the placement route."):
		return
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	if not _require(_bool(snapshot, "active") and _bool(snapshot, "preview_visible"), "Valid pointer input did not display the native preview proxy."):
		return
	if not _require(_parent.get_child_count() == _parent_count and _canary_count() == 0, "Pointer preview instantiated the scripted source."):
		return
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	var cancel_consumed: int = _placement_plugin.process_pointer(_camera, escape)
	if not _require(cancel_consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Escape did not cancel active placement."):
		return
	var cancelled: Dictionary = _placement_plugin.get_snapshot()
	if not _require(not _bool(cancelled, "active") and not _bool(cancelled, "preview_visible"), "Cancellation retained an active or visible preview."):
		return
	_phase = &"cancel_settle"
	_frames = 0


func _after_cancel() -> void:
	_phase = &"running"
	if not _require(_scene.find_children("*", "MeshInstance3D", true, false).size() == _mesh_count, "Cancelled preview left a mesh in the edited scene."):
		return
	var clicked: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(clicked == EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == _parent_count and _canary_count() == 0, "A late click after cancel created an instance or executed a script."):
		return
	if not _check_confirmation_failure_feedback():
		return
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	if not _start_placement():
		return
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var _motion_consumed: int = _placement_plugin.process_pointer(_camera, move)
	var confirm_consumed: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(confirm_consumed != EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == _parent_count + 1, "Native left click did not confirm exactly one placement."):
		return
	var created: Node3D = _last_placed_child()
	if not _require(created != null and created.global_position.is_equal_approx(_pointer_world), "Pointer confirmation did not use the camera-derived world hit."):
		return
	if not _require(not _bool(_placement_plugin.get_snapshot(), "active") and not _bool(_placement_plugin.get_snapshot(), "preview_visible"), "Default single placement retained an active preview."):
		return
	var late_click: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(late_click == EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == _parent_count + 1, "Default single placement accepted another click without restarting."):
		return
	if not _require(_history.undo() and _parent.get_child_count() == _parent_count, "Pointer-created action was not routed to the current scene native history."):
		return
	_results["native_pointer_plane_cancel_and_confirm"] = true
	if not _check_continuous_placement():
		return
	if not _check_continuous_invalidation():
		return
	if not _check_continuous_creation_cancellation():
		return
	if not _check_continuous_inspector_reentry(false):
		return
	if not _check_continuous_inspector_reentry(true):
		return
	_results["continuous_confirmation_reentry"] = true
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	_set_mode(1)
	if not _start_placement():
		return
	_phase = &"surface_wait"
	_frames = 0


func _check_continuous_placement() -> bool:
	if not _set_continuous(true) or not _start_placement():
		return false
	var children_before: int = _parent.get_child_count()
	if not _move_pointer(_pointer_position):
		return false
	var first_confirm: int = _placement_plugin.process_pointer(_camera, _key_press(KEY_ENTER))
	var first: Node3D = _last_placed_child()
	if not _require(first_confirm != EditorPlugin.AFTER_GUI_INPUT_PASS and first != null and _parent.get_child_count() == children_before + 1, "Continuous Enter did not create exactly one first instance."):
		return false
	var first_id: int = first.get_instance_id()
	var first_world: Transform3D = first.global_transform
	if not _require_continuous_pending():
		return false
	var version_after_first: int = _history.get_version()
	var _repeated_enter: int = _placement_plugin.process_pointer(_camera, _key_press(KEY_ENTER))
	if not _require(_parent.get_child_count() == children_before + 1 and _history.get_version() == version_after_first, "Repeated Enter reused the previous placement hit."):
		return false
	if not _move_pointer(_pointer_position + Vector2(24.0, 0.0)):
		return false
	var second_confirm: int = _placement_plugin.process_pointer(_camera, _key_press(KEY_ENTER))
	var second: Node3D = _last_placed_child()
	if not _require(second_confirm != EditorPlugin.AFTER_GUI_INPUT_PASS and second != null and second != first and _parent.get_child_count() == children_before + 2, "Continuous mode did not create a distinct second instance under the original parent."):
		return false
	var second_id: int = second.get_instance_id()
	var second_world: Transform3D = second.global_transform
	if not _require(not first_world.origin.is_equal_approx(second_world.origin) and _panel.get_parent_node() == _parent, "The second hit or captured placement parent changed unexpectedly."):
		return false
	if not _require_continuous_pending() or not _move_pointer(_pointer_position):
		return false
	var history_before_cancel: int = _history.get_version()
	var _escape_consumed: int = _placement_plugin.process_pointer(_camera, _key_press(KEY_ESCAPE))
	if not _require_inactive("Escape"):
		return false
	var late_click: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(late_click == EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == children_before + 2 and _history.get_version() == history_before_cancel, "Escape or a late click changed already confirmed continuous instances."):
		return false
	if not _require(_history.undo() and second.get_parent() == null and first.get_parent() == _parent and _parent.get_child_count() == children_before + 1, "First undo did not remove only the second continuous instance."):
		return false
	if not _require(_history.undo() and first.get_parent() == null and _parent.get_child_count() == children_before, "Second undo did not remove only the first continuous instance."):
		return false
	if not _require(_history.redo() and first.get_instance_id() == first_id and first.get_parent() == _parent and second.get_parent() == null, "First redo did not reattach the same first continuous instance."):
		return false
	if not _require(_history.redo() and second.get_instance_id() == second_id and second.get_parent() == _parent and _parent.get_child_count() == children_before + 2, "Second redo did not reattach the same second continuous instance."):
		return false
	if not _require(first.owner == _scene and second.owner == _scene and first.global_transform.is_equal_approx(first_world) and second.global_transform.is_equal_approx(second_world), "Continuous history replay lost scene owners or captured world transforms."):
		return false
	if not _require(_history.undo() and _history.undo() and _parent.get_child_count() == children_before, "Could not restore the fixture after continuous history checks."):
		return false
	_results["continuous_independent_undo_redo_and_cancel"] = true
	return true


func _check_continuous_invalidation() -> bool:
	if not _start_placement() or not _move_pointer(_pointer_position):
		return false
	var children_before: int = _parent.get_child_count()
	var history_before: int = _history.get_version()
	if not _set_continuous(false) or not _require_inactive("Configuration change"):
		return false
	var late_click: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(late_click == EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == children_before and _history.get_version() == history_before, "A configuration change left an armed continuous pointer or changed history."):
		return false
	if not _set_continuous(true):
		return false
	var temporary_parent: Node3D = Node3D.new()
	temporary_parent.name = "ContinuousInvalidationParent"
	_scene.add_child(temporary_parent)
	temporary_parent.owner = _scene
	_panel.set_parent_node(temporary_parent)
	var began: bool = _start_placement() and _move_pointer(_pointer_position)
	_scene.remove_child(temporary_parent)
	var invalid_click: int = _placement_plugin.process_pointer(_camera, _left_click())
	var unchanged: bool = temporary_parent.get_child_count() == 0 and _history.get_version() == history_before
	_panel.set_parent_node(_parent)
	temporary_parent.free()
	if not began or not _require(invalid_click == EditorPlugin.AFTER_GUI_INPUT_PASS and unchanged, "An invalidated parent accepted another continuous placement."):
		return false
	if not _require_inactive("Parent invalidation"):
		return false
	if not _start_placement() or not _move_pointer(_pointer_position):
		return false
	_panel.hide()
	var hidden_start_requested: bool = _press("StartPlacement")
	var hidden_snapshot: Dictionary = _placement_plugin.get_snapshot()
	_panel.show()
	if not _require(hidden_start_requested and not _bool(hidden_snapshot, "active") and not _bool(hidden_snapshot, "preview_visible"), "A hidden panel accepted Start and revived its cancelled continuous session."):
		return false
	_results["continuous_configuration_and_parent_invalidation"] = true
	return true


func _check_continuous_creation_cancellation() -> bool:
	if not _start_placement():
		return false
	var children_before: int = _parent.get_child_count()
	var history_before: int = _history.get_version()
	var observed: Array[bool] = [false]
	var cancel_creation: Callable = func(_child: Node) -> void:
		observed[0] = true
		_placement_plugin.cancel_placement()
	var connected: int = _parent.child_entered_tree.connect(cancel_creation)
	if not _require(connected == OK, "Could not connect synchronous continuous creation cancellation."):
		return false
	var _confirm_consumed: int = _placement_plugin.process_pointer(_camera, _left_click())
	_parent.child_entered_tree.disconnect(cancel_creation)
	if not _require(observed[0] and _parent.get_child_count() == children_before and _history.get_version() == history_before, "Cancellation during creation left an instance or history entry."):
		return false
	return _require_inactive("Synchronous creation cancellation")


func _check_continuous_inspector_reentry(replace_session: bool) -> bool:
	if not _start_placement():
		return false
	var children_before: int = _parent.get_child_count()
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var observed: Dictionary = { "entered": false, "replacement_ready": false }
	var on_edited_object_changed: Callable = func() -> void:
		if _bool(observed, "entered"):
			return
		var edited: Object = inspector.get_edited_object()
		if not edited is Node3D:
			return
		var edited_node: Node3D = edited
		if edited_node.get_parent() != _parent or _parent.get_child_count() != children_before + 1:
			return
		observed["entered"] = true
		_placement_plugin.cancel_placement()
		if replace_session:
			observed["replacement_ready"] = _start_placement() and _move_pointer(_pointer_position + Vector2(12.0, 0.0))
			var _nested_confirm: int = _placement_plugin.process_pointer(_camera, _key_press(KEY_ENTER))
	var connected: int = inspector.edited_object_changed.connect(on_edited_object_changed)
	if not _require(connected == OK, "Could not connect native Inspector confirmation reentry."):
		return false
	var _confirmed: int = _placement_plugin.process_pointer(_camera, _left_click())
	inspector.edited_object_changed.disconnect(on_edited_object_changed)
	if not _require(_bool(observed, "entered") and _parent.get_child_count() == children_before + 1, "Confirmation did not synchronously enter the real Inspector callback after committing one instance."):
		return false
	if replace_session:
		var snapshot: Dictionary = _placement_plugin.get_snapshot()
		if not _require(_bool(observed, "replacement_ready") and _bool(snapshot, "active") and _bool(snapshot, "preview_visible") and _int(snapshot, "state") == GFEditorPickOperation.State.READY, "The old confirmation replaced or cancelled the Inspector callback's newly armed session."):
			return false
		_placement_plugin.cancel_placement()
	else:
		if not _require_inactive("Inspector callback cancellation"):
			return false
	if not _require(_history.undo() and _parent.get_child_count() == children_before, "Inspector callback cancellation changed the committed instance's undo history."):
		return false
	return true


func _require_continuous_pending() -> bool:
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	return _require(_bool(snapshot, "active") and not _bool(snapshot, "preview_visible") and _int(snapshot, "state") == GFEditorPickOperation.State.PICKING, "Continuous confirmation must await a fresh hit without reusing the old preview.")


func _require_inactive(reason: String) -> bool:
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	return _require(not _bool(snapshot, "active") and not _bool(snapshot, "preview_visible"), reason + " retained an active operation or preview.")


func _move_pointer(position: Vector2) -> bool:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	var consumed: int = _placement_plugin.process_pointer(_camera, motion)
	return _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS and _bool(_placement_plugin.get_snapshot(), "preview_visible"), "Fresh native pointer motion did not produce a placement preview.")


func _check_confirmation_failure_feedback() -> bool:
	_panel.set_source_scene(_load_scene(_ASSET))
	_panel.set_parent_node(_parent)
	if not _start_placement():
		return false
	var history_version: int = _history.get_version()
	var children_before: int = _parent.get_child_count()
	var callback_reached: Array[bool] = [false]
	var reject_created_child: Callable = func(child: Node) -> void:
		callback_reached[0] = true
		child.queue_free()
	var connected: int = _parent.child_entered_tree.connect(reject_created_child)
	if not _require(connected == OK, "Could not install the synchronous creation failure fixture."):
		return false
	var consumed: int = _placement_plugin.process_pointer(_camera, _left_click())
	_parent.child_entered_tree.disconnect(reject_created_child)
	if not _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS and callback_reached[0], "Confirmation did not reach the actual creation failure."):
		return false
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	if not _require(not _bool(snapshot, "active") and not _bool(snapshot, "preview_visible"), "Failed confirmation retained an active operation or preview."):
		return false
	if not _require(_parent.get_child_count() == children_before and _history.get_version() == history_version, "Failed confirmation left an instance or changed native history."):
		return false
	if not _require(_int(snapshot, "last_error") == ERR_CANT_CREATE, "Failed confirmation did not preserve its error code."):
		return false
	var status_node: Node = _panel.get_node_or_null(^"PlacementStatus")
	if not _require(status_node is Label, "The placement status label is missing."):
		return false
	if status_node is Label:
		var status: Label = status_node
		if not _require(status.text.contains("未能创建场景实例") and status.text.contains("工具脚本") and status.text.contains("creation_failed"), "Failed confirmation did not show its cause, suggested check, and diagnostic reason: " + status.text):
			return false
	_results["confirmation_failure_feedback_and_cleanup"] = true
	return true


func _surface_pointer() -> void:
	_phase = &"running"
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = _pointer_position
	var consumed: int = _placement_plugin.process_pointer(_camera, move)
	if not _require(consumed != EditorPlugin.AFTER_GUI_INPUT_PASS, "Surface pointer motion bypassed the tool."):
		return
	if not _require(_bool(_placement_plugin.get_snapshot(), "preview_visible"), "The real editor collision world did not yield a visible surface candidate."):
		return
	var before: int = _parent.get_child_count()
	var confirmed: int = _placement_plugin.process_pointer(_camera, _left_click())
	if not _require(confirmed != EditorPlugin.AFTER_GUI_INPUT_PASS and _parent.get_child_count() == before + 1, "Actual editor world ray did not hit StaticBody3D/CollisionShape3D for surface placement."):
		return
	var created: Node3D = _last_placed_child()
	if not _require(created != null and absf(created.global_position.y) < 0.001 and created.global_position.distance_to(_pointer_world) < 0.01, "Surface placement did not land on the fixture's real floor collision."):
		return
	if not _require(_history.undo() and _parent.get_child_count() == before, "Surface confirmation did not produce a reversible native action."):
		return
	_results["actual_editor_world_collision_surface"] = true
	_set_mode(0)
	_panel.set_source_scene(_load_scene(_SCRIPTED_ASSET))
	_panel.set_parent_node(_parent)
	if not _start_placement():
		return
	var _preview_consumed: int = _placement_plugin.process_pointer(_camera, move)
	if not _require(_panel.is_continuous_placement_enabled() and _bool(_placement_plugin.get_snapshot(), "active"), "Scene switching must interrupt an active continuous session."):
		return
	_phase = &"scene_b"
	EditorInterface.open_scene_from_path(_SCENE_B)


func _wait_scene_b() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_B:
		return
	_phase = &"running"
	var manager: EditorUndoRedoManager = get_undo_redo()
	var second_id: int = manager.get_object_history_id(root)
	if not _require(second_id > 0 and second_id != _scene_history_id, "Two opened scenes did not receive distinct native histories."):
		return
	var second_parent: Node3D = _node_3d(root.get_node_or_null(^"PlacementParent"))
	var second_camera_value: Node = root.get_node_or_null(^"PointerCamera")
	if not _require(second_parent != null and second_camera_value is Camera3D, "Scene B fixture is incomplete."):
		return
	var second_camera: Camera3D = null
	if second_camera_value is Camera3D:
		second_camera = second_camera_value
	var children_before: int = second_parent.get_child_count()
	var response: int = _placement_plugin.process_pointer(second_camera, _left_click())
	if not _require(response == EditorPlugin.AFTER_GUI_INPUT_PASS and second_parent.get_child_count() == children_before and _canary_count() == 0, "A scene switch retained an armed pointer operation from the previous scene."):
		return
	var snapshot: Dictionary = _placement_plugin.get_snapshot()
	if not _require(not _bool(snapshot, "active") and not _bool(snapshot, "preview_visible"), "Scene switching retained the previous preview proxy."):
		return
	_results["scene_switch_cancels_stale_pointer"] = true
	_results["second_scene_history_id"] = second_id
	_phase = &"return_scene_a"
	EditorInterface.open_scene_from_path(_SCENE_A)


func _return_scene_a() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != _SCENE_A:
		return
	_phase = &"running"
	_panel.set_source_scene(_load_scene(_SCRIPTED_ASSET))
	_panel.set_parent_node(_parent)
	if not _set_continuous(true) or not _start_placement() or not _move_pointer(_pointer_position):
		return
	_plugin_ref = weakref(_placement_plugin)
	_panel_ref = weakref(_panel)
	if not _press("ClosePlacementPlugin"):
		return
	_placement_plugin = null
	_panel = null
	_phase = &"unload_settle"
	_frames = 0


func _after_unload() -> void:
	_phase = &"running"
	if not _require(_plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Plugin disable did not release the plugin and panel."):
		return
	if not _require(_canary_count() == 0, "Unloading an active continuous preview instantiated its scripted source."):
		return
	if not _require(_history.redo(), "History could not replay after the placement plugin was unloaded."):
		return
	if not _require(_history.undo(), "History could not undo after the placement plugin was unloaded."):
		return
	if not _require(_native_node.get_instance_id() == _native_node_id and _native_node.global_transform.is_equal_approx(_expected_world), "Unloading the plugin altered the earlier committed instance."):
		return
	_results["unloaded_plugin_history_replay"] = true
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	if not _capture_launched_plugin():
		return
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher.set_editor_context(null)
	_phase = &"independent_context_clear_settle"
	_frames = 0


func _after_independent_context_clear() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_survives_context_clear"] = true
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	_launcher.free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_replacement_settle"
	_frames = 0


func _after_independent_replacement() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_survives_page_replacement"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _press_launcher("CloseScenePlacement"):
		return
	if not _open_launcher():
		return
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_open_settle"
	_frames = 0


func _after_independent_open() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_plugin_open_does_not_claim_ownership"] = true
	_results["independent_plugin_close_then_open_preserves_child"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _press_launcher("CloseScenePlacement"):
		return
	_phase = &"independent_close_settle"
	_frames = 0


func _after_independent_close() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Explicit launcher Close did not release the independently enabled plugin and panel."):
		return
	_results["independent_plugin_explicit_close_releases_child"] = true
	_launcher.queue_free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	_launcher_ref = weakref(_launcher)
	if not _open_launcher():
		return
	_phase = &"launcher_open_settle"
	_frames = 0


func _open_launcher() -> bool:
	return _press_launcher("OpenScenePlacement")


func _press_launcher(button_name: String) -> bool:
	var button_node: Node = _launcher.get_node_or_null(NodePath(button_name))
	if not _require(button_node is Button, "The launcher has no native plugin control: " + button_name):
		return false
	if button_node is Button:
		var control_button: Button = button_node
		control_button.pressed.emit()
	return true


func _require_independent_plugin() -> bool:
	return _require(
		EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() != null and _panel_ref.get_ref() != null,
		"A launcher lifecycle change closed the independently enabled plugin or replaced its native panel."
	)


func _capture_launched_plugin() -> bool:
	var launched_plugin: GFScenePlacementPlugin = null
	for candidate: Node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate is GFScenePlacementPlugin:
			launched_plugin = candidate
			break
	if not _require(EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and launched_plugin != null, "Launcher activation did not create an engine-owned plugin."):
		return false
	var launched_panel: GFScenePlacementPanel = launched_plugin.get_panel()
	if not _require(launched_panel != null and launched_panel.is_inside_tree(), "Launcher activation did not attach the native placement panel."):
		return false
	_plugin_ref = weakref(launched_plugin)
	_panel_ref = weakref(launched_panel)
	return true


func _after_launcher_open() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_launcher.set_editor_context(null)
	_phase = &"launcher_context_clear_settle"
	_frames = 0


func _after_launcher_context_clear() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Clearing launcher context did not disable and release the child plugin and panel."):
		return
	_results["launcher_context_clear_releases_child"] = true
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	if not _open_launcher():
		return
	_phase = &"launcher_reopen_settle"
	_frames = 0


func _after_launcher_reopen() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_launcher.queue_free()
	_launcher = null
	_phase = &"launcher_exit_settle"
	_frames = 0


func _after_launcher_exit() -> void:
	_phase = &"running"
	if not _require(_launcher_ref.get_ref() == null and not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "Destroying the launcher did not release the native child plugin and panel."):
		return
	_results["launcher_exit_releases_child"] = true
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher() or not _capture_launched_plugin():
		return
	_launcher.set_editor_context(null)
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	if not _capture_launched_plugin():
		return
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	_launcher.queue_free()
	_launcher = null
	_phase = &"independent_reenable_settle"
	_frames = 0


func _after_independent_reenable() -> void:
	_phase = &"running"
	if not _require_independent_plugin():
		return
	_results["independent_reenabled_plugin_survives_old_owner"] = true
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)
	_phase = &"independent_reenable_cleanup_settle"
	_frames = 0


func _after_independent_reenable_cleanup() -> void:
	_phase = &"running"
	if not _require(not EditorInterface.is_plugin_enabled(_PLUGIN_NAME) and _plugin_ref.get_ref() == null and _panel_ref.get_ref() == null, "The independent re-enable fixture did not release its native plugin and panel."):
		return
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher():
		return
	_launcher.free()
	_launcher = GFScenePlacementLauncher.new()
	_launcher.set_editor_context(GFEditorToolContext.from_plugin(self))
	add_child(_launcher)
	if not _open_launcher():
		return
	_phase = &"launcher_replacement_settle"
	_frames = 0


func _after_launcher_replacement() -> void:
	_phase = &"running"
	if not _capture_launched_plugin():
		return
	_results["launcher_same_frame_replacement_preserves_child"] = true
	if not _require(_launcher.is_inside_tree() and EditorInterface.is_plugin_enabled(_PLUGIN_NAME), "The editor exit probe must retain an active launcher and child plugin until shutdown."):
		return
	_results["launcher_left_enabled_for_editor_exit"] = true
	_phase = &"finish_settle"
	_frames = 0


func _save_and_reload() -> bool:
	var packed: PackedScene = PackedScene.new()
	if not _require(packed.pack(_scene) == OK and ResourceSaver.save(packed, _SAVED_SCENE) == OK, "The placed scene could not be saved to isolated output."):
		return false
	var reloaded: PackedScene = _load_scene(_SAVED_SCENE)
	if reloaded == null:
		return false
	var clone: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not _require(clone is Node3D, "Saved scene reload has the wrong root type."):
		if clone != null:
			clone.free()
		return false
	var cloned_parent: Node3D = _node_3d(clone.get_node_or_null(^"PlacementParent"))
	var cloned_node: Node3D = null
	if cloned_parent != null:
		cloned_node = _node_3d(cloned_parent.get_node_or_null(NodePath(String(_native_node.name))))
	var valid: bool = _require(cloned_parent != null and cloned_node != null, "Saved scene omitted the placed instance.")
	if valid:
		valid = _require((cloned_parent.transform * cloned_node.transform).is_equal_approx(_expected_world), "Save/reload changed the placed transform under a non-unit parent.")
		valid = _require(cloned_node.owner == clone, "Saved scene did not preserve owner routing.") and valid
	clone.free()
	return valid


func _operation(path: String, options: Dictionary = {}) -> GFScenePlacementOperation:
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	if not _require(operation.configure(_load_scene(path), _parent, _scene, options) == OK, "Could not configure the native placement operation."):
		return null
	if not _require(operation.begin(GFEditorToolContext.from_plugin(self)), "Could not begin native placement with editor context."):
		return null
	return operation


func _load_scene(path: String) -> PackedScene:
	var loaded: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var _valid: bool = _require(loaded is PackedScene, "Expected a saved PackedScene: " + path)
	if loaded is PackedScene:
		var scene: PackedScene = loaded
		return scene
	return null


func _set_mode(index: int) -> void:
	var node: Node = _panel.find_child("PlacementMode", true, false)
	var _valid: bool = _require(node is OptionButton, "Placement mode control is missing.")
	if node is OptionButton:
		var picker: OptionButton = node
		picker.select(index)
		picker.item_selected.emit(index)


func _set_continuous(enabled: bool) -> bool:
	var control: Node = _panel.find_child("ContinuousPlacement", true, false)
	if not _require(control is CheckBox, "The continuous placement checkbox is missing."):
		return false
	if control is CheckBox:
		var checkbox: CheckBox = control
		checkbox.button_pressed = enabled
	return _require(_panel.is_continuous_placement_enabled() == enabled, "The continuous placement getter disagrees with the native checkbox.")


func _start_placement() -> bool:
	var branch: Node = _panel
	var ancestor: Node = branch.get_parent()
	while ancestor != null:
		if ancestor is TabContainer and branch is Control:
			var tabs: TabContainer = ancestor
			var tab_control: Control = branch
			var index: int = tabs.get_tab_idx_from_control(tab_control)
			if index >= 0:
				tabs.current_tab = index
		branch = ancestor
		ancestor = ancestor.get_parent()
	if not _require(_panel.is_visible_in_tree(), "The placement dock could not be selected."):
		return false
	return _press("StartPlacement")


func _press(name_value: String) -> bool:
	var node: Node = _panel.find_child(name_value, true, false)
	var _valid: bool = _require(node is Button, "Missing placement control: " + name_value)
	if node is Button:
		var button: Button = node
		if not _require(not button.disabled, "Placement control is unexpectedly disabled: " + name_value):
			return false
		button.pressed.emit()
		return true
	return false


func _left_click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _pointer_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _key_press(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _ray(origin: Vector3) -> Dictionary:
	return { "ray_origin": origin, "ray_direction": Vector3.DOWN }


func _node_3d(value: Variant) -> Node3D:
	if value is Node3D:
		var node: Node3D = value
		return node
	return null


func _last_placed_child() -> Node3D:
	if _parent.get_child_count() == 0:
		return null
	return _node_3d(_parent.get_child(_parent.get_child_count() - 1))


func _transform(report: Dictionary, key: String) -> Transform3D:
	var value: Variant = report.get(key)
	if value is Transform3D:
		var transform_value: Transform3D = value
		return transform_value
	_fail("Missing or wrongly typed transform: " + key)
	return Transform3D.IDENTITY


func _bool(report: Dictionary, key: String) -> bool:
	var value: Variant = report.get(key)
	if value is bool:
		var boolean: bool = value
		return boolean
	_fail("Missing or wrongly typed bool: " + key)
	return false


func _int(report: Dictionary, key: String) -> int:
	var value: Variant = report.get(key)
	if value is int:
		var integer: int = value
		return integer
	_fail("Missing or wrongly typed int: " + key)
	return -1


func _canary_count() -> int:
	var value: Variant = Engine.get_meta(_CANARY_KEY, -1)
	if value is int:
		var count: int = value
		return count
	return -1


func _require(condition: bool, message: String) -> bool:
	_assertions += 1
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_FAILED " + message)
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_DETAILS " + JSON.stringify(_results))
	get_tree().quit(1)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_results["assertions"] = _assertions
	print("GF_SCENE_PLACEMENT_EDITOR_SMOKE_OK " + JSON.stringify(_results))
	get_tree().quit(0)


# --- 信号处理函数 ---

func _on_frame() -> void:
	if _finished:
		return
	if Time.get_ticks_msec() > _deadline:
		_fail("Editor smoke exceeded its deadline in phase " + String(_phase))
		return
	_frames += 1
	match _phase:
		&"startup":
			if _frames >= 12:
				_phase = &"running"
				_startup()
		&"scene_a":
			await _wait_scene_a()
		&"asset_workbench":
			await _check_asset_workbench()
		&"native_forward_wait":
			if _frames >= 3:
				_check_native_forward()
		&"native_render_wait":
			if _frames >= 6:
				_complete_native_forward()
		&"cancel_settle":
			if _frames >= 5:
				_after_cancel()
		&"surface_wait":
			if _frames >= 12:
				_surface_pointer()
		&"scene_b":
			_wait_scene_b()
		&"return_scene_a":
			_return_scene_a()
		&"unload_settle":
			if _frames >= 8:
				_after_unload()
		&"independent_context_clear_settle":
			if _frames >= 8:
				_after_independent_context_clear()
		&"independent_replacement_settle":
			if _frames >= 8:
				_after_independent_replacement()
		&"independent_open_settle":
			if _frames >= 8:
				_after_independent_open()
		&"independent_close_settle":
			if _frames >= 8:
				_after_independent_close()
		&"launcher_open_settle":
			if _frames >= 8:
				_after_launcher_open()
		&"launcher_context_clear_settle":
			if _frames >= 8:
				_after_launcher_context_clear()
		&"launcher_reopen_settle":
			if _frames >= 8:
				_after_launcher_reopen()
		&"launcher_exit_settle":
			if _frames >= 8:
				_after_launcher_exit()
		&"independent_reenable_settle":
			if _frames >= 8:
				_after_independent_reenable()
		&"independent_reenable_cleanup_settle":
			if _frames >= 8:
				_after_independent_reenable_cleanup()
		&"launcher_replacement_settle":
			if _frames >= 8:
				_after_launcher_replacement()
		&"finish_settle":
			if _frames >= 8:
				_finish()
