@tool

# 编辑器贡献应用结果：在页面重建之间保留请求身份与实际安装结果。
extends RefCounted


# --- 私有变量 ---

## 最新请求或完成结果，所有对外读取返回深复制。
## [br]
## @api private
var _report: Dictionary = {
	"status": "pending",
	"generation": 0,
	"settings": {},
	"issues": [],
}

## 最近完整或部分安装的实际设置快照。
## [br]
## @api private
var _installed_settings: Dictionary = {}


# --- 框架内部方法 ---

## 登记最新请求；旧代完成不能覆盖新请求。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param generation: 刷新状态机请求代次。
## [br]
## @param settings: 本次请求对应的设置副本。
## [br]
## @schema settings: Dictionary of extension ProjectSettings names to saved values.
func request(generation: int, settings: Dictionary) -> void:
	_report = {
		"status": "pending",
		"generation": generation,
		"settings": settings.duplicate(true),
		"issues": [],
	}


## 核对应用前的设置身份，避免将扫描期间发生的新设置当成原请求。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param generation: 正在安装的代次。
## [br]
## @param settings: 即将安装的设置快照。
## [br]
## @schema settings: Dictionary of extension ProjectSettings names to values.
## [br]
## @return: 请求代次和设置完全匹配时返回 true。
func accepts(generation: int, settings: Dictionary) -> bool:
	return (
		_report["status"] == "pending"
		and _report["generation"] == generation
		and _report["settings"] == settings
	)


## 记录实际安装结果；有跳过或失败贡献时只能报告部分应用。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param generation: 完成代次。
## [br]
## @param settings: 安装时捕获的设置快照。
## [br]
## @param issues: 发现或安装阶段未能应用的原因。
## [br]
## @schema settings: Dictionary of extension ProjectSettings names to values.
func complete(
	generation: int,
	settings: Dictionary,
	issues: Array[String]
) -> void:
	_installed_settings = settings.duplicate(true)
	if not accepts(generation, settings):
		return
	_report["status"] = "applied" if issues.is_empty() else "partial"
	_report["issues"] = issues.duplicate()


## 记录本次未能执行安装的原因，不宣称已恢复旧贡献。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param generation: 失败代次。
## [br]
## @param reason: 非空失败原因。
func fail(generation: int, reason: String) -> void:
	if _report["generation"] != generation:
		return
	_report["status"] = "failed"
	_report["issues"] = [reason]


## 获取结果；设置已再次改变时显示待应用，保留上次结果供诊断。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param settings: 当前设置快照。
## [br]
## @schema settings: Dictionary of extension ProjectSettings names to values.
## [br]
## @return: 独立结果副本。
## [br]
## @schema return: Dictionary with status (pending/applied/partial/failed), generation: int, settings: Dictionary, installed_settings: Dictionary, issues: Array, and previous_status: String.
func get_report(settings: Dictionary) -> Dictionary:
	var result: Dictionary = _report.duplicate(true)
	result["installed_settings"] = _installed_settings.duplicate(true)
	result["previous_status"] = result["status"]
	if result["settings"] != settings:
		result["status"] = "pending"
		result["issues"] = ["settings_changed"]
	return result
