# GFVisualActionGroup

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_visual_action_group.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

动作组复合节点 (Composite Pattern) 继承自 GFVisualAction。允许将一组子动作打包，按并行（全部一起发出并按策略等待） 或顺序（逐个执行并等待各自完成）两种模式执行。 子动作可以继承 GFVisualAction，也可以直接实现动作协议方法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ParallelCompletionPolicy`](#member-gfvisualactiongroup-enums-parallelcompletionpolicy) | `enum ParallelCompletionPolicy` |
| 属性 | [`actions`](#member-gfvisualactiongroup-properties-actions) | `var actions: Array[Object] = []` |
| 属性 | [`is_parallel`](#member-gfvisualactiongroup-properties-is_parallel) | `var is_parallel: bool = true` |
| 属性 | [`parallel_completion_policy`](#member-gfvisualactiongroup-properties-parallel_completion_policy) | `var parallel_completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL` |
| 属性 | [`cancel_remaining_on_first_completed`](#member-gfvisualactiongroup-properties-cancel_remaining_on_first_completed) | `var cancel_remaining_on_first_completed: bool = true` |
| 方法 | [`add`](#member-gfvisualactiongroup-methods-add) | `func add(action: Object) -> void:` |
| 方法 | [`execute`](#member-gfvisualactiongroup-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfvisualactiongroup-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfvisualactiongroup-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfvisualactiongroup-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfvisualactiongroup-methods-finish) | `func finish() -> void:` |

## 枚举

<a id="member-gfvisualactiongroup-enums-parallelcompletionpolicy"></a>

### `ParallelCompletionPolicy`

- API：`public`
- 首次版本：`3.24.0`

```gdscript
enum ParallelCompletionPolicy {
	## 等待所有需要等待的子动作完成。
	WAIT_FOR_ALL,
	## 任一子动作完成后就结束动作组。
	FIRST_COMPLETED,
}
```

并行动作组何时视为完成。

## 属性

<a id="member-gfvisualactiongroup-properties-actions"></a>

### `actions`

- API：`public`

```gdscript
var actions: Array[Object] = []
```

包含的子动作列表。

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfvisualactiongroup-properties-is_parallel"></a>

### `is_parallel`

- API：`public`

```gdscript
var is_parallel: bool = true
```

是否并行执行。为 true 时，并行触发所有子动作并按 parallel_completion_policy 完成； 为 false 时，按数组顺序依次执行并等待各自完成。

<a id="member-gfvisualactiongroup-properties-parallel_completion_policy"></a>

### `parallel_completion_policy`

- API：`public`
- 首次版本：`3.24.0`

```gdscript
var parallel_completion_policy: ParallelCompletionPolicy = ParallelCompletionPolicy.WAIT_FOR_ALL
```

并行动作组完成策略。

<a id="member-gfvisualactiongroup-properties-cancel_remaining_on_first_completed"></a>

### `cancel_remaining_on_first_completed`

- API：`public`
- 首次版本：`3.24.0`

```gdscript
var cancel_remaining_on_first_completed: bool = true
```

FIRST_COMPLETED 完成策略触发后，是否取消仍在等待的子动作。

## 方法

<a id="member-gfvisualactiongroup-methods-add"></a>

### `add`

- API：`public`

```gdscript
func add(action: Object) -> void:
```

添加一个子动作。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 动作对象。 |

<a id="member-gfvisualactiongroup-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行动作组逻辑。根据 is_parallel 决定并发还是串行。

返回：需要等待则返回内部完成信号，否则返回 null。

结构：

- `return`: Variant，动作组为空时返回 null；否则返回内部完成 Signal。

<a id="member-gfvisualactiongroup-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

请求取消当前动作组执行。

<a id="member-gfvisualactiongroup-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停所有有效子动作。

<a id="member-gfvisualactiongroup-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复所有有效子动作。

<a id="member-gfvisualactiongroup-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即完成所有有效子动作并释放等待者。
