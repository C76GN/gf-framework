## GFStorageRevisionStore: 显式 schema 2 布局的 committed state 协作者。
##
## state 只在全组 commit 成立后发布。发布失败必须保留事务证据供恢复，不能生成替代 token。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
class_name GFStorageRevisionStore
extends RefCounted


# --- 常量 ---

const _STATE_LEAF: String = "committed-state.json"
const _MAX_STATE_BYTES: int = 4096


# --- 框架内部方法 ---

## 由冻结的 descriptor 与布局 incarnation 构造只供 Storage 使用的读取上下文。
## [br]
## @api framework_internal
## [br]
## @param descriptor: 已校验的 family descriptor。
## [br]
## @schema descriptor: Dictionary，GFStorageFamilyStore 的内部 descriptor。
## [br]
## @param incarnation: schema 2 的 UUID v4；schema 1 使用空字符串。
## [br]
## @return 内部快照；schema 1 返回空字典。
## [br]
## @schema return: Dictionary，非空时包含 state_path、payload_path、logical_path、family_id、storage_incarnation。
static func make_context_for_framework(descriptor: Dictionary, incarnation: String) -> Dictionary:
	if not GFUuid.is_valid(incarnation, 4):
		return {}
	return {
		"state_path": GFVariantData.get_option_string(descriptor, "family_path").path_join(_STATE_LEAF),
		"payload_path": GFVariantData.get_option_string(descriptor, "payload_path"),
		"logical_path": GFVariantData.get_option_string(descriptor, "logical_path"),
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"storage_incarnation": incarnation,
	}


## 读取已恢复 family 的持久状态；本方法不恢复、不读取 payload 内容。
## [br]
## @api framework_internal
## [br]
## @param context: make_context_for_framework() 的冻结输出。
## [br]
## @schema context: Dictionary，内部 revision 上下文。
## [br]
## @return 成功 token 或明确失败；空上下文为 UNSUPPORTED。
static func read_for_framework(context: Dictionary) -> GFStorageRevisionResult:
	if context.is_empty():
		return GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.UNSUPPORTED, ERR_UNAVAILABLE)
	if not FileAccess.file_exists(GFVariantData.get_option_string(context, "payload_path")):
		return GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.NOT_FOUND, ERR_FILE_NOT_FOUND)
	var state_read: Dictionary = read_state_for_framework(context)
	var state_error: Error = GFVariantData.get_option_int(state_read, "error", ERR_FILE_CORRUPT) as Error
	if state_error != OK:
		return failure_for_framework(state_error)
	return GFStorageRevisionResult.available(_make_token(
		context,
		GFVariantData.get_option_string(state_read, "commit_id")
	))


## 发布可由闭合事务证据重建的 state；调用方必须在成功前保留全部 commit/prepare。
## [br]
## @api framework_internal
## [br]
## @param context: 冻结的内部上下文。
## [br]
## @schema context: Dictionary，内部 revision 上下文。
## [br]
## @param commit_id: 已持久化事务证据中的 UUID v4。
## [br]
## @param writer: 接受绝对路径与 Dictionary、返回 Error 的框架文件写入接点。
## [br]
## @return schema 1 不写入并返回 OK；schema 2 写入且复核后成功。
static func publish_for_framework(context: Dictionary, commit_id: String, writer: Callable) -> Error:
	if context.is_empty():
		return OK
	if not GFUuid.is_valid(commit_id, 4) or not writer.is_valid():
		return ERR_FILE_CORRUPT
	if matches_for_framework(context, commit_id):
		return OK
	var state_path: String = GFVariantData.get_option_string(context, "state_path")
	var write_error: Error = GFVariantData.to_exact_int(
		writer.call(state_path, _make_state(context, commit_id)), ERR_CANT_CREATE
	) as Error
	if write_error != OK:
		return write_error
	return OK if matches_for_framework(context, commit_id) else ERR_FILE_CORRUPT


## 校验状态是否精确对应同一持久提交；不依据文件存在推测代次。
## [br]
## @api framework_internal
## [br]
## @param context: 冻结的内部上下文。
## [br]
## @schema context: Dictionary，内部 revision 上下文。
## [br]
## @param commit_id: 事务证据中的 UUID v4。
## [br]
## @return schema 1 为 true，schema 2 需精确匹配。
static func matches_for_framework(context: Dictionary, commit_id: String) -> bool:
	if context.is_empty():
		return true
	var state: Dictionary = read_state_for_framework(context)
	return (
		GFVariantData.get_option_int(state, "error", ERR_FILE_CORRUPT) == OK
		and GFVariantData.get_option_string(state, "commit_id") == commit_id
	)


## 有界读取严格闭合的 state；供离线迁移复用已落盘的代次。
## [br]
## @api framework_internal
## [br]
## @param context: 冻结的内部上下文。
## [br]
## @schema context: Dictionary，内部 revision 上下文。
## [br]
## @return error 与 commit_id；失败不返回代次。
## [br]
## @schema return: Dictionary，固定包含 error: int、commit_id: String。
static func read_state_for_framework(context: Dictionary) -> Dictionary:
	var path: String = GFVariantData.get_option_string(context, "state_path")
	if not FileAccess.file_exists(path):
		return {"error": int(ERR_FILE_CORRUPT), "commit_id": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": int(FileAccess.get_open_error()), "commit_id": ""}
	var length: int = file.get_length()
	if length <= 0 or length > _MAX_STATE_BYTES:
		file.close()
		return {"error": int(ERR_FILE_CORRUPT), "commit_id": ""}
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		return {"error": int(ERR_FILE_CANT_READ), "commit_id": ""}
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"error": int(ERR_FILE_CORRUPT), "commit_id": ""}
	var record: Dictionary = parser.data
	var commit_id: String = GFVariantData.get_option_string(record, "commit_id")
	if not GFUuid.is_valid(commit_id, 4) or not _matches_state(record, _make_state(context, commit_id)):
		return {"error": int(ERR_FILE_CORRUPT), "commit_id": ""}
	return {"error": int(OK), "commit_id": commit_id}


## 把 Godot error 映射为 revision 查询失败。
## [br]
## @api framework_internal
## [br]
## @param error: 非 OK 错误码。
## [br]
## @return 不带 token 的失败结果。
static func failure_for_framework(error: Error) -> GFStorageRevisionResult:
	var status: GFStorageRevisionResult.Status = GFStorageRevisionResult.Status.IO_FAILED
	match error:
		ERR_FILE_NOT_FOUND:
			status = GFStorageRevisionResult.Status.NOT_FOUND
		ERR_INVALID_PARAMETER:
			status = GFStorageRevisionResult.Status.INVALID_REQUEST
		ERR_UNAVAILABLE:
			status = GFStorageRevisionResult.Status.UNAVAILABLE
		ERR_BUSY:
			status = GFStorageRevisionResult.Status.BUSY
		ERR_FILE_CORRUPT, ERR_INVALID_DATA:
			status = GFStorageRevisionResult.Status.CORRUPT
	return GFStorageRevisionResult.failure(status, error)


# --- 私有/辅助方法 ---

static func _make_state(context: Dictionary, commit_id: String) -> Dictionary:
	return {
		"schema": "gf.storage.committed-state",
		"schema_version": 1,
		"logical_path": GFVariantData.get_option_string(context, "logical_path"),
		"family_id": GFVariantData.get_option_string(context, "family_id"),
		"storage_incarnation": GFVariantData.get_option_string(context, "storage_incarnation"),
		"commit_id": commit_id,
	}


static func _make_token(context: Dictionary, commit_id: String) -> String:
	return JSON.stringify([
		GFVariantData.get_option_string(context, "storage_incarnation"),
		GFVariantData.get_option_string(context, "family_id"),
		commit_id,
	]).sha256_text()


static func _matches_state(record: Dictionary, expected: Dictionary) -> bool:
	if record.size() != expected.size():
		return false
	for key: String in expected:
		if key == "schema_version":
			if GFVariantData.to_exact_int(record.get(key), -1) != 1:
				return false
		elif not record.get(key) is String or record.get(key) != expected.get(key):
			return false
	return true
