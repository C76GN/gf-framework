## GFSaveSectionProvider: Save Profile section 所有权协议。
##
## 一个 provider 只拥有一个稳定 section。保存通过显式协作式 Snapshot Operation
## 分片推进；读取应用与回滚快照保持独立协议。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 10.0.0
class_name GFSaveSectionProvider
extends Resource


# --- 导出变量 ---

## 稳定且在 profile 内唯一的 section ID。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var section_id: StringName = &"":
	set(value):
		if _definition_locked and value != section_id:
			push_error("[GFSaveSectionProvider] 已注册的 section_id 不可修改。")
			return
		section_id = value

## 当前 section schema 版本。
## [br]
## @api public
## [br]
## @since 10.0.0
@export_range(1, 2_147_483_647, 1) var schema_version: int = 1:
	set(value):
		if _definition_locked and value != schema_version:
			push_error("[GFSaveSectionProvider] 已注册的 schema_version 不可修改。")
			return
		schema_version = value

## 是否参与保存采集。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var save_enabled: bool = true:
	set(value):
		if _definition_locked and value != save_enabled:
			push_error("[GFSaveSectionProvider] 已注册的 save_enabled 不可修改。")
			return
		save_enabled = value

## 是否参与读取应用。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var load_enabled: bool = true:
	set(value):
		if _definition_locked and value != load_enabled:
			push_error("[GFSaveSectionProvider] 已注册的 load_enabled 不可修改。")
			return
		load_enabled = value

## 读取时该 section 是否必须存在。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var required_on_load: bool = true:
	set(value):
		if _definition_locked and value != required_on_load:
			push_error("[GFSaveSectionProvider] 已注册的 required_on_load 不可修改。")
			return
		required_on_load = value


# --- 私有变量 ---

var _definition_locked: bool = false


# --- 公共方法 ---

## 校验 provider 身份和能力配置。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_provider() -> Dictionary:
	var report: Dictionary = {"issues": []}
	if section_id == &"" or String(section_id) != String(section_id).strip_edges():
		var _id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_section_id",
			"Section provider id must be non-empty and trimmed.",
			{"path": "section_id"}
		)
	if schema_version <= 0:
		var _version_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_section_version",
			"Section provider schema version must be positive.",
			{"path": "schema_version", "value": schema_version}
		)
	if not save_enabled and not load_enabled:
		var _capability_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"provider_disabled",
			"Section provider must support save, load, or both.",
			{"path": "save_enabled"}
		)
	if required_on_load and not load_enabled:
		var _required_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"required_provider_not_loadable",
			"A required section provider must support load.",
			{"path": "required_on_load"}
		)
	return GFValidationReportDictionary.finalize_report(report, "Save section provider", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_section_id": "Assign a non-empty trimmed section id owned by one module.",
			"invalid_section_version": "Use a positive current section version.",
			"provider_disabled": "Enable save, load, or both.",
			"required_provider_not_loadable": "Enable load or make the section optional.",
		},
		"fallback_action": "Review the first section provider issue.",
		"no_action": "Save section provider is valid.",
	})


## 开始主线程协作式保存快照。
##
## begin 回调必须保持有界，只捕获稳定根引用或创建 Operation；大型数据应由
## Operation 的后续 slice 分片构造。返回的 Operation 会绑定当前 Provider 身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param context: 本次操作的临时上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return 已绑定 Operation；创建失败时返回 null。
func begin_save_snapshot(
	context: Dictionary = {}
) -> GFSaveSectionSnapshotOperation:
	if not save_enabled:
		return null
	var operation: GFSaveSectionSnapshotOperation = _begin_save_snapshot(context)
	if operation == null:
		return null
	if not operation.configure_for_framework(section_id, schema_version):
		return null
	return operation


## 采集应用前回滚快照。
##
## 该能力独立于 `save_enabled`，允许只读取 provider 提供可回滚的内存快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param context: 本次操作的临时上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return 合法且身份匹配的当前 section；失败时返回 null。
func capture_section(context: Dictionary = {}) -> GFSaveSection:
	if not load_enabled:
		return null
	return _normalize_section(_capture_section(context))


## 应用属于当前 provider 的 section。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param section: 已迁移并校验的当前版本 section。
## [br]
## @param context: 本次操作的临时上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return Godot Error 结果码。
func apply_section(section: GFSaveSection, context: Dictionary = {}) -> Error:
	if not load_enabled or not _matches_section(section):
		return ERR_INVALID_DATA
	return _apply_section(section.duplicate_section(), context)


## 使用应用前快照恢复当前 provider。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param previous_section: 应用前采集的当前版本 section。
## [br]
## @param context: 本次操作的临时上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return Godot Error 结果码。
func rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:
	if not load_enabled or not _matches_section(previous_section):
		return ERR_INVALID_DATA
	return _rollback_section(previous_section.duplicate_section(), context)


## 创建带当前 provider 身份的 section。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param payload: 可持久化 section 载荷。
## [br]
## @param metadata: 可持久化 section 元数据。
## [br]
## @schema payload: Variant accepted by GFSavePersistedValueValidator.
## [br]
## @schema metadata: Dictionary with provider-defined persisted metadata.
## [br]
## @return 新 section。
func make_section(payload: Variant, metadata: Dictionary = {}) -> GFSaveSection:
	return GFSaveSection.new().configure(section_id, schema_version, payload, metadata)


## 接管纯数据并创建一次性 Snapshot。
##
## 该方法不深复制数据；成功返回后调用方必须放弃 payload、metadata 及全部嵌套
## alias。大型 Provider 应在 Operation slice 中逐步构造独占数据，再调用本方法。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 调用方移交的纯 Variant 载荷。
## [br]
## @param metadata: 调用方移交的纯 Variant 元数据。
## [br]
## @schema payload: Variant accepted by the Save persisted-value contract.
## [br]
## @schema metadata: Dictionary with provider-defined persisted metadata.
## [br]
## @return 可用 Snapshot。
func make_snapshot(
	payload: Variant,
	metadata: Dictionary = {}
) -> GFSaveSectionSnapshot:
	return GFSaveSectionSnapshot.take_ownership(
		section_id,
		schema_version,
		payload,
		metadata
	)


## 创建已经完成的小型 Snapshot Operation。
##
## 该便捷方法只适用于已经独占且可在固定成本内移交的数据；不得用它在 begin
## 回调中同步构造大型对象图。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 调用方移交的纯 Variant 载荷。
## [br]
## @param metadata: 调用方移交的纯 Variant 元数据。
## [br]
## @schema payload: Variant accepted by the Save persisted-value contract.
## [br]
## @schema metadata: Dictionary with provider-defined persisted metadata.
## [br]
## @return 已完成 Operation。
func make_completed_snapshot(
	payload: Variant,
	metadata: Dictionary = {}
) -> GFSaveSectionSnapshotOperation:
	return GFSaveSectionSnapshotOperation.completed(
		make_snapshot(payload, metadata)
	)


# --- 可重写钩子 / 虚方法 ---

## 创建协作式保存 Snapshot Operation。返回 null 表示失败。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _context: 本次操作的临时上下文。
## [br]
## @schema _context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return 自定义 Operation，或通过 `make_completed_snapshot()` 创建的小型 Operation。
func _begin_save_snapshot(
	_context: Dictionary = {}
) -> GFSaveSectionSnapshotOperation:
	return null


## 采集应用前回滚快照。
##
## 保存 Snapshot 与读取回滚属于不同一致性边界，因此不再隐式复用保存实现。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _context: 本次操作的临时上下文。
## [br]
## @schema _context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return 通过 `make_section()` 创建的当前版本 section。
func _capture_section(_context: Dictionary = {}) -> GFSaveSection:
	return null


## 应用当前版本 section。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param _section: 已校验的 section 副本。
## [br]
## @param _context: 本次操作的临时上下文。
## [br]
## @schema _context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return Godot Error 结果码。
func _apply_section(_section: GFSaveSection, _context: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE


## 恢复应用前 section。默认复用 `_apply_section()`。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param previous_section: 应用前 section 副本。
## [br]
## @param context: 本次操作的临时上下文。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @return Godot Error 结果码。
func _rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:
	return _apply_section(previous_section, context)


# --- 框架内部方法 ---

## 锁定影响文档身份和能力的定义字段。
##
## Provider 首次注册后保持锁定；项目需要修改定义时必须创建新的 Provider。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @return Provider 合法且已锁定时返回 true。
func lock_definition_for_framework() -> bool:
	if not GFVariantData.get_option_bool(validate_provider(), "ok", false):
		return false
	_definition_locked = true
	return true


# --- 私有/辅助方法 ---

func _normalize_section(section: GFSaveSection) -> GFSaveSection:
	if section == null:
		return null
	if section.get_section_id() != section_id or section.get_schema_version() != schema_version:
		return null
	if not GFVariantData.get_option_bool(section.validate_section(), "ok", false):
		return null
	return section.duplicate_section()

func _matches_section(section: GFSaveSection) -> bool:
	return (
		section != null
		and section.get_section_id() == section_id
		and section.get_schema_version() == schema_version
		and GFVariantData.get_option_bool(section.validate_section(), "ok", false)
	)
