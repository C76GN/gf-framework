## GFStorageRevisionMigration: 把现有 Storage schema 1 显式离线升级为 schema 2。
##
## 调用前必须停止该 root 的全部其他 Utility、进程与外部文件写入者。
## 迁移 intent 存在期间普通运行时拒绝 I/O；失败后应在同一离线条件下重试。
## 开始发布 state 后不能任意回滚到 schema 1；损坏的 intent 需要从可信备份恢复。
## 本类型不解释业务载荷，不触发业务 schema migration，也不自动迁移默认存储。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFStorageRevisionMigration
extends RefCounted


# --- 常量 ---

## 单条离线升级 JSON 记录允许的最大字节数。
## [br]
## @api private
## [br]
const _MAX_RECORD_BYTES: int = 4096

## 持久化升级 intent 的文件名。
## [br]
## @api private
## [br]
const _INTENT_LEAF: String = "upgrade.intent.json"

## 持久化当前迁移位置的 cursor 文件名。
## [br]
## @api private
## [br]
const _CURSOR_LEAF: String = "upgrade.cursor.json"

## cursor 原子安装前的 pending 文件名。
## [br]
## @api private
## [br]
const _CURSOR_PENDING_LEAF: String = "upgrade.cursor.pending.json"

## 新版 layout manifest 暂存文件名。
## [br]
## @api private
## [br]
const _LAYOUT_STAGE_LEAF: String = "upgrade.layout.json"


# --- 私有变量 ---

## 防止同一迁移器实例重入 upgrade。
## [br]
## @api private
## [br]
var _running: bool = false

## 当前离线迁移绑定的 canonical Storage root。
## [br]
## @api private
## [br]
var _storage_root_path: String = ""

## 当前 root 下 v1 私有布局目录。
## [br]
## @api private
## [br]
var _version_root: String = ""

## 用于枚举 family、验证布局及绑定迁移 intent 的协作者。
## [br]
## @api private
## [br]
var _family_store: GFStorageFamilyStore = null

## 已验证或从磁盘读取的迁移 intent。
## [br]
## @api private
## [br]
var _intent: Dictionary = {}

## 本轮捕获并用于迁移遍历的 family descriptor 列表。
## [br]
## @api private
## [br]
var _descriptors: Array[Dictionary] = []

## 标记 descriptor 列表已冻结，防止恢复过程中枚举集发生变化。
## [br]
## @api private
## [br]
var _descriptors_captured: bool = false


# --- 公共方法 ---

## 在调用方已建立的离线单写入者边界内升级或继续升级一个已有 Storage root。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param save_dir_name: 与 GFStorageUtility.save_dir_name 相同的合法存储目录配置。
## [br]
## @return 完整 schema 2 验收成功返回 OK；失败保留恢复证据，不创建缺失的存储 root。
func upgrade(save_dir_name: String) -> Error:
	if _running:
		return ERR_BUSY
	_running = true
	var result: Error = _upgrade(save_dir_name)
	if _family_store != null:
		_family_store.end_revision_upgrade_for_framework()
	_family_store = null
	_intent.clear()
	_descriptors.clear()
	_descriptors_captured = false
	_storage_root_path = ""
	_version_root = ""
	_running = false
	return result


# --- 私有/辅助方法 ---

# 只写入本次迁移拥有的有界记录，失败时保留其他恢复证据。
# 测试子类在此注入 I/O 故障；这不是提供给项目重写的扩展点。
## 将有界 JSON 记录写入非链接普通文件并 flush，返回实际 I/O 错误。
## [br]
## @api private
## [br]
func _write_upgrade_record(path: String, record: Dictionary) -> Error:
	var bytes: PackedByteArray = JSON.stringify(record, "\t").to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > _MAX_RECORD_BYTES:
		return ERR_INVALID_PARAMETER
	if _is_link(path) or DirAccess.dir_exists_absolute(path):
		return ERR_FILE_CORRUPT
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_buffer(bytes) != null
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return result


# 只删除本次迁移拥有的精确文件；链接或目录必须保留并报错。
## 只移除非链接且非目录的指定文件；目标缺失时返回 OK。
## [br]
## @api private
## [br]
func _remove_upgrade_file(path: String) -> Error:
	if _is_link(path) or DirAccess.dir_exists_absolute(path):
		return ERR_FILE_CORRUPT
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK


# 安装已完整回读的 staging 文件，不得覆盖已经存在的目标。
## 将存在的非链接源文件改名到尚不存在的目标，不覆盖已有目标。
## [br]
## @api private
## [br]
func _rename_upgrade_file(source_path: String, target_path: String) -> Error:
	if _is_link(source_path) or not FileAccess.file_exists(source_path):
		return ERR_FILE_CORRUPT
	if _leaf_exists(target_path):
		return ERR_ALREADY_EXISTS
	return DirAccess.rename_absolute(source_path, target_path)


## 执行 intent 建立/恢复、family state 发布、全量验证、layout 发布和迁移记录清理流程。
## [br]
## @api private
## [br]
func _upgrade(save_dir_name: String) -> Error:
	_storage_root_path = GFStorageFamilyStore.make_storage_root_path_for_framework(save_dir_name)
	if _storage_root_path.is_empty():
		return ERR_INVALID_PARAMETER
	var ancestry_error: Error = _validate_ancestry()
	if ancestry_error != OK:
		return ancestry_error
	_version_root = _storage_root_path.path_join(".gf-storage/v1")
	_family_store = GFStorageFamilyStore.new()
	if not _family_store.configure_for_framework(_storage_root_path):
		return ERR_INVALID_PARAMETER
	var intent_path: String = _version_root.path_join(_INTENT_LEAF)
	if not _leaf_exists(intent_path):
		var initial_error: Error = _prepare_initial_upgrade(save_dir_name)
		if initial_error != OK:
			return initial_error
		if not _family_store.get_revision_incarnation_for_framework().is_empty():
			return _validate_all_states(_family_store.get_revision_incarnation_for_framework())
		var old_layout_hash: String = FileAccess.get_sha256(_version_root.path_join("layout.json"))
		if old_layout_hash.is_empty():
			return ERR_FILE_CANT_READ
		_intent = {
			"schema": "gf.storage.revision-upgrade",
			"schema_version": 1,
			"old_layout_hash": old_layout_hash,
			"storage_incarnation": GFUuid.generate_v4(),
		}
		var intent_error: Error = _write_upgrade_record(intent_path, _intent)
		if intent_error != OK:
			return intent_error
	var intent_read: Dictionary = _read_record(intent_path)
	if GFVariantData.get_option_int(intent_read, "error", ERR_FILE_CORRUPT) != OK:
		return GFVariantData.get_option_int(intent_read, "error", ERR_FILE_CORRUPT) as Error
	var persisted_intent: Dictionary = GFVariantData.get_option_dictionary(intent_read, "data")
	if not _intent.is_empty() and not _records_equal(persisted_intent, _intent):
		return ERR_FILE_CORRUPT
	_intent = persisted_intent
	var begin_error: Error = _family_store.begin_revision_upgrade_for_framework(_intent)
	if begin_error != OK:
		return begin_error
	var collect_error: Error = _collect_descriptors()
	if collect_error != OK:
		return collect_error
	var cursor_error: Error = _recover_cursor()
	if cursor_error != OK:
		return cursor_error
	for descriptor: Dictionary in _descriptors:
		var state_error: Error = _upgrade_family(descriptor)
		if state_error != OK:
			return state_error
	var incarnation: String = GFVariantData.get_option_string(_intent, "storage_incarnation")
	var validation_error: Error = _validate_all_states(incarnation)
	if validation_error != OK:
		return validation_error
	var layout_error: Error = _publish_layout(incarnation)
	if layout_error != OK:
		return layout_error
	validation_error = _validate_all_states(incarnation)
	if validation_error != OK:
		return validation_error
	for leaf: String in [_CURSOR_PENDING_LEAF, _CURSOR_LEAF, _LAYOUT_STAGE_LEAF, _INTENT_LEAF]:
		var remove_error: Error = _remove_upgrade_file(_version_root.path_join(leaf))
		if remove_error != OK:
			return remove_error
	return OK


## 检查既有 layout，通过临时 StorageUtility 准备升级并重新收集 family descriptors。
## [br]
## @api private
## [br]
func _prepare_initial_upgrade(save_dir_name: String) -> Error:
	var inspection: Dictionary = _family_store.inspect_layout_for_reset_for_framework()
	var inspection_error: Error = GFVariantData.get_option_int(inspection, "error", ERR_FILE_CORRUPT) as Error
	if inspection_error != OK:
		return inspection_error
	var storage: GFStorageUtility = GFStorageUtility.new()
	storage.save_dir_name = save_dir_name
	var prepare_error: Error = storage.prepare_revision_upgrade_for_framework()
	storage.dispose()
	if prepare_error != OK:
		return prepare_error
	return _collect_descriptors()


## 列举 family descriptors，拒绝活动事务 sidecar，并校验重复收集结果不变。
## [br]
## @api private
## [br]
func _collect_descriptors() -> Error:
	var listing: Dictionary = _family_store.list_claimed_family_descriptors_for_framework()
	var listing_error: Error = GFVariantData.get_option_int(listing, "error", ERR_FILE_CORRUPT) as Error
	if listing_error != OK:
		return listing_error
	var fresh: Array[Dictionary] = []
	for descriptor_value: Variant in GFVariantData.get_option_array(listing, "descriptors"):
		if not descriptor_value is Dictionary:
			return ERR_FILE_CORRUPT
		var descriptor: Dictionary = descriptor_value
		for path_key: String in [
			"candidate_path", "backup_path", "transaction_path", "transaction_pending_path",
			"transaction_commit_path", "transaction_commit_pending_path", "resource_stage_path",
		]:
			if _leaf_exists(GFVariantData.get_option_string(descriptor, path_key)):
				return ERR_BUSY
		fresh.append(descriptor)
	if _descriptors_captured and fresh != _descriptors:
		return ERR_FILE_CORRUPT
	_descriptors = fresh
	_descriptors_captured = true
	return OK


## 按 cursor 检查 family revision 状态，必要时写入/恢复 cursor 后发布该 family state。
## [br]
## @api private
## [br]
func _upgrade_family(descriptor: Dictionary) -> Error:
	var context: Dictionary = _make_context(descriptor)
	var state_path: String = GFVariantData.get_option_string(context, "state_path")
	if not FileAccess.file_exists(GFVariantData.get_option_string(descriptor, "payload_path")):
		return OK
	var state: Dictionary = GFStorageRevisionStore.read_state_for_framework(context)
	var cursor_read: Dictionary = _read_cursor(_version_root.path_join(_CURSOR_LEAF))
	if GFVariantData.get_option_int(cursor_read, "error", ERR_FILE_CORRUPT) != OK:
		return GFVariantData.get_option_int(cursor_read, "error", ERR_FILE_CORRUPT) as Error
	var cursor: Dictionary = GFVariantData.get_option_dictionary(cursor_read, "data")
	var cursor_matches: bool = (
		GFVariantData.get_option_string(cursor, "logical_path")
		== GFVariantData.get_option_string(descriptor, "logical_path")
	)
	if GFVariantData.get_option_int(state, "error", ERR_FILE_CORRUPT) == OK:
		return OK if (
			not cursor_matches
			or GFVariantData.get_option_string(state, "commit_id")
			== GFVariantData.get_option_string(cursor, "commit_id")
		) else ERR_FILE_CORRUPT
	if _leaf_exists(state_path) and not cursor_matches:
		return GFVariantData.get_option_int(state, "error", ERR_FILE_CORRUPT) as Error
	if not cursor_matches:
		var layout_read: Dictionary = _read_record(_version_root.path_join("layout.json"))
		var layout: Dictionary = GFVariantData.get_option_dictionary(layout_read, "data")
		if (
			GFVariantData.to_exact_int(layout.get("schema_version"), -1) == 2
			or (
				not cursor.is_empty()
				and GFVariantData.get_option_string(descriptor, "logical_path")
				< GFVariantData.get_option_string(cursor, "logical_path")
			)
		):
			return ERR_FILE_CORRUPT
		cursor = {
			"schema": "gf.storage.revision-upgrade-cursor",
			"schema_version": 1,
			"storage_incarnation": GFVariantData.get_option_string(_intent, "storage_incarnation"),
			"logical_path": GFVariantData.get_option_string(descriptor, "logical_path"),
			"commit_id": GFUuid.generate_v4(),
		}
		var pending_path: String = _version_root.path_join(_CURSOR_PENDING_LEAF)
		var write_error: Error = _write_upgrade_record(pending_path, cursor)
		if write_error != OK:
			return write_error
		var pending_read: Dictionary = _read_cursor(pending_path)
		if (
			GFVariantData.get_option_int(pending_read, "error", ERR_FILE_CORRUPT) != OK
			or not _records_equal(GFVariantData.get_option_dictionary(pending_read, "data"), cursor)
		):
			return ERR_FILE_CORRUPT
		var recover_error: Error = _recover_cursor()
		if recover_error != OK:
			return recover_error
	return GFStorageRevisionStore.publish_for_framework(
		context, GFVariantData.get_option_string(cursor, "commit_id"), _write_upgrade_record
	)


## 校验 cursor 与 pending 记录，并按已提交 state 情况清理重复项或安装下一 cursor。
## [br]
## @api private
## [br]
func _recover_cursor() -> Error:
	var cursor_path: String = _version_root.path_join(_CURSOR_LEAF)
	var pending_path: String = _version_root.path_join(_CURSOR_PENDING_LEAF)
	var cursor_read: Dictionary = _read_cursor(cursor_path)
	var pending_read: Dictionary = _read_cursor(pending_path)
	if GFVariantData.get_option_int(cursor_read, "error", ERR_FILE_CORRUPT) != OK:
		return GFVariantData.get_option_int(cursor_read, "error", ERR_FILE_CORRUPT) as Error
	var cursor: Dictionary = GFVariantData.get_option_dictionary(cursor_read, "data")
	var pending_error: Error = GFVariantData.get_option_int(pending_read, "error", ERR_FILE_CORRUPT) as Error
	if pending_error != OK:
		if (
			pending_error == ERR_FILE_CORRUPT
			and _is_incomplete_staging_record(pending_path)
			and _can_discard_cursor_staging(cursor)
		):
			return _remove_upgrade_file(pending_path)
		return pending_error
	var pending: Dictionary = GFVariantData.get_option_dictionary(pending_read, "data")
	if pending.is_empty():
		return OK
	var next_descriptor: Dictionary = _find_descriptor(GFVariantData.get_option_string(pending, "logical_path"))
	var next_context: Dictionary = _make_context(next_descriptor)
	if (
		_leaf_exists(GFVariantData.get_option_string(next_context, "state_path"))
		and not GFStorageRevisionStore.matches_for_framework(
			next_context, GFVariantData.get_option_string(pending, "commit_id")
		)
	):
		return ERR_FILE_CORRUPT
	if not cursor.is_empty():
		if _records_equal(cursor, pending):
			return _remove_upgrade_file(pending_path)
		if (
			GFVariantData.get_option_string(pending, "logical_path")
			<= GFVariantData.get_option_string(cursor, "logical_path")
		):
			return ERR_FILE_CORRUPT
		var previous_descriptor: Dictionary = _find_descriptor(GFVariantData.get_option_string(cursor, "logical_path"))
		if not GFStorageRevisionStore.matches_for_framework(
			_make_context(previous_descriptor), GFVariantData.get_option_string(cursor, "commit_id")
		):
			return ERR_FILE_CORRUPT
		var remove_error: Error = _remove_upgrade_file(cursor_path)
		if remove_error != OK:
			return remove_error
	var rename_error: Error = _rename_upgrade_file(pending_path, cursor_path)
	if rename_error != OK:
		return rename_error
	var installed: Dictionary = _read_cursor(cursor_path)
	return OK if (
		GFVariantData.get_option_int(installed, "error", ERR_FILE_CORRUPT) == OK
		and _records_equal(GFVariantData.get_option_dictionary(installed, "data"), pending)
	) else ERR_FILE_CORRUPT


## 仅当旧 layout 哈希仍匹配、没有 layout 暂存，且游标前后的 revision 状态一致时允许丢弃游标暂存。
## 此检查不发布 state；pending 尚未成为正式 cursor，不能授权推进迁移。
## [br]
## @api private
func _can_discard_cursor_staging(cursor: Dictionary) -> bool:
	# pending 尚未成为 cursor，不能授权发布 state；旧 schema 1 layout 必须仍在。
	if (
		FileAccess.get_sha256(_version_root.path_join("layout.json"))
		!= GFVariantData.get_option_string(_intent, "old_layout_hash")
		or _leaf_exists(_version_root.path_join(_LAYOUT_STAGE_LEAF))
	):
		return false
	var cursor_logical_path: String = GFVariantData.get_option_string(cursor, "logical_path")
	if not cursor.is_empty() and not GFStorageRevisionStore.matches_for_framework(
		_make_context(_find_descriptor(cursor_logical_path)),
		GFVariantData.get_option_string(cursor, "commit_id")
	):
		return false
	for descriptor: Dictionary in _descriptors:
		var context: Dictionary = _make_context(descriptor)
		var logical_path: String = GFVariantData.get_option_string(descriptor, "logical_path")
		var state_path: String = GFVariantData.get_option_string(context, "state_path")
		if cursor.is_empty() or logical_path > cursor_logical_path:
			if _leaf_exists(state_path):
				return false
			continue
		if not FileAccess.file_exists(GFVariantData.get_option_string(context, "payload_path")):
			if _leaf_exists(state_path):
				return false
			continue
		if logical_path == cursor_logical_path:
			if not GFStorageRevisionStore.matches_for_framework(
				context, GFVariantData.get_option_string(cursor, "commit_id")
			):
				return false
		elif GFVariantData.get_option_int(
			GFStorageRevisionStore.read_state_for_framework(context), "error", ERR_FILE_CORRUPT
		) != OK:
			return false
	return true


## 读取 cursor 记录并校验固定 schema、当前 incarnation、family 存在性及 UUID commit ID。
## [br]
## @api private
## [br]
func _read_cursor(path: String) -> Dictionary:
	if not _leaf_exists(path):
		return {"error": int(OK), "data": {}}
	var result: Dictionary = _read_record(path)
	if GFVariantData.get_option_int(result, "error", ERR_FILE_CORRUPT) != OK:
		return result
	var cursor: Dictionary = GFVariantData.get_option_dictionary(result, "data")
	var logical_path: String = GFVariantData.get_option_string(cursor, "logical_path")
	var commit_id: String = GFVariantData.get_option_string(cursor, "commit_id")
	var expected: Dictionary = {
		"schema": "gf.storage.revision-upgrade-cursor",
		"schema_version": 1,
		"storage_incarnation": GFVariantData.get_option_string(_intent, "storage_incarnation"),
		"logical_path": logical_path,
		"commit_id": commit_id,
	}
	if (
		not GFUuid.is_valid(commit_id, 4)
		or _find_descriptor(logical_path).is_empty()
		or not _records_equal(cursor, expected)
	):
		return {"error": int(ERR_FILE_CORRUPT), "data": {}}
	return result


## 重新捕获 family 列表并验证每个 payload 或已存在 revision state。
## [br]
## @api private
## [br]
func _validate_all_states(incarnation: String) -> Error:
	var collect_error: Error = _collect_descriptors()
	if collect_error != OK:
		return collect_error
	for descriptor: Dictionary in _descriptors:
		var context: Dictionary = GFStorageRevisionStore.make_context_for_framework(descriptor, incarnation)
		if (
			not FileAccess.file_exists(GFVariantData.get_option_string(context, "payload_path"))
			and not _leaf_exists(GFVariantData.get_option_string(context, "state_path"))
		):
			continue
		var state: Dictionary = GFStorageRevisionStore.read_state_for_framework(context)
		if GFVariantData.get_option_int(state, "error", ERR_FILE_CORRUPT) != OK:
			return GFVariantData.get_option_int(state, "error", ERR_FILE_CORRUPT) as Error
	return OK


## 写入并回读新版 layout staging，检查 state 后替换旧 layout 并验证安装结果。
## [br]
## @api private
## [br]
func _publish_layout(incarnation: String) -> Error:
	var target: Dictionary = GFStorageFamilyStore.make_revision_upgrade_layout_for_framework(incarnation)
	var layout_path: String = _version_root.path_join("layout.json")
	var existing: Dictionary = _read_record(layout_path)
	if _records_equal(GFVariantData.get_option_dictionary(existing, "data"), target):
		return OK
	var staged_path: String = _version_root.path_join(_LAYOUT_STAGE_LEAF)
	if not _leaf_exists(staged_path) or _is_incomplete_staging_record(staged_path):
		# intent、旧 layout 和全部 state 已验收；暂存的部分写入没有独立身份权限。
		var write_error: Error = _write_upgrade_record(staged_path, target)
		if write_error != OK:
			return write_error
	var staged: Dictionary = _read_record(staged_path)
	if (
		GFVariantData.get_option_int(staged, "error", ERR_FILE_CORRUPT) != OK
		or not _records_equal(GFVariantData.get_option_dictionary(staged, "data"), target)
	):
		return ERR_FILE_CORRUPT
	var layout_check_error: Error = _family_store.ensure_layout_for_framework()
	if layout_check_error != OK:
		return layout_check_error
	var remove_error: Error = _remove_upgrade_file(layout_path)
	if remove_error != OK:
		return remove_error
	var rename_error: Error = _rename_upgrade_file(staged_path, layout_path)
	if rename_error != OK:
		return rename_error
	var installed: Dictionary = _read_record(layout_path)
	return OK if (
		GFVariantData.get_option_int(installed, "error", ERR_FILE_CORRUPT) == OK
		and _records_equal(GFVariantData.get_option_dictionary(installed, "data"), target)
	) else ERR_FILE_CORRUPT


## 识别非链接普通 staging 文件中的空内容或无法解析的 JSON 记录。
## [br]
## @api private
## [br]
static func _is_incomplete_staging_record(path: String) -> bool:
	if _is_link(path) or DirAccess.dir_exists_absolute(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var length: int = file.get_length()
	if length > _MAX_RECORD_BYTES:
		file.close()
		return false
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		return false
	var parser: JSON = JSON.new()
	return length == 0 or parser.parse(bytes.get_string_from_utf8()) != OK


## 使用当前 intent incarnation 与 descriptor 派生 revision store context。
## [br]
## @api private
## [br]
func _make_context(descriptor: Dictionary) -> Dictionary:
	return GFStorageRevisionStore.make_context_for_framework(
		descriptor, GFVariantData.get_option_string(_intent, "storage_incarnation")
	)


## 按 logical_path 查找捕获的 family descriptor；未找到时返回空字典。
## [br]
## @api private
## [br]
func _find_descriptor(logical_path: String) -> Dictionary:
	for descriptor: Dictionary in _descriptors:
		if GFVariantData.get_option_string(descriptor, "logical_path") == logical_path:
			return descriptor
	return {}


## 检查 root 到私有 v1 目录的每个现有祖先均为目录且不是链接。
## [br]
## @api private
## [br]
func _validate_ancestry() -> Error:
	var current_path: String = "user://"
	var relative_path: String = _storage_root_path.trim_prefix("user://") + "/.gf-storage/v1"
	var segments: PackedStringArray = relative_path.split("/", false)
	for segment: String in segments:
		current_path = current_path.path_join(segment)
		if _is_link(current_path) or FileAccess.file_exists(current_path):
			return ERR_FILE_CORRUPT
		if not DirAccess.dir_exists_absolute(current_path):
			return ERR_FILE_NOT_FOUND
	return OK


## 读取不超过记录上限的 JSON 字典，拒绝链接、目录、空文件和非字典 JSON。
## [br]
## @api private
## [br]
static func _read_record(path: String) -> Dictionary:
	if _is_link(path) or DirAccess.dir_exists_absolute(path):
		return {"error": int(ERR_FILE_CORRUPT), "data": {}}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": int(FileAccess.get_open_error()), "data": {}}
	var length: int = file.get_length()
	if length <= 0 or length > _MAX_RECORD_BYTES:
		file.close()
		return {"error": int(ERR_FILE_CORRUPT), "data": {}}
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		return {"error": int(ERR_FILE_CANT_READ), "data": {}}
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"error": int(ERR_FILE_CORRUPT), "data": {}}
	var record: Dictionary = parser.data
	return {"error": int(OK), "data": record}


## 要求记录字段数量与 expected 相同；schema_version 精确比整数，其余字段须为相同字符串。
## [br]
## @api private
## [br]
static func _records_equal(record: Dictionary, expected: Dictionary) -> bool:
	if record.size() != expected.size():
		return false
	for key: String in expected:
		if key == "schema_version":
			if (
				GFVariantData.to_exact_int(record.get(key), -1)
				!= GFVariantData.to_exact_int(expected.get(key), -2)
			):
				return false
		elif not record.get(key) is String or record.get(key) != expected.get(key):
			return false
	return true


## 通过父目录 DirAccess 判断目标 leaf 是否为链接。
## [br]
## @api private
## [br]
static func _is_link(path: String) -> bool:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	return directory != null and directory.is_link(path.get_file())


## 判断目标 leaf 是否为链接、文件或目录。
## [br]
## @api private
## [br]
static func _leaf_exists(path: String) -> bool:
	return _is_link(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
