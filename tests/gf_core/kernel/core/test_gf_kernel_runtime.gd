# GFKernelRuntime 激活、静默与释放状态转换回归测试。
extends GutTest


# --- 测试用例 ---

func test_activation_requires_current_initialization_generation() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	var lifecycle_generation: int = runtime.begin_initialization()

	assert_eq(runtime.begin_initialization(), -1)
	assert_true(runtime.is_initializing())
	assert_false(runtime.begin_activation(lifecycle_generation + 1))
	assert_true(runtime.is_initializing())
	assert_true(runtime.begin_activation(lifecycle_generation))
	assert_true(runtime.is_activating())
	assert_eq(runtime.begin_initialization(), -1)
	assert_false(runtime.finish_activation(lifecycle_generation + 1))
	assert_true(runtime.is_activating())
	assert_true(runtime.finish_activation(lifecycle_generation))
	assert_true(runtime.is_ready())
	assert_eq(runtime.begin_initialization(), -1)
	assert_eq(runtime.get_state_name(), "ready")


func test_failed_runtime_requires_clear_failure_before_retry() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	var first_generation: int = runtime.begin_initialization()
	var first_transaction: Dictionary = runtime.begin_transaction("first")

	assert_true(runtime.fail_initialization(first_generation))
	assert_true(runtime.has_failed())
	assert_eq(runtime.begin_initialization(), -1)
	assert_true(runtime.is_transaction_failed(first_transaction))
	assert_true(runtime.is_transaction_invalidated(first_transaction))
	assert_true(runtime.clear_failure())
	assert_eq(runtime.get_state(), GFKernelRuntime.LifecycleState.NEW)
	assert_false(runtime.clear_failure())

	var retry_generation: int = runtime.begin_initialization()
	assert_gt(retry_generation, first_generation)
	assert_true(runtime.is_initializing())
	assert_true(runtime.begin_activation(retry_generation))
	assert_true(runtime.finish_activation(retry_generation))
	assert_true(runtime.is_ready())


func test_disposed_runtime_rejects_initialization_retry() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	assert_true(runtime.begin_dispose())
	assert_eq(runtime.begin_initialization(), -1)
	runtime.finish_dispose()

	assert_true(runtime.is_disposed())
	assert_eq(runtime.begin_initialization(), -1)
	assert_false(runtime.clear_failure())


func test_quiesce_preserves_generation_and_accepted_transactions_until_dispose() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	var lifecycle_generation: int = runtime.begin_initialization()
	assert_true(runtime.begin_activation(lifecycle_generation))
	assert_true(runtime.finish_activation(lifecycle_generation))
	var transaction: Dictionary = runtime.begin_transaction("accepted-before-quiesce")

	assert_true(runtime.begin_quiesce())
	assert_true(runtime.is_quiescing())
	assert_true(runtime.is_lifecycle_active())
	assert_eq(runtime.get_lifecycle_generation(), lifecycle_generation)
	assert_false(runtime.is_transaction_invalidated(transaction))
	assert_false(runtime.begin_quiesce())

	assert_true(runtime.begin_dispose())
	assert_true(runtime.is_disposing())
	assert_eq(runtime.get_lifecycle_generation(), lifecycle_generation + 1)
	assert_true(runtime.is_transaction_invalidated(transaction))
	runtime.finish_dispose()
	assert_true(runtime.is_disposed())
	assert_false(runtime.is_lifecycle_active())


func test_direct_dispose_is_a_safe_force_fallback_from_new_state() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	var initial_generation: int = runtime.get_lifecycle_generation()
	var transaction: Dictionary = runtime.begin_transaction("pre-init")

	assert_true(runtime.begin_dispose())
	assert_true(runtime.is_disposing())
	assert_eq(runtime.get_lifecycle_generation(), initial_generation + 1)
	assert_true(runtime.is_transaction_invalidated(transaction))
	assert_false(runtime.begin_dispose())
	runtime.finish_dispose()
	assert_true(runtime.is_disposed())
	assert_eq(runtime.get_state_name(), "disposed")


func test_finish_dispose_cannot_skip_disposing_state() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()

	runtime.finish_dispose()

	assert_eq(runtime.get_state(), GFKernelRuntime.LifecycleState.NEW)
	assert_false(runtime.is_disposed())


func test_activation_failure_advances_generation_and_invalidates_transactions() -> void:
	var runtime: GFKernelRuntime = GFKernelRuntime.new()
	var lifecycle_generation: int = runtime.begin_initialization()
	var transaction: Dictionary = runtime.begin_transaction("activation")
	assert_true(runtime.begin_activation(lifecycle_generation))

	assert_true(runtime.fail_initialization(lifecycle_generation))

	assert_true(runtime.has_failed())
	assert_eq(runtime.get_lifecycle_generation(), lifecycle_generation + 1)
	assert_true(runtime.is_transaction_invalidated(transaction))
	assert_true(runtime.is_transaction_failed(transaction))
