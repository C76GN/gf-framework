## 验证 GFController 的期望事件绑定会随节点、上下文和对象池生命周期迁移。
extends GutTest


# --- 辅助类 ---

class EventController extends GFController:
	var payloads: Array[Variant] = []

	func listen(event_id: StringName) -> void:
		register_simple_event(
			event_id,
			GFEventListener.from_method(self, &"_on_event", 1)
		)

	func _on_event(payload: Variant) -> void:
		payloads.append(payload)


class EmptyScopedContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		auto_init = false


class InheritedContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.INHERITED
		context_wait_timeout_seconds = 0.0


class RetryModel extends GFModel:
	pass


class ExactControllerEvent extends RefCounted:
	pass


class BaseControllerEvent extends RefCounted:
	pass


class ChildControllerEvent extends BaseControllerEvent:
	pass


# --- GUT 生命周期方法 ---

func before_each() -> void:
	_clear_global_architecture()


func after_each() -> void:
	_clear_global_architecture()


# --- 测试方法 ---

func test_tree_reentry_restores_desired_event_bindings() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = architecture
	var controller: EventController = EventController.new()
	add_child(controller)
	controller.listen(&"tree_reentry")

	architecture.send_simple_event(&"tree_reentry", "before_exit")
	remove_child(controller)
	architecture.send_simple_event(&"tree_reentry", "outside_tree")
	add_child(controller)
	await get_tree().process_frame
	architecture.send_simple_event(&"tree_reentry", "after_reentry")

	assert_eq(
		controller.payloads,
		["before_exit", "after_reentry"],
		"退出树只应暂停实际注册；重新进入树后应恢复期望绑定。"
	)

	controller.queue_free()
	await get_tree().process_frame


func test_global_observer_tracks_resolved_autoload_instance() -> void:
	var controller: EventController = EventController.new()
	var global_singleton: Node = GFAutoload.get_singleton_or_null()
	add_child(controller)
	var callback: Callable = Callable(
		controller,
		&"_on_global_architecture_identity_changed"
	)

	assert_same(
		controller._observed_global_singleton,
		global_singleton,
		"Controller 应缓存 GFAutoload 实际解析出的单例，而不是直接绑定全局标识符。"
	)
	assert_true(
		global_singleton != null
		and global_singleton.is_connected(
			&"architecture_identity_changed",
			callback
		),
		"进入树时应在解析出的 AutoLoad 实例上建立架构身份观察。"
	)

	remove_child(controller)
	assert_null(
		controller._observed_global_singleton,
		"退出树时应断开并清除同一个 AutoLoad 实例观察。"
	)
	controller.free()


func test_reparent_migrates_bindings_to_nearest_context_architecture() -> void:
	var global_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = global_architecture
	var context: EmptyScopedContext = EmptyScopedContext.new()
	var controller: EventController = EventController.new()
	add_child(context)
	add_child(controller)
	controller.listen(&"context_migration")
	global_architecture.send_simple_event(&"context_migration", "global")

	controller.reparent(context)
	var scoped_architecture: GFArchitecture = context.get_architecture()
	global_architecture.send_simple_event(&"context_migration", "stale_global")
	scoped_architecture.send_simple_event(&"context_migration", "scoped")

	assert_eq(
		controller.payloads,
		["global", "scoped"],
		"迁移后旧架构必须清除 owner 注册，新架构必须恢复全部期望绑定。"
	)

	context.queue_free()
	await get_tree().process_frame


func test_pool_acquire_retries_until_architecture_becomes_available() -> void:
	var controller: EventController = EventController.new()
	add_child(controller)
	controller.listen(&"late_pool_architecture")
	controller._gf_on_object_pool_release()
	controller._gf_on_object_pool_acquire()
	await get_tree().process_frame

	var late_architecture: GFArchitecture = Gf.create_architecture()
	late_architecture.send_simple_event(&"late_pool_architecture", "restored")

	assert_eq(
		controller.payloads,
		["restored"],
		"acquire 时架构暂不可用不应永久保持暂停；架构可用后应自动恢复。"
	)

	controller.queue_free()
	await get_tree().process_frame


func test_live_global_architecture_replacement_migrates_event_bindings() -> void:
	var first_architecture: GFArchitecture = GFArchitecture.new()
	var replacement_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = first_architecture
	var controller: EventController = EventController.new()
	add_child(controller)
	controller.listen(&"live_global_replacement")
	first_architecture.send_simple_event(&"live_global_replacement", "first")

	var replacement_succeeded: bool = await Gf.set_architecture(replacement_architecture)
	replacement_architecture.send_simple_event(&"live_global_replacement", "replacement")

	assert_true(replacement_succeeded, "正式全局架构替换应成功。")
	assert_eq(
		controller.payloads,
		["first", "replacement"],
		"set_architecture() 返回前必须把期望绑定同步迁移到 replacement 全局架构。"
	)

	controller.queue_free()
	await get_tree().process_frame


func test_same_global_architecture_retry_restores_cleared_event_bindings() -> void:
	var controller: EventController = EventController.new()
	add_child(controller)
	controller.listen(&"same_identity_retry")
	var architecture: GFArchitecture = Gf.create_architecture()
	architecture.send_simple_event(&"same_identity_retry", "before_failure")

	architecture.fail_initialization("[test] same identity initialization failure")
	var retry_succeeded: bool = await Gf.init()
	architecture.send_simple_event(&"same_identity_retry", "after_retry")

	assert_true(retry_succeeded, "同一全局 Architecture 应允许从可重试失败状态重新初始化。")
	assert_same(
		Gf.get_architecture(),
		architecture,
		"重试成功不应依赖更换全局 Architecture identity。"
	)
	assert_eq(
		controller.payloads,
		["before_failure", "after_retry"],
		"失败清空 event system 后，Controller 应在同 identity READY 时恢复 desired bindings。"
	)
	assert_push_error("[test] same identity initialization failure")

	controller.queue_free()
	await get_tree().process_frame


func test_failed_context_stays_closed_when_shared_architecture_retries() -> void:
	var architecture: GFArchitecture = Gf.create_architecture()
	assert_true(await Gf.init(), "全局 Architecture 首次初始化应成功。")
	var context: InheritedContext = InheritedContext.new()
	var controller: EventController = EventController.new()
	add_child(context)
	context.add_child(controller)
	controller.listen(&"failed_context_retry")
	await get_tree().process_frame

	assert_true(context.is_context_ready(), "Inherited Context 应先进入 READY。")
	architecture.send_simple_event(&"failed_context_retry", "before_failure")

	var failure_reason: String = "[test] inherited context architecture failure"
	architecture.fail_initialization(failure_reason)
	assert_true(context.is_context_failed(), "共享 Architecture 失败后 Context 应进入 FAILED 终态。")

	var retry_succeeded: bool = await Gf.init()
	var recovered_model: RetryModel = RetryModel.new()
	var model_registered: bool = await architecture.register_model_instance(
		recovered_model
	)
	var dispatch_state: Dictionary = {
		"count": 0,
	}
	var direct_listener: GFEventListener = GFEventListener.from_callable(
		func(_event: ExactControllerEvent) -> void:
			dispatch_state["count"] = (
				GFVariantData.get_option_int(dispatch_state, "count") + 1
			),
		1
	)
	architecture.register_event(ExactControllerEvent, direct_listener)
	architecture.send_event(ExactControllerEvent.new())
	controller.send_event(ExactControllerEvent.new())
	architecture.send_simple_event(&"failed_context_retry", "after_retry")

	assert_true(retry_succeeded, "无 Context 的全局 Architecture 同 identity 重试应继续成功。")
	assert_true(model_registered, "重试后的全局 Architecture 应恢复正常模块注册。")
	assert_true(architecture.is_inited(), "共享 Architecture 重试后应重新 READY。")
	assert_true(context.is_context_failed(), "Context FAILED 不得随共享 Architecture 重试复活。")
	assert_null(
		controller.get_architecture_or_null(),
		"最近 Context 已 FAILED 时 Controller 必须继续拒绝同 identity Architecture。"
	)
	assert_null(
		controller.get_architecture(),
		"严格 Architecture accessor 也不得越过 FAILED Context。"
	)
	assert_null(
		controller.get_model(RetryModel),
		"FAILED Context 下不得通过 Controller.get_model() 访问重试后的共享模块。"
	)
	assert_eq(
		GFVariantData.get_option_int(dispatch_state, "count"),
		1,
		"FAILED Context 下 Controller.send_event() 不得访问重试后的共享事件总线。"
	)
	assert_eq(
		controller.payloads,
		["before_failure"],
		"FAILED Context 下 desired bindings 不得因共享 Architecture READY 而恢复。"
	)
	assert_push_error(failure_reason)
	assert_push_warning("[GFNodeContext] %s" % failure_reason)

	context.queue_free()
	await get_tree().process_frame


func test_stale_failure_signal_cannot_clear_replacement_bindings() -> void:
	var failed_architecture: GFArchitecture = Gf.create_architecture()
	var replacement_architecture: GFArchitecture = GFArchitecture.new()
	var replacement_state: Dictionary = {
		"result": false,
	}
	var _failure_connect_error: Error = failed_architecture.initialization_failed.connect(
		func(_reason: String) -> void:
			var raw_replacement_result: Variant = Gf.call(
				&"set_architecture",
				replacement_architecture
			)
			replacement_state["result"] = GFVariantData.to_bool(
				raw_replacement_result
			)
	) as Error
	var controller: EventController = EventController.new()
	add_child(controller)
	controller.listen(&"failure_reentry_replacement")
	failed_architecture.send_simple_event(
		&"failure_reentry_replacement",
		"before_failure"
	)

	failed_architecture.fail_initialization("[test] failure listener replacement")
	replacement_architecture.send_simple_event(
		&"failure_reentry_replacement",
		"replacement"
	)

	assert_true(
		GFVariantData.get_option_bool(replacement_state, "result"),
		"较早 failure listener 发起的 replacement 应成功提交。"
	)
	assert_same(
		Gf.get_architecture(),
		replacement_architecture,
		"failure signal 重入的 replacement 应成为当前 identity。"
	)
	assert_eq(
		controller.payloads,
		["before_failure", "replacement"],
		"旧 Architecture 的迟到 failure handler 不得清除 replacement 上的新绑定。"
	)
	assert_push_error("[test] failure listener replacement")

	controller.queue_free()
	await get_tree().process_frame


func test_binding_revision_rebuilds_type_assignable_and_simple_desired_set() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = architecture
	var controller: EventController = EventController.new()
	add_child(controller)
	var counts: Dictionary = {
		"simple": 0,
		"exact": 0,
		"assignable": 0,
	}
	var simple_listener: GFEventListener = GFEventListener.from_callable(
		func(_payload: Variant) -> void:
			counts["simple"] = GFVariantData.get_option_int(counts, "simple") + 1,
		1
	)
	var exact_listener: GFEventListener = GFEventListener.from_callable(
		func(_event: ExactControllerEvent) -> void:
			counts["exact"] = GFVariantData.get_option_int(counts, "exact") + 1,
		1
	)
	var assignable_listener: GFEventListener = GFEventListener.from_callable(
		func(_event: BaseControllerEvent) -> void:
			counts["assignable"] = GFVariantData.get_option_int(counts, "assignable") + 1,
		1
	)

	controller.register_simple_event(&"desired_set", simple_listener)
	architecture.send_simple_event(&"desired_set")
	controller.register_event(ExactControllerEvent, exact_listener)
	controller.register_assignable_event(BaseControllerEvent, assignable_listener)
	architecture.send_event(ExactControllerEvent.new())
	architecture.send_event(ChildControllerEvent.new())

	assert_eq(
		counts,
		{"simple": 1, "exact": 1, "assignable": 1},
		"同一架构内追加 type/assignable 绑定时必须立即重建完整 desired set。"
	)

	controller.unregister_event(ExactControllerEvent, exact_listener)
	architecture.send_event(ExactControllerEvent.new())
	architecture.send_event(ChildControllerEvent.new())
	controller.unregister_assignable_event(BaseControllerEvent, assignable_listener)
	architecture.send_event(ChildControllerEvent.new())
	architecture.send_simple_event(&"desired_set")
	controller.unregister_simple_event(&"desired_set", simple_listener)
	architecture.send_simple_event(&"desired_set")

	assert_eq(
		counts,
		{"simple": 2, "exact": 1, "assignable": 2},
		"删除其中一个绑定时旧监听必须立即消失，剩余 type/assignable/simple 绑定不得丢失。"
	)

	controller.queue_free()
	await get_tree().process_frame


func test_invalid_nearest_context_does_not_fall_through_to_global_architecture() -> void:
	var global_architecture: GFArchitecture = GFArchitecture.new()
	Gf._architecture = global_architecture
	var context: EmptyScopedContext = EmptyScopedContext.new()
	var controller: EventController = EventController.new()
	add_child(context)
	context.add_child(controller)
	var scoped_architecture: GFArchitecture = context.get_architecture()

	scoped_architecture.dispose()

	assert_null(
		controller.get_architecture_or_null(),
		"最近 Context 已失效时，nullable accessor 必须 fail closed。"
	)
	assert_null(
		controller.get_architecture(),
		"最近 Context 已失效时，严格 accessor 也不得静默越过作用域回退全局架构。"
	)

	context.queue_free()
	await get_tree().process_frame
	assert_push_warning("[GFNodeContext] 上下文架构生命周期已结束。")


# --- 辅助方法 ---

func _clear_global_architecture() -> void:
	if Gf.has_architecture():
		var architecture: GFArchitecture = Gf.get_architecture()
		architecture.dispose()
	Gf._architecture = null
