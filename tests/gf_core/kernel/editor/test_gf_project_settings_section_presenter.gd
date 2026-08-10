# 测试 Project Settings 分区展示适配器的对称清理。
@tool

extends GutTest


const GF_PROJECT_SETTINGS_SECTION_PRESENTER_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_project_settings_section_presenter.gd"
)


# --- 测试 ---

func test_cleanup_restores_original_tree_item_presentation() -> void:
	var presenter: RefCounted = GF_PROJECT_SETTINGS_SECTION_PRESENTER_SCRIPT.new()
	var catalog: RecordingCatalog = RecordingCatalog.new()
	var tree: Tree = Tree.new()
	var item: TreeItem = tree.create_item()
	item.set_metadata(0, "gf/test")
	item.set_text(0, "Original label")
	item.set_tooltip_text(0, "Original tooltip")
	presenter.set("_catalog", catalog)

	presenter.call("_apply_section_presentations", item)
	presenter.call("_apply_section_presentations", item)

	assert_eq(item.get_text(0), "Localized label", "展示适配器应应用本地化标签。")
	assert_eq(item.get_tooltip_text(0), "Localized tooltip", "展示适配器应应用本地化悬浮说明。")

	presenter.call("cleanup")

	assert_eq(item.get_text(0), "Original label", "cleanup 应恢复接管前标签。")
	assert_eq(item.get_tooltip_text(0), "Original tooltip", "cleanup 应恢复接管前悬浮说明。")
	tree.free()


func test_cleanup_preserves_external_changes_made_after_presentation() -> void:
	var presenter: RefCounted = GF_PROJECT_SETTINGS_SECTION_PRESENTER_SCRIPT.new()
	var catalog: RecordingCatalog = RecordingCatalog.new()
	var tree: Tree = Tree.new()
	var item: TreeItem = tree.create_item()
	item.set_metadata(0, "gf/test")
	item.set_text(0, "Original label")
	item.set_tooltip_text(0, "Original tooltip")
	presenter.set("_catalog", catalog)
	presenter.call("_apply_section_presentations", item)
	item.set_text(0, "Editor rebuilt label")
	item.set_tooltip_text(0, "Editor rebuilt tooltip")

	presenter.call("cleanup")

	assert_eq(item.get_text(0), "Editor rebuilt label", "cleanup 不应覆盖后续外部标签。")
	assert_eq(item.get_tooltip_text(0), "Editor rebuilt tooltip", "cleanup 不应覆盖后续外部说明。")
	tree.free()


# --- 内部类 ---

class RecordingCatalog extends RefCounted:
	func get_section_presentation(
		section_path: String,
		_locale: String = ""
	) -> Dictionary:
		if section_path != "gf/test":
			return {}
		return {
			"label": "Localized label",
			"tooltip": "Localized tooltip",
		}
