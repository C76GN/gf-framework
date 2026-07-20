## GFSaveSlotStorageAdapter: Save 扩展的通用槽位存储适配器。
##
## 把逻辑槽位索引映射到可配置的数据/元数据文件名，并通过 GFStorageUtility
## 的通用字典事务 API 完成持久化。该类不定义项目存档字段，也不绑定 UI。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSaveSlotStorageAdapter
extends Resource


# --- 常量 ---

const _GF_SAVE_PERSISTED_VALUE_VALIDATOR = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")

## 默认槽位数据文件模板。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_DATA_FILE_TEMPLATE: String = "slot_{index}_data.sav"

## 默认槽位元数据文件模板。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_METADATA_FILE_TEMPLATE: String = "slot_{index}_meta.sav"


# --- 导出变量 ---

## 数据文件模板，支持 `{index}` 占位符。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var data_file_template: String = DEFAULT_DATA_FILE_TEMPLATE

## 元数据文件模板，支持 `{index}` 占位符。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var metadata_file_template: String = DEFAULT_METADATA_FILE_TEMPLATE


# --- 私有变量 ---

var _storage: GFStorageUtility = null
var _clock: GFClock = GFClock.new()


# --- 公共方法 ---

## 设置底层存储工具。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param storage: 底层 GFStorageUtility。
## [br]
## @param clock: 可选墙上时钟；为空时保留当前时钟。
## [br]
## @return 当前适配器。
func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveSlotStorageAdapter:
	_storage = storage
	if clock != null:
		_clock = clock
	return self


## 获取底层存储工具。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前 GFStorageUtility；未配置时返回 null。
func get_storage() -> GFStorageUtility:
	return _storage


## 设置缺省元数据时间戳使用的墙上时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param clock: 新时钟。
## [br]
## @return 时钟合法并完成设置时返回 true。
func set_clock(clock: GFClock) -> bool:
	if clock == null:
		return false
	_clock = clock
	return true


## 获取缺省元数据时间戳使用的时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前时钟。
func get_clock() -> GFClock:
	return _clock


## 生成槽位数据文件名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return 数据文件名。
func get_data_file_name(slot_index: int) -> String:
	return _format_slot_file_name(data_file_template, slot_index)


## 生成槽位元数据文件名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return 元数据文件名。
func get_metadata_file_name(slot_index: int) -> String:
	return _format_slot_file_name(metadata_file_template, slot_index)


## 保存版本化槽位文档和元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引；必须大于等于 0。
## [br]
## @param document: 项目聚合后的版本化存档文档。
## [br]
## @param metadata: 槽位摘要元数据。
## [br]
## @return Godot 的 `Error` 结果码。
## [br]
## @schema metadata: Dictionary，通常来自 GFSaveSlotMetadata.to_dict()。
func save_slot(
	slot_index: int,
	document: GFSaveDocument,
	metadata: Dictionary = {}
) -> Error:
	if not _can_access_slot(slot_index, "save_slot"):
		return ERR_INVALID_PARAMETER
	if document == null:
		push_error("[GFSaveSlotStorageAdapter] save_slot 失败：document 为空。")
		return ERR_INVALID_PARAMETER
	var document_validation: Dictionary = document.validate_document()
	if not GFVariantData.get_option_bool(document_validation, "ok", false):
		push_error("[GFSaveSlotStorageAdapter] save_slot 失败：document 无效。")
		return ERR_INVALID_DATA
	var document_payload: Dictionary = document.to_dict()
	if not _validate_persisted_value(document_payload, "document", "save_slot"):
		return ERR_INVALID_DATA
	if not _validate_persisted_value(metadata, "metadata", "save_slot"):
		return ERR_INVALID_DATA
	if not _metadata_matches_document(metadata, document):
		push_error("[GFSaveSlotStorageAdapter] save_slot 失败：metadata schema 与 document 不一致。")
		return ERR_INVALID_DATA

	var metadata_payload: Dictionary = _make_metadata_payload(slot_index, metadata, document)
	return _storage.save_data_group({
		get_data_file_name(slot_index): document_payload,
		get_metadata_file_name(slot_index): metadata_payload,
	})


## 读取、迁移并校验槽位文档。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @param target_schema: 可选目标 schema；提供后要求最终版本完全匹配。
## [br]
## @param migrations: 可选迁移注册表；旧版本文档需要迁移时必须提供。
## [br]
## @param context: 项目定义的迁移上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral migration data.
## [br]
## @return 强类型读取结果。
func load_slot(
	slot_index: int,
	target_schema: GFSaveDocumentSchema = null,
	migrations: GFSaveMigrationRegistry = null,
	context: Dictionary = {}
) -> GFSaveDocumentReadResult:
	if not _can_access_slot(slot_index, "load_slot"):
		return _make_document_read_failure(
			ERR_INVALID_PARAMETER,
			"Slot cannot be accessed."
		)
	var read_result: GFStorageReadResult = _storage.load_data(get_data_file_name(slot_index))
	if not read_result.ok:
		return _make_document_read_failure(
			read_result.error_code,
			read_result.error,
			read_result
		)
	var inspection: Dictionary = GFSaveDocument.inspect_dict(read_result.payload)
	if not GFVariantData.get_option_bool(inspection, "ok", false):
		return _make_document_read_failure(
			ERR_FILE_CORRUPT,
			_get_first_validation_message(inspection, "Save document is malformed."),
			read_result,
			inspection
		)
	var document: GFSaveDocument = GFSaveDocument.from_dict(read_result.payload)
	if document == null:
		return _make_document_read_failure(
			ERR_FILE_CORRUPT,
			"Save document could not be parsed.",
			read_result,
			inspection
		)
	if target_schema == null:
		return _make_document_read_success(document, read_result, null, inspection)
	var migration_result: GFSaveMigrationResult = null
	if migrations != null:
		migration_result = migrations.migrate(document, target_schema, context)
		if not migration_result.is_successful():
			return _make_document_read_failure(
				migration_result.get_error_code(),
				migration_result.get_error(),
				read_result,
				{},
				migration_result
			)
		document = migration_result.get_document()
	var validation: Dictionary = target_schema.validate_document(document, true)
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return _make_document_read_failure(
			ERR_INVALID_DATA,
			_get_first_validation_message(validation, "Save document does not match the target schema."),
			read_result,
			validation,
			migration_result
		)
	return _make_document_read_success(
		document,
		read_result,
		migration_result,
		validation
	)


## 读取槽位元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return 槽位元数据；读取失败时为空字典。
## [br]
## @schema return: Dictionary，通常兼容 GFSaveSlotMetadata.to_dict()。
func load_slot_metadata(slot_index: int) -> Dictionary:
	if not _can_access_slot(slot_index, "load_slot_metadata"):
		return {}
	var read_result: GFStorageReadResult = _storage.load_data(get_metadata_file_name(slot_index))
	return read_result.payload.duplicate(true) if read_result.ok else {}


## 检查槽位是否同时具备数据和元数据文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return 同时存在数据和元数据时返回 true。
func has_slot(slot_index: int) -> bool:
	if not _can_access_slot(slot_index, "has_slot"):
		return false
	return (
		FileAccess.file_exists(_get_full_storage_path(get_data_file_name(slot_index)))
		and FileAccess.file_exists(_get_full_storage_path(get_metadata_file_name(slot_index)))
	)


## 删除槽位数据和元数据文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param slot_index: 槽位索引。
## [br]
## @return 两个文件都成功删除时返回 OK；任一文件缺失时返回 ERR_FILE_NOT_FOUND。
func delete_slot(slot_index: int) -> Error:
	if not _can_access_slot(slot_index, "delete_slot"):
		return ERR_INVALID_PARAMETER
	var data_error: Error = _storage.delete_file(get_data_file_name(slot_index))
	var metadata_error: Error = _storage.delete_file(get_metadata_file_name(slot_index))
	if data_error == OK and metadata_error == OK:
		return OK
	if data_error != OK and data_error != ERR_FILE_NOT_FOUND:
		return data_error
	if metadata_error != OK and metadata_error != ERR_FILE_NOT_FOUND:
		return metadata_error
	return ERR_FILE_NOT_FOUND


## 枚举现有槽位摘要。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 槽位摘要数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 slot_index、slot_id、metadata 和 modified_time。
func list_slots() -> Array[Dictionary]:
	if _storage == null:
		return []

	var result: Array[Dictionary] = []
	var metadata_files: PackedStringArray = _storage.list_files("", "", true)
	var slot_indices: Array[int] = []
	for file_name: String in metadata_files:
		var slot_index: int = _parse_slot_index_from_file_name(file_name, metadata_file_template)
		if slot_index < 0 or slot_indices.has(slot_index) or not has_slot(slot_index):
			continue
		slot_indices.append(slot_index)

	slot_indices.sort()
	for slot_index: int in slot_indices:
		var metadata_file_name: String = get_metadata_file_name(slot_index)
		var metadata_result: GFStorageReadResult = _storage.load_data(metadata_file_name)
		if not metadata_result.ok:
			continue
		var metadata: Dictionary = metadata_result.payload.duplicate(true)
		result.append({
			"slot_index": slot_index,
			"slot_id": GFVariantData.get_option_string_name(metadata, "slot_id", StringName(str(slot_index))),
			"metadata": metadata,
			"modified_time": FileAccess.get_modified_time(_get_full_storage_path(metadata_file_name)),
		})
	return result


# --- 私有/辅助方法 ---

func _can_access_slot(slot_index: int, operation: String) -> bool:
	if _storage == null:
		push_error("[GFSaveSlotStorageAdapter] %s 失败：storage 为空。" % operation)
		return false
	if slot_index < 0:
		push_error("[GFSaveSlotStorageAdapter] %s 失败：slot_index 必须大于等于 0，当前为 %d。" % [operation, slot_index])
		return false
	if not _validate_file_templates(slot_index, operation):
		return false
	return true


func _validate_file_templates(slot_index: int, operation: String) -> bool:
	if not data_file_template.contains("{index}"):
		push_error("[GFSaveSlotStorageAdapter] %s 失败：data_file_template 必须包含 {index}。" % operation)
		return false
	if not metadata_file_template.contains("{index}"):
		push_error("[GFSaveSlotStorageAdapter] %s 失败：metadata_file_template 必须包含 {index}。" % operation)
		return false
	var data_file_name: String = _format_slot_file_name(data_file_template, slot_index)
	var metadata_file_name: String = _format_slot_file_name(metadata_file_template, slot_index)
	var data_target: String = _get_canonical_storage_target(data_file_name)
	var metadata_target: String = _get_canonical_storage_target(metadata_file_name)
	if data_target.is_empty() or metadata_target.is_empty():
		push_error("[GFSaveSlotStorageAdapter] %s 失败：文件模板无法解析到有效存储目标。" % operation)
		return false
	if data_target.to_lower() == metadata_target.to_lower():
		push_error("[GFSaveSlotStorageAdapter] %s 失败：数据与元数据模板解析到同一存储目标：%s。" % [operation, data_target])
		return false
	return true


func _validate_persisted_value(value: Variant, label: String, operation: String) -> bool:
	var report: Dictionary = _GF_SAVE_PERSISTED_VALUE_VALIDATOR.validate(value)
	if GFVariantData.get_option_bool(report, "ok", false):
		return true
	push_error(
		"[GFSaveSlotStorageAdapter] %s 失败：%s 在 %s 不可持久化：%s。" % [
			operation,
			label,
			GFVariantData.get_option_string(report, "path", "$"),
			GFVariantData.get_option_string(report, "error", "invalid_value"),
		]
	)
	return false


func _format_slot_file_name(template: String, slot_index: int) -> String:
	return template.replace("{index}", str(slot_index))


func _make_metadata_payload(
	slot_index: int,
	metadata: Dictionary,
	document: GFSaveDocument
) -> Dictionary:
	var payload: Dictionary = metadata.duplicate(true)
	if not payload.has("slot_index"):
		payload["slot_index"] = slot_index
	if not payload.has("slot_id"):
		payload["slot_id"] = StringName(str(slot_index))
	if not payload.has("updated_at_unix"):
		payload["updated_at_unix"] = _clock.get_unix_time_seconds()
	payload["schema_id"] = document.get_schema_id()
	payload["schema_version"] = document.get_schema_version()
	return payload


func _metadata_matches_document(
	metadata: Dictionary,
	document: GFSaveDocument
) -> bool:
	var metadata_schema_id: StringName = GFVariantData.get_option_string_name(metadata, "schema_id")
	if metadata_schema_id == &"":
		return true
	return (
		metadata_schema_id == document.get_schema_id()
		and GFVariantData.get_option_int(metadata, "schema_version") == document.get_schema_version()
	)


func _make_document_read_success(
	document: GFSaveDocument,
	storage_result: GFStorageReadResult,
	migration_result: GFSaveMigrationResult,
	validation_report: Dictionary
) -> GFSaveDocumentReadResult:
	var result: GFSaveDocumentReadResult = GFSaveDocumentReadResult.new()
	var status: StringName = GFSaveDocumentReadResult.STATUS_LOADED
	if migration_result != null and migration_result.was_migrated():
		status = GFSaveDocumentReadResult.STATUS_MIGRATED
	result._gf_configure(
		status,
		document,
		storage_result,
		migration_result,
		validation_report,
		OK,
		""
	)
	return result


func _make_document_read_failure(
	error_code: Error,
	error: String,
	storage_result: GFStorageReadResult = null,
	validation_report: Dictionary = {},
	migration_result: GFSaveMigrationResult = null
) -> GFSaveDocumentReadResult:
	var result: GFSaveDocumentReadResult = GFSaveDocumentReadResult.new()
	result._gf_configure(
		GFSaveDocumentReadResult.STATUS_FAILED,
		null,
		storage_result,
		migration_result,
		validation_report,
		error_code,
		error
	)
	return result


func _get_first_validation_message(report: Dictionary, fallback: String) -> String:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	if issues.is_empty():
		return fallback
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	return GFVariantData.get_option_string(first_issue, "message", fallback)


func _parse_slot_index_from_file_name(file_name: String, template: String) -> int:
	var marker: String = "{index}"
	var marker_index: int = template.find(marker)
	if marker_index < 0:
		return -1
	var prefix: String = template.substr(0, marker_index)
	var suffix: String = template.substr(marker_index + marker.length())
	if not file_name.begins_with(prefix) or not file_name.ends_with(suffix):
		return -1
	var index_text: String = file_name.trim_prefix(prefix).trim_suffix(suffix)
	if not index_text.is_valid_int():
		return -1
	return index_text.to_int()


func _get_full_storage_path(file_name: String) -> String:
	var directory_name: String = file_name.get_base_dir()
	if directory_name == ".":
		directory_name = ""
	var directory_path: String = _storage.get_storage_directory_path(directory_name)
	if directory_path.is_empty():
		return ""
	return directory_path.path_join(file_name.get_file())


func _get_canonical_storage_target(file_name: String) -> String:
	var full_path: String = _get_full_storage_path(file_name.replace("\\", "/"))
	if full_path.is_empty():
		return ""
	return ProjectSettings.globalize_path(full_path).replace("\\", "/").simplify_path()
