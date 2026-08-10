## 测试通用标签集合与查询工具。
extends GutTest


func test_tag_query_matches_all_any_none_with_hierarchy() -> void:
	var tag_set: GFTagSet = GFTagSet.new()
	var _burning_added: GFTagSet = tag_set.add_tag(&"state.burning", 2)
	var _enemy_added: GFTagSet = tag_set.add_tag(&"team.enemy")
	var query: GFTagQuery = GFTagQuery.new()
	query.all_tags = [&"state"]
	query.any_tags = [&"team.enemy", &"team.ally"]
	query.none_tags = [&"state.frozen"]
	query.include_child_tags = true

	var report: Dictionary = query.get_match_report(tag_set)
	var missing_all: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "missing_all"))
	var blocked_tags: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "blocked_tags"))

	assert_true(GFVariantData.get_option_bool(report, "ok"), "层级标签应能满足父级查询。")
	assert_true(missing_all.is_empty(), "满足 all 条件时不应报告缺失。")
	assert_true(blocked_tags.is_empty(), "未命中 none 条件时不应报告阻塞。")


func test_tag_query_reports_blocked_tags() -> void:
	var tag_set: GFTagSet = GFTagSet.new()
	var _tags_set: GFTagSet = tag_set.set_tags([&"state.stunned"])
	var query: GFTagQuery = GFTagQuery.new()
	query.none_tags = [&"state.stunned"]

	var report: Dictionary = query.get_match_report(tag_set)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "命中禁止标签时查询应失败。")
	assert_eq(GFVariantData.get_option_array(report, "blocked_tags"), [&"state.stunned"], "报告应包含阻塞标签。")


func test_tag_utility_reads_object_protocol_and_dictionary_sources() -> void:
	var component: SampleTagSource = SampleTagSource.new()
	component.add_tag(&"state.burning", 2)
	var dictionary_source: Dictionary = {
		"tags": PackedStringArray(["state.frozen", "team.enemy"]),
	}

	assert_true(GFTagSourceAdapter.source_has_tag(component, &"state", 2, true), "工具应读取对象标签协议并支持层级层数。")
	assert_true(GFTagSourceAdapter.source_has_tag(dictionary_source, &"state", 1, true), "工具应读取字典标签源。")
	assert_eq(component.get_tags(), PackedStringArray(["state.burning"]), "对象标签协议应提供可枚举快照。")


func test_tag_source_adapter_uses_object_has_tag_for_exact_minimum_count() -> void:
	var source: HasTagOnlySource = HasTagOnlySource.new()

	assert_true(GFTagSourceAdapter.source_has_tag(source, &"charged", 2), "对象只实现 has_tag 时，精确匹配仍应传入 minimum_count。")
	assert_false(GFTagSourceAdapter.source_has_tag(source, &"charged", 3), "minimum_count 不满足时不应因为无法枚举而误判通过。")
	assert_false(GFTagSourceAdapter.source_has_tag(source, &"charged", 2, true), "层级匹配需要可枚举标签源，不能用 has_tag 伪装。")


func test_tag_set_hierarchical_count_refreshes_after_direct_tag_counts_mutation() -> void:
	var tag_set: GFTagSet = GFTagSet.new()
	var _burning_added: GFTagSet = tag_set.add_tag(&"state.burning", 2)
	var first_count: int = tag_set.get_tag_count(&"state", true)

	tag_set.tag_counts[&"state.frozen"] = 3
	var second_count: int = tag_set.get_tag_count(&"state", true)

	assert_eq(first_count, 2, "首次层级计数应包含子标签。")
	assert_eq(second_count, 5, "直接修改 tag_counts 后层级计数缓存应刷新。")


func test_tag_set_hierarchical_count_signature_escapes_delimiters() -> void:
	var tag_set: GFTagSet = GFTagSet.new()
	tag_set.tag_counts = {
		&"a=1|b": 2,
	}
	var first_count: int = tag_set.get_tag_count(&"a=1|b", true)

	tag_set.tag_counts = {
		&"a": 1,
		&"b": 2,
	}
	var second_count: int = tag_set.get_tag_count(&"a", true)

	assert_eq(first_count, 2, "首次查询应建立层级计数缓存。")
	assert_eq(second_count, 1, "包含分隔符的旧标签不应让不同 tag_counts 复用缓存。")


func test_tag_source_adapter_supports_one_argument_has_tag_protocol() -> void:
	var source: OneArgumentHasTagSource = OneArgumentHasTagSource.new()

	assert_true(GFTagSourceAdapter.source_has_tag(source, &"ready"), "一参数 has_tag 协议应能用于精确匹配。")
	assert_false(GFTagSourceAdapter.source_has_tag(source, &"missing"), "一参数 has_tag 协议仍应保留对象自身判断。")


func test_tag_source_adapter_passes_include_child_tags_to_two_argument_count_protocol() -> void:
	var source: TwoArgumentTagCountSource = TwoArgumentTagCountSource.new()

	assert_eq(GFTagSourceAdapter.get_tag_count(source, &"state", false), 0, "未启用层级时应请求精确计数。")
	assert_eq(GFTagSourceAdapter.get_tag_count(source, &"state", true), 3, "二参数 get_tag_count 应接收 include_child_tags。")
	assert_true(GFTagSourceAdapter.source_has_tag(source, &"state", 3, true), "层级查询应使用对象协议的完整计数。")


func test_tag_source_adapter_normalizes_sources_to_counts_and_sets() -> void:
	var dictionary_source: Dictionary = {
		"tag_counts": {
			&"state.burning": 2,
			"team.enemy": 1,
		},
	}
	var array_source: PackedStringArray = PackedStringArray(["state.burning", "state.burning", "rank.elite"])

	var counts: Dictionary = GFTagSourceAdapter.get_tag_counts(dictionary_source)
	var tag_set: GFTagSet = GFTagSourceAdapter.to_tag_set(array_source)

	assert_eq(GFVariantData.get_option_int(counts, &"state.burning"), 2, "字典来源应规范化为标签层数字典。")
	assert_eq(GFVariantData.get_option_int(counts, &"team.enemy"), 1, "String key 应规范化为 StringName。")
	assert_eq(tag_set.get_tag_count(&"state.burning"), 2, "数组来源应规范化为 GFTagSet。")
	assert_eq(tag_set.get_tag_count(&"rank.elite"), 1, "数组来源应保留普通标签。")


func test_tag_source_adapter_preserves_mixed_array_and_empty_tag_semantics() -> void:
	var source: Array = [&"state.ready", "state.ready", 1, "1", ""]

	var counts: Dictionary = GFTagSourceAdapter.get_tag_counts(source)

	assert_eq(GFVariantData.get_option_int(counts, &"state.ready"), 2, "StringName 与 String 应规范化为同一标签。")
	assert_eq(GFVariantData.get_option_int(counts, &"1"), 2, "混合数组中的原始值应保留既有文本转换语义。")
	assert_eq(GFVariantData.get_option_int(counts, &""), 1, "空标签也必须保留既有计数语义。")
	assert_eq(counts.size(), 3, "单遍计数不得引入额外标签。")


func test_tag_source_adapter_merges_multiple_sources() -> void:
	var component: SampleTagSource = SampleTagSource.new()
	component.add_tag(&"state.burning", 2)
	var merged: GFTagSet = GFTagSourceAdapter.merge_sources([
		component,
		[&"state.burning", &"team.enemy"],
		{ "tag_counts": { &"team.enemy": 2 } },
	])

	assert_eq(merged.get_tag_count(&"state.burning"), 3, "合并时应累加不同来源的标签层数。")
	assert_eq(merged.get_tag_count(&"team.enemy"), 3, "合并时应累加字典和数组来源。")


# --- 内部类 ---

class SampleTagSource:
	extends RefCounted

	var _tags: GFTagSet = GFTagSet.new()

	func add_tag(tag: StringName, count: int = 1) -> void:
		var _added: GFTagSet = _tags.add_tag(tag, count)

	func has_tag(tag: StringName, minimum_count: int = 1) -> bool:
		return get_tag_count(tag) >= minimum_count

	func get_tag_count(tag: StringName) -> int:
		return _tags.get_tag_count(tag)

	func get_tags() -> PackedStringArray:
		return _tags.get_tags()


class HasTagOnlySource:
	extends RefCounted

	func has_tag(tag: StringName, minimum_count: int = 1) -> bool:
		return tag == &"charged" and minimum_count <= 2


class OneArgumentHasTagSource:
	extends RefCounted

	func has_tag(tag: StringName) -> bool:
		return tag == &"ready"


class TwoArgumentTagCountSource:
	extends RefCounted

	func get_tag_count(tag: StringName, include_child_tags: bool) -> int:
		if tag == &"state" and include_child_tags:
			return 3
		return 0

	func get_tags() -> PackedStringArray:
		return PackedStringArray(["state.burning"])
