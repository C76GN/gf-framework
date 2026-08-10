# GFDragSession

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/drag_drop/gf_drag_session.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用拖拽会话数据。 描述一次拖拽从开始到释放的稳定上下文，不绑定具体 UI、背包、棋盘、 关卡编辑器或任何业务对象。项目可把任意 payload 放入会话，再由落点规则解释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`session_id`](#member-gfdragsession-properties-session_id) | `var session_id: int = -1` |
| 属性 | [`drag_type`](#member-gfdragsession-properties-drag_type) | `var drag_type: StringName = &""` |
| 属性 | [`payload`](#member-gfdragsession-properties-payload) | `var payload: Variant = null` |
| 属性 | [`start_position`](#member-gfdragsession-properties-start_position) | `var start_position: Vector2 = Vector2.ZERO` |
| 属性 | [`current_position`](#member-gfdragsession-properties-current_position) | `var current_position: Vector2 = Vector2.ZERO` |
| 属性 | [`previous_position`](#member-gfdragsession-properties-previous_position) | `var previous_position: Vector2 = Vector2.ZERO` |
| 属性 | [`metadata`](#member-gfdragsession-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`setup`](#member-gfdragsession-methods-setup) | `func setup( new_session_id: int, new_drag_type: StringName, new_payload: Variant, position: Vector2, source: Object = null, new_metadata: Dictionary = {} ) -> void:` |
| 方法 | [`update_position`](#member-gfdragsession-methods-update_position) | `func update_position(position: Vector2) -> void:` |
| 方法 | [`get_delta`](#member-gfdragsession-methods-get_delta) | `func get_delta() -> Vector2:` |
| 方法 | [`get_source`](#member-gfdragsession-methods-get_source) | `func get_source() -> Object:` |
| 方法 | [`to_dictionary`](#member-gfdragsession-methods-to_dictionary) | `func to_dictionary(json_compatible: bool = true) -> Dictionary:` |

## 属性

<a id="member-gfdragsession-properties-session_id"></a>

### `session_id`

- API：`public`

```gdscript
var session_id: int = -1
```

会话 ID，由 GFDragDropUtility 分配。

<a id="member-gfdragsession-properties-drag_type"></a>

### `drag_type`

- API：`public`

```gdscript
var drag_type: StringName = &""
```

拖拽类型。落点可用它做通用接收过滤。

<a id="member-gfdragsession-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

项目自定义载荷。框架不解释该字段。

结构：

- `payload`: Variant，透传给 drop zone 的项目侧拖拽载荷。

<a id="member-gfdragsession-properties-start_position"></a>

### `start_position`

- API：`public`

```gdscript
var start_position: Vector2 = Vector2.ZERO
```

起始位置，通常是屏幕或画布坐标。

<a id="member-gfdragsession-properties-current_position"></a>

### `current_position`

- API：`public`

```gdscript
var current_position: Vector2 = Vector2.ZERO
```

当前指针位置。

<a id="member-gfdragsession-properties-previous_position"></a>

### `previous_position`

- API：`public`

```gdscript
var previous_position: Vector2 = Vector2.ZERO
```

上一次位置。

<a id="member-gfdragsession-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架只负责复制和透传。

结构：

- `metadata`: Dictionary，复制到拖拽会话中的项目侧元数据。

## 方法

<a id="member-gfdragsession-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup( new_session_id: int, new_drag_type: StringName, new_payload: Variant, position: Vector2, source: Object = null, new_metadata: Dictionary = {} ) -> void:
```

初始化会话。

参数：

| 名称 | 说明 |
|---|---|
| `new_session_id` | 会话 ID。 |
| `new_drag_type` | 拖拽类型。 |
| `new_payload` | 项目自定义载荷。 |
| `position` | 起始位置。 |
| `source` | 可选来源对象。 |
| `new_metadata` | 项目自定义元数据。 |

结构：

- `new_payload`: Variant，透传给 drop zone 的项目侧拖拽载荷。
- `new_metadata`: Dictionary，复制到拖拽会话中的项目侧元数据。

<a id="member-gfdragsession-methods-update_position"></a>

### `update_position`

- API：`public`

```gdscript
func update_position(position: Vector2) -> void:
```

更新当前拖拽位置。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 新位置。 |

<a id="member-gfdragsession-methods-get_delta"></a>

### `get_delta`

- API：`public`

```gdscript
func get_delta() -> Vector2:
```

获取本次更新的位移。

返回：当前和上一次位置的差值。

<a id="member-gfdragsession-methods-get_source"></a>

### `get_source`

- API：`public`

```gdscript
func get_source() -> Object:
```

获取来源对象。

返回：来源仍有效时返回对象，否则返回 null。

<a id="member-gfdragsession-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary(json_compatible: bool = true) -> Dictionary:
```

转换为调试字典。 JSON 模式直接经过带循环检测和遍历预算的 GFVariantJsonCodec，不会在 codec 前对 metadata 执行无界原生深复制，也不会在编码异常时回退原始对象。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时返回可直接 JSON.stringify() 的值。 |

返回：会话快照。

结构：

- `return`: Dictionary，包含 session_id、drag_type、start_position、current_position、previous_position、delta、has_source 和 metadata。
