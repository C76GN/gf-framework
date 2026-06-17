# GFSignalConnection

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/gf_signal_connection.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

可管理的 Godot Signal 链式连接。 连接支持默认参数、过滤、映射、延迟、防抖、节流、次数限制、 累积转换、一次性触发和 owner 归属清理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`OperationType`](#member-gfsignalconnection-enums-operationtype) | `enum OperationType` |
| 方法 | [`filter`](#member-gfsignalconnection-methods-filter) | `func filter(predicate: Callable) -> GFSignalConnection:` |
| 方法 | [`map`](#member-gfsignalconnection-methods-map) | `func map(mapper: Callable) -> GFSignalConnection:` |
| 方法 | [`delay`](#member-gfsignalconnection-methods-delay) | `func delay(seconds: float) -> GFSignalConnection:` |
| 方法 | [`debounce`](#member-gfsignalconnection-methods-debounce) | `func debounce(seconds: float) -> GFSignalConnection:` |
| 方法 | [`throttle`](#member-gfsignalconnection-methods-throttle) | `func throttle(seconds: float) -> GFSignalConnection:` |
| 方法 | [`skip`](#member-gfsignalconnection-methods-skip) | `func skip(count: int) -> GFSignalConnection:` |
| 方法 | [`take`](#member-gfsignalconnection-methods-take) | `func take(count: int) -> GFSignalConnection:` |
| 方法 | [`first`](#member-gfsignalconnection-methods-first) | `func first() -> GFSignalConnection:` |
| 方法 | [`scan`](#member-gfsignalconnection-methods-scan) | `func scan(accumulator: Variant, reducer: Callable) -> GFSignalConnection:` |
| 方法 | [`start_with`](#member-gfsignalconnection-methods-start_with) | `func start_with(value: Variant) -> GFSignalConnection:` |
| 方法 | [`once`](#member-gfsignalconnection-methods-once) | `func once() -> GFSignalConnection:` |
| 方法 | [`start`](#member-gfsignalconnection-methods-start) | `func start() -> GFSignalConnection:` |
| 方法 | [`disconnect_signal`](#member-gfsignalconnection-methods-disconnect_signal) | `func disconnect_signal() -> void:` |
| 方法 | [`is_active`](#member-gfsignalconnection-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`is_owned_by`](#member-gfsignalconnection-methods-is_owned_by) | `func is_owned_by(owner: Object) -> bool:` |
| 方法 | [`matches`](#member-gfsignalconnection-methods-matches) | `func matches(source_signal: Signal, callback: Callable, owner: Object = null) -> bool:` |
| 方法 | [`prune_if_invalid`](#member-gfsignalconnection-methods-prune_if_invalid) | `func prune_if_invalid() -> bool:` |

## 枚举

<a id="member-gfsignalconnection-enums-operationtype"></a>

### `OperationType`

- API：`public`

```gdscript
enum OperationType {
	## 过滤信号参数。
	FILTER,
	## 映射信号参数。
	MAP,
	## 延迟处理。
	DELAY,
	## 防抖处理。
	DEBOUNCE,
	## 节流处理。
	THROTTLE,
	## 跳过前若干次触发。
	SKIP,
	## 只接收前若干次触发。
	TAKE,
	## 累积转换信号参数。
	SCAN,
}
```

链式连接处理步骤类型。

## 方法

<a id="member-gfsignalconnection-methods-filter"></a>

### `filter`

- API：`public`

```gdscript
func filter(predicate: Callable) -> GFSignalConnection:
```

增加过滤步骤。predicate 返回 false 时停止本次回调。

参数：

| 名称 | 说明 |
|---|---|
| `predicate` | 用于过滤信号参数的回调。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-map"></a>

### `map`

- API：`public`

```gdscript
func map(mapper: Callable) -> GFSignalConnection:
```

增加映射步骤。mapper 的返回值会替换后续回调参数。

参数：

| 名称 | 说明 |
|---|---|
| `mapper` | 用于转换信号参数的回调。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-delay"></a>

### `delay`

- API：`public`

```gdscript
func delay(seconds: float) -> GFSignalConnection:
```

每次触发都延迟指定秒数后再继续处理。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 延迟时间（秒）。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-debounce"></a>

### `debounce`

- API：`public`

```gdscript
func debounce(seconds: float) -> GFSignalConnection:
```

防抖处理。连续触发时只保留静默期后的最后一次。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 防抖静默期（秒）。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-throttle"></a>

### `throttle`

- API：`public`

```gdscript
func throttle(seconds: float) -> GFSignalConnection:
```

节流处理。指定秒数内只允许首次触发继续传递。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 节流时间（秒）。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-skip"></a>

### `skip`

- API：`public`

```gdscript
func skip(count: int) -> GFSignalConnection:
```

跳过前 count 次成功进入该步骤的触发。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 需要跳过的次数。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-take"></a>

### `take`

- API：`public`

```gdscript
func take(count: int) -> GFSignalConnection:
```

只允许前 count 次成功进入该步骤的触发继续传递，耗尽后自动断开。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 允许传递的次数。 |

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-first"></a>

### `first`

- API：`public`

```gdscript
func first() -> GFSignalConnection:
```

只允许第一次成功进入该步骤的触发继续传递，之后自动断开。

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-scan"></a>

### `scan`

- API：`public`

```gdscript
func scan(accumulator: Variant, reducer: Callable) -> GFSignalConnection:
```

对信号参数执行累积转换。reducer 第一个参数为当前累积值，后续参数为当前信号参数。

参数：

| 名称 | 说明 |
|---|---|
| `accumulator` | 初始累积值。 |
| `reducer` | 累积转换回调。 |

返回：当前连接对象，便于继续链式配置。

结构：

- `accumulator`: Variant，传给 reducer 的初始累加器。

<a id="member-gfsignalconnection-methods-start_with"></a>

### `start_with`

- API：`public`

```gdscript
func start_with(value: Variant) -> GFSignalConnection:
```

立即用指定参数主动执行一次链式处理。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 初始参数；Array 会按参数列表传入，Callable 会被调用并使用其返回值。 |

返回：当前连接对象，便于继续链式配置。

结构：

- `value`: Variant，起始值、参数 Array，或返回这两类形态的 Callable。

<a id="member-gfsignalconnection-methods-once"></a>

### `once`

- API：`public`

```gdscript
func once() -> GFSignalConnection:
```

设置为一次性连接，首次成功触发后自动断开。

返回：当前连接对象，便于继续链式配置。

<a id="member-gfsignalconnection-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start() -> GFSignalConnection:
```

启动连接。

返回：当前连接对象。

<a id="member-gfsignalconnection-methods-disconnect_signal"></a>

### `disconnect_signal`

- API：`public`

```gdscript
func disconnect_signal() -> void:
```

主动断开连接。

<a id="member-gfsignalconnection-methods-is_active"></a>

### `is_active`

- API：`public`

```gdscript
func is_active() -> bool:
```

当前连接是否仍有效。

返回：当前连接仍处于连接状态时返回 true。

<a id="member-gfsignalconnection-methods-is_owned_by"></a>

### `is_owned_by`

- API：`public`

```gdscript
func is_owned_by(owner: Object) -> bool:
```

当前连接是否属于指定 owner。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听或连接的拥有者。 |

返回：owner 匹配时返回 true。

<a id="member-gfsignalconnection-methods-matches"></a>

### `matches`

- API：`public`

```gdscript
func matches(source_signal: Signal, callback: Callable, owner: Object = null) -> bool:
```

检查连接是否匹配指定 Signal、回调和可选 owner。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接或断开的 Godot 信号。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `owner` | 监听或连接的拥有者。 |

返回：Signal、回调和 owner 匹配时返回 true。

<a id="member-gfsignalconnection-methods-prune_if_invalid"></a>

### `prune_if_invalid`

- API：`public`

```gdscript
func prune_if_invalid() -> bool:
```

owner、signal 发射源或 callback 目标失效时清理连接。

返回：连接已被判定无效并清理时返回 true。
