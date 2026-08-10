# GFPointerCapture

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/common/gf_pointer_capture.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

单指针捕获状态句柄。 用于触屏控件、虚拟光标或拖放控制器记录当前由哪个 pointer/touch id 拥有交互。它只保存捕获身份，不读取输入事件，也不规定 UI 行为。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`NO_POINTER_ID`](#member-gfpointercapture-constants-no_pointer_id) | `const NO_POINTER_ID: int = -1` |
| 属性 | [`active_pointer_id`](#member-gfpointercapture-properties-active_pointer_id) | `var active_pointer_id: int = NO_POINTER_ID` |
| 方法 | [`is_active`](#member-gfpointercapture-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`matches`](#member-gfpointercapture-methods-matches) | `func matches(pointer_id: int) -> bool:` |
| 方法 | [`try_capture`](#member-gfpointercapture-methods-try_capture) | `func try_capture(pointer_id: int) -> bool:` |
| 方法 | [`release`](#member-gfpointercapture-methods-release) | `func release(pointer_id: int = NO_POINTER_ID) -> bool:` |
| 方法 | [`reset`](#member-gfpointercapture-methods-reset) | `func reset() -> bool:` |
| 方法 | [`to_dictionary`](#member-gfpointercapture-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 常量

<a id="member-gfpointercapture-constants-no_pointer_id"></a>

### `NO_POINTER_ID`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const NO_POINTER_ID: int = -1
```

无活动指针。

## 属性

<a id="member-gfpointercapture-properties-active_pointer_id"></a>

### `active_pointer_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var active_pointer_id: int = NO_POINTER_ID
```

当前捕获的指针 ID；没有捕获时为 -1。

## 方法

<a id="member-gfpointercapture-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_active() -> bool:
```

检查是否已有活动捕获。

返回：有活动捕获时返回 true。

<a id="member-gfpointercapture-methods-matches"></a>

### `matches`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func matches(pointer_id: int) -> bool:
```

检查传入指针是否匹配当前捕获。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 要检查的指针 ID。 |

返回：匹配当前捕获时返回 true。

<a id="member-gfpointercapture-methods-try_capture"></a>

### `try_capture`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func try_capture(pointer_id: int) -> bool:
```

尝试捕获指针。 若当前没有捕获，则记录传入指针；若已经捕获同一指针，也视为成功。 `NO_POINTER_ID` 永远会被拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 要捕获的指针 ID。 |

返回：捕获成功或已经捕获同一指针时返回 true。

<a id="member-gfpointercapture-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func release(pointer_id: int = NO_POINTER_ID) -> bool:
```

释放当前捕获。 `pointer_id` 为 -1 时释放任意当前捕获；否则只释放匹配的指针。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 要释放的指针 ID；-1 表示释放任意当前捕获。 |

返回：实际释放了活动捕获时返回 true。

<a id="member-gfpointercapture-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func reset() -> bool:
```

强制清空捕获状态。

返回：实际清空了活动捕获时返回 true。

<a id="member-gfpointercapture-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为调试字典。

返回：捕获状态快照。

结构：

- `return`: Dictionary，包含 active_pointer_id 和 active。
