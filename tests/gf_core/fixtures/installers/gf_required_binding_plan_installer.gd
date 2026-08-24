## 通过 required binding plan 制造确定性重复注册失败的 Installer 夹具。
extends GFInstaller


# --- 常量 ---

const RequiredBindingPlanUtilityFixture = preload(
	"res://tests/gf_core/fixtures/installers/required_binding_plan_utility_fixture.gd"
)
const RESULT_SETTING: String = "gf/test/required_binding_plan_result"
const CLEANUP_COUNT_SETTING: String = "gf/test/required_binding_plan_cleanup_count"


# --- 公共方法 ---

func install_bindings(binder: Variant, scope: GFAsyncScope) -> void:
	var _registered_cleanup: bool = scope.register_cleanup(
		Callable(self, &"_increment_cleanup_count")
	)
	if not binder is GFBinder:
		return

	var typed_binder: GFBinder = binder
	var plan: GFBindingPlan = typed_binder.create_required_plan()
	var _first_entry: GFBindingPlan = plan.require_singleton(
		&"installer.required.first",
		typed_binder.bind_utility(RequiredBindingPlanUtilityFixture)
	)
	var _duplicate_entry: GFBindingPlan = plan.require_singleton(
		&"installer.required.duplicate",
		typed_binder.bind_utility(RequiredBindingPlanUtilityFixture)
	)
	var result: GFBindingPlanResult = plan.execute(scope)
	ProjectSettings.set_setting(RESULT_SETTING, result.to_dict())


# --- 私有/辅助方法 ---

func _increment_cleanup_count() -> void:
	var count_value: Variant = ProjectSettings.get_setting(CLEANUP_COUNT_SETTING, 0)
	var count: int = count_value if count_value is int else 0
	ProjectSettings.set_setting(CLEANUP_COUNT_SETTING, count + 1)
