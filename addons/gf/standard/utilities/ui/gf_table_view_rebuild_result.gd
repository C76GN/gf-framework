## GFTableViewRebuildResult: 表格投影事务的类型化结果。
##
## 成功结果描述一次提交或 no-op；失败结果描述未提交的阶段、谓词和行身份。
## 结果不携带源 row，从而可安全交给 UI 诊断层。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFTableViewRebuildResult
extends RefCounted


# --- 常量 ---

## 允许的最大错误码 UTF-8 字节数。
## [br]
## @api private
const _MAX_ERROR_CODE_UTF8_BYTES: int = 128

## 失败说明允许保留的最大 UTF-8 字节数。
## [br]
## @api private
const _MAX_ERROR_MESSAGE_UTF8_BYTES: int = 1_024

## 允许的最大诊断 ID UTF-8 字节数。
## [br]
## @api private
const _MAX_DIAGNOSTIC_ID_UTF8_BYTES: int = 128

## 失败行 ID 文本形式允许的最大 UTF-8 字节数。
## [br]
## @api private
const _MAX_DIAGNOSTIC_ROW_ID_UTF8_BYTES: int = 256


# --- 私有变量 ---

## 是否已由成功或失败配置入口初始化。
## [br]
## @api private
var _configured: bool = false

## 结果是否表示成功重建。
## [br]
## @api private
var _successful: bool = false

## 成功结果是否提交了新的 revision。
## [br]
## @api private
var _committed: bool = false

## 结果对应的已提交 revision。
## [br]
## @api private
var _view_revision: int = 0

## 结果对应的可见行数量。
## [br]
## @api private
var _visible_count: int = 0

## 候选投影扫描的源行数量。
## [br]
## @api private
var _scanned_row_count: int = 0

## 候选投影执行的行谓词次数。
## [br]
## @api private
var _predicate_evaluation_count: int = 0

## 归一化后的失败码；成功结果为空。
## [br]
## @api private
var _error_code: StringName = &""

## 按 UTF-8 字节数截断后的失败说明。
## [br]
## @api private
var _error_message: String = ""

## 归一化后的失败谓词 ID。
## [br]
## @api private
var _failed_predicate_id: StringName = &""

## 失败对应的源行索引；非行级失败为 -1。
## [br]
## @api private
var _failed_source_row_index: int = -1

## 通过稳定键校验并复制的失败行 ID。
## [br]
## @api private
var _failed_row_id: Variant = null


# --- 公共方法 ---

## 查询事务是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功时返回 true。
func is_successful() -> bool:
	return _successful


## 查询事务是否提交了新 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 提交时返回 true；成功 no-op 返回 false。
func was_committed() -> bool:
	return _committed


## 获取结果对应的已提交 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前已提交 revision。
func get_view_revision() -> int:
	return _view_revision


## 获取当前已提交可见行数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 可见行数量。
func get_visible_count() -> int:
	return _visible_count


## 获取本次候选扫描的源行数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已扫描行数量。
func get_scanned_row_count() -> int:
	return _scanned_row_count


## 获取本次候选执行的谓词次数。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 谓词求值次数。
func get_predicate_evaluation_count() -> int:
	return _predicate_evaluation_count


## 获取稳定错误码。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败错误码；成功时为空。
func get_error_code() -> StringName:
	return _error_code


## 获取有界错误说明。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败说明；成功时为空。
func get_error_message() -> String:
	return _error_message


## 获取失败谓词 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败谓词 ID；非谓词失败时为空。
func get_failed_predicate_id() -> StringName:
	return _failed_predicate_id


## 获取失败源行索引。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败行索引；非行失败时为 -1。
func get_failed_source_row_index() -> int:
	return _failed_source_row_index


## 获取失败行 ID 副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 失败行 ID；非行失败时为 null。
## [br]
## @schema return: Variant stable row identity copy, or null.
func get_failed_row_id() -> Variant:
	return GFVariantData.duplicate_variant(_failed_row_id, true, true)


## 创建结果的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新结果对象；未配置实例返回新的未配置实例。
func duplicate_result() -> GFTableViewRebuildResult:
	var duplicate: GFTableViewRebuildResult = GFTableViewRebuildResult.new()
	if not _configured:
		return duplicate
	if _successful:
		var _success_configured: bool = duplicate.configure_success_for_framework(
			_committed,
			_view_revision,
			_visible_count,
			_scanned_row_count,
			_predicate_evaluation_count
		)
	else:
		var _failure_configured: bool = duplicate.configure_failure_for_framework(
			_error_code,
			_error_message,
			_view_revision,
			_visible_count,
			_scanned_row_count,
			_predicate_evaluation_count,
			_failed_predicate_id,
			_failed_source_row_index,
			_failed_row_id
		)
	return duplicate


# --- 框架内部方法 ---

## 写入成功结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param committed: 是否提交了新 revision。
## [br]
## @param view_revision: 当前已提交 revision。
## [br]
## @param visible_count: 当前可见行数量。
## [br]
## @param scanned_row_count: 候选扫描行数量。
## [br]
## @param predicate_evaluation_count: 谓词求值次数。
## [br]
## @return 首次配置时返回 true。
func configure_success_for_framework(
	committed: bool,
	view_revision: int,
	visible_count: int,
	scanned_row_count: int,
	predicate_evaluation_count: int
) -> bool:
	if _configured:
		return false
	_configured = true
	_successful = true
	_committed = committed
	_view_revision = maxi(view_revision, 0)
	_visible_count = maxi(visible_count, 0)
	_scanned_row_count = maxi(scanned_row_count, 0)
	_predicate_evaluation_count = maxi(predicate_evaluation_count, 0)
	_error_code = &""
	_error_message = ""
	_failed_predicate_id = &""
	_failed_source_row_index = -1
	_failed_row_id = null
	return true


## 写入失败结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param error_code: 稳定错误码。
## [br]
## @param error_message: 有界错误说明。
## [br]
## @param view_revision: 仍然有效的已提交 revision。
## [br]
## @param visible_count: 仍然有效的可见行数量。
## [br]
## @param scanned_row_count: 失败前扫描行数量。
## [br]
## @param predicate_evaluation_count: 失败前谓词求值次数。
## [br]
## @param failed_predicate_id: 失败谓词 ID。
## [br]
## @param failed_source_row_index: 失败源行索引。
## [br]
## @param failed_row_id: 失败行稳定 ID。
## [br]
## @schema failed_row_id: Variant stable key accepted by GFVariantKeyCodec, or null.
## [br]
## @return 首次配置时返回 true。
func configure_failure_for_framework(
	error_code: StringName,
	error_message: String,
	view_revision: int,
	visible_count: int,
	scanned_row_count: int = 0,
	predicate_evaluation_count: int = 0,
	failed_predicate_id: StringName = &"",
	failed_source_row_index: int = -1,
	failed_row_id: Variant = null
) -> bool:
	if _configured:
		return false
	_configured = true
	_successful = false
	_committed = false
	_view_revision = maxi(view_revision, 0)
	_visible_count = maxi(visible_count, 0)
	_scanned_row_count = maxi(scanned_row_count, 0)
	_predicate_evaluation_count = maxi(predicate_evaluation_count, 0)
	_error_code = _normalize_error_code(error_code)
	_error_message = _truncate_utf8(error_message, _MAX_ERROR_MESSAGE_UTF8_BYTES)
	_failed_predicate_id = _normalize_diagnostic_id(failed_predicate_id)
	_failed_source_row_index = failed_source_row_index
	_failed_row_id = _copy_bounded_diagnostic_row_id(failed_row_id)
	return true


# --- 私有/辅助方法 ---

## 将空白、超长或首尾带空格的错误码归一为 view_rebuild_failed。
## [br]
## @api private
static func _normalize_error_code(error_code: StringName) -> StringName:
	var error_text: String = String(error_code)
	if (
		error_text.is_empty()
		or error_text != error_text.strip_edges()
		or error_text.length() > _MAX_ERROR_CODE_UTF8_BYTES
		or error_text.to_utf8_buffer().size() > _MAX_ERROR_CODE_UTF8_BYTES
	):
		return &"view_rebuild_failed"
	return error_code


## 将空白、超长或首尾带空格的诊断 ID 归一为空字符串。
## [br]
## @api private
static func _normalize_diagnostic_id(diagnostic_id: StringName) -> StringName:
	var id_text: String = String(diagnostic_id)
	if (
		id_text.is_empty()
		or id_text != id_text.strip_edges()
		or id_text.length() > _MAX_DIAGNOSTIC_ID_UTF8_BYTES
		or id_text.to_utf8_buffer().size() > _MAX_DIAGNOSTIC_ID_UTF8_BYTES
	):
		return &""
	return diagnostic_id


## 仅复制稳定键；字符串类键超出字节限制或其他值不稳定时返回 null。
## [br]
## @api private
static func _copy_bounded_diagnostic_row_id(row_id: Variant) -> Variant:
	if not GFVariantKeyCodec.is_stable_key(row_id):
		return null
	if row_id is String or row_id is StringName or row_id is NodePath:
		var row_id_text: String = GFVariantData.to_text(row_id)
		if (
			row_id_text.length() > _MAX_DIAGNOSTIC_ROW_ID_UTF8_BYTES
			or row_id_text.to_utf8_buffer().size() > _MAX_DIAGNOSTIC_ROW_ID_UTF8_BYTES
		):
			return null
	return GFVariantData.duplicate_variant(row_id, true, true)


## 按 UTF-8 字节上限截取文本，避免截断多字节字符。
## [br]
## @api private
static func _truncate_utf8(text_value: String, max_bytes: int) -> String:
	var bounded_text: String = text_value.left(max_bytes)
	if text_value.length() <= max_bytes and bounded_text.to_utf8_buffer().size() <= max_bytes:
		return text_value
	var low: int = 0
	var high: int = bounded_text.length()
	while low < high:
		var middle: int = floori(float(low + high + 1) / 2.0)
		if bounded_text.left(middle).to_utf8_buffer().size() <= max_bytes:
			low = middle
		else:
			high = middle - 1
	return bounded_text.left(low)
