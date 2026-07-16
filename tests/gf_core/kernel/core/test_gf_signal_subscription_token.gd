extends GutTest


# --- 测试用例 ---

func test_signal_subscription_token_disconnects_signal_on_cancel() -> void:
	var signal_source: SignalSource = SignalSource.new()
	var receiver: SignalReceiver = SignalReceiver.new()
	var subscription_token: GFSignalSubscriptionToken = GFSignalSubscriptionToken.new(
		signal_source.pinged,
		Callable(receiver, &"record_ping"),
		0,
		"test.pinged"
	)

	assert_true(subscription_token.is_active(), "有效 Signal 和 Callable 应创建活动订阅。")
	assert_eq(subscription_token.get_source_id(), signal_source.get_instance_id(), "订阅应记录 Signal 来源实例 ID。")
	assert_eq(subscription_token.get_signal_name(), &"pinged", "订阅应记录 Signal 名称。")

	signal_source.emit_pinged()
	assert_eq(receiver.ping_count, 1, "Signal 触发时应调用回调。")

	assert_true(subscription_token.cancel(), "首次 cancel 应断开活动订阅。")
	assert_false(subscription_token.cancel(), "重复 cancel 应保持幂等。")
	signal_source.emit_pinged()
	assert_eq(receiver.ping_count, 1, "cancel 后 Signal 不应继续调用回调。")


func test_owned_signal_subscription_cancels_signal_connection() -> void:
	var signal_source: SignalSource = SignalSource.new()
	var owner_node: Node = Node.new()
	add_child_autofree(owner_node)
	var receiver: SignalReceiver = SignalReceiver.new()
	var subscription_token: GFLifetimeSubscription = GFSignalSubscriptionToken.connect_owned(
		signal_source.value_changed,
		owner_node,
		Callable(receiver, &"record_value"),
		0,
		"test.value_changed"
	)

	assert_true(subscription_token.is_active(), "有效 owner 应创建活动生命周期订阅。")
	signal_source.emit_value_changed(3)
	assert_eq(receiver.value_total, 3, "owner-bound 订阅应转发 Signal。")

	assert_true(subscription_token.cancel(), "取消生命周期订阅应断开底层 Signal。")
	signal_source.emit_value_changed(7)
	assert_eq(receiver.value_total, 3, "取消后 owner-bound 订阅不应继续转发 Signal。")


func test_signal_subscription_rejects_invalid_inputs() -> void:
	var signal_source: SignalSource = SignalSource.new()
	var receiver: SignalReceiver = SignalReceiver.new()

	var invalid_signal_token: GFSignalSubscriptionToken = GFSignalSubscriptionToken.new(
		Signal(),
		Callable(receiver, &"record_ping")
	)
	var invalid_callback_token: GFSignalSubscriptionToken = GFSignalSubscriptionToken.new(
		signal_source.pinged,
		Callable()
	)
	var invalid_owner_token: GFLifetimeSubscription = GFSignalSubscriptionToken.connect_owned(
		signal_source.pinged,
		null,
		Callable(receiver, &"record_ping")
	)

	assert_false(invalid_signal_token.is_active(), "空 Signal 不应创建活动订阅。")
	assert_false(invalid_callback_token.is_active(), "空 Callable 不应创建活动订阅。")
	assert_false(invalid_owner_token.is_active(), "空 owner 不应创建活动生命周期订阅。")


# --- 内部类 ---

class SignalSource:
	extends RefCounted

	signal pinged
	signal value_changed(value: int)

	func emit_pinged() -> void:
		pinged.emit()

	func emit_value_changed(value: int) -> void:
		value_changed.emit(value)


class SignalReceiver:
	extends RefCounted

	var ping_count: int = 0
	var value_total: int = 0

	func record_ping() -> void:
		ping_count += 1

	func record_value(value: int) -> void:
		value_total += value
