## Required binding plan identity 测试使用的不相关 Utility。
extends GFUtility


# --- 公共变量 ---

var dispose_count: int = 0
var hostile_architecture: GFArchitecture = null
var reentrant_registration_attempts: int = 0
var reentrant_registration_result: bool = false


# --- GF 生命周期方法 ---

func dispose() -> void:
	dispose_count += 1
	if hostile_architecture == null or reentrant_registration_attempts > 0:
		return
	reentrant_registration_attempts += 1
	var script_value: Variant = get_script()
	if not script_value is Script:
		return
	var script_cls: Script = script_value
	var registration_error: Error = (
		hostile_architecture.register_utility_instance_for_required_plan_for_framework(
			script_cls,
			self,
			false
		)
	)
	reentrant_registration_result = registration_error == OK
