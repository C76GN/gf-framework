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


func test_signal_subscription_token_does_not_adopt_preexisting_connection() -> void:
	var signal_source: SignalSource = SignalSource.new()
	var receiver: SignalReceiver = SignalReceiver.new()
	var callback: Callable = Callable(receiver, &"record_ping")
	var connect_error: Error = signal_source.pinged.connect(callback) as Error

	assert_eq(connect_error, OK, "测试前置连接应成功。")
	var subscription_token: GFSignalSubscriptionToken = GFSignalSubscriptionToken.new(
		signal_source.pinged,
		callback,
		0,
		"test.preexisting_pinged"
	)

	assert_false(subscription_token.is_active(), "重复连接不应创建拥有旧连接的活动 token。")
	assert_false(subscription_token.cancel(), "非活动 token 不应取消任何连接。")
	assert_true(signal_source.pinged.is_connected(callback), "原始连接必须继续由原创建方持有。")
	signal_source.emit_pinged()
	assert_eq(receiver.ping_count, 1, "取消新 token 后原始连接仍应正常派发。")
	if signal_source.pinged.is_connected(callback):
		signal_source.pinged.disconnect(callback)


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


func test_ref_counted_owner_release_requires_explicit_signal_cancellation() -> void:
	var signal_source: SignalSource = SignalSource.new()
	var lifecycle_owner: RefCounted = RefCounted.new()
	var receiver: SignalReceiver = SignalReceiver.new()
	var subscription_token: GFLifetimeSubscription = GFSignalSubscriptionToken.connect_owned(
		signal_source.pinged,
		lifecycle_owner,
		Callable(receiver, &"record_ping")
	)

	lifecycle_owner = null

	assert_true(subscription_token.owner_is_released(), "普通 Object owner 应通过弱引用报告已释放。")
	assert_false(subscription_token.is_active(), "owner 释放后生命周期句柄应报告非活动。")
	signal_source.emit_pinged()
	assert_eq(receiver.ping_count, 1, "普通 Object 无释放通知，底层连接需由调用方显式取消。")

	assert_true(subscription_token.cancel(), "owner 释放后仍应允许显式取消底层连接。")
	signal_source.emit_pinged()
	assert_eq(receiver.ping_count, 1, "显式取消后 Signal 不应继续派发。")


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
