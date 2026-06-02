# GFDropZone

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/drag_drop/gf_drop_zone.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用拖拽落点规则。 落点只描述“某个位置是否命中、某个会话是否可接收、接收时如何返回结果”。 它不移动节点、不修改业务数据，也不规定任何具体 UI 或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`zone_id`](#member-gfdropzone-properties-zone_id) | `var zone_id: StringName = &""` |
| 属性 | [`accepted_types`](#member-gfdropzone-properties-accepted_types) | `var accepted_types: PackedStringArray = PackedStringArray()` |
| 属性 | [`priority`](#member-gfdropzone-properties-priority) | `var priority: int = 0` |
| 属性 | [`enabled`](#member-gfdropzone-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`contains_callable`](#member-gfdropzone-properties-contains_callable) | `var contains_callable: Callable = Callable()` |
| 属性 | [`can_accept_callable`](#member-gfdropzone-properties-can_accept_callable) | `var can_accept_callable: Callable = Callable()` |
| 属性 | [`drop_callable`](#member-gfdropzone-properties-drop_callable) | `var drop_callable: Callable = Callable()` |
| 属性 | [`metadata`](#member-gfdropzone-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`contains`](#member-gfdropzone-methods-contains) | `func contains(position: Variant, session: GFDragSession) -> bool:` |
| 方法 | [`can_accept`](#member-gfdropzone-methods-can_accept) | `func can_accept(session: GFDragSession) -> bool:` |
| 方法 | [`drop`](#member-gfdropzone-methods-drop) | `func drop(session: GFDragSession, position: Variant) -> Variant:` |
| 方法 | [`to_dictionary`](#member-gfdropzone-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_rect`](#member-gfdropzone-methods-from_rect) | `static func from_rect( new_zone_id: StringName, rect: Rect2, new_accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |
| 方法 | [`from_control`](#member-gfdropzone-methods-from_control) | `static func from_control( new_zone_id: StringName, control: Control, new_accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:` |

## 属性

<a id="member-gfdropzone-properties-zone_id"></a>

### `zone_id`

- API：`public`

```gdscript
var zone_id: StringName = &""
```

落点 ID。

<a id="member-gfdropzone-properties-accepted_types"></a>

### `accepted_types`

- API：`public`

```gdscript
var accepted_types: PackedStringArray = PackedStringArray()
```

可接收的拖拽类型。为空表示不限制类型。

<a id="member-gfdropzone-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

匹配优先级。数值越大越优先。

<a id="member-gfdropzone-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用。

<a id="member-gfdropzone-properties-contains_callable"></a>

### `contains_callable`

- API：`public`

```gdscript
var contains_callable: Callable = Callable()
```

命中检测回调，签名为 func(position: Variant, session: GFDragSession) -> bool。

<a id="member-gfdropzone-properties-can_accept_callable"></a>

### `can_accept_callable`

- API：`public`

```gdscript
var can_accept_callable: Callable = Callable()
```

可接收检测回调，签名为 func(session: GFDragSession, zone: GFDropZone) -> bool。

<a id="member-gfdropzone-properties-drop_callable"></a>

### `drop_callable`

- API：`public`

```gdscript
var drop_callable: Callable = Callable()
```

接收回调，签名为 func(session: GFDragSession, zone: GFDropZone, position: Variant) -> Variant。

<a id="member-gfdropzone-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，关联到 drop zone 的项目侧元数据。

## 方法

<a id="member-gfdropzone-methods-contains"></a>

### `contains`

- API：`public`

```gdscript
func contains(position: Variant, session: GFDragSession) -> bool:
```

检查落点是否包含位置。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 位置，通常是屏幕或画布坐标。 |
| `session` | 当前拖拽会话。 |

返回：命中时返回 true。

结构：

- `position`: Variant，zone contains 回调接受的位置值。

<a id="member-gfdropzone-methods-can_accept"></a>

### `can_accept`

- API：`public`

```gdscript
func can_accept(session: GFDragSession) -> bool:
```

检查落点是否接收会话。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 当前拖拽会话。 |

返回：可接收时返回 true。

<a id="member-gfdropzone-methods-drop"></a>

### `drop`

- API：`public`

```gdscript
func drop(session: GFDragSession, position: Variant) -> Variant:
```

执行落点接收回调。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 当前拖拽会话。 |
| `position` | 释放位置。 |

返回：回调返回值；未设置回调时返回成功字典。

结构：

- `position`: Variant release position passed to the drop callback.
- `return`: Variant，由 drop 回调返回；Dictionary 会由 GFDragDropUtility 规范化。

<a id="member-gfdropzone-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为调试字典。

返回：落点快照。

结构：

- `return`: Dictionary，包含 zone_id、accepted_types、priority、enabled、回调标记和 metadata。

<a id="member-gfdropzone-methods-from_rect"></a>

### `from_rect`

- API：`public`

```gdscript
static func from_rect( new_zone_id: StringName, rect: Rect2, new_accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:
```

创建矩形落点。

参数：

| 名称 | 说明 |
|---|---|
| `new_zone_id` | 落点 ID。 |
| `rect` | 全局矩形区域。 |
| `new_accepted_types` | 可接收类型；为空表示不限制。 |
| `options` | 可选参数，支持 priority、enabled、metadata、can_accept、drop。 |

返回：新落点。

结构：

- `options`: Dictionary，包含 priority: int、enabled: bool、metadata: Dictionary、can_accept: Callable 和 drop: Callable。

<a id="member-gfdropzone-methods-from_control"></a>

### `from_control`

- API：`public`

```gdscript
static func from_control( new_zone_id: StringName, control: Control, new_accepted_types: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFDropZone:
```

创建 Control 全局矩形落点。

参数：

| 名称 | 说明 |
|---|---|
| `new_zone_id` | 落点 ID。 |
| `control` | 用于读取 get_global_rect() 的 Control。 |
| `new_accepted_types` | 可接收类型；为空表示不限制。 |
| `options` | 可选参数，支持 priority、enabled、metadata、can_accept、drop。 |

返回：新落点。

结构：

- `options`: Dictionary，包含 priority: int、enabled: bool、metadata: Dictionary、can_accept: Callable 和 drop: Callable。
