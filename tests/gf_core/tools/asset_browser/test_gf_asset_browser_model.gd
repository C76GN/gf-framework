@tool
extends GutTest


const GF_ASSET_BROWSER_MODEL_SCRIPT = preload("res://addons/gf/tools/asset_browser/gf_asset_browser_model.gd")


class ImmediateFailRenderer extends GFThumbnailRenderer:
	func submit_render_request(request: GFThumbnailRenderRequest) -> GFThumbnailRenderTask:
		var task: GFThumbnailRenderTask = GFThumbnailRenderTask.new(request, 1)
		var _failed: bool = task.fail("intentional_test_failure")
		return task


func test_catalog_replacement_is_isolated_and_invalidates_missing_selection() -> void:
	var source_catalog: GFAssetCatalog = _make_catalog([
		_make_entry(&"alpha", "Alpha", { "license": "CC0" }),
	])
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()

	var first_report: Dictionary = model.replace_catalog(source_catalog)
	assert_true(GFVariantData.get_option_bool(first_report, "ok"))
	assert_eq(GFVariantData.get_option_int(first_report, "catalog_revision"), 1)
	assert_true(model.select_asset(&"alpha"))

	var source_entry: GFAssetCatalogEntry = source_catalog.get_entry(&"alpha")
	source_entry.title = "Mutated"
	assert_true(source_catalog.set_entry(source_entry))
	var first_page: Dictionary = model.get_page()
	var first_items: Array = GFVariantData.get_option_array(first_page, "items")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.as_dictionary(first_items[0]), "title"),
		"Alpha",
		"模型必须持有隔离目录快照，不能观察到 provider 后续修改。"
	)

	var replacement_catalog: GFAssetCatalog = _make_catalog([
		_make_entry(&"beta", "Beta"),
	])
	var second_report: Dictionary = model.replace_catalog(replacement_catalog)

	assert_true(GFVariantData.get_option_bool(second_report, "ok"))
	assert_eq(GFVariantData.get_option_int(second_report, "catalog_revision"), 2)
	assert_eq(model.get_selected_asset_id(), &"", "目录替换后必须清除已经不存在的稳定选择。")


func test_nested_catalog_and_selection_notifications_are_fifo() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _initial_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"alpha", "Alpha"),
	]))
	assert_true(model.select_asset(&"alpha"))
	var first_catalog_revisions: Array[int] = []
	var second_catalog_revisions: Array[int] = []
	var second_selection_ids: Array[StringName] = []
	var nested_once: Array[bool] = [false]
	var first_catalog_callback: Callable = func(
		catalog_revision: int,
		_query_generation: int
	) -> void:
		first_catalog_revisions.append(catalog_revision)
		if catalog_revision != 2 or nested_once[0]:
			return
		nested_once[0] = true
		var _nested_report: Dictionary = model.replace_catalog(_make_catalog([
			_make_entry(&"gamma", "Gamma"),
		]))
		var _selected: bool = model.select_asset(&"gamma")
	var second_catalog_callback: Callable = func(
		catalog_revision: int,
		_query_generation: int
	) -> void:
		second_catalog_revisions.append(catalog_revision)
	var selection_callback: Callable = func(
		asset_id: StringName
	) -> void:
		second_selection_ids.append(asset_id)
	var _first_catalog_connected: Error = model.catalog_changed.connect(first_catalog_callback) as Error
	var _second_catalog_connected: Error = model.catalog_changed.connect(second_catalog_callback) as Error
	var _selection_connected: Error = model.selection_changed.connect(selection_callback) as Error

	var outer_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"beta", "Beta"),
	]))

	assert_true(GFVariantData.get_option_bool(outer_report, "ok"))
	assert_eq(first_catalog_revisions, [2, 3])
	assert_eq(
		second_catalog_revisions,
		[2, 3],
		"同步嵌套替换不能让后注册监听器先看到新 revision、再看到旧 revision。"
	)
	assert_eq(
		second_selection_ids,
		[&"", &"gamma"],
		"目录清空选择与嵌套新选择必须按提交顺序各发布一次。"
	)
	assert_eq(model.get_selected_asset_id(), &"gamma")
	model.catalog_changed.disconnect(first_catalog_callback)
	model.catalog_changed.disconnect(second_catalog_callback)
	model.selection_changed.disconnect(selection_callback)
	model.dispose()


func test_nested_query_notifications_are_fifo() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var first_generations: Array[int] = []
	var second_generations: Array[int] = []
	var nested_once: Array[bool] = [false]
	var first_callback: Callable = func(
		query_generation: int
	) -> void:
		first_generations.append(query_generation)
		if not nested_once[0]:
			nested_once[0] = true
			var _nested_report: Dictionary = model.set_query("nested")
	var second_callback: Callable = func(
		query_generation: int
	) -> void:
		second_generations.append(query_generation)
	var _first_connected: Error = model.query_changed.connect(first_callback) as Error
	var _second_connected: Error = model.query_changed.connect(second_callback) as Error

	var outer_report: Dictionary = model.set_query("outer")

	assert_true(GFVariantData.get_option_bool(outer_report, "ok"))
	assert_eq(first_generations, [1, 2])
	assert_eq(
		second_generations,
		[1, 2],
		"同步嵌套查询不能使后注册监听器逆序观察 generation。"
	)
	model.query_changed.disconnect(first_callback)
	model.query_changed.disconnect(second_callback)
	model.dispose()


func test_nested_selection_aba_notifications_preserve_commit_order() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _replace_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"alpha", "Alpha"),
		_make_entry(&"beta", "Beta"),
	]))
	assert_true(model.select_asset(&"alpha"))
	var second_selection_ids: Array[StringName] = []
	var nested_once: Array[bool] = [false]
	var first_callback: Callable = func(
		asset_id: StringName
	) -> void:
		if asset_id != &"beta" or nested_once[0]:
			return
		nested_once[0] = true
		var _selected_alpha: bool = model.select_asset(&"alpha")
		var _selected_beta: bool = model.select_asset(&"beta")
	var second_callback: Callable = func(
		asset_id: StringName
	) -> void:
		second_selection_ids.append(asset_id)
	var _first_connected: Error = model.selection_changed.connect(first_callback) as Error
	var _second_connected: Error = model.selection_changed.connect(second_callback) as Error

	assert_true(model.select_asset(&"beta"))

	assert_eq(
		second_selection_ids,
		[&"beta", &"alpha", &"beta"],
		"ABA 重入必须逐次发布提交时的稳定选择，不能从 live state 重读或倒序。"
	)
	assert_eq(model.get_selected_asset_id(), &"beta")
	model.selection_changed.disconnect(first_callback)
	model.selection_changed.disconnect(second_callback)
	model.dispose()


func test_dispose_discards_notifications_committed_but_not_yet_dispatched() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _initial_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"alpha", "Alpha"),
	]))
	assert_true(model.select_asset(&"alpha"))
	var selection_ids: Array[StringName] = []
	var catalog_callback: Callable = func(
		_catalog_revision: int,
		_query_generation: int
	) -> void:
		model.dispose()
	var selection_callback: Callable = func(
		asset_id: StringName
	) -> void:
		selection_ids.append(asset_id)
	var _catalog_connected: Error = model.catalog_changed.connect(catalog_callback) as Error
	var _selection_connected: Error = model.selection_changed.connect(selection_callback) as Error

	var replace_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"beta", "Beta"),
	]))

	assert_true(GFVariantData.get_option_bool(replace_report, "ok"))
	assert_true(selection_ids.is_empty(), "dispose 后不能继续发布同一提交批次的尾随选择通知。")
	assert_false(model.select_asset(&"beta"), "dispose 必须保持写入口终态关闭。")
	model.catalog_changed.disconnect(catalog_callback)
	model.selection_changed.disconnect(selection_callback)


func test_nested_preview_resolution_notifications_are_fifo() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _replace_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"mesh", "Mesh"),
	]))
	var renderer: ImmediateFailRenderer = ImmediateFailRenderer.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_mesh_texture(BoxMesh.new())
	var second_generations: Array[int] = []
	var nested_once: Array[bool] = [false]
	var first_callback: Callable = func(_report: Dictionary) -> void:
		if nested_once[0]:
			return
		nested_once[0] = true
		var _nested_task: GFThumbnailRenderTask = model.request_preview(&"mesh", renderer, request)
	var second_callback: Callable = func(report: Dictionary) -> void:
		assert_true(report.is_read_only(), "预览通知必须发布提交时冻结的报告 payload。")
		second_generations.append(GFVariantData.get_option_int(report, "preview_generation"))
	var _first_connected: Error = model.preview_resolved.connect(first_callback) as Error
	var _second_connected: Error = model.preview_resolved.connect(second_callback) as Error

	var first_task: GFThumbnailRenderTask = model.request_preview(&"mesh", renderer, request)

	assert_not_null(first_task)
	assert_true(first_task.is_finished())
	assert_eq(
		second_generations,
		[1, 2],
		"同步完成的嵌套预览必须按代际提交顺序发布，不能穿透当前信号分发。"
	)
	model.preview_resolved.disconnect(first_callback)
	model.preview_resolved.disconnect(second_callback)
	model.dispose()
	renderer.free()


func test_terminal_preview_task_does_not_keep_a_completion_connection() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _replace_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"mesh", "Mesh"),
	]))
	var renderer: ImmediateFailRenderer = ImmediateFailRenderer.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_mesh_texture(
		BoxMesh.new()
	)

	var task: GFThumbnailRenderTask = model.request_preview(&"mesh", renderer, request)

	assert_not_null(task)
	assert_true(task.is_finished())
	assert_true(
		task.completed.get_connections().is_empty(),
		"终态任务不能遗留只会持有陈旧预览代际的 completion 连接。"
	)
	model.dispose()
	renderer.free()


func test_query_generation_and_page_size_are_bounded() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var catalog: GFAssetCatalog = _make_catalog([
		_make_entry(&"alpha", "Alpha"),
		_make_entry(&"beta", "Beta", { "license": "CC-BY" }),
		_make_entry(&"gamma", "Gamma"),
	])
	var _replace_report: Dictionary = model.replace_catalog(catalog)

	var query_report: Dictionary = model.set_query("Beta")
	var query_generation: int = GFVariantData.get_option_int(query_report, "query_generation")
	var page: Dictionary = model.get_page(1, 10_000)
	var items: Array = GFVariantData.get_option_array(page, "items")
	var item: Dictionary = GFVariantData.as_dictionary(items[0])
	var metadata: Dictionary = GFVariantData.get_option_dictionary(item, "metadata")

	assert_true(GFVariantData.get_option_bool(query_report, "ok"))
	assert_eq(query_generation, 2, "目录替换和查询变化必须分别推进查询 generation。")
	assert_eq(
		GFVariantData.get_option_int(page, "page_size"),
		GF_ASSET_BROWSER_MODEL_SCRIPT.MAX_PAGE_SIZE,
		"调用方不能绕过模型的分页上限。"
	)
	assert_eq(GFVariantData.get_option_int(page, "total_count"), 1)
	assert_eq(GFVariantData.get_option_string(item, "asset_id"), "beta")
	assert_eq(GFVariantData.get_option_string(metadata, "license"), "CC-BY", "通用来源元数据必须原样保留。")

	var oversized_query: String = "x".repeat(GF_ASSET_BROWSER_MODEL_SCRIPT.MAX_QUERY_LENGTH + 1)
	var rejected_report: Dictionary = model.set_query(oversized_query)
	assert_false(GFVariantData.get_option_bool(rejected_report, "ok"))
	assert_eq(GFVariantData.get_option_string(rejected_report, "error"), "query_too_long")
	assert_eq(
		GFVariantData.get_option_int(rejected_report, "query_generation"),
		query_generation,
		"被拒绝的查询不能使已发布页面代际失效。"
	)


func test_preview_requests_cancel_superseded_thumbnail_tasks() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _replace_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"mesh", "Mesh"),
	]))
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var first_request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_mesh_texture(BoxMesh.new())
	var second_request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_mesh_texture(SphereMesh.new())

	var first_task: GFThumbnailRenderTask = model.request_preview(&"mesh", renderer, first_request)
	var first_generation: int = model.get_preview_generation()
	var second_task: GFThumbnailRenderTask = model.request_preview(&"mesh", renderer, second_request)

	assert_not_null(first_task)
	assert_not_null(second_task)
	assert_true(first_task.is_cancelled(), "新代际预览必须取消旧的等待任务。")
	assert_eq(model.get_preview_generation(), first_generation + 1)
	assert_true(model.get_active_preview_task() == second_task)
	assert_true(model.cancel_preview(&"test_cancel"))
	assert_true(second_task.is_cancelled())
	assert_null(model.get_active_preview_task(), "终态任务不能继续被模型持有。")
	assert_true(
		second_task.completed.get_connections().is_empty(),
		"一次性 completion 连接必须随异步任务终态自动释放。"
	)
	renderer.free()


func test_catalog_replacement_rejects_cyclic_metadata_without_mutating_state() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var initial_metadata: Dictionary = {
		"provenance": "internal-library",
		"license": "CC-BY-4.0",
		"hash": "sha256:stable",
	}
	var _initial_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"stable", "Stable", initial_metadata),
	]))
	assert_true(model.select_asset(&"stable"))
	var initial_revision: int = model.get_catalog_revision()
	var initial_generation: int = model.get_query_generation()
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var active_task: GFThumbnailRenderTask = model.request_preview(
		&"stable",
		renderer,
		GFThumbnailRenderRequest.for_mesh_texture(BoxMesh.new())
	)
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	var hostile_entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	hostile_entry.asset_id = &"hostile"
	hostile_entry.title = "Hostile"
	hostile_entry.metadata = cyclic_metadata
	var hostile_catalog: GFAssetCatalog = GFAssetCatalog.new()
	hostile_catalog.entries.append(hostile_entry)

	var report: Dictionary = model.replace_catalog(hostile_catalog)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string(report, "error"), "catalog_metadata_cycle")
	assert_eq(model.get_catalog_revision(), initial_revision)
	assert_eq(model.get_query_generation(), initial_generation)
	assert_eq(model.get_selected_asset_id(), &"stable")
	assert_true(model.get_active_preview_task() == active_task)
	assert_false(active_task.is_cancelled(), "拒绝的目录不能取消仍属于旧快照的预览任务。")
	_assert_first_page_metadata_equals(model, initial_metadata)
	var _cancelled: bool = model.cancel_preview(&"test_cleanup")
	renderer.free()


func test_catalog_replacement_rejects_invalid_last_entry_atomically() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var _initial_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"stable", "Stable", { "license": "MIT" }),
	]))
	assert_true(model.select_asset(&"stable"))
	var initial_revision: int = model.get_catalog_revision()
	var initial_generation: int = model.get_query_generation()
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var active_task: GFThumbnailRenderTask = model.request_preview(
		&"stable",
		renderer,
		GFThumbnailRenderRequest.for_mesh_texture(BoxMesh.new())
	)
	var invalid_catalog: GFAssetCatalog = GFAssetCatalog.new()
	for index: int in range(256):
		var asset_id: StringName = StringName("candidate_%03d" % index)
		invalid_catalog.entries.append(_make_entry(asset_id, "Candidate %03d" % index))
	invalid_catalog.entries.append(_make_entry(&"candidate_000", "Duplicate Last"))

	var report: Dictionary = model.replace_catalog(invalid_catalog)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string(report, "error"), "duplicate_catalog_asset_id")
	assert_eq(model.get_catalog_revision(), initial_revision)
	assert_eq(model.get_query_generation(), initial_generation)
	assert_eq(model.get_selected_asset_id(), &"stable")
	assert_true(model.get_active_preview_task() == active_task)
	assert_false(active_task.is_cancelled())
	var page: Dictionary = model.get_page()
	assert_eq(GFVariantData.get_option_int(page, "total_count"), 1)
	var items: Array = GFVariantData.get_option_array(page, "items")
	assert_eq(GFVariantData.get_option_string(
		GFVariantData.as_dictionary(items[0]),
		"asset_id"
	), "stable")
	var _cancelled: bool = model.cancel_preview(&"test_cleanup")
	renderer.free()


func test_large_catalog_replacement_builds_one_complete_index() -> void:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	const ENTRY_COUNT: int = 2048
	for index: int in range(ENTRY_COUNT):
		var asset_id: StringName = StringName("asset_%04d" % index)
		catalog.entries.append(_make_entry(asset_id, "Asset %04d" % index))
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()

	var report: Dictionary = model.replace_catalog(catalog)
	var last_page: Dictionary = model.get_page(21, 100)
	var items: Array = GFVariantData.get_option_array(last_page, "items")

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_int(report, "asset_count"), ENTRY_COUNT)
	assert_eq(GFVariantData.get_option_int(last_page, "total_count"), ENTRY_COUNT)
	assert_eq(GFVariantData.get_option_int(last_page, "page_count"), 21)
	assert_eq(items.size(), 48)
	assert_eq(GFVariantData.get_option_string(
		GFVariantData.as_dictionary(items[0]),
		"asset_id"
	), "asset_2000")


func test_catalog_replacement_rejects_oversized_metadata_without_truncating_attribution() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var initial_metadata: Dictionary = {
		"provenance": "curated-source",
		"license": "MIT",
		"hash": "sha256:unchanged",
	}
	var _initial_report: Dictionary = model.replace_catalog(_make_catalog([
		_make_entry(&"stable", "Stable", initial_metadata),
	]))
	var initial_revision: int = model.get_catalog_revision()
	var initial_generation: int = model.get_query_generation()
	var oversized_entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	oversized_entry.asset_id = &"oversized"
	oversized_entry.metadata = {
		"provenance": "x".repeat(1_000_000),
		"license": "MIT",
		"hash": "sha256:hostile",
	}
	var oversized_catalog: GFAssetCatalog = GFAssetCatalog.new()
	oversized_catalog.entries.append(oversized_entry)

	var report: Dictionary = model.replace_catalog(oversized_catalog)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(report, "error"),
		"catalog_metadata_text_limit_exceeded"
	)
	assert_eq(model.get_catalog_revision(), initial_revision)
	assert_eq(model.get_query_generation(), initial_generation)
	_assert_first_page_metadata_equals(model, initial_metadata)


func test_query_filters_fail_closed_and_dispose_is_terminal_for_writes() -> void:
	var model: GF_ASSET_BROWSER_MODEL_SCRIPT = GF_ASSET_BROWSER_MODEL_SCRIPT.new()
	var catalog: GFAssetCatalog = _make_catalog([_make_entry(&"stable", "Stable")])
	var _replace_report: Dictionary = model.replace_catalog(catalog)
	var initial_generation: int = model.get_query_generation()

	var whitespace_report: Dictionary = model.set_query("", PackedStringArray([" "]))
	var padded_report: Dictionary = model.set_query("", PackedStringArray([" stable "]))
	assert_false(GFVariantData.get_option_bool(whitespace_report, "ok"))
	assert_false(GFVariantData.get_option_bool(padded_report, "ok"))
	assert_eq(model.get_query_generation(), initial_generation)

	model.dispose()
	var disposed_catalog_report: Dictionary = model.replace_catalog(catalog)
	var disposed_query_report: Dictionary = model.set_query("Stable")
	assert_eq(
		GFVariantData.get_option_string(disposed_catalog_report, "error"),
		"disposed"
	)
	assert_eq(GFVariantData.get_option_string(disposed_query_report, "error"), "disposed")
	assert_false(model.select_asset(&"stable"))
	var renderer: GFThumbnailRenderer = GFThumbnailRenderer.new()
	var request: GFThumbnailRenderRequest = GFThumbnailRenderRequest.for_mesh_texture(
		BoxMesh.new()
	)
	assert_null(model.request_preview(&"stable", renderer, request))
	renderer.free()


func _make_catalog(entries: Array[GFAssetCatalogEntry]) -> GFAssetCatalog:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	for entry: GFAssetCatalogEntry in entries:
		assert_true(catalog.set_entry(entry))
	return catalog


func _make_entry(
	asset_id: StringName,
	title: String,
	metadata: Dictionary = {}
) -> GFAssetCatalogEntry:
	return GFAssetCatalogEntry.new().configure(asset_id, "", {
		"title": title,
		"metadata": metadata,
	})


func _assert_first_page_metadata_equals(
	model: GF_ASSET_BROWSER_MODEL_SCRIPT,
	expected: Dictionary
) -> void:
	var items: Array = GFVariantData.get_option_array(model.get_page(), "items")
	assert_eq(items.size(), 1)
	var item: Dictionary = GFVariantData.as_dictionary(items[0])
	assert_eq(GFVariantData.get_option_dictionary(item, "metadata"), expected)
