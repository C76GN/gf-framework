# 监听器所有权与生命周期

事件监听应跟随 owner 生命周期注册和清理。动态节点、临时 Utility、关卡局部模块和状态对象不应使用无 owner 的全局监听，除非它们明确负责手动注销。

## GF 基类监听

从 `1.9.1` 起，事件系统支持把监听器登记到某个 owner 名下，之后可以按 owner 一次性清理全部类型事件和简单事件监听。

`GFSystem`、`GFUtility`、`GFController` 与 `GFState` 基类提供的 `register_event()` / `register_simple_event()` 已经默认使用当前实例作为 owner；模块被注销或状态被释放时，框架会自动清理这些监听。若 `GFState` 的监听只应在当前状态激活期间生效，应在 `exit()` 中调用 `unregister_owner_events()`。

```gdscript
class_name QuestHudController
extends GFController


func _ready() -> void:
	register_simple_event(&"EVENT_QUEST_UPDATED", GFEventListener.from_method(self, &"_on_quest_updated", 1))
	register_event(QuestCompletedPayload, GFEventListener.from_method(self, &"_on_quest_completed", 1), 100)


func _on_quest_updated(_payload: Variant) -> void:
	_refresh()


func _on_quest_completed(payload: GFPayload) -> void:
	var completed := payload as QuestCompletedPayload
	_show_completed(completed.quest_id)
```

## 普通对象监听

如果监听者不是 GF 基类实例，可以使用全局门面的 owner 版本：

```gdscript
func _ready() -> void:
	Gf.listen_simple_owned(self, &"EVENT_PLAYER_JUMPED", GFEventListener.from_method(self, &"_on_player_jumped", 1))
	Gf.listen_owned(self, DamagePayload, GFEventListener.from_method(self, &"_on_damage_taken", 1), 100)


func _exit_tree() -> void:
	Gf.unlisten_owner(self)
```

`Gf.listen()` / `Gf.listen_simple()` 没有 owner 归属，只适合 AutoLoad、全局常驻服务或明确手动管理生命周期的监听；动态节点、临时 Utility、关卡局部模块应使用 owner 绑定写法。

## 可取消与一次性订阅

需要由调用方持有取消权，或只处理首个匹配事件时，使用返回 `GFSubscriptionToken` 的 `Gf.subscribe()`、`Gf.subscribe_assignable()` 和 `Gf.subscribe_simple()`。每次调用都会建立独立订阅身份；即使多个订阅复用同一个 Callable，取消其中一个 token 也不会移除其余订阅。

```gdscript
var _damage_subscription: GFSubscriptionToken


func _ready() -> void:
	_damage_subscription = Gf.subscribe(
		DamagePayload,
		GFEventListener.from_method(self, &"_on_first_damage", 1),
		100,
		true
	)


func close_panel() -> void:
	if _damage_subscription != null:
		_damage_subscription.cancel()
```

`once = true` 的订阅会在用户回调开始前从当前轨道退休，因此回调内部再次发送同类事件也不会重入同一个一次性订阅。`cancel()` 是幂等的；一次性派发、owner 清理、显式 unregister 或事件系统 `clear()` 已经结束订阅时，token 会自动变为非活动状态，后续 `cancel()` 返回 `false`。

`GFEventListener.from_method(owner, ...)` 已携带 owner，事件系统会返回绑定该 owner 的 `GFLifetimeSubscription` 实例；Node 离树时会自动取消。无 owner 的订阅必须由调用方保留 token 并明确取消。直接持有 `GFArchitecture` 时，对应入口为 `subscribe_event()`、`subscribe_assignable_event()` 和 `subscribe_simple_event()`。

`GFController` 等需要在架构替换或重新入树后重建长期绑定的模块，继续使用现有 `register_event()` 系列生命周期 API；一次性 token 表达一次具体订阅，不应在协调层失效后被自动“复活”。

## 清理时序

如果在事件回调中调用 `Gf.unlisten_owner()`，框架会延迟到最外层派发结束后统一合并清理，并会在当前派发中跳过该 owner 后续尚未执行的 exact、assignable 与 simple 监听器。

这个规则能避免遍历中的监听列表被直接改写，同时保证已明确释放的 owner 不会继续处理本轮事件。

避免在 `Controller` 的 `_init()` 阶段注册监听，因为彼时对应的 `GFArchitecture` 事件总线可能还没有准备完毕。始终在 `ready`、`_ready` 或明确的生命周期挂载点注册监听。

避免每帧重复注册/注销监听。类型事件派发会缓存脚本类型匹配结果，并在监听器变化时只刷新受影响的类型条目；监听生命周期仍应跟随模块、节点或 owner，而不是在 `tick()` 中反复注册和注销。
