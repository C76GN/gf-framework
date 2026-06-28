# GFCancelToken

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_cancel_token.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

只读取消状态句柄。 取消 token 用于把“用户主动取消、生命周期结束、超时或上游取消”传递给异步流程。 调用方只能观察状态；实际取消由 [GFCancelSource] 负责触发。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cancelled`](#member-gfcanceltoken-signals-cancelled) | `signal cancelled(reason: StringName, metadata: Dictionary)` |
| 方法 | [`is_cancelled`](#member-gfcanceltoken-methods-is_cancelled) | `func is_cancelled() -> bool:` |
| 方法 | [`get_reason`](#member-gfcanceltoken-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_metadata`](#member-gfcanceltoken-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_cancelled_msec`](#member-gfcanceltoken-methods-get_cancelled_msec) | `func get_cancelled_msec() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfcanceltoken-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfcanceltoken-signals-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal cancelled(reason: StringName, metadata: Dictionary)
```

token 首次进入取消状态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因。 |
| `metadata` | 调用方附加的取消上下文。 |

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

## 方法

<a id="member-gfcanceltoken-methods-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_cancelled() -> bool:
```

判断 token 是否已经取消。

返回：已取消时返回 true。

<a id="member-gfcanceltoken-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_reason() -> StringName:
```

获取取消原因。

返回：取消原因；未取消时为空 StringName。

<a id="member-gfcanceltoken-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取取消元数据副本。

返回：取消元数据副本。

结构：

- `return`: Dictionary，包含调用方传入的取消上下文。

<a id="member-gfcanceltoken-methods-get_cancelled_msec"></a>

### `get_cancelled_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_cancelled_msec() -> int:
```

获取取消发生时的 Time.get_ticks_msec()。

返回：取消发生时的毫秒 tick；未取消时为 0。

<a id="member-gfcanceltoken-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取取消状态快照。

返回：取消状态快照。

结构：

- `return`: Dictionary，包含 cancelled、reason、metadata 和 cancelled_msec。
