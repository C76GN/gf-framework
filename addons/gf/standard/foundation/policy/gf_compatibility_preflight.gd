## GFCompatibilityPreflight: 通用兼容性预检报告构建器。
##
## 将版本、平台、功能、包和外部报告合并为标准校验报告。它只做显式声明的
## 预检，不安装包、不下载资源、不执行代码，也不把项目发布策略写入框架。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFCompatibilityPreflight
extends RefCounted


# --- 常量 ---

## 任一候选满足即可。
## [br]
## @api public
## [br]
## @since 7.0.0
const MATCH_ANY: StringName = &"any"

## 全部候选都必须满足。
## [br]
## @api public
## [br]
## @since 7.0.0
const MATCH_ALL: StringName = &"all"

const _DEFAULT_SUBJECT: String = "Compatibility preflight"


# --- 公共变量 ---

## 报告主题。
## [br]
## @api public
## [br]
## @since 7.0.0
var subject: String = _DEFAULT_SUBJECT

## 预检目标 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_id: StringName = &""

## 预检目标版本。
## [br]
## @api public
## [br]
## @since 7.0.0
var target_version: String = ""

## 当前使用的 Profile。
## [br]
## @api public
## [br]
## @since 7.0.0
var profile: GFCompatibilityProfile = null

## 预检检查记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema checks: Array[Dictionary]，每项包含 check_id、kind、ok、expected_value、actual_value 和 metadata。
var checks: Array[Dictionary] = []

## 预检问题。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema issues: Array[Dictionary] GFValidationReportDictionary-compatible issue payloads.
var issues: Array[Dictionary] = []

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary caller-defined preflight metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置预检构建器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_subject: 报告主题。
## [br]
## @param p_profile: 兼容性 Profile。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined preflight metadata.
## [br]
## @return 当前构建器。
func configure(
	p_subject: String = _DEFAULT_SUBJECT,
	p_profile: GFCompatibilityProfile = null,
	p_metadata: Dictionary = {}
) -> GFCompatibilityPreflight:
	subject = p_subject if not p_subject.strip_edges().is_empty() else _DEFAULT_SUBJECT
	profile = p_profile
	metadata = p_metadata.duplicate(true)
	return self


## 清空检查和问题。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	target_id = &""
	target_version = ""
	checks.clear()
	issues.clear()
	metadata.clear()


## 设置 Profile。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_profile: 兼容性 Profile。
## [br]
## @return 当前构建器。
func set_profile(p_profile: GFCompatibilityProfile) -> GFCompatibilityPreflight:
	profile = p_profile
	return self


## 要求 Godot 版本满足范围。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param minimum_version: 最低版本；为空时不检查。
## [br]
## @param maximum_version_exclusive: 排他最高版本；为空时不检查。
## [br]
## @param options: 检查选项，支持 check_id、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func require_godot_version(
	minimum_version: String = "",
	maximum_version_exclusive: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var actual_version: String = _get_profile_godot_version()
	return _require_version_range(
		&"godot_version",
		actual_version,
		minimum_version,
		maximum_version_exclusive,
		options
	)


## 要求 GF 框架版本满足范围。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param minimum_version: 最低版本；为空时不检查。
## [br]
## @param maximum_version_exclusive: 排他最高版本；为空时不检查。
## [br]
## @param options: 检查选项，支持 check_id、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func require_framework_version(
	minimum_version: String = "",
	maximum_version_exclusive: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var actual_version: String = _get_profile_framework_version()
	return _require_version_range(
		&"framework_version",
		actual_version,
		minimum_version,
		maximum_version_exclusive,
		options
	)


## 要求平台能力满足候选集合。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param required_platforms: 平台标识候选。
## [br]
## @param mode: MATCH_ANY 或 MATCH_ALL。
## [br]
## @param options: 检查选项，支持 check_id、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func require_platforms(
	required_platforms: PackedStringArray,
	mode: StringName = MATCH_ANY,
	options: Dictionary = {}
) -> Dictionary:
	return _require_string_set(&"platform", _get_profile_platforms(), required_platforms, mode, options)


## 要求功能能力满足候选集合。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param required_features: 功能能力标识候选。
## [br]
## @param mode: MATCH_ANY 或 MATCH_ALL。
## [br]
## @param options: 检查选项，支持 check_id、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func require_features(
	required_features: PackedStringArray,
	mode: StringName = MATCH_ALL,
	options: Dictionary = {}
) -> Dictionary:
	return _require_string_set(&"feature", _get_profile_features(), required_features, mode, options)


## 要求包存在并可选满足版本范围。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param package_id: 包 ID。
## [br]
## @param minimum_version: 最低版本；为空时不检查。
## [br]
## @param maximum_version_exclusive: 排他最高版本；为空时不检查。
## [br]
## @param options: 检查选项，支持 check_id、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func require_package(
	package_id: StringName,
	minimum_version: String = "",
	maximum_version_exclusive: String = "",
	options: Dictionary = {}
) -> Dictionary:
	var package_entry: Dictionary = _get_profile_package(package_id)
	if package_entry.is_empty():
		var check: Dictionary = _append_check(
			GFVariantData.get_option_string_name(options, "check_id", StringName("package:%s" % String(package_id))),
			&"package",
			false,
			String(package_id),
			"",
			options
		)
		_append_issue(
			GFVariantData.get_option_string_name(options, "severity", &"error"),
			&"package_missing",
			"required package is missing",
			{
				"package_id": package_id,
				"expected_value": String(package_id),
			}
		)
		return check

	var minimum: String = minimum_version.strip_edges()
	var maximum: String = maximum_version_exclusive.strip_edges()
	if minimum.is_empty() and maximum.is_empty():
		return _append_check(
			GFVariantData.get_option_string_name(options, "check_id", StringName("package:%s" % String(package_id))),
			&"package",
			true,
			String(package_id),
			String(package_id),
			GFVariantData.merge_dictionary(options, {
				"package_id": package_id,
			}, true)
		)

	var actual_version: String = GFVariantData.get_option_string(package_entry, "version")
	var version_check: Dictionary = _require_version_range(
		&"package_version",
		actual_version,
		minimum_version,
		maximum_version_exclusive,
		GFVariantData.merge_dictionary(options, {
			"check_id": GFVariantData.get_option_string_name(options, "check_id", StringName("package:%s" % String(package_id))),
			"package_id": package_id,
		}, true)
	)
	return version_check


## 添加自定义检查结果。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param check_id: 检查 ID。
## [br]
## @param ok: 检查是否通过。
## [br]
## @param options: 检查选项，支持 kind、expected_value、actual_value、issue_kind、message、severity 和 metadata。
## [br]
## @schema options: Dictionary check metadata.
## [br]
## @return 检查记录副本。
## [br]
## @schema return: Dictionary check record.
func add_check(check_id: StringName, ok: bool, options: Dictionary = {}) -> Dictionary:
	var check: Dictionary = _append_check(
		check_id,
		GFVariantData.get_option_string_name(options, "kind", &"custom"),
		ok,
		GFVariantData.get_option_value(options, "expected_value", null),
		GFVariantData.get_option_value(options, "actual_value", null),
		options
	)
	if not ok:
		_append_issue(
			GFVariantData.get_option_string_name(options, "severity", &"error"),
			GFVariantData.get_option_string_name(options, "issue_kind", &"custom_check_failed"),
			GFVariantData.get_option_string(options, "message", "custom compatibility check failed"),
			{
				"check_id": check_id,
				"expected_value": GFVariantData.get_option_value(options, "expected_value", null),
				"actual_value": GFVariantData.get_option_value(options, "actual_value", null),
			}
		)
	return check


## 合并另一份校验报告的问题。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param report: GFValidationReportDictionary 兼容报告。
## [br]
## @param options: 合并选项，支持 component、phase 和 issue_kind。
## [br]
## @schema report: Dictionary report payload.
## [br]
## @schema options: Dictionary merge metadata.
## [br]
## @return 当前构建器。
func merge_report(report: Dictionary, options: Dictionary = {}) -> GFCompatibilityPreflight:
	var component: StringName = GFVariantData.get_option_string_name(options, "component")
	var phase: StringName = GFVariantData.get_option_string_name(options, "phase")
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFValidationReportDictionary.issue_to_dict(issue_value)
		if issue.is_empty():
			continue
		if component != &"":
			issue["component"] = component
		if phase != &"":
			issue["phase"] = phase
		if options.has("issue_kind"):
			issue["kind"] = String(GFVariantData.get_option_string_name(options, "issue_kind"))
		issues.append(issue)
	var ok: bool = GFVariantData.get_option_bool(report, "ok", true)
	var _check: Dictionary = _append_check(
		GFVariantData.get_option_string_name(options, "check_id", GFVariantData.get_option_string_name(report, "subject", &"external_report")),
		&"external_report",
		ok,
		"ok",
		ok,
		{
			"metadata": {
				"summary": GFVariantData.get_option_string(report, "summary"),
				"issue_count": GFVariantData.get_option_int(report, "issue_count"),
			},
		}
	)
	return self


## 获取预检报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 报告选项，支持 subject、fallback_action、no_action 和 warnings_as_errors。
## [br]
## @schema options: Dictionary report finalization options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, profile, checks, issues, summary, and next_action.
func get_report(options: Dictionary = {}) -> Dictionary:
	var report_subject: String = GFVariantData.get_option_string(options, "subject", subject)
	var report: Dictionary = {
		"subject": report_subject,
		"target_id": target_id,
		"target_version": target_version,
		"profile": profile.to_dict() if profile != null else {},
		"check_count": checks.size(),
		"checks": _copy_entries(checks),
		"issues": _copy_entries(issues),
		"metadata": metadata.duplicate(true),
	}
	return GFValidationReportDictionary.finalize_report(report, report_subject, {
		"fallback_action": GFVariantData.get_option_string(options, "fallback_action", "Review the first compatibility preflight issue."),
		"no_action": GFVariantData.get_option_string(options, "no_action", "Compatibility preflight is healthy."),
		"warnings_as_errors": GFVariantData.get_option_bool(options, "warnings_as_errors", false),
	})


# --- 私有/辅助方法 ---

func _require_version_range(
	kind: StringName,
	actual_version: String,
	minimum_version: String,
	maximum_version_exclusive: String,
	options: Dictionary
) -> Dictionary:
	var minimum: String = minimum_version.strip_edges()
	var maximum: String = maximum_version_exclusive.strip_edges()
	var ok: bool = true
	var issue_kind: StringName = &""
	var message: String = ""
	if actual_version.strip_edges().is_empty():
		ok = false
		issue_kind = StringName("%s_missing" % String(kind))
		message = "%s is missing" % String(kind)
	elif not minimum.is_empty() and _compare_versions(actual_version, minimum) < 0:
		ok = false
		issue_kind = StringName("%s_below_minimum" % String(kind))
		message = "%s is below the required minimum" % String(kind)
	elif not maximum.is_empty() and _compare_versions(actual_version, maximum) >= 0:
		ok = false
		issue_kind = StringName("%s_at_or_above_maximum" % String(kind))
		message = "%s is at or above the exclusive maximum" % String(kind)

	var expected_value: Dictionary = {
		"minimum": minimum,
		"maximum_exclusive": maximum,
	}
	var check: Dictionary = _append_check(
		GFVariantData.get_option_string_name(options, "check_id", kind),
		kind,
		ok,
		expected_value,
		actual_version,
		options
	)
	if not ok:
		var fields: Dictionary = {
			"expected_value": expected_value,
			"actual_value": actual_version,
		}
		if options.has("package_id"):
			fields["package_id"] = GFVariantData.get_option_string_name(options, "package_id")
		_append_issue(
			GFVariantData.get_option_string_name(options, "severity", &"error"),
			issue_kind,
			message,
			fields
		)
	return check


func _require_string_set(
	kind: StringName,
	actual_values: PackedStringArray,
	required_values: PackedStringArray,
	mode: StringName,
	options: Dictionary
) -> Dictionary:
	var required: PackedStringArray = _normalize_string_set(required_values)
	var actual: PackedStringArray = _normalize_string_set(actual_values)
	var ok: bool = true
	if mode == MATCH_ANY:
		ok = _has_any(actual, required)
	else:
		ok = _has_all(actual, required)

	var check: Dictionary = _append_check(
		GFVariantData.get_option_string_name(options, "check_id", kind),
		kind,
		ok,
		required,
		actual,
		options
	)
	if not ok:
		_append_issue(
			GFVariantData.get_option_string_name(options, "severity", &"error"),
			StringName("%s_missing" % String(kind)),
			"%s requirement is not satisfied" % String(kind),
			{
				"expected_value": required,
				"actual_value": actual,
				"match_mode": mode,
			}
		)
	return check


func _append_check(
	check_id: StringName,
	kind: StringName,
	ok: bool,
	expected_value: Variant,
	actual_value: Variant,
	options: Dictionary
) -> Dictionary:
	var check: Dictionary = {
		"check_id": check_id,
		"kind": kind,
		"ok": ok,
		"expected_value": GFVariantData.duplicate_variant(expected_value),
		"actual_value": GFVariantData.duplicate_variant(actual_value),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	checks.append(check)
	return check.duplicate(true)


func _append_issue(severity: StringName, kind: StringName, message: String, fields: Dictionary) -> void:
	var report: Dictionary = { "issues": [] }
	var issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		severity,
		kind,
		message,
		fields
	)
	issues.append(issue)


func _get_profile_godot_version() -> String:
	return profile.godot_version if profile != null else ""


func _get_profile_framework_version() -> String:
	return profile.framework_version if profile != null else ""


func _get_profile_platforms() -> PackedStringArray:
	return profile.platforms.duplicate() if profile != null else PackedStringArray()


func _get_profile_features() -> PackedStringArray:
	return profile.features.duplicate() if profile != null else PackedStringArray()


func _get_profile_package(package_id: StringName) -> Dictionary:
	return profile.get_package(package_id) if profile != null else {}


static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(entry.duplicate(true))
	return result


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _has_any(actual: PackedStringArray, required: PackedStringArray) -> bool:
	if required.is_empty():
		return true
	for item: String in required:
		if actual.has(item):
			return true
	return false


static func _has_all(actual: PackedStringArray, required: PackedStringArray) -> bool:
	for item: String in required:
		if not actual.has(item):
			return false
	return true


static func _compare_versions(left: String, right: String) -> int:
	var left_version: Dictionary = _parse_semver(left)
	var right_version: Dictionary = _parse_semver(right)
	var left_numbers: Array[int] = GFVariantData.get_option_value(left_version, "numbers", [0, 0, 0])
	var right_numbers: Array[int] = GFVariantData.get_option_value(right_version, "numbers", [0, 0, 0])
	for index: int in range(3):
		if left_numbers[index] < right_numbers[index]:
			return -1
		if left_numbers[index] > right_numbers[index]:
			return 1
	return _compare_prerelease(
		GFVariantData.get_option_packed_string_array(left_version, "prerelease"),
		GFVariantData.get_option_packed_string_array(right_version, "prerelease")
	)


static func _parse_semver(version: String) -> Dictionary:
	var normalized: String = version.strip_edges()
	var build_index: int = normalized.find("+")
	if build_index >= 0:
		normalized = normalized.substr(0, build_index)

	var prerelease: PackedStringArray = PackedStringArray()
	var core: String = normalized
	var prerelease_index: int = normalized.find("-")
	if prerelease_index >= 0:
		core = normalized.substr(0, prerelease_index)
		prerelease = normalized.substr(prerelease_index + 1).split(".")
	return {
		"numbers": _parse_version_numbers(core),
		"prerelease": prerelease,
	}


static func _compare_prerelease(left: PackedStringArray, right: PackedStringArray) -> int:
	if left.is_empty() and right.is_empty():
		return 0
	if left.is_empty():
		return 1
	if right.is_empty():
		return -1

	var max_count: int = maxi(left.size(), right.size())
	for index: int in range(max_count):
		if index >= left.size():
			return -1
		if index >= right.size():
			return 1
		var left_part: String = left[index]
		var right_part: String = right[index]
		if left_part == right_part:
			continue
		var left_numeric: bool = _is_numeric_identifier(left_part)
		var right_numeric: bool = _is_numeric_identifier(right_part)
		if left_numeric and right_numeric:
			var left_number: int = int(left_part)
			var right_number: int = int(right_part)
			if left_number < right_number:
				return -1
			if left_number > right_number:
				return 1
			continue
		if left_numeric != right_numeric:
			return -1 if left_numeric else 1
		return -1 if left_part < right_part else 1
	return 0


static func _parse_version_numbers(version: String) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	var parts: PackedStringArray = version.strip_edges().split(".")
	for index: int in range(mini(parts.size(), 3)):
		result[index] = _leading_int(parts[index])
	return result


static func _leading_int(value: String) -> int:
	var digits: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if not "0123456789".contains(character):
			break
		digits += character
	return int(digits) if not digits.is_empty() else 0


static func _is_numeric_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in range(value.length()):
		if not "0123456789".contains(value.substr(index, 1)):
			return false
	return true
