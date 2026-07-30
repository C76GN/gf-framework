## GFSaveSectionSnapshot: 单个 Save section 的一次性所有权快照。
##
## Snapshot 只保存纯 Variant 数据，并在框架接管后立即清空自身引用。调用
## `take_ownership()` 后，调用方必须放弃原 payload、metadata 及其全部嵌套别名；
## GDScript 不提供语言级 move 语义，因此该约束属于显式所有权协议。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveSectionSnapshot
extends RefCounted


# --- 常量 ---

## Snapshot 尚未被框架接管。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_AVAILABLE: StringName = &"available"

## Snapshot 已被框架接管，载荷不再可用。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CLAIMED: StringName = &"claimed"

## Snapshot 已被取消并释放载荷。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_DISCARDED: StringName = &"discarded"


# --- 私有变量 ---

var _section_id: StringName = &""
var _schema_version: int = 0
var _payload: Variant = null
var _metadata: Dictionary = {}
var _state: StringName = STATE_DISCARDED


# --- 公共方法 ---

## 接管一个 section 的纯数据所有权。
##
## 该方法不会深复制 payload 或 metadata。成功返回后，调用方不得继续读取、修改
## 或向其它线程提交原 Dictionary、Array 及其嵌套别名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param section_id: 稳定 section ID。
## [br]
## @param schema_version: 当前 section schema 版本。
## [br]
## @param payload: 调用方移交的纯 Variant 载荷。
## [br]
## @param metadata: 调用方移交的纯 Variant 元数据。
## [br]
## @schema payload: Variant accepted by the Save persisted-value contract.
## [br]
## @schema metadata: Dictionary with provider-defined persisted metadata.
## [br]
## @return 可用 Snapshot；身份无效时返回 null。
static func take_ownership(
	section_id: StringName,
	schema_version: int,
	payload: Variant,
	metadata: Dictionary = {}
) -> GFSaveSectionSnapshot:
	if section_id == &"" or schema_version <= 0:
		return null
	var snapshot: GFSaveSectionSnapshot = GFSaveSectionSnapshot.new()
	snapshot._section_id = section_id
	snapshot._schema_version = schema_version
	snapshot._payload = payload
	snapshot._metadata = metadata
	snapshot._state = STATE_AVAILABLE
	return snapshot


## 获取稳定 section ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return section ID。
func get_section_id() -> StringName:
	return _section_id


## 获取 section schema 版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 schema 版本。
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


## 检查 Snapshot 是否仍可由框架接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未接管或释放时返回 true。
func is_available() -> bool:
	return _state == STATE_AVAILABLE


# --- 框架内部方法 ---

## 一次性接管 section 记录并清空 Snapshot。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 规范 section 记录；已接管或释放时返回空字典。
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


## 取消尚未接管的 Snapshot 并释放载荷。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 本次确实释放了可用 Snapshot 时返回 true。
func discard_for_framework() -> bool:
	if not is_available():
		return false
	_payload = null
	_metadata = {}
	_state = STATE_DISCARDED
	return true
