## Required binding plan Installer 回滚测试使用的 Utility。
extends GFUtility


# --- 常量 ---

const DISPOSE_COUNT_SETTING: String = "gf/test/required_binding_plan_utility_dispose_count"


# --- GF 生命周期方法 ---

func dispose() -> void:
	var count_value: Variant = ProjectSettings.get_setting(DISPOSE_COUNT_SETTING, 0)
	var count: int = count_value if count_value is int else 0
	ProjectSettings.set_setting(DISPOSE_COUNT_SETTING, count + 1)
