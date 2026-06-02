# GFRefCountedPool

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/pooling/gf_ref_counted_pool.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.20.0`

通用 RefCounted 对象池。 用工厂 Callable 创建短生命周期 RefCounted 对象，并在归还时通过 hook 或 reset_callback 显式清理状态。它不管理 Node、场景树、资源加载或业务生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`HOOK_ON_ACQUIRE`](#member-gfrefcountedpool-constants-hook_on_acquire) | `const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"` |
| 常量 | [`HOOK_ON_RELEASE`](#member-gfrefcountedpool-constants-hook_on_release) | `const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"` |
| 常量 | [`HOOK_RESET`](#member-gfrefcountedpool-constants-hook_reset) | `const HOOK_RESET: StringName = &"reset_for_pool"` |
| 属性 | [`factory`](#member-gfrefcountedpool-properties-factory) | `var factory: Callable = Callable()` |
| 属性 | [`reset_callback`](#member-gfrefcountedpool-properties-reset_callback) | `var reset_callback: Callable = Callable()` |
| 属性 | [`max_available`](#member-gfrefcountedpool-properties-max_available) | `var max_available: int:` |
| 属性 | [`created_count`](#member-gfrefcountedpool-properties-created_count) | `var created_count: int:` |
| 属性 | [`available_count`](#member-gfrefcountedpool-properties-available_count) | `var available_count: int:` |
| 属性 | [`active_count`](#member-gfrefcountedpool-properties-active_count) | `var active_count: int:` |
| 方法 | [`configure`](#member-gfrefcountedpool-methods-configure) | `func configure( p_factory: Callable, p_reset_callback: Callable = Callable(), p_max_available: int = 0 ) -> GFRefCountedPool:` |
| 方法 | [`acquire`](#member-gfrefcountedpool-methods-acquire) | `func acquire() -> RefCounted:` |
| 方法 | [`release`](#member-gfrefcountedpool-methods-release) | `func release(item: RefCounted) -> bool:` |
| 方法 | [`prewarm`](#member-gfrefcountedpool-methods-prewarm) | `func prewarm(count: int) -> int:` |
| 方法 | [`clear_available`](#member-gfrefcountedpool-methods-clear_available) | `func clear_available() -> void:` |
| 方法 | [`reset_pool`](#member-gfrefcountedpool-methods-reset_pool) | `func reset_pool() -> void:` |
| 方法 | [`is_active`](#member-gfrefcountedpool-methods-is_active) | `func is_active(item: RefCounted) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfrefcountedpool-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfrefcountedpool-constants-hook_on_acquire"></a>

### `HOOK_ON_ACQUIRE`

- API：`public`

```gdscript
const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"
```

对象可选实现：从池中取出后调用。

<a id="member-gfrefcountedpool-constants-hook_on_release"></a>

### `HOOK_ON_RELEASE`

- API：`public`

```gdscript
const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"
```

对象可选实现：归还池时调用。

<a id="member-gfrefcountedpool-constants-hook_reset"></a>

### `HOOK_RESET`

- API：`public`

```gdscript
const HOOK_RESET: StringName = &"reset_for_pool"
```

对象可选实现：归还池时用于清理可复用状态。

## 属性

<a id="member-gfrefcountedpool-properties-factory"></a>

### `factory`

- API：`public`

```gdscript
var factory: Callable = Callable()
```

对象工厂。必须返回 RefCounted。

<a id="member-gfrefcountedpool-properties-reset_callback"></a>

### `reset_callback`

- API：`public`

```gdscript
var reset_callback: Callable = Callable()
```

归还对象时执行的可选重置回调。回调收到被归还的对象。

<a id="member-gfrefcountedpool-properties-max_available"></a>

### `max_available`

- API：`public`

```gdscript
var max_available: int:
```

最多保留的可用对象数量。为 0 时不限制。

<a id="member-gfrefcountedpool-properties-created_count"></a>

### `created_count`

- API：`public`

```gdscript
var created_count: int:
```

池累计创建对象数量。

<a id="member-gfrefcountedpool-properties-available_count"></a>

### `available_count`

- API：`public`

```gdscript
var available_count: int:
```

当前可用对象数量。

<a id="member-gfrefcountedpool-properties-active_count"></a>

### `active_count`

- API：`public`

```gdscript
var active_count: int:
```

当前借出对象数量。

## 方法

<a id="member-gfrefcountedpool-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_factory: Callable, p_reset_callback: Callable = Callable(), p_max_available: int = 0 ) -> GFRefCountedPool:
```

配置对象池并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_factory` | 对象工厂，必须返回 RefCounted。 |
| `p_reset_callback` | 归还对象时执行的可选重置回调。 |
| `p_max_available` | 最多保留的可用对象数量；0 表示不限制。 |

返回：当前对象池。

<a id="member-gfrefcountedpool-methods-acquire"></a>

### `acquire`

- API：`public`

```gdscript
func acquire() -> RefCounted:
```

从池中借出对象。

返回：借出的 RefCounted；工厂无效或返回非 RefCounted 时返回 null。

<a id="member-gfrefcountedpool-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release(item: RefCounted) -> bool:
```

归还对象。

参数：

| 名称 | 说明 |
|---|---|
| `item` | 通过当前对象池借出的 RefCounted。 |

返回：成功归还或因容量上限丢弃时返回 true。

<a id="member-gfrefcountedpool-methods-prewarm"></a>

### `prewarm`

- API：`public`

```gdscript
func prewarm(count: int) -> int:
```

预热对象池。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 要创建并保留的可用对象数量。 |

返回：实际新增到可用池的数量。

<a id="member-gfrefcountedpool-methods-clear_available"></a>

### `clear_available`

- API：`public`

```gdscript
func clear_available() -> void:
```

清空当前可用对象，不影响已经借出的对象。

<a id="member-gfrefcountedpool-methods-reset_pool"></a>

### `reset_pool`

- API：`public`

```gdscript
func reset_pool() -> void:
```

忘记借出记录并清空可用池。 这不会强制回收外部仍持有的 RefCounted，只让当前池停止追踪它们。

<a id="member-gfrefcountedpool-methods-is_active"></a>

### `is_active`

- API：`public`

```gdscript
func is_active(item: RefCounted) -> bool:
```

检查对象是否由当前池借出且尚未归还。

参数：

| 名称 | 说明 |
|---|---|
| `item` | 要检查的对象。 |

返回：对象处于借出状态时返回 true。

<a id="member-gfrefcountedpool-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取对象池调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 created_count、available_count、active_count 与 max_available。
