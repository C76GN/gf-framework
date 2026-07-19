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


# --- 公共方法 ---

## 配置成功结果。
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
	ok = true
	payload = p_payload.duplicate(true)
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = OK
	error = ""
	document_schema_version = maxi(p_document_schema_version, 0)
	source_data_version = maxi(GFVariantData.get_option_int(metadata, "data_version", 1), 1)
	data_version = source_data_version
	migrated = false
	return self


## 配置失败结果。
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
## @schema p_metadata: Dictionary，失败时仍可安全展示或诊断的框架存储元数据。
## [br]
## @return 当前结果。
func configure_failure(
	p_error: String,
	p_error_code: Error = ERR_INVALID_DATA,
	p_metadata: Dictionary = {},
	p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED,
	p_document_schema_version: int = 0
) -> GFStorageReadResult:
	ok = false
	payload.clear()
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = p_error_code
	error = p_error.strip_edges()
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
## @return 新读取结果。
func duplicate_result() -> GFStorageReadResult:
	return from_dict(to_dict())


## 转换为线程、报告和工具可传递的字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 读取结果字典。
## [br]
## @schema return: Dictionary，包含 ok、payload、metadata、integrity_status、error_code、error、document_schema_version、source_data_version、data_version 和 migrated。
func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"payload": payload.duplicate(true),
		"metadata": metadata.duplicate(true),
		"integrity_status": int(integrity_status),
		"error_code": int(error_code),
		"error": error,
		"document_schema_version": document_schema_version,
		"source_data_version": source_data_version,
		"data_version": data_version,
		"migrated": migrated,
	}


## 从字典应用读取结果字段。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 读取结果字典。
## [br]
## @schema data: Dictionary，GFStorageReadResult.to_dict() 输出。
func apply_dict(data: Dictionary) -> void:
	ok = GFVariantData.get_option_bool(data, "ok")
	payload = GFVariantData.get_option_dictionary(data, "payload") if ok else {}
	metadata = GFVariantData.get_option_dictionary(data, "metadata")
	integrity_status = _to_integrity_status(GFVariantData.get_option_int(data, "integrity_status"))
	error_code = GFVariantData.get_option_int(data, "error_code", ERR_INVALID_DATA) as Error
	error = GFVariantData.get_option_string(data, "error").strip_edges()
	document_schema_version = maxi(GFVariantData.get_option_int(data, "document_schema_version"), 0)
	source_data_version = maxi(GFVariantData.get_option_int(data, "source_data_version", 1), 1)
	data_version = maxi(GFVariantData.get_option_int(data, "data_version", source_data_version), 1)
	migrated = GFVariantData.get_option_bool(data, "migrated")


## 从字典创建读取结果。
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


# --- 私有/辅助方法 ---

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
