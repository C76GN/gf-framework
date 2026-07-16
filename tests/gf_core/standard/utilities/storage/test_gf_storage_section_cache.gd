## 测试 GFStorageSectionCache 的分区缓存、脏标记和后端能力报告。
extends GutTest


# --- 测试方法 ---

func test_section_cache_builds_dirty_payload_and_marks_clean() -> void:
	var cache: GFStorageSectionCache = GFStorageSectionCache.new()
	assert_true(cache.write_section(&"profile", &"stats", { "hp": 10 }), "写入分区应成功。")
	assert_true(cache.write_section(&"profile", &"inventory", { "coins": 3 }, false), "可写入非脏分区。")

	var stats: Dictionary = cache.read_section(&"profile", &"stats")
	var dirty_payload: Dictionary = cache.build_payload(&"profile")
	var dirty_sections: Dictionary = GFVariantData.get_option_dictionary(dirty_payload, "sections")

	assert_eq(GFVariantData.get_option_int(stats, "hp"), 10, "写入分区后应能读回数据。")
	assert_true(cache.is_dirty(&"profile", &"stats"), "默认写入应标记分区为脏。")
	assert_true(dirty_sections.has(&"stats"), "默认 payload 应包含脏分区。")
	assert_false(dirty_sections.has(&"inventory"), "默认 payload 不应包含干净分区。")
	var clean_count: int = cache.mark_clean(&"profile", PackedStringArray(["stats"]))
	assert_eq(clean_count, 1, "mark_clean 应返回被清理数量。")
	assert_false(cache.is_dirty(&"profile"), "清理后作用域不应仍为脏。")


func test_section_cache_deep_merges_and_can_include_clean_sections() -> void:
	var cache: GFStorageSectionCache = GFStorageSectionCache.new()
	assert_true(cache.write_section("world", &"region", {
		"weather": {
			"rain": 1,
			"wind": 2,
		},
	}, false), "初始分区应写入。")

	var merged: Dictionary = cache.merge_section("world", &"region", {
		"weather": {
			"rain": 3,
		},
	})
	var payload: Dictionary = cache.build_payload("world", true, true)
	var sections: Dictionary = GFVariantData.get_option_dictionary(payload, "sections")
	var region: Dictionary = GFVariantData.get_option_dictionary(sections, &"region")
	var weather: Dictionary = GFVariantData.get_option_dictionary(region, "weather")

	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(merged, "weather"), "wind"), 2, "深合并应保留未覆盖字段。")
	assert_eq(GFVariantData.get_option_int(weather, "rain"), 3, "include_clean payload 应包含最终分区值。")
	assert_false(cache.is_dirty("world"), "mark_clean_after_build 应清理脏状态。")


func test_storage_backend_capability_report_lists_known_data() -> void:
	var backend: MemoryStorageBackend = MemoryStorageBackend.new()
	backend.set_record("a.json", { "value": 1 })
	backend.set_record("b.json", { "value": 2 })

	var report: Dictionary = backend.get_capability_report({
		"label": "memory",
		"include_data_names": true,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "能力报告应成功。")
	assert_eq(GFVariantData.get_option_string(report, "label"), "memory", "报告应保留调用方标签。")
	assert_eq(GFVariantData.get_option_int(report, "data_count"), 2, "报告应统计文件数量。")
	assert_eq(GFVariantData.get_option_packed_string_array(report, "data_names"), PackedStringArray(["a.json", "b.json"]), "报告应返回排序后的文件名。")


# --- 辅助类型 ---

class MemoryStorageBackend:
	extends GFStorageBackend

	var records: Dictionary = {}

	func set_record(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> void:
		records[file_name] = {
			"data": data.duplicate(true),
			"metadata": metadata.duplicate(true),
		}

	func _save_data(file_name: String, data: Dictionary, metadata: Dictionary) -> Error:
		set_record(file_name, data, metadata)
		return OK

	func _load_data(file_name: String) -> Dictionary:
		if not records.has(file_name):
			return {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": "missing",
			}
		var record: Dictionary = GFVariantData.get_option_dictionary(records, file_name)
		return {
			"ok": true,
			"data": GFVariantData.get_option_dictionary(record, "data"),
			"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
			"error": "",
		}

	func _list_data() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for file_name: String in records.keys():
			result.append({
				"file_name": file_name,
			})
		return result

	func _get_capabilities() -> Dictionary:
		return {
			"read": true,
			"write": true,
			"delete": false,
			"list": true,
			"sync": true,
		}
