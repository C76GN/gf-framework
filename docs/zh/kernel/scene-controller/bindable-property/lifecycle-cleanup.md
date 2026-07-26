# 生命周期与清理

在 UI 开发中，最常见的风险是 Node 销毁后监听器未释放。`GFBindableProperty.bind_to()` 会额外监听目标 Node 的 `tree_exited`，适合作为表现层默认绑定方式。

```gdscript
func _ready() -> void:
	# 绑定到自身，当该 Controller(Node) 销毁时会自动 disconnect
	player_model.level.bind_to(self, _on_level_changed)

	# 依然建议手动刷新一次初始值
	_on_level_changed(null, player_model.level.get_value())
```

需要手动清理 UI 绑定时，`unbind(node, callable)` 只断开指定节点绑定。如果传入的是已经失效的节点引用，会先清理失效绑定，再决定是否释放框架托管的 `value_changed` 连接。

`unbind_all()` / `unbind_all_node_bindings()` 只清理由 `bind_to()` 创建的节点生命周期绑定，不会断开业务层直接连接到 `value_changed` 的订阅。

同一个 callable 绑定到多个节点时，只要仍有一个节点绑定存活，框架创建的 `value_changed` 连接就会保留。最后一个绑定离开后才自动断开。

`subscribe(callback, emit_current)` 适合无 Node 生命周期的对象。它直接连接 `value_changed` 并返回一个取消订阅函数；持有方应保存这个 Callable，并在释放、重建或测试结束时调用它。`emit_current` 为 `true` 时会立即用当前值调用回调，避免单独写一次初始刷新逻辑。

需要把取消动作作为显式运行时句柄传递时，使用 `subscribe_token()` 返回 `GFSubscriptionToken`。需要把订阅绑定到 owner 生命周期时，使用 `subscribe_owned(owner, callback)` 返回 `GFLifetimeSubscription`；如果回调是 owner 上的方法，优先使用 `subscribe_method(owner, method_name)`，它只弱引用 owner，避免为了订阅回调而延长 owner 生命周期。对非绑定属性的普通 Godot Signal，使用 `GFSignalSubscriptionToken` 把连接建模成可取消句柄；需要随 Node owner 自动清理时，用 `GFSignalSubscriptionToken.connect_owned(...)`。

这四个 `subscribe*` 入口的每次调用都会建立独立订阅，即使 callback、owner 和 method name 完全相同，也会返回独立取消函数或 token。取消其中一个句柄只移除该次注册；需要去重时应由调用方保存并复用既有句柄，而不是依赖属性容器隐式合并。

确实要清空 `value_changed` 上所有订阅者时，使用语义更明确的 `disconnect_all_subscribers()`。
