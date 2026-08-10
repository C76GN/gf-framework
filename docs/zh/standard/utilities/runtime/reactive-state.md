# 响应式状态与控件绑定

`GFReactiveStateStore` 提供运行时 Dictionary 状态树、路径级变更记录、dirty queue 和 owner 自动解绑。它适合项目界面、调试面板、设置页或编辑工具中同时维护多个字段状态，但不定义字段含义，也不替代业务 Model。

## 定位

- `GFBindableProperty`：Model 暴露单个字段，Controller 直接订阅。
- `GFReactiveEffect` / `GFComputedProperty`：组合多个 `GFBindableProperty` 形成局部副作用或派生值。
- `GFFormBinder`：批量读写一组表单控件，不持有应用状态。
- `GFReactiveStateStore`：维护一棵通用状态树，按路径生成变更记录并批量派发。
- `GFReactiveStateControlBinder`：把一个 `Control` 的值和 store path 双向同步。

如果项目已有清晰的业务 Model，应优先把业务状态归属留在 Model 中；store 更适合 UI 本地状态、工具状态、筛选条件、面板草稿和可丢弃的运行时视图状态。

`GFReadOnlyBindableProperty` 与 `GFComputedProperty` 的 `get_value()` 会对 `Array` / `Dictionary` 返回深拷贝，避免调用方通过集合引用绕过只读约束；需要可写集合时应使用普通 `GFBindableProperty` 并通过其 mutator 或宿主 Model 更新。

## 状态路径

路径可以使用点号字符串、`StringName`、`PackedStringArray` 或 `Array`：

```gdscript
var store := GFReactiveStateStore.new({
	"profile": {
		"name": "Ada",
	},
})

store.set_value("profile.name", "Grace")
print(store.get_value(["profile", "name"]))
```

`String` 路径按 `.` 分段，`Array` 路径可包含 `int` 段读取已有数组索引。自动创建中间容器时只创建 `Dictionary`，不会自动扩容数组。`set_value()` 会先验证整条路径再提交写入；若后续数组索引或容器类型使写入无法完成，它返回 `false`，状态树、dirty queue 和信号都保持不变，不会遗留半创建的中间字典。

## Dirty Queue

普通写入会立即 flush：

```gdscript
store.subscribe("profile.name", func(change: Dictionary, _store: GFReactiveStateStore) -> void:
	%NameLabel.text = GFVariantData.to_text(change["new_value"])
)

store.set_value("profile.name", "Grace")
```

需要合并多次写入时使用批量模式：

```gdscript
store.begin_batch()
store.set_value("profile.name", "Grace")
store.set_value("profile.level", 2)
var changes := store.end_batch()
```

同一路径在一个批次内会合并为一条 dirty change，并保留第一次写入前的旧值和最后一次写入后的新值。合并身份由带类型的 path segment 序列决定，不使用人读字符串，因此字段名 `profile.name` 与路径 `profile -> name`、字符串键 `items[1]` 与整数索引 `1` 不会碰撞；报告中的 `path` 仍只负责显示。`set_state()` 会复用 `GFVariantData.diff_variant()` 生成路径级差异，方便调试、日志和保存工具复用同一种变更记录形态。若 diff 达到 `max_changes` 上限并被截断，store 会降级派发根级 `state_replaced` 变更，表示订阅者应全量刷新，而不是只相信已收集到的部分路径。

订阅回调、`state_changed` 或 `path_changed` 中再次写入 store 时，新 dirty change 不会重入当前正在通知的订阅者批次；当前批次完成后，store 会按下一批继续派发，避免嵌套 flush 打乱同一批订阅者顺序。

## 订阅与解绑

`subscribe()` 返回取消订阅的 `Callable`。`options.owner` 传入 `Node` 时，该节点退出场景树会自动取消订阅：

```gdscript
var unsubscribe := store.subscribe("filters", _on_filters_changed, {
	"mode": GFReactiveStateStore.SUBSCRIBE_PREFIX,
	"owner": self,
	"emit_current": true,
})
```

`options.owner` 也可以是普通 `Object` / `RefCounted`。这类 owner 没有场景树退出信号，store 会通过 `WeakRef` 在 `flush()`、`get_subscription_count()` 或后续清理点懒移除失效订阅。

订阅模式：

- `SUBSCRIBE_EXACT`：只接收完全相同路径。
- `SUBSCRIBE_PREFIX`：接收该路径及其子路径。
- `SUBSCRIBE_ANY`：接收所有路径。

回调签名固定为 `func(change: Dictionary, store: GFReactiveStateStore) -> void`。变更记录包含 `kind`、`path`、`path_segments`、`old_value`、`new_value`、`old_exists`、`new_exists`、`old_type` 和 `new_type`。

## 控件绑定

`GFReactiveStateControlBinder` 复用 `GFControlValueAdapter`，支持 `LineEdit`、`TextEdit`、`CheckBox`、`Slider`、`OptionButton`、`ColorPickerButton`、`ItemList` 和提供 `value` / `get_value()` / `set_value()` 的自定义控件：

```gdscript
var store := GFReactiveStateStore.new({
	"profile": {
		"name": "Ada",
	},
})
var binder := GFReactiveStateControlBinder.new()

binder.bind_control(store, "profile.name", %NameEdit)
```

默认行为是先把 store 中的值写入控件，再监听控件变化写回 store。需要用控件当前值初始化 store 时：

```gdscript
binder.bind_control(store, "profile.name", %NameEdit, {
	"write_initial_to_store": true,
})
```

控件退出场景树、store 被释放或显式调用 `unbind_control()` / `clear()` 时，binder 会断开控件信号，并通过 store 的 owner 订阅清理路径监听。

## 使用边界

- Store 只保存通用 Variant 数据，不解释字段语义、权限、校验规则或业务动作。
- Store 不替代 `GFArchitecture` 中的 Model/System/Utility 生命周期。
- 需要字段类型声明和默认值校验时，使用 `GFBlackboardSchema` 或 `GFDictionarySchema` 处理数据契约，再把结果写入 store。
- 需要提交/回滚一组业务操作时，使用 `GFMutationBatch`；store 的 batch 只合并通知，不提供事务语义。
- 大状态树替换时应按需设置 `set_state(..., { "max_changes": ... })`，或者让截断触发 `state_replaced` 后由订阅者主动拉取最新状态。

参考测试：

- `tests/gf_core/standard/utilities/state/test_gf_reactive_state_store.gd`
- `tests/gf_core/standard/utilities/ui/test_gf_reactive_state_control_binder.gd`
