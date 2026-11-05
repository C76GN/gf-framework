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
	## 文件、解码明文或 JSON 遍历超出读取预算；也包含无法排除解压上限的解压失败，不代表文件损坏。
	LIMIT_EXCEEDED,
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

## 标记结果是否绑定了不可序列化的 Storage 来源。
## [br]
## @api private
## [br]
var _origin_bound: bool = false

## 签发结果的 Utility 实例 ID。
## [br]
## @api private
## [br]
var _origin_utility_id: int = 0

## 来源绑定的 canonical logical identity。
## [br]
## @api private
## [br]
var _origin_logical_path: String = ""

## 来源绑定的 Storage root/family 内部身份键。
## [br]
## @api private
## [br]
var _origin_file_key: String = ""

## Utility 生命周期内不可序列化的结果来源 token。
## [br]
## @api private
## [br]
var _origin_token: String = ""

## 读取终态绑定的 opaque family 观察快照。
## [br]
## @api private
## [br]
var _origin_observation_token: String = ""

## 来源绑定时冻结的成功标记，用于检测授权字段被改写。
## [br]
## @api private
## [br]
var _origin_ok: bool = false

## 来源绑定时冻结的 Error 码。
## [br]
## @api private
## [br]
var _origin_error_code: Error = FAILED

## 来源绑定时冻结的失败分类。
## [br]
## @api private
## [br]
var _origin_failure_kind: FailureKind = FailureKind.NONE

## 与实际物理读取配对的不可变 committed revision。
## [br]
## @api private
## [br]
var _captured_revision: GFStorageRevisionResult

## 同一次 JSON parse 的只读输入树；仅内部同步读取选择保留，副本共享且不参与公开序列化。
## [br]
## @api private
var _json_projection: Variant = null


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
	_captured_revision = null
	_json_projection = null
	ok = true
	payload = p_payload.duplicate(true)
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = OK
	error = ""
	failure_kind = FailureKind.NONE
	document_schema_version = maxi(p_document_schema_version, 0)
	source_data_version = maxi(
		GFVariantData.get_option_int(
			metadata,
			"data_version",
			1
		),
		1
	)
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
	_json_projection = null
	_clear_origin_binding()
	_captured_revision = null
	ok = false
	payload.clear()
	metadata = p_metadata.duplicate(true)
	integrity_status = p_integrity_status
	error_code = p_error_code
	error = p_error.strip_edges()
	failure_kind = p_failure_kind if p_failure_kind != FailureKind.NONE else FailureKind.IO_FAILED
	document_schema_version = maxi(p_document_schema_version, 0)
	source_data_version = maxi(
		GFVariantData.get_option_int(
			metadata,
			"data_version",
			1
		),
		1
	)
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


## 返回实际读取源的 committed revision；仅做等值比较，不代表载荷完整性或业务 schema 版本。
##
## schema 1、手工构造及 Dictionary 往返结果为 UNSUPPORTED。该快照表示读取来源，
## 不随返回后对 payload 的修改而变化；调用方应在修改前建立摘要缓存。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不可变的 revision 结果；失败读取不提供可缓存 token。
func get_committed_revision() -> GFStorageRevisionResult:
	if not ok:
		return GFStorageRevisionStore.failure_for_framework(error_code)
	if _captured_revision == null:
		return GFStorageRevisionResult.failure(GFStorageRevisionResult.Status.UNSUPPORTED, ERR_UNAVAILABLE)
	return _captured_revision


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
	var copy: GFStorageReadResult = from_dict(_make_field_dictionary())
	copy._captured_revision = _captured_revision
	copy._json_projection = _json_projection
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
	var data: Dictionary = _make_field_dictionary()
	data["payload"] = payload.duplicate(true)
	data["metadata"] = metadata.duplicate(true)
	return data


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
	_captured_revision = null
	_json_projection = null
	ok = GFVariantData.get_option_bool(data, "ok")
	payload = GFVariantData.get_option_dictionary(data, "payload") if ok else {}
	metadata = GFVariantData.get_option_dictionary(data, "metadata")
	integrity_status = _to_integrity_status(GFVariantData.get_option_int(data, "integrity_status"))
	error_code = GFVariantData.get_option_int(
		data,
		"error_code",
		ERR_INVALID_DATA
	) as Error
	error = GFVariantData.get_option_string(data, "error").strip_edges()
	if ok:
		failure_kind = FailureKind.NONE
	else:
		failure_kind = _to_failure_kind(
			GFVariantData.get_option_int(
				data,
				"failure_kind",
				FailureKind.IO_FAILED
			)
		)
		if failure_kind == FailureKind.NONE:
			failure_kind = FailureKind.IO_FAILED
	document_schema_version = maxi(
		GFVariantData.get_option_int(data, "document_schema_version"),
		0
	)
	source_data_version = maxi(
		GFVariantData.get_option_int(
			data,
			"source_data_version",
			1
		),
		1
	)
	data_version = maxi(
		GFVariantData.get_option_int(
			data,
			"data_version",
			source_data_version
		),
		1
	)
	migrated = GFVariantData.get_option_bool(data, "migrated")


## 从字典创建不带 Storage 来源绑定或 committed revision 的读取结果。
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

## 接管已经完整解码验证的同次 JSON parse 输入并递归只读封存；额外验证沿用 codec 遍历预算，不保存第二份原生载荷。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param document: 与当前结果同次读取的 JSON 文档树。
## [br]
## @schema document: 原始 JSON scalar、Array、Dictionary 树；循环、不完整 marker 或遍历超限不保留。
func capture_json_projection_for_framework(document: Variant) -> void:
	_json_projection = null
	if not ok or not is_integrity_accepted():
		return
	var validation: Dictionary = GFVariantJsonCodec.json_compatible_to_variant_result(document)
	if not GFResultDictionary.is_ok(validation):
		return
	_make_json_projection_read_only(document)
	_json_projection = document


## 按原生键或数组索引定位同次 JSON 输入；中间 Dictionary 包装只解码键，叶子 marker 保持原编码。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param path: 从物理文档根开始的 String/StringName 键或整数数组索引。
## [br]
## @param project_dictionary: 为 true 时仅展开目标 Dictionary 的外层，保留各 value 的 prepared 表示。
## [br]
## @schema path: Array，元素只能为 String、StringName 或 int。
## [br]
## @return: 无投影或路径缺失为空；成功为 ok/value；迁移已改变原生数据时显式失败，不返回旧投影。
## [br]
## @schema return: Dictionary，可包含 ok: bool、value: Variant、error: String；value 的嵌套原始输入只读且与副本共享。
func get_json_projection_value_for_framework(path: Array, project_dictionary: bool = false) -> Dictionary:
	if _json_projection == null:
		return {}
	if (
		not ok
		or migrated
		or not is_integrity_accepted()
	):
		return { "ok": false, "error": "Prepared JSON projection is no longer valid after the Storage result changed." }
	var current: Variant = _json_projection
	for segment: Variant in path:
		if not (
			segment is String
			or segment is StringName
			or segment is int
		):
			return {}
		if current is Dictionary:
			var projected: Dictionary = _project_json_dictionary(current)
			if not GFResultDictionary.is_ok(projected):
				return {}
			var dictionary: Dictionary = GFVariantData.as_dictionary(projected.get("value"))
			if not dictionary.has(segment):
				return {}
			current = dictionary[segment]
		elif current is Array and segment is int:
			var array: Array = current
			var index: int = segment
			if index < 0 or index >= array.size():
				return {}
			current = array[index]
		else:
			return {}
	if project_dictionary:
		return _project_json_dictionary(current)
	return { "ok": true, "value": current }


## 捕获实际物理读取源的不可变 revision；不扩展公开 Dictionary schema。
## [br]
## @api framework_internal
## [br]
## @param revision: 同一次读取捕获的结果。
func capture_revision_for_framework(revision: GFStorageRevisionResult) -> void:
	_captured_revision = revision if ok else null


## 返回实际捕获的 revision，不合成失败或不支持状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 成功读取捕获的 revision；未捕获时为 null。
func get_captured_revision_for_framework() -> GFStorageRevisionResult:
	return _captured_revision


## 绑定本次读取的 Utility、root 与 logical identity；该来源不会进入公开字典 schema。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
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
## @since 11.0.0
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
## @since 11.0.0
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

## 已完整验证的 JSON 树不含循环；封存现有容器而不深复制，使多个 Result 安全共享投影。
## [br]
## @api private
func _make_json_projection_read_only(value: Variant) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary:
			_make_json_projection_read_only(dictionary[key])
		dictionary.make_read_only()
	elif value is Array:
		var array: Array = value
		for child: Variant in array:
			_make_json_projection_read_only(child)
		array.make_read_only()


## 仅展开 Dictionary 的一层键映射，绝不递归解释 value marker；普通 JSON object 沿用其文本键。
## [br]
## @api private
func _project_json_dictionary(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var dictionary: Dictionary = value
	var marker: Dictionary = GFVariantData.as_dictionary(dictionary.get(GFVariantJsonCodec.JSON_MARKER_KEY))
	if (
		dictionary.size() == 1
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_CODEC_KEY) == GFVariantJsonCodec.JSON_CODEC_ID
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_TYPE_KEY) == "Dictionary"
	):
		var projected: Dictionary = {}
		for entry_value: Variant in GFVariantData.as_array(marker.get(GFVariantJsonCodec.JSON_VALUE_KEY)):
			var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
			var decoded_key: Dictionary = GFVariantJsonCodec.json_compatible_to_variant_result(entry.get("key"))
			if not GFResultDictionary.is_ok(decoded_key):
				return {}
			projected[decoded_key.get("value")] = entry.get("value")
		return { "ok": true, "value": projected }
	return { "ok": true, "value": dictionary }


## 组装 to_dict/from_dict 使用的字段集合，不包含 opaque 来源和 captured revision。
## [br]
## @api private
## [br]
func _make_field_dictionary() -> Dictionary:
	# 仅在当前调用内传递字段；from_dict 负责规范化与隔离，公开导出另行复制容器。
	return {
		"ok": ok,
		"payload": payload,
		"metadata": metadata,
		"integrity_status": int(integrity_status),
		"error_code": int(error_code),
		"error": error,
		"failure_kind": int(failure_kind),
		"document_schema_version": document_schema_version,
		"source_data_version": source_data_version,
		"data_version": data_version,
		"migrated": migrated,
	}


## 清除全部不可序列化来源身份及签发时冻结的授权字段。
## [br]
## @api private
## [br]
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


## 检查来源绑定存在且当前 ok、error_code 与 failure_kind 仍等于签发快照。
## [br]
## @api private
## [br]
func _origin_binding_is_current() -> bool:
	return (
		_origin_bound
		and ok == _origin_ok
		and error_code == _origin_error_code
		and failure_kind == _origin_failure_kind
	)


## 将整数映射为已知完整性状态，未知值回退到 NOT_CHECKED。
## [br]
## @api private
## [br]
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


## 将整数映射为已知读取失败分类，未知值回退到 IO_FAILED。
## [br]
## @api private
## [br]
static func _to_failure_kind(value: int) -> FailureKind:
	if FailureKind.values().has(value):
		return value as FailureKind
	return FailureKind.IO_FAILED
