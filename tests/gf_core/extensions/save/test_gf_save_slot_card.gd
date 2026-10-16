## 测试 GFSaveSlotCard 从槽位摘要配置、状态标识与字典序列化。
extends GutTest


func test_default_card_reports_empty_status() -> void:
	var card: GFSaveSlotCard = GFSaveSlotCard.new()
	assert_true(card.is_empty, "新卡片预设为空槽。")
	assert_eq(
		card.get_status_id(),
		&"empty",
		"空槽状态标识应为 empty。"
	)


func test_configure_from_summary_sets_index_display_and_active() -> void:
	var summary: Dictionary = {
		"slot_index": 2,
		"modified_time": 100,
		"metadata": { "display_name": "Save 2", "description": "Line1" },
		"is_compatible": true,
	}
	var card: GFSaveSlotCard = GFSaveSlotCard.new().configure_from_slot_summary(
		summary,
		&"",
		2
	)
	assert_eq(
		card.slot_index,
		2,
		"应采用摘要中的 slot_index。"
	)
	assert_true(card.is_active, "当前选中索引一致时应标记为 active。")
	assert_false(card.is_empty, "已配置摘要后不应为空槽。")
	assert_eq(
		card.display_name,
		"Save 2",
		"应从 metadata 读取显示名称。"
	)
	assert_eq(
		card.description,
		"Line1",
		"应从 metadata 读取描述。"
	)
	assert_eq(
		card.get_status_id(),
		&"active",
		"当前选中槽位状态标识应为 active。"
	)


func test_parse_trailing_digits_from_slot_id_string() -> void:
	var summary: Dictionary = {
		"metadata": { "slot_id": "slot_profile_7" },
		"modified_time": 1,
	}
	var card: GFSaveSlotCard = GFSaveSlotCard.new().configure_from_slot_summary(
		summary,
		&"",
		-1
	)
	assert_eq(
		card.slot_index,
		7,
		"slot_id 字符串末尾连续数字应解析为槽位索引。"
	)


func test_incompatible_card_status_id() -> void:
	var summary: Dictionary = {
		"slot_index": 0,
		"is_compatible": false,
		"metadata": {},
	}
	var card: GFSaveSlotCard = GFSaveSlotCard.new().configure_from_slot_summary(summary)
	assert_eq(
		card.get_status_id(),
		&"incompatible",
		"不兼容槽位应报告 incompatible。"
	)


func test_ready_status_when_not_active() -> void:
	var summary: Dictionary = {
		"slot_index": 1,
		"is_compatible": true,
		"metadata": {},
	}
	var card: GFSaveSlotCard = GFSaveSlotCard.new().configure_from_slot_summary(
		summary,
		&"",
		0
	)
	assert_eq(
		card.get_status_id(),
		&"ready",
		"非当前选中且兼容时应为 ready。"
	)


func test_from_slot_summary_static_factory() -> void:
	var card: GFSaveSlotCard = GFSaveSlotCard.from_slot_summary({ "slot_index": 5, "metadata": {} })
	assert_eq(
		card.slot_index,
		5,
		"静态工厂应创建已配置的卡片。"
	)


func test_to_dict_contains_core_fields() -> void:
	var card: GFSaveSlotCard = GFSaveSlotCard.new()
	card.slot_index = 3
	card.slot_id = &"three"
	card.display_name = "T"
	card.is_empty = false
	card.is_compatible = true
	card.is_active = false
	card.modified_time = 99
	card.metadata = { "k": 1 }
	card.compatibility_errors = PackedStringArray(["e1"])
	var d: Dictionary = card.to_dict()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(d, "metadata")
	var compatibility_errors: PackedStringArray = GFVariantData.get_option_packed_string_array(d, "compatibility_errors")
	assert_eq(
		GFVariantData.get_option_int(d, "slot_index"),
		3
	)
	assert_eq(
		GFVariantData.get_option_string_name(d, "slot_id"),
		&"three"
	)
	assert_eq(
		GFVariantData.get_option_string(d, "display_name"),
		"T"
	)
	assert_eq(
		GFVariantData.get_option_bool(d, "is_empty"),
		false
	)
	assert_eq(
		GFVariantData.get_option_bool(d, "is_compatible"),
		true
	)
	assert_eq(
		GFVariantData.get_option_bool(d, "is_active"),
		false
	)
	assert_eq(
		GFVariantData.get_option_string_name(d, "status_id"),
		&"ready"
	)
	assert_eq(
		GFVariantData.get_option_int(d, "modified_time"),
		99
	)
	assert_eq(
		GFVariantData.get_option_int(metadata, "k"),
		1
	)
	assert_eq(
		compatibility_errors.size(),
		1
	)


func test_compatibility_errors_from_array_in_summary() -> void:
	var summary: Dictionary = {
		"slot_index": 0,
		"is_compatible": false,
		"compatibility_errors": ["missing_header", "bad_crc"],
		"metadata": {},
	}
	var card: GFSaveSlotCard = GFSaveSlotCard.new().configure_from_slot_summary(summary)
	assert_eq(
		card.compatibility_errors.size(),
		2
	)
	assert_eq(
		card.compatibility_errors[0],
		"missing_header"
	)
