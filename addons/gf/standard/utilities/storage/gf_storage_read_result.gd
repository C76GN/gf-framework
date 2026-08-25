## GFStorageReadResult: 严格存储读取结果。
##
## 将业务载荷、框架存储元数据、完整性状态和失败原因分离，避免调用方
## 把空字典误判为成功，也避免存储层保留字段渗入业务数据。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFStorageReadResult
extends RefCounted


# --- 枚举 ---

## 存储文档完整性状态。
## [br]
## @api public
## [br]
## @since 9.0.0
enum IntegrityStatus {
	## 文档没有声明完整性校验，且调用方没有要求校验。
	NOT_CHECKED,
	## 文档完整性校验通过。
	VALID,
	## 调用方要求完整性校验，但文档没有校验信息。
	MISSING,
	## 文档完整性校验失败。
	INVALID,
}

## 读取失败的稳定分类。
##
## 调用方必须依据该分类选择恢复策略，不得从 Error 码或错误文本推断数据语义。
## [br]
## @api public
## [br]
## @since 10.0.0
enum FailureKind {
	## 没有失败。
	NONE,
	## 请求参数或路径无效。
	INVALID_REQUEST,
	## 文件不存在。
	NOT_FOUND,
	## 文件 IO 或异步执行失败。
	IO_FAILED,
	## 文件格式、载荷或完整性损坏。
	CORRUPT,
	## 物理存储版本高于当前运行时。
	FUTURE_VERSION,
	## 物理存储迁移链缺失或迁移失败。
	MIGRATION_FAILED,
	## 请求在执行前被底层服务终止。
	UNAVAILABLE,
}


# --- 公共变量 ---

## 读取、解码和迁移是否全部成功。
## [br]
## @api public
## [br]
## @since 9.0.0
var ok: bool = false

## 与框架存储字段完全隔离的业务载荷。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @schema payload: Dictionary，项目写入的原始业务数据。
var payload: Dictionary = {}

## 框架存储文档元数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @schema metadata: Dictionary，包含 data_version 以及可选时间戳、格式和压缩信息。
var metadata: Dictionary = {}

## 完整性校验状态。
## [br]
## @api public
## [br]
## @since 9.0.0
var integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED

## Godot 错误码；成功时为 OK。
## [br]
## @api public
## [br]
## @since 9.0.0
var error_code: Error = OK

## 稳定、可展示的错误描述；成功时为空字符串。
## [br]
## @api public
## [br]
## @since 9.0.0
var error: String = ""

## 读取失败的稳定分类；成功时为 `FailureKind.NONE`。
## [br]
## @api public
## [br]
## @since 10.0.0
var failure_kind: FailureKind = FailureKind.NONE

## 物理存储文档 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
var document_schema_version: int = 0

## 读取时发现的数据 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
var source_data_version: int = 0

## 完成迁移后的数据 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
var data_version: int = 0

## 本次读取是否执行过数据迁移。
## [br]
## @api public
## [br]
## @since 9.0.0
var migrated: bool = false


# --- 私有变量 ---

var _origin_bound: bool = false
var _origin_utility_id: int = 0
var _origin_logical_path: String = ""
var _origin_file_key: String = ""
var _origin_token: String = ""
var _origin_observation_token: String = ""
var _origin_ok: bool = false
var _origin_error_code: Error = FAILED
var _origin_failure_kind: FailureKind = FailureKind.NONE


# --- 公共方法 ---

## 配置成功结果，并清除任何不透明 Storage 来源绑定。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param p_payload: 业务载荷。
## [br]
## @param p_metadata: 框架存储元数据。
## [br]
## @param p_integrity_status: 完整性状态。
## [br]
## @param p_document_schema_version: 物理文档 schema 版本。
## [br]
## @schema p_payload: Dictionary，项目写入的业务数据。
## [br]
## @schema p_metadata: Dictionary，框架存储元数据。
## [br]
## @return 当前结果。
func configure_success(
	p_payload: Dictionary,
	p_metadata: Dictionary = {},
	p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED,
	p_document_schema_version: int = 0
) -> GFStorageReadResult:
	_clear_origin_binding()
	ok = true
	payload = p_payload.duplicate(true)
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = OK
	error = ""
	failure_kind = FailureKind.NONE
	document_schema_version = maxi(p_document_schema_version, 0)
	source_data_version = maxi(GFVariantData.get_option_int(metadata, "data_version", 1), 1)
	data_version = source_data_version
	migrated = false
	return self


## 配置失败结果，并清除任何不透明 Storage 来源绑定。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param p_error: 错误描述。
## [br]
## @param p_error_code: Godot 错误码。
## [br]
## @param p_metadata: 已能安全恢复的框架存储元数据。
## [br]
## @param p_integrity_status: 完整性状态。
## [br]
## @param p_document_schema_version: 物理文档 schema 版本。
## [br]
## @param p_failure_kind: 稳定失败分类。
## [br]
## @schema p_metadata: Dictionary，失败时仍可安全展示或诊断的框架存储元数据。
## [br]
## @return 当前结果。
func configure_failure(
	p_error: String,
	p_error_code: Error = ERR_INVALID_DATA,
	p_metadata: Dictionary = {},
	p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED,
	p_document_schema_version: int = 0,
	p_failure_kind: FailureKind = FailureKind.IO_FAILED
) -> GFStorageReadResult:
	_clear_origin_binding()
	ok = false
	payload.clear()
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = p_error_code
	error = p_error.strip_edges()
	failure_kind = p_failure_kind if p_failure_kind != FailureKind.NONE else FailureKind.IO_FAILED
	document_schema_version = maxi(p_document_schema_version, 0)
	source_data_version = maxi(GFVariantData.get_option_int(metadata, "data_version", 1), 1)
	data_version = source_data_version
	migrated = false
	return self


## 完整性状态是否允许调用方使用载荷。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 状态不是 MISSING 或 INVALID 时返回 true。
func is_integrity_accepted() -> bool:
	return integrity_status == IntegrityStatus.NOT_CHECKED or integrity_status == IntegrityStatus.VALID


## 创建读取结果深拷贝。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## 原对象的授权资格字段仍精确匹配 Storage 签发快照时，副本保留不透明来源绑定；
## `ok`、`error_code` 或 `failure_kind` 被改写后，副本不会保留该绑定。
## [br]
## @return 新读取结果。
func duplicate_result() -> GFStorageReadResult:
	var copy: GFStorageReadResult = from_dict(to_dict())
	if _origin_binding_is_current():
		var _bound: bool = copy.bind_origin_for_framework(
			_origin_utility_id,
			_origin_logical_path,
			_origin_file_key,
			_origin_token,
			_origin_observation_token
		)
	return copy


## 转换为执行器、报告和工具可传递的字典。
##
## 不透明 Storage 来源绑定不会序列化；Dictionary 往返结果不能作为破坏性 family reset 授权证据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 读取结果字典。
## [br]
## @schema return: Dictionary，包含 ok、payload、metadata、integrity_status、error_code、error、failure_kind、document_schema_version、source_data_version、data_version 和 migrated。
func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"payload": payload.duplicate(true),
		"metadata": metadata.duplicate(true),
		"integrity_status": int(integrity_status),
		"error_code": int(error_code),
		"error": error,
		"failure_kind": int(failure_kind),
		"document_schema_version": document_schema_version,
		"source_data_version": source_data_version,
		"data_version": data_version,
		"migrated": migrated,
	}


## 从字典应用读取结果字段，并清除任何不透明 Storage 来源绑定。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 读取结果字典。
## [br]
## @schema data: Dictionary，GFStorageReadResult.to_dict() 输出。
func apply_dict(data: Dictionary) -> void:
	_clear_origin_binding()
	ok = GFVariantData.get_option_bool(data, "ok")
	payload = GFVariantData.get_option_dictionary(data, "payload") if ok else {}
	metadata = GFVariantData.get_option_dictionary(data, "metadata")
	integrity_status = _to_integrity_status(GFVariantData.get_option_int(data, "integrity_status"))
	error_code = GFVariantData.get_option_int(data, "error_code", ERR_INVALID_DATA) as Error
	error = GFVariantData.get_option_string(data, "error").strip_edges()
	if ok:
		failure_kind = FailureKind.NONE
	else:
		failure_kind = _to_failure_kind(
			GFVariantData.get_option_int(data, "failure_kind", FailureKind.IO_FAILED)
		)
		if failure_kind == FailureKind.NONE:
			failure_kind = FailureKind.IO_FAILED
	document_schema_version = maxi(GFVariantData.get_option_int(data, "document_schema_version"), 0)
	source_data_version = maxi(GFVariantData.get_option_int(data, "source_data_version", 1), 1)
	data_version = maxi(GFVariantData.get_option_int(data, "data_version", source_data_version), 1)
	migrated = GFVariantData.get_option_bool(data, "migrated")


## 从字典创建不带 Storage 来源绑定的读取结果。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 读取结果字典。
## [br]
## @schema data: Dictionary，GFStorageReadResult.to_dict() 输出。
## [br]
## @return 新读取结果。
static func from_dict(data: Dictionary) -> GFStorageReadResult:
	var result: GFStorageReadResult = GFStorageReadResult.new()
	result.apply_dict(data)
	return result


# --- 框架内部方法 ---

## 绑定本次读取的 Utility、root 与 logical identity；该来源不会进入公开字典 schema。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @param utility_id: 签发结果的 GFStorageUtility 实例 ID。
## [br]
## @param logical_path: canonical logical identity。
## [br]
## @param file_key: 冻结 Storage root 与 family 的私有绑定键。
## [br]
## @param origin_token: Utility 生命周期内不可序列化的来源 token。
## [br]
## @param observation_token: 读取终态绑定的不可序列化 family 观察快照。
## [br]
## @return 首次绑定合法来源时返回 true。
func bind_origin_for_framework(
	utility_id: int,
	logical_path: String,
	file_key: String,
	origin_token: String,
	observation_token: String
) -> bool:
	if (
		_origin_bound
		or utility_id == 0
		or not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(logical_path)
		or file_key.is_empty()
		or origin_token.is_empty()
		or observation_token.is_empty()
	):
		return false
	_origin_bound = true
	_origin_utility_id = utility_id
	_origin_logical_path = logical_path
	_origin_file_key = file_key
	_origin_token = origin_token
	_origin_observation_token = observation_token
	_origin_ok = ok
	_origin_error_code = error_code
	_origin_failure_kind = failure_kind
	return true


## 检查结果是否仍由指定 Utility 为同一 logical family 签发，且授权资格字段
## `ok`、`error_code` 与 `failure_kind` 仍匹配签发快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @param utility_id: 当前 GFStorageUtility 实例 ID。
## [br]
## @param logical_path: 当前请求的 canonical logical identity。
## [br]
## @param file_key: 当前冻结 Storage root 与 family 的私有绑定键。
## [br]
## @param origin_token: 当前 Utility 生命周期的来源 token。
## [br]
## @return 来源、身份与绑定时终态全部精确匹配时返回 true。
func matches_origin_for_framework(
	utility_id: int,
	logical_path: String,
	file_key: String,
	origin_token: String
) -> bool:
	return (
		_origin_binding_is_current()
		and utility_id == _origin_utility_id
		and logical_path == _origin_logical_path
		and file_key == _origin_file_key
		and origin_token == _origin_token
	)


## 获取精确来源绑定携带的不可序列化 family 观察快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @param utility_id: 当前 GFStorageUtility 实例 ID。
## [br]
## @param logical_path: 当前请求的 canonical logical identity。
## [br]
## @param file_key: 当前冻结 Storage root 与 family 的私有绑定键。
## [br]
## @param origin_token: 当前 Utility 生命周期的来源 token。
## [br]
## @return 来源身份仍精确匹配时返回非空 opaque token，否则返回空字符串。
func get_origin_observation_token_for_framework(
	utility_id: int,
	logical_path: String,
	file_key: String,
	origin_token: String
) -> String:
	if not matches_origin_for_framework(
		utility_id,
		logical_path,
		file_key,
		origin_token
	):
		return ""
	return _origin_observation_token


# --- 私有/辅助方法 ---

func _clear_origin_binding() -> void:
	_origin_bound = false
	_origin_utility_id = 0
	_origin_logical_path = ""
	_origin_file_key = ""
	_origin_token = ""
	_origin_observation_token = ""
	_origin_ok = false
	_origin_error_code = FAILED
	_origin_failure_kind = FailureKind.NONE


func _origin_binding_is_current() -> bool:
	return (
		_origin_bound
		and ok == _origin_ok
		and error_code == _origin_error_code
		and failure_kind == _origin_failure_kind
	)


static func _to_integrity_status(value: int) -> IntegrityStatus:
	match value:
		IntegrityStatus.VALID:
			return IntegrityStatus.VALID
		IntegrityStatus.MISSING:
			return IntegrityStatus.MISSING
		IntegrityStatus.INVALID:
			return IntegrityStatus.INVALID
		_:
			return IntegrityStatus.NOT_CHECKED


static func _to_failure_kind(value: int) -> FailureKind:
	if FailureKind.values().has(value):
		return value as FailureKind
	return FailureKind.IO_FAILED
