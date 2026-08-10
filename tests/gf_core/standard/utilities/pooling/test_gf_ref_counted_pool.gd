## 测试 GFRefCountedPool 的借出、归还、重置协议和容量限制。
extends GutTest


# --- 测试方法 ---

func test_ref_counted_pool_reuses_released_item() -> void:
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return PooledItem.new()
	)

	var first: PooledItem = _to_pooled_item(pool.acquire())
	assert_not_null(first, "factory 应创建 PooledItem。")
	if first == null:
		return
	first.value = 7
	var released: bool = pool.release(first)
	var second: PooledItem = _to_pooled_item(pool.acquire())
	assert_not_null(second, "归还后应能再次借出 PooledItem。")
	if second == null:
		return

	assert_true(released, "有效对象应能归还对象池。")
	assert_same(second, first, "归还后再次借出应复用同一对象。")
	assert_eq(second.value, 0, "归还时 reset_for_pool 应清理对象状态。")
	assert_eq(second.acquire_count, 2, "每次借出都应调用 acquire hook。")
	assert_eq(second.release_count, 1, "归还时应调用 release hook。")
	assert_eq(second.reset_count, 1, "归还时应调用 reset hook。")


func test_ref_counted_pool_uses_reset_callback() -> void:
	var pool: GFRefCountedPool = GFRefCountedPool.new(
		func() -> RefCounted:
			return CallbackResetItem.new(),
		func(pooled_item: RefCounted) -> void:
			var callback_item: CallbackResetItem = _to_callback_reset_item(pooled_item)
			if callback_item != null:
				callback_item.value = -1
	)

	var acquired_item: CallbackResetItem = _to_callback_reset_item(pool.acquire())
	assert_not_null(acquired_item, "factory 应创建 CallbackResetItem。")
	if acquired_item == null:
		return
	acquired_item.value = 5
	var released: bool = pool.release(acquired_item)
	var reused: CallbackResetItem = _to_callback_reset_item(pool.acquire())
	assert_not_null(reused, "归还后应能再次借出 CallbackResetItem。")
	if reused == null:
		return

	assert_true(released, "有效对象应能归还对象池。")
	assert_same(reused, acquired_item, "对象应被复用。")
	assert_eq(reused.value, -1, "reset_callback 应能清理不实现 hook 的对象。")


func test_ref_counted_pool_respects_max_available() -> void:
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return PooledItem.new()
	)
	pool.max_available = 1

	var first: RefCounted = pool.acquire()
	var second: RefCounted = pool.acquire()
	var first_released: bool = pool.release(first)
	var second_released: bool = pool.release(second)

	assert_true(first_released, "第一个 active 对象应能归还。")
	assert_true(second_released, "第二个 active 对象应能归还。")
	assert_eq(pool.available_count, 1, "可用对象数量不应超过 max_available。")
	assert_eq(pool.active_count, 0, "归还后不应保留 active 记录。")


func test_ref_counted_pool_prewarms_and_reports_snapshot() -> void:
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return PooledItem.new()
	)
	pool.max_available = 2

	var created: int = pool.prewarm(4)
	var snapshot: Dictionary = pool.get_debug_snapshot()

	assert_eq(created, 2, "预热应受 max_available 限制。")
	assert_eq(pool.available_count, 2, "预热后可用数量应正确。")
	assert_eq(GFVariantData.get_option_int(snapshot, "created_count"), 2, "调试快照应包含累计创建数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "available_count"), 2, "调试快照应包含可用数量。")


func test_ref_counted_pool_rejects_factory_returning_active_item() -> void:
	var shared: PooledItem = PooledItem.new()
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return shared
	)

	var first: PooledItem = _to_pooled_item(pool.acquire())
	var second: RefCounted = pool.acquire()

	assert_same(first, shared, "首次借出应接受未追踪对象。")
	assert_null(second, "factory 返回已借出对象时不应重复借出同一身份。")
	assert_eq(pool.active_count, 1, "重复借出被拒绝后 active 计数应保持唯一。")
	assert_push_error("[GFRefCountedPool] acquire 失败：factory 返回了已被当前池追踪的对象，已拒绝重复借出。")


func test_ref_counted_pool_prewarm_rejects_duplicate_available_item() -> void:
	var shared: PooledItem = PooledItem.new()
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return shared
	)

	var created: int = pool.prewarm(2)

	assert_eq(created, 1, "prewarm 遇到重复可用对象时应停止继续加入。")
	assert_eq(pool.available_count, 1, "重复对象不应以多个引用进入可用池。")
	assert_eq(GFVariantData.get_option_int(pool.get_debug_snapshot(), "created_count"), 1, "被拒绝的重复对象不应计入已接受创建数。")
	assert_push_error("[GFRefCountedPool] prewarm 失败：factory 返回了已被当前池追踪的对象，已停止预热。")


func test_ref_counted_pool_rejects_invalid_factory() -> void:
	var pool: GFRefCountedPool = GFRefCountedPool.new()

	var acquired_item: RefCounted = pool.acquire()

	assert_null(acquired_item, "无效 factory 不应创建对象。")
	assert_push_error("[GFRefCountedPool] factory 无效，无法创建对象。")


func test_ref_counted_pool_acquire_hook_release_wins_without_double_loan() -> void:
	var item: ReentrantPooledItem = ReentrantPooledItem.new()
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return item
	)
	item.pool = pool
	item.release_on_acquire = true

	var cancelled_acquire: RefCounted = pool.acquire()

	assert_null(cancelled_acquire, "acquire hook 已归还对象时，外层 acquire 不得再发布同一借用。")
	assert_true(item.acquire_release_result, "acquire hook 的归还应成功并成为最终 mutation。")
	assert_eq(pool.active_count, 0, "已在 hook 中归还的对象不应保持 active。")
	assert_eq(pool.available_count, 1, "已在 hook 中归还的对象应恰好进入 available 一次。")

	item.release_on_acquire = false
	var next_acquire: RefCounted = pool.acquire()
	assert_same(next_acquire, item, "下一次 acquire 可以安全复用已归还对象。")
	assert_eq(pool.active_count, 1, "复用后只能存在一个 active borrower。")
	assert_eq(pool.available_count, 0, "active 对象不能同时留在 available。")
	var _released: bool = pool.release(next_acquire)
	item.pool = null
	pool.factory = Callable()
	pool.reset_pool()


func test_ref_counted_pool_release_hook_reentry_is_rejected_without_recursion() -> void:
	var item: ReentrantPooledItem = ReentrantPooledItem.new()
	var pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
		return item
	)
	item.pool = pool
	var acquired: RefCounted = pool.acquire()
	item.release_on_release = true

	var released: bool = pool.release(acquired)

	assert_true(released, "外层 release 应成功。")
	assert_false(item.release_reentry_result, "release hook 的同项递归 release 必须被稳定拒绝。")
	assert_eq(item.release_count, 1, "release hook 只能执行一次。")
	assert_eq(pool.active_count, 0, "release 完成后不应保留 active。")
	assert_eq(pool.available_count, 1, "对象只能进入 available 一次。")
	assert_push_warning("[GFRefCountedPool] release 收到未由当前池借出的对象，已忽略。")
	item.pool = null
	pool.factory = Callable()
	pool.reset_pool()


func test_ref_counted_pool_reset_callback_cannot_reborrow_releasing_item() -> void:
	var item: PooledItem = PooledItem.new()
	var reentrant_acquired: Array[RefCounted] = [null]
	var pool_holder: Array[GFRefCountedPool] = [null]
	var pool: GFRefCountedPool = GFRefCountedPool.new(
		func() -> RefCounted:
			return item,
		func(_pooled_item: RefCounted) -> void:
			reentrant_acquired[0] = pool_holder[0].acquire()
	)
	pool_holder[0] = pool
	var acquired: RefCounted = pool.acquire()

	var released: bool = pool.release(acquired)

	assert_true(released, "外层 release 应成功。")
	assert_null(reentrant_acquired[0], "reset callback 不得经 factory 重借正在 release 的同一对象。")
	assert_eq(pool.active_count, 0, "release callback 返回后不应保留幽灵 active borrow。")
	assert_eq(pool.available_count, 1, "releasing item 应只进入 available。")
	assert_push_error("[GFRefCountedPool] acquire 失败：factory 返回了已被当前池追踪的对象，已拒绝重复借出。")
	pool.reset_callback = Callable()
	pool.factory = Callable()
	pool.reset_pool()
	reentrant_acquired[0] = null
	pool_holder[0] = null


func _to_pooled_item(value: RefCounted) -> PooledItem:
	if value is PooledItem:
		var pooled_item: PooledItem = value
		return pooled_item
	return null


func _to_callback_reset_item(value: RefCounted) -> CallbackResetItem:
	if value is CallbackResetItem:
		var callback_item: CallbackResetItem = value
		return callback_item
	return null


# --- 辅助类型 ---

class PooledItem extends RefCounted:
	var value: int = 0
	var acquire_count: int = 0
	var release_count: int = 0
	var reset_count: int = 0

	func on_gf_pool_acquire() -> void:
		acquire_count += 1

	func on_gf_pool_release() -> void:
		release_count += 1

	func reset_for_pool() -> void:
		value = 0
		reset_count += 1


class CallbackResetItem extends RefCounted:
	var value: int = 0


class ReentrantPooledItem extends RefCounted:
	var pool: GFRefCountedPool
	var release_on_acquire: bool = false
	var release_on_release: bool = false
	var acquire_release_result: bool = false
	var release_reentry_result: bool = true
	var release_count: int = 0

	func on_gf_pool_acquire() -> void:
		if release_on_acquire:
			acquire_release_result = pool.release(self)

	func on_gf_pool_release() -> void:
		release_count += 1
		if release_on_release:
			release_reentry_result = pool.release(self)
