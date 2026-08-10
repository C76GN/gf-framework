## 测试版本化存档文档、schema 和确定性迁移注册表。
extends GutTest


# --- 测试方法 ---

func test_save_document_round_trip_is_canonical_and_isolated() -> void:
	var source_payload: Dictionary = { "level": 3 }
	var section: GFSaveSection = GFSaveSection.new().configure(
		&"profile",
		1,
		source_payload,
		{ "owner": "profile_module" }
	)
	var sections: Array[GFSaveSection] = [section]
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		&"game.save",
		1,
		sections,
		{ "build": "dev" }
	)
	source_payload["level"] = 99

	var encoded: Dictionary = document.to_dict()
	var inspection: Dictionary = GFSaveDocument.inspect_dict(encoded)
	var restored: GFSaveDocument = GFSaveDocument.from_dict(encoded)

	assert_true(GFVariantData.get_option_bool(inspection, "ok"), "规范文档应通过字典检查。")
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.get_schema_id(), &"game.save")
	assert_eq(restored.get_schema_version(), 1)
	assert_eq(restored.get_section_ids(), PackedStringArray(["profile"]))
	assert_eq(_get_section_payload_int(restored, &"profile", "level"), 3, "文档必须隔离配置时的动态数据。")
	var encoded_sections: Dictionary = GFVariantData.get_option_dictionary(encoded, "sections")
	var encoded_profile: Dictionary = GFVariantData.get_option_dictionary(encoded_sections, "profile")
	var encoded_payload: Dictionary = GFVariantData.get_option_dictionary(encoded_profile, "payload")
	encoded_payload["level"] = 100
	assert_eq(_get_section_payload_int(document, &"profile", "level"), 3, "to_dict() 输出不得反向修改文档。")


func test_save_document_rejects_legacy_bare_payload_and_future_container() -> void:
	var legacy_report: Dictionary = GFSaveDocument.inspect_dict({ "hp": 10 })
	var document: GFSaveDocument = _make_document(1, 1, { "level": 1 })
	var future_data: Dictionary = document.to_dict()
	future_data["format_version"] = GFSaveDocument.FORMAT_VERSION + 1
	var future_report: Dictionary = GFSaveDocument.inspect_dict(future_data)
	var unknown_field_data: Dictionary = document.to_dict()
	unknown_field_data["future_field"] = true
	var unknown_field_report: Dictionary = GFSaveDocument.inspect_dict(unknown_field_data)

	assert_false(GFVariantData.get_option_bool(legacy_report, "ok"), "旧裸 Dictionary 不得伪装成版本化文档。")
	assert_false(GFVariantData.get_option_bool(future_report, "ok"), "未来容器版本必须 fail-closed。")
	assert_false(GFVariantData.get_option_bool(unknown_field_report, "ok"), "同一容器版本不得静默丢弃未知字段。")
	assert_null(GFSaveDocument.from_dict(future_data))


func test_save_document_rejects_coercive_identity_and_version_fields() -> void:
	var invalid_values: Array = [1.5, "1", true]
	for invalid_value: Variant in invalid_values:
		var invalid_format_version: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
		invalid_format_version["format_version"] = invalid_value
		_assert_document_dictionary_rejected(
			invalid_format_version,
			"format_version 不得接受隐式类型转换：%s" % [invalid_value]
		)

		var invalid_schema_version: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
		invalid_schema_version["schema_version"] = invalid_value
		_assert_document_dictionary_rejected(
			invalid_schema_version,
			"schema_version 不得接受隐式类型转换：%s" % [invalid_value]
		)

		var invalid_section_version: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
		var section_map: Dictionary = GFVariantData.get_option_dictionary(invalid_section_version, "sections")
		var profile_section: Dictionary = GFVariantData.get_option_dictionary(section_map, "profile")
		profile_section["schema_version"] = invalid_value
		section_map["profile"] = profile_section
		invalid_section_version["sections"] = section_map
		_assert_document_dictionary_rejected(
			invalid_section_version,
			"分区 schema_version 不得接受隐式类型转换：%s" % [invalid_value]
		)

	var invalid_format: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
	invalid_format["format"] = StringName(GFSaveDocument.FORMAT_ID)
	_assert_document_dictionary_rejected(invalid_format, "format 必须保持规范 String 类型。")

	var invalid_schema_id: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
	invalid_schema_id["schema_id"] = 42
	_assert_document_dictionary_rejected(invalid_schema_id, "schema_id 不得把数值强转为标识。")

	var invalid_section_id: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
	var sections: Dictionary = GFVariantData.get_option_dictionary(invalid_section_id, "sections")
	var profile: Dictionary = GFVariantData.get_option_dictionary(sections, "profile")
	profile["section_id"] = 42
	sections["profile"] = profile
	invalid_section_id["sections"] = sections
	_assert_document_dictionary_rejected(invalid_section_id, "section_id 不得把数值强转为标识。")


func test_save_section_and_schema_dictionary_parsers_fail_closed() -> void:
	var canonical_section: Dictionary = GFSaveSection.new().configure(
		&"profile",
		1,
		{ "level": 1 }
	).to_dict()
	assert_not_null(GFSaveSection.from_dict(canonical_section), "规范分区应可解析。")

	var fractional_section: Dictionary = canonical_section.duplicate(true)
	fractional_section["schema_version"] = 1.5
	assert_null(GFSaveSection.from_dict(fractional_section), "独立分区解析也必须拒绝小数版本。")
	var repaired_metadata_section: Dictionary = canonical_section.duplicate(true)
	repaired_metadata_section["metadata"] = "not-a-dictionary"
	assert_null(GFSaveSection.from_dict(repaired_metadata_section), "分区解析不得把错误 metadata 修补为空字典。")
	var unknown_section_field: Dictionary = canonical_section.duplicate(true)
	unknown_section_field["future_field"] = true
	assert_null(GFSaveSection.from_dict(unknown_section_field), "分区解析不得忽略未知字段。")

	var canonical_schema: Dictionary = _make_schema(1, { &"profile": 1 }).to_dict()
	assert_not_null(GFSaveDocumentSchema.from_dict(canonical_schema), "规范 schema 应可解析。")
	var fractional_schema: Dictionary = canonical_schema.duplicate(true)
	var section_versions: Dictionary = GFVariantData.get_option_dictionary(
		fractional_schema,
		"section_versions"
	)
	section_versions[&"profile"] = 1.5
	fractional_schema["section_versions"] = section_versions
	assert_null(GFSaveDocumentSchema.from_dict(fractional_schema), "schema 分区版本不得接受小数。")
	var coercive_flag_schema: Dictionary = canonical_schema.duplicate(true)
	coercive_flag_schema["allow_unknown_sections"] = "true"
	assert_null(GFSaveDocumentSchema.from_dict(coercive_flag_schema), "schema 布尔选项不得接受字符串转换。")
	var unknown_schema_field: Dictionary = canonical_schema.duplicate(true)
	unknown_schema_field["future_field"] = true
	assert_null(GFSaveDocumentSchema.from_dict(unknown_schema_field), "schema 解析不得忽略未知字段。")


func test_save_document_rejects_every_noncanonical_raw_section_key() -> void:
	var canonical: Dictionary = _make_document(1, 1, { "level": 1 }).to_dict()
	var canonical_sections: Dictionary = GFVariantData.get_option_dictionary(canonical, "sections")
	var canonical_profile: Dictionary = GFVariantData.get_option_dictionary(
		canonical_sections,
		"profile"
	)
	var cases: Array[Variant] = ["", " ", " profile ", 42]
	for raw_key: Variant in cases:
		var candidate: Dictionary = canonical.duplicate(true)
		var sections: Dictionary = GFVariantData.get_option_dictionary(candidate, "sections")
		sections[raw_key] = canonical_profile.duplicate(true)
		candidate["sections"] = sections
		_assert_document_dictionary_rejected(
			candidate,
			"非规范 section key 必须被逐个拒绝：%s" % [raw_key]
		)

	var alias_candidate: Dictionary = canonical.duplicate(true)
	var alias_sections: Dictionary = GFVariantData.get_option_dictionary(
		alias_candidate,
		"sections"
	)
	var alias_profile: Dictionary = canonical_profile.duplicate(true)
	alias_profile["section_id"] = " profile "
	alias_sections[" profile "] = alias_profile
	alias_candidate["sections"] = alias_sections
	_assert_document_dictionary_rejected(
		alias_candidate,
		"trim 后与规范 key 冲突的 alias 不得被静默丢弃。"
	)


func test_persisted_value_boundaries_validate_before_deep_copy() -> void:
	var circular_payload: Dictionary = {}
	circular_payload["self"] = circular_payload
	var section: GFSaveSection = GFSaveSection.new().configure(
		&"profile",
		1,
		circular_payload
	)
	var section_report: Dictionary = section.validate_section()
	assert_false(
		GFVariantData.get_option_bool(section_report, "ok"),
		"循环 payload 应结构化拒绝，且不得先触发引擎递归错误。"
	)

	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	var document: GFSaveDocument = GFSaveDocument.new().configure(
		&"game.save",
		1,
		[],
		circular_metadata
	)
	var document_report: Dictionary = document.validate_document()
	assert_false(
		GFVariantData.get_option_bool(document_report, "ok"),
		"循环 metadata 应在复制前被有界校验拒绝。"
	)

	var deep_payload: Dictionary = {}
	var cursor: Dictionary = deep_payload
	for index: int in range(65):
		var next: Dictionary = { "index": index }
		cursor["next"] = next
		cursor = next
	var deep_section: GFSaveSection = GFSaveSection.new().configure(&"deep", 1, deep_payload)
	assert_false(
		GFVariantData.get_option_bool(deep_section.validate_section(), "ok"),
		"超过持久化深度预算的 payload 应在深复制前失败关闭。"
	)


func test_save_document_schema_distinguishes_migration_from_future_versions() -> void:
	var schema: GFSaveDocumentSchema = _make_schema(2, { &"profile": 2 })
	var old_document: GFSaveDocument = _make_document(1, 1, { "level": 1 })
	var compatible_report: Dictionary = schema.validate_document(old_document, false)
	var exact_report: Dictionary = schema.validate_document(old_document, true)
	var future_document: GFSaveDocument = _make_document(3, 3, { "level": 1 })
	var future_report: Dictionary = schema.validate_document(future_document, false)

	assert_true(GFVariantData.get_option_bool(compatible_report, "ok"), "旧版本在迁移前检查中应是可迁移状态。")
	assert_true(GFVariantData.get_option_bool(compatible_report, "migration_required"))
	assert_false(GFVariantData.get_option_bool(exact_report, "ok"), "提交前必须要求当前版本。")
	assert_false(GFVariantData.get_option_bool(future_report, "ok"), "未来版本不可向后读取。")


func test_migration_registry_migrates_document_then_sections_transactionally() -> void:
	var source: GFSaveDocument = _make_document(1, 1, { "level": 3 })
	var unknown_section: GFSaveSection = GFSaveSection.new().configure(
		&"mod.extra",
		7,
		{ "enabled": true }
	)
	assert_true(source.set_section(unknown_section))
	var schema: GFSaveDocumentSchema = _make_schema(
		2,
		{ &"profile": 2, &"inventory": 1 },
		PackedStringArray(["profile", "inventory"]),
		true
	)
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	var document_step: AddInventoryDocumentStep = AddInventoryDocumentStep.new()
	var profile_step: UpgradeProfileSectionStep = UpgradeProfileSectionStep.new()
	assert_true(registry.register_step(document_step))
	assert_true(registry.register_step(profile_step))
	document_step.to_version = 99
	profile_step.section_id = &"mutated_after_registration"

	var result: GFSaveMigrationResult = registry.migrate(source, schema, { "request_id": "test" })
	var migrated: GFSaveDocument = result.get_document()

	assert_true(result.is_successful(), result.get_error())
	assert_true(result.was_migrated())
	assert_not_null(migrated)
	if migrated == null:
		return
	assert_eq(source.get_schema_version(), 1, "迁移不得原地修改来源文档。")
	assert_false(source.has_section(&"inventory"), "失败或成功迁移都不得回写来源分区集合。")
	assert_eq(migrated.get_schema_version(), 2)
	assert_eq(migrated.get_section(&"profile").get_schema_version(), 2)
	assert_eq(_get_section_payload_int(migrated, &"profile", "experience"), 30)
	assert_eq(_get_section_payload_int(migrated, &"inventory", "capacity"), 20)
	assert_true(migrated.has_section(&"mod.extra"), "允许未知分区时必须原样保留。")
	assert_eq(migrated.get_section(&"mod.extra").get_schema_version(), 7)
	var trace: Array[Dictionary] = result.get_trace()
	assert_eq(trace.size(), 2)
	assert_eq(GFVariantData.get_option_string_name(trace[0], "step_id"), &"document_1_to_2")
	assert_eq(GFVariantData.get_option_string_name(trace[1], "step_id"), &"profile_1_to_2")


func test_migration_registry_missing_edge_returns_no_partial_document() -> void:
	var source: GFSaveDocument = _make_document(1, 1, { "level": 3 })
	var schema: GFSaveDocumentSchema = _make_schema(2, { &"profile": 2 })
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	assert_true(registry.register_step(AddInventoryDocumentStep.new()))

	var result: GFSaveMigrationResult = registry.migrate(source, schema)

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), ERR_DOES_NOT_EXIST)
	assert_null(result.get_document(), "迁移链不完整时不得暴露只完成文档步骤的中间结果。")
	assert_eq(source.get_schema_version(), 1)
	assert_eq(source.get_section(&"profile").get_schema_version(), 1)


func test_migration_registry_rejects_duplicate_edges_and_step_ids() -> void:
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	var first: UpgradeProfileSectionStep = UpgradeProfileSectionStep.new()
	var duplicate_edge: UpgradeProfileSectionStep = UpgradeProfileSectionStep.new()
	duplicate_edge.step_id = &"different_id"
	var duplicate_id: AddInventoryDocumentStep = AddInventoryDocumentStep.new()
	duplicate_id.step_id = first.step_id

	assert_true(registry.register_step(first))
	assert_false(registry.register_step(duplicate_edge), "同一版本 edge 只能注册一次。")
	assert_false(registry.register_step(duplicate_id), "step_id 必须全局唯一。")
	assert_eq(registry.describe_steps().size(), 1)


func test_document_migration_cannot_bypass_section_version_steps() -> void:
	var source: GFSaveDocument = _make_document(1, 1, { "level": 3 })
	var schema: GFSaveDocumentSchema = _make_schema(2, { &"profile": 2 })
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	assert_true(registry.register_step(BypassSectionVersionDocumentStep.new()))

	var result: GFSaveMigrationResult = registry.migrate(source, schema)

	assert_false(result.is_successful())
	assert_eq(result.get_failed_step_id(), &"bypass_profile_version")
	assert_true(result.get_error().contains("must not change"))
	assert_null(result.get_document())


func test_migration_executes_the_preflight_step_snapshot_during_registry_reentry() -> void:
	var source: GFSaveDocument = _make_document(1, 1, { "level": 3 })
	var schema: GFSaveDocumentSchema = _make_schema(3, { &"profile": 1 })
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	assert_true(registry.register_step(ClearRegistryDocumentStep.new()))
	assert_true(registry.register_step(AdvanceDocumentStep.new()))

	var result: GFSaveMigrationResult = registry.migrate(source, schema, {
		"registry": registry,
	})

	assert_true(result.is_successful(), result.get_error())
	assert_eq(result.get_document().get_schema_version(), 3)
	assert_eq(result.get_trace().size(), 2, "运行中的 registry 变更不得改变已验收迁移计划。")
	assert_eq(registry.describe_steps().size(), 0, "测试 hook 应确实清空 live registry。")
	assert_eq(source.get_schema_version(), 1, "迁移始终只操作来源副本。")


# --- 私有/辅助方法 ---

func _make_document(
	document_version: int,
	section_version: int,
	payload: Dictionary
) -> GFSaveDocument:
	var section: GFSaveSection = GFSaveSection.new().configure(
		&"profile",
		section_version,
		payload
	)
	var sections: Array[GFSaveSection] = [section]
	return GFSaveDocument.new().configure(
		&"game.save",
		document_version,
		sections
	)


func _make_schema(
	document_version: int,
	versions: Dictionary,
	required: PackedStringArray = PackedStringArray(["profile"]),
	allow_unknown: bool = true
) -> GFSaveDocumentSchema:
	return GFSaveDocumentSchema.new().configure(
		&"game.save",
		document_version,
		versions,
		{
			"required_sections": required,
			"allow_unknown_sections": allow_unknown,
		}
	)


func _get_section_payload_int(
	document: GFSaveDocument,
	section_id: StringName,
	key: String
) -> int:
	var section: GFSaveSection = document.get_section(section_id)
	if section == null:
		return 0
	var payload_value: Variant = section.get_payload()
	if not payload_value is Dictionary:
		return 0
	var payload: Dictionary = GFVariantData.as_dictionary(payload_value)
	return GFVariantData.get_option_int(payload, key)


func _assert_document_dictionary_rejected(data: Dictionary, message: String) -> void:
	var inspection: Dictionary = GFSaveDocument.inspect_dict(data)
	assert_false(GFVariantData.get_option_bool(inspection, "ok"), message)
	assert_null(GFSaveDocument.from_dict(data), "%s 解析必须 fail-closed。" % message)


# --- 内部类 ---

class AddInventoryDocumentStep extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"document_1_to_2"
		schema_id = &"game.save"
		from_version = 1
		to_version = 2

	func _migrate_document(
		document: GFSaveDocument,
		_context: Dictionary = {}
	) -> GFSaveDocument:
		var result: GFSaveDocument = document.duplicate_document()
		var inventory: GFSaveSection = GFSaveSection.new().configure(
			&"inventory",
			1,
			{ "capacity": 20 }
		)
		var _stored: bool = result.set_section(inventory)
		return result


class UpgradeProfileSectionStep extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"profile_1_to_2"
		schema_id = &"game.save"
		section_id = &"profile"
		from_version = 1
		to_version = 2

	func _migrate_section(
		section: GFSaveSection,
		_context: Dictionary = {}
	) -> GFSaveSection:
		var payload_value: Variant = section.get_payload()
		if not payload_value is Dictionary:
			return null
		var payload: Dictionary = GFVariantData.as_dictionary(payload_value)
		payload["experience"] = GFVariantData.get_option_int(payload, "level") * 10
		var _erased: bool = payload.erase("level")
		return GFSaveSection.new().configure(
			section.get_section_id(),
			section.get_schema_version(),
			payload,
			section.get_metadata()
		)


class BypassSectionVersionDocumentStep extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"bypass_profile_version"
		schema_id = &"game.save"
		from_version = 1
		to_version = 2

	func _migrate_document(
		document: GFSaveDocument,
		_context: Dictionary = {}
	) -> GFSaveDocument:
		var result: GFSaveDocument = document.duplicate_document()
		var profile: GFSaveSection = result.get_section(&"profile")
		if profile == null:
			return result
		var bypassed: GFSaveSection = GFSaveSection.new().configure(
			profile.get_section_id(),
			2,
			profile.get_payload(),
			profile.get_metadata()
		)
		var _stored: bool = result.set_section(bypassed)
		return result


class ClearRegistryDocumentStep extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"document_1_to_2_clear_registry"
		schema_id = &"game.save"
		from_version = 1
		to_version = 2

	func _migrate_document(
		document: GFSaveDocument,
		context: Dictionary = {}
	) -> GFSaveDocument:
		var registry_value: Variant = context.get("registry")
		if registry_value is GFSaveMigrationRegistry:
			var registry: GFSaveMigrationRegistry = registry_value
			registry.clear()
		return document.duplicate_document()


class AdvanceDocumentStep extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"document_2_to_3"
		schema_id = &"game.save"
		from_version = 2
		to_version = 3

	func _migrate_document(
		document: GFSaveDocument,
		_context: Dictionary = {}
	) -> GFSaveDocument:
		return document.duplicate_document()
