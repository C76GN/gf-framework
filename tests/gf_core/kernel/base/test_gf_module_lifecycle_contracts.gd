# GF 模块基类激活与静默协议回归测试。
extends GutTest


# --- 常量 ---

const GF_MODEL_SCRIPT = preload("res://addons/gf/kernel/base/gf_model.gd")
const GF_SYSTEM_SCRIPT = preload("res://addons/gf/kernel/base/gf_system.gd")
const GF_UTILITY_SCRIPT = preload("res://addons/gf/kernel/base/gf_utility.gd")


# --- 测试用例 ---

func test_base_modules_expose_isolated_typed_dependency_declarations() -> void:
	var model: GF_MODEL_SCRIPT = GF_MODEL_SCRIPT.new()
	var system_instance: GF_SYSTEM_SCRIPT = GF_SYSTEM_SCRIPT.new()
	var utility: GF_UTILITY_SCRIPT = GF_UTILITY_SCRIPT.new()

	_assert_empty_dependency_contract(model)
	_assert_empty_dependency_contract(system_instance)
	_assert_empty_dependency_contract(utility)


func test_model_base_lifecycle_completions_are_already_succeeded() -> void:
	var model: GF_MODEL_SCRIPT = GF_MODEL_SCRIPT.new()

	var activation: GFAsyncCompletion = _call_completion(
		model,
		&"begin_activation"
	)
	var quiesce: GFAsyncCompletion = _call_completion(
		model,
		&"begin_quiesce"
	)

	assert_not_null(activation)
	assert_not_null(quiesce)
	assert_not_same(activation, quiesce)
	assert_true(activation.is_completed())
	assert_true(activation.is_successful())
	assert_true(quiesce.is_completed())
	assert_true(quiesce.is_successful())


func test_system_base_lifecycle_completions_are_already_succeeded() -> void:
	var system_instance: GF_SYSTEM_SCRIPT = GF_SYSTEM_SCRIPT.new()

	var activation: GFAsyncCompletion = _call_completion(
		system_instance,
		&"begin_activation"
	)
	var quiesce: GFAsyncCompletion = _call_completion(
		system_instance,
		&"begin_quiesce"
	)

	assert_not_null(activation)
	assert_not_null(quiesce)
	assert_not_same(activation, quiesce)
	assert_true(activation.is_completed())
	assert_true(activation.is_successful())
	assert_true(quiesce.is_completed())
	assert_true(quiesce.is_successful())


func test_utility_base_lifecycle_completions_are_already_succeeded() -> void:
	var utility: GF_UTILITY_SCRIPT = GF_UTILITY_SCRIPT.new()

	var activation: GFAsyncCompletion = _call_completion(
		utility,
		&"begin_activation"
	)
	var quiesce: GFAsyncCompletion = _call_completion(
		utility,
		&"begin_quiesce"
	)

	assert_not_null(activation)
	assert_not_null(quiesce)
	assert_not_same(activation, quiesce)
	assert_true(activation.is_completed())
	assert_true(activation.is_successful())
	assert_true(quiesce.is_completed())
	assert_true(quiesce.is_successful())


# --- 辅助方法 ---

func _assert_empty_dependency_contract(module_instance: Object) -> void:
	var hooks: Array[StringName] = [
		&"get_required_models",
		&"get_required_systems",
		&"get_required_utilities",
		&"get_required_factories",
	]
	for hook: StringName in hooks:
		var declaration: Variant = module_instance.call(hook)
		assert_true(declaration is Array)
		if declaration is Array:
			var dependencies: Array = declaration
			assert_true(dependencies.is_typed())
			assert_true(dependencies.is_empty())
			dependencies.append(GF_MODEL_SCRIPT)
			var fresh_declaration: Variant = module_instance.call(hook)
			assert_true(fresh_declaration is Array)
			if fresh_declaration is Array:
				var fresh_dependencies: Array = fresh_declaration
				assert_true(
					fresh_dependencies.is_empty(),
					"基类每次必须返回新的依赖声明容器。"
				)


func _call_completion(
	module_instance: Object,
	hook: StringName
) -> GFAsyncCompletion:
	var result: Variant = module_instance.call(hook, GFAsyncScope.new())
	if result is GFAsyncCompletion:
		var completion: GFAsyncCompletion = result
		return completion
	return null
