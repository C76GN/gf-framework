## GFSaveSectionMutation: 单个 Save section 的一次性候选替换句柄。
##
## Mutation 只描述完整候选 section，不接受可执行 Callable 或增量 patch。
## `take_ownership()` 成功后，调用方必须永久放弃 payload、metadata 及其全部
## 嵌套集合 alias；框架 claim 后句柄会立即清空载荷。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveSectionMutation
extends RefCounted


# --- 常量 ---

## Mutation 尚未被框架接管。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_AVAILABLE: StringName = &"available"

## Mutation 已被框架接管，候选载荷不再可用。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CLAIMED: StringName = &"claimed"

## Mutation 已被框架丢弃，候选载荷不再可用。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_DISCARDED: StringName = &"discarded"

const _PERSISTED_VALUE_VALIDATOR_SCRIPT = preload(
	"res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd"
)


# --- 私有变量 ---

var _section_id: StringName = &""
var _schema_version: int = 0
var _payload: Variant = null
var _metadata: Dictionary = {}
var _state: StringName = STATE_DISCARDED


# --- 公共方法 ---

## 接管一个完整候选 section 的逻辑唯一所有权。
##
## 该方法不会深复制 payload 或 metadata。成功返回后，调用方不得继续读取、
## 修改或复用原集合及其嵌套 alias。输入必须满足 Save persisted-value 契约；
## Callable、Object、Signal、RID、循环集合和非有限数会被拒绝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param section_id: 稳定 section ID。
## [br]
## @param schema_version: 候选 section 的正整数 schema 版本。
## [br]
## @param payload: 完整候选 section 载荷，不是 patch 或回调。
## [br]
## @param metadata: 候选 section 持久化元数据。
## [br]
## @schema payload: Variant accepted by the Save persisted-value contract.
## [br]
## @schema metadata: Dictionary accepted by the Save persisted-value contract.
## [br]
## @return 可用 Mutation；身份或候选数据无效时返回 null。
static func take_ownership(
	section_id: StringName,
	schema_version: int,
	payload: Variant,
	metadata: Dictionary = {}
) -> GFSaveSectionMutation:
	if (
		section_id == &""
		or String(section_id) != String(section_id).strip_edges()
		or schema_version <= 0
	):
		return null
	var payload_report: Dictionary = _PERSISTED_VALUE_VALIDATOR_SCRIPT.validate(payload)
	if not GFVariantData.get_option_bool(payload_report, "ok", false):
		return null
	var metadata_report: Dictionary = _PERSISTED_VALUE_VALIDATOR_SCRIPT.validate(metadata)
	if not GFVariantData.get_option_bool(metadata_report, "ok", false):
		return null

	var mutation: GFSaveSectionMutation = GFSaveSectionMutation.new()
	mutation._section_id = section_id
	mutation._schema_version = schema_version
	mutation._payload = payload
	mutation._metadata = metadata
	mutation._state = STATE_AVAILABLE
	return mutation


## 获取稳定 section ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return section ID。
func get_section_id() -> StringName:
	return _section_id


## 获取候选 section schema 版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 schema 版本；无效句柄为 0。
func get_schema_version() -> int:
	return _schema_version


## 获取当前所有权状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATE_*` 常量之一。
func get_state() -> StringName:
	return _state


## 检查 Mutation 是否仍可被请求或框架接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未 claim 或 discard 时返回 true。
func is_available() -> bool:
	return _state == STATE_AVAILABLE


# --- 框架内部方法 ---

## 获取不含候选载荷的 Mutation 身份快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 包含 section_id、schema_version、state 和 available 的快照。
## [br]
## @schema return: Payload-free Dictionary with section_id, schema_version, state, and available.
func inspect_for_framework() -> Dictionary:
	return {
		"section_id": _section_id,
		"schema_version": _schema_version,
		"state": _state,
		"available": is_available(),
	}


## 一次性接管完整候选 section，并清空当前句柄。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 规范候选记录；不可用时返回空字典。
## [br]
## @schema return: Dictionary with section_id, schema_version, payload, and metadata.
func claim_for_framework() -> Dictionary:
	if not is_available():
		return {}
	var record: Dictionary = {
		"section_id": _section_id,
		"schema_version": _schema_version,
		"payload": _payload,
		"metadata": _metadata,
	}
	_payload = null
	_metadata = {}
	_state = STATE_CLAIMED
	return record


## 丢弃尚未被接管的候选载荷。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 本次确实丢弃可用 Mutation 时返回 true。
func discard_for_framework() -> bool:
	if not is_available():
		return false
	_payload = null
	_metadata = {}
	_state = STATE_DISCARDED
	return true
