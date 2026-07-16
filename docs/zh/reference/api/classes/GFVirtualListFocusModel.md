# GFVirtualListFocusModel

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_virtual_list_focus_model.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

虚拟列表焦点索引模型。 用数据索引维护虚拟焦点，供回收式列表、长日志、资源浏览器或编辑器表格在 不绑定具体 Control 节点的前提下处理键盘/手柄焦点。它不创建 UI、不读取输入、 不提交业务选择，只负责焦点索引、可聚焦判断和前后移动。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`focused_index_changed`](#member-gfvirtuallistfocusmodel-signals-focused_index_changed) | `signal focused_index_changed(previous_index: int, focused_index: int)` |
| 常量 | [`NO_FOCUS`](#member-gfvirtuallistfocusmodel-constants-no_focus) | `const NO_FOCUS: int = -1` |
| 属性 | [`item_count`](#member-gfvirtuallistfocusmodel-properties-item_count) | `var item_count: int:` |
| 属性 | [`focused_index`](#member-gfvirtuallistfocusmodel-properties-focused_index) | `var focused_index: int:` |
| 属性 | [`wrap_navigation`](#member-gfvirtuallistfocusmodel-properties-wrap_navigation) | `var wrap_navigation: bool = false` |
| 属性 | [`auto_focus_on_count_change`](#member-gfvirtuallistfocusmodel-properties-auto_focus_on_count_change) | `var auto_focus_on_count_change: bool = false` |
| 属性 | [`focusable_callback`](#member-gfvirtuallistfocusmodel-properties-focusable_callback) | `var focusable_callback: Callable:` |
| 方法 | [`configure`](#member-gfvirtuallistfocusmodel-methods-configure) | `func configure(p_item_count: int, options: Dictionary = {}) -> GFVirtualListFocusModel:` |
| 方法 | [`set_item_count`](#member-gfvirtuallistfocusmodel-methods-set_item_count) | `func set_item_count(p_item_count: int, repair_focus_enabled: bool = true) -> bool:` |
| 方法 | [`set_focused_index`](#member-gfvirtuallistfocusmodel-methods-set_focused_index) | `func set_focused_index(item_index: int) -> bool:` |
| 方法 | [`clear_focus`](#member-gfvirtuallistfocusmodel-methods-clear_focus) | `func clear_focus() -> bool:` |
| 方法 | [`has_focus`](#member-gfvirtuallistfocusmodel-methods-has_focus) | `func has_focus() -> bool:` |
| 方法 | [`focus_first`](#member-gfvirtuallistfocusmodel-methods-focus_first) | `func focus_first() -> bool:` |
| 方法 | [`focus_last`](#member-gfvirtuallistfocusmodel-methods-focus_last) | `func focus_last() -> bool:` |
| 方法 | [`move_focus`](#member-gfvirtuallistfocusmodel-methods-move_focus) | `func move_focus(step: int) -> bool:` |
| 方法 | [`focus_next`](#member-gfvirtuallistfocusmodel-methods-focus_next) | `func focus_next() -> bool:` |
| 方法 | [`focus_previous`](#member-gfvirtuallistfocusmodel-methods-focus_previous) | `func focus_previous() -> bool:` |
| 方法 | [`repair_focus`](#member-gfvirtuallistfocusmodel-methods-repair_focus) | `func repair_focus(preferred_index: int = NO_FOCUS) -> bool:` |
| 方法 | [`is_focusable`](#member-gfvirtuallistfocusmodel-methods-is_focusable) | `func is_focusable(item_index: int) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfvirtuallistfocusmodel-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfvirtuallistfocusmodel-signals-focused_index_changed"></a>

### `focused_index_changed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal focused_index_changed(previous_index: int, focused_index: int)
```

当前虚拟焦点索引变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_index` | 变化前的焦点索引；无焦点时为 NO_FOCUS。 |
| `focused_index` | 变化后的焦点索引；无焦点时为 NO_FOCUS。 |

## 常量

<a id="member-gfvirtuallistfocusmodel-constants-no_focus"></a>

### `NO_FOCUS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const NO_FOCUS: int = -1
```

无焦点标记。

## 属性

<a id="member-gfvirtuallistfocusmodel-properties-item_count"></a>

### `item_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var item_count: int:
```

当前条目数量，小于 0 时按 0 处理。

<a id="member-gfvirtuallistfocusmodel-properties-focused_index"></a>

### `focused_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var focused_index: int:
```

当前虚拟焦点索引；无焦点时为 NO_FOCUS。设置不可聚焦索引会被忽略。

<a id="member-gfvirtuallistfocusmodel-properties-wrap_navigation"></a>

### `wrap_navigation`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var wrap_navigation: bool = false
```

焦点移动到首尾边界后是否环绕。

<a id="member-gfvirtuallistfocusmodel-properties-auto_focus_on_count_change"></a>

### `auto_focus_on_count_change`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var auto_focus_on_count_change: bool = false
```

当条目数量变化且当前没有焦点时，是否自动聚焦第一个可聚焦条目。

<a id="member-gfvirtuallistfocusmodel-properties-focusable_callback"></a>

### `focusable_callback`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var focusable_callback: Callable:
```

可选可聚焦判断回调。回调接收 item_index，返回 false 时该索引会被跳过。

结构：

- `focusable_callback`: Callable(item_index: int) -> bool。

## 方法

<a id="member-gfvirtuallistfocusmodel-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure(p_item_count: int, options: Dictionary = {}) -> GFVirtualListFocusModel:
```

配置焦点模型并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_item_count` | 条目数量。 |
| `options` | 可选项。 |

返回：当前焦点模型。

结构：

- `options`: Dictionary，支持 focused_index、wrap_navigation、auto_focus_on_count_change 和 focusable_callback。

<a id="member-gfvirtuallistfocusmodel-methods-set_item_count"></a>

### `set_item_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_item_count(p_item_count: int, repair_focus_enabled: bool = true) -> bool:
```

设置条目数量，并按需修正当前焦点。

参数：

| 名称 | 说明 |
|---|---|
| `p_item_count` | 条目数量。 |
| `repair_focus_enabled` | 是否修正越界或不可聚焦的当前焦点。 |

返回：条目数量或焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-set_focused_index"></a>

### `set_focused_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_focused_index(item_index: int) -> bool:
```

设置当前虚拟焦点索引。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 目标条目索引；传入 NO_FOCUS 会清空焦点。 |

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-clear_focus"></a>

### `clear_focus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_focus() -> bool:
```

清空当前虚拟焦点。

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-has_focus"></a>

### `has_focus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_focus() -> bool:
```

判断当前是否有虚拟焦点。

返回：当前存在有效焦点时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-focus_first"></a>

### `focus_first`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func focus_first() -> bool:
```

聚焦第一个可聚焦条目。

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-focus_last"></a>

### `focus_last`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func focus_last() -> bool:
```

聚焦最后一个可聚焦条目。

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-move_focus"></a>

### `move_focus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func move_focus(step: int) -> bool:
```

按可聚焦条目步进移动焦点。 step 为正时向后移动，为负时向前移动；绝对值表示跨过多少个可聚焦条目。 当前没有焦点时，正向移动会聚焦第一个可聚焦条目，反向移动会聚焦最后一个。

参数：

| 名称 | 说明 |
|---|---|
| `step` | 移动步数。 |

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-focus_next"></a>

### `focus_next`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func focus_next() -> bool:
```

聚焦下一个可聚焦条目。

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-focus_previous"></a>

### `focus_previous`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func focus_previous() -> bool:
```

聚焦上一个可聚焦条目。

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-repair_focus"></a>

### `repair_focus`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func repair_focus(preferred_index: int = NO_FOCUS) -> bool:
```

根据当前条目数量和可聚焦规则修正焦点。

参数：

| 名称 | 说明 |
|---|---|
| `preferred_index` | 优先尝试的索引；无偏好时传 NO_FOCUS。 |

返回：焦点发生变化时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-is_focusable"></a>

### `is_focusable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_focusable(item_index: int) -> bool:
```

判断某个条目索引是否可聚焦。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：可聚焦时返回 true。

<a id="member-gfvirtuallistfocusmodel-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取焦点模型调试快照。

返回：焦点状态字典。

结构：

- `return`: Dictionary，包含 item_count、focused_index、has_focus、wrap_navigation 和 auto_focus_on_count_change。
