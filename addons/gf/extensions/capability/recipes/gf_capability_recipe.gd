## GFCapabilityRecipe: 可复用的能力组合资源。
##
## Recipe 用于把一组通用 Capability 条目批量应用到 receiver。它只描述组合结构，
## 不规定实体类型、玩法规则、UI 或存档字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFCapabilityRecipe
extends Resource


# --- 导出变量 ---

## Recipe 稳定标识。为空时可由项目层按资源路径管理。
## [br]
## @api public
@export var recipe_id: StringName = &""

## Recipe 展示名，仅供编辑器和项目工具显示。
## [br]
## @api public
@export var display_name: String = ""

## 能力条目列表。
## [br]
## @api public
@export var entries: Array[GFCapabilityRecipeEntry] = []

## 应用 Recipe 时附加到 receiver 的能力查询分组。
## [br]
## @api public
@export var groups: Array[StringName] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取展示名。
## [br]
## @api public
## [br]
## @return: 展示名。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if recipe_id != &"":
		return String(recipe_id)
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().to_pascal_case()
	return "Capability Recipe"


## 描述 Recipe。
## [br]
## @api public
## [br]
## @return: Recipe 描述字典。
## [br]
## @schema return: 包含 recipe_id、display_name、entry_count、entries、groups 和 metadata 字段的 Dictionary；entries 为各条目的 describe_entry() 快照数组。
func describe_recipe() -> Dictionary:
	var entry_descriptions: Array[Dictionary] = []
	for entry: GFCapabilityRecipeEntry in entries:
		if entry != null:
			entry_descriptions.append(entry.describe_entry())

	return {
		"recipe_id": recipe_id,
		"display_name": get_display_name(),
		"entry_count": entry_descriptions.size(),
		"entries": entry_descriptions,
		"groups": groups.duplicate(),
		"metadata": metadata.duplicate(true),
	}


## 校验 Recipe 结构。
## [br]
## @api public
## [br]
## @return: 校验报告对象。
func validate_recipe_report() -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("Capability recipe", {
		"recipe_id": String(recipe_id),
		"resource_path": resource_path,
	})

	_validate_groups(report)
	_validate_entries(report)
	return report


## 校验 Recipe 结构并导出为 Dictionary。
## [br]
## @api public
## [br]
## @return: 校验报告。
## [br]
## @schema return: GFValidationReport.to_dict() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action 和 entry_count 等字段。
func validate_recipe() -> Dictionary:
	var report: GFValidationReport = validate_recipe_report()
	return report.to_dict(
		{
			"recipe_id": recipe_id,
			"entry_count": entries.size(),
			"group_count": groups.size(),
		},
		{
			"include_subject": false,
			"include_metadata": false,
			"include_info_count": false,
			"include_issue_count": false,
			"next_actions": _get_next_actions(),
			"fallback_action": "Review the first reported capability recipe issue before applying it.",
		}
	)


# --- 私有/辅助方法 ---

func _validate_groups(report: GFValidationReport) -> void:
	var seen_groups: Dictionary = {}
	for index: int in range(groups.size()):
		var group_name: StringName = groups[index]
		if group_name == &"":
			_add_recipe_issue(
				report,
				GFValidationIssue.Severity.WARNING,
				&"empty_group",
				"Recipe contains an empty group name.",
				index,
				_make_group_path(index),
				{ "group_index": index }
			)
			continue
		if seen_groups.has(group_name):
			_add_recipe_issue(
				report,
				GFValidationIssue.Severity.WARNING,
				&"duplicate_group",
				"Recipe contains duplicate group names.",
				group_name,
				_make_group_path(index),
				{
					"group_index": index,
					"group_name": String(group_name),
				}
			)
		seen_groups[group_name] = true


func _validate_entries(report: GFValidationReport) -> void:
	var seen_keys: Dictionary = {}
	for index: int in range(entries.size()):
		var entry: GFCapabilityRecipeEntry = entries[index]
		if entry == null:
			_add_recipe_issue(
				report,
				GFValidationIssue.Severity.WARNING,
				&"null_entry",
				"Recipe contains a null entry.",
				index,
				_make_entry_path(index),
				{ "entry_index": index }
			)
			continue
		if not entry.is_valid_entry():
			_add_recipe_issue(
				report,
				GFValidationIssue.Severity.ERROR,
				&"invalid_entry",
				"Recipe entry requires capability_type or scene.",
				index,
				_make_entry_path(index),
				{ "entry_index": index }
			)
			continue

		var key: String = _get_entry_key(entry)
		if not key.is_empty() and seen_keys.has(key):
			_add_recipe_issue(
				report,
				GFValidationIssue.Severity.WARNING,
				&"duplicate_entry",
				"Recipe contains duplicate capability entries.",
				key,
				_make_entry_path(index),
				{
					"entry_index": index,
					"entry_key": key,
				}
			)
		seen_keys[key] = true


func _get_entry_key(entry: GFCapabilityRecipeEntry) -> String:
	if entry == null:
		return ""
	if entry.capability_type != null:
		var global_name: StringName = entry.capability_type.get_global_name()
		if global_name != &"":
			return String(global_name)
		if not entry.capability_type.resource_path.is_empty():
			return entry.capability_type.resource_path
	if entry.scene != null:
		return entry.scene.resource_path
	return ""


func _make_entry_path(index: int) -> String:
	return "entries[%d]" % index


func _make_group_path(index: int) -> String:
	return "groups[%d]" % index


func _add_recipe_issue(
	report: GFValidationReport,
	severity: GFValidationIssue.Severity,
	kind: StringName,
	message: String,
	key: Variant,
	path: String,
	issue_metadata: Dictionary = {}
) -> void:
	var metadata_copy: Dictionary = issue_metadata.duplicate(true)
	metadata_copy["recipe_id"] = String(recipe_id)
	var issue: RefCounted = report.add_issue(GFValidationIssue.new(
		severity,
		kind,
		message,
		key,
		path,
		metadata_copy
	))
	if issue is GFValidationIssue:
		var validation_issue: GFValidationIssue = issue
		validation_issue.source_path = resource_path


func _get_next_actions() -> Dictionary:
	return {
		"null_entry": "Remove the null Recipe entry or replace it with a valid GFCapabilityRecipeEntry.",
		"invalid_entry": "Set capability_type or scene on every Recipe entry.",
		"duplicate_entry": "Remove duplicate entries unless the duplication is intentional metadata for project tools.",
		"empty_group": "Remove empty Recipe group names.",
		"duplicate_group": "Remove duplicate Recipe group names unless repeated metadata is intentional.",
	}
