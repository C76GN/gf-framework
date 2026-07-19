## GFSaveMigrationStep: 单向相邻版本迁移步骤协议。
##
## 空 section_id 表示文档级迁移；非空 section_id 表示单个分区迁移。
## 每个步骤只允许 `N -> N + 1`，以消除路径歧义并保持迁移链可审计。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 9.0.0
class_name GFSaveMigrationStep
extends Resource


# --- 导出变量 ---

## 稳定步骤 ID，用于诊断与审计。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var step_id: StringName = &""

## 步骤所属项目 schema ID。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var schema_id: StringName = &""

## 目标分区 ID；为空表示文档级迁移。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var section_id: StringName = &""

## 来源版本。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var from_version: int = 0

## 目标版本，必须等于 from_version + 1。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var to_version: int = 0


# --- 公共方法 ---

## 检查是否为文档级步骤。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return section_id 为空时返回 true。
func is_document_step() -> bool:
	return section_id == &""


## 校验步骤身份和版本边。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_step() -> Dictionary:
	var report: Dictionary = { "issues": [] }
	if step_id == &"":
		var _step_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_migration_step_id",
			"Migration step id is required.",
			{ "path": "step_id" }
		)
	if schema_id == &"":
		var _schema_id_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_migration_schema_id",
			"Migration schema id is required.",
			{ "path": "schema_id" }
		)
	if from_version <= 0 or to_version != from_version + 1:
		var _version_edge_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_migration_version_edge",
			"Migration steps must advance exactly one positive version.",
			{
				"path": "to_version",
				"from_version": from_version,
				"to_version": to_version,
			}
		)
	return GFValidationReportDictionary.finalize_report(report, "Save migration step", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
		"fallback_action": "Review the first save migration step issue.",
		"no_action": "Save migration step is valid.",
	})


## 描述步骤。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 步骤描述。
## [br]
## @schema return: Dictionary with step_id, schema_id, section_id, scope, from_version, and to_version.
func describe_step() -> Dictionary:
	return {
		"step_id": step_id,
		"schema_id": schema_id,
		"section_id": section_id,
		"scope": &"document" if is_document_step() else &"section",
		"from_version": from_version,
		"to_version": to_version,
	}


# --- 可重写钩子 / 虚方法 ---

## 执行文档级迁移。
##
## 输入是隔离副本；返回 null 表示失败。Registry 会强制保持 schema_id，
## 并在步骤成功后写入声明的目标版本。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param document: 当前文档副本。
## [br]
## @param _context: 调用方迁移上下文副本。
## [br]
## @schema _context: Dictionary with caller-defined migration context and registry-provided step fields.
## [br]
## @return 迁移后的文档；失败时返回 null。
func _migrate_document(
	document: GFSaveDocument,
	_context: Dictionary = {}
) -> GFSaveDocument:
	return document.duplicate_document() if document != null else null


## 执行分区级迁移。
##
## 输入是隔离副本；返回 null 表示失败。Registry 会强制保持 section_id，
## 并在步骤成功后写入声明的目标版本。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param section: 当前分区副本。
## [br]
## @param _context: 调用方迁移上下文副本。
## [br]
## @schema _context: Dictionary with caller-defined migration context and registry-provided step fields.
## [br]
## @return 迁移后的分区；失败时返回 null。
func _migrate_section(
	section: GFSaveSection,
	_context: Dictionary = {}
) -> GFSaveSection:
	return section.duplicate_section() if section != null else null


# --- 私有/辅助方法 ---

func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_migration_step_id": "Assign a stable migration step_id.",
		"missing_migration_schema_id": "Bind the step to one project schema_id.",
		"invalid_migration_version_edge": "Split migration logic into adjacent N to N+1 steps.",
	}
