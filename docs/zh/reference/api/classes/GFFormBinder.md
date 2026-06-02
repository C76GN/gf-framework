# GFFormBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_form_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

轻量 Control 表单读写绑定器。 将 StringName 字段映射到 Control 节点，提供批量 read/write 和变化信号。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`field_changed`](#member-gfformbinder-signals-field_changed) | `signal field_changed(key: StringName, value: Variant)` |
| 方法 | [`bind_field`](#member-gfformbinder-methods-bind_field) | `func bind_field(key: StringName, control: Control, default_value: Variant = null) -> void:` |
| 方法 | [`unbind_field`](#member-gfformbinder-methods-unbind_field) | `func unbind_field(key: StringName) -> void:` |
| 方法 | [`clear`](#member-gfformbinder-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_bound_fields`](#member-gfformbinder-methods-get_bound_fields) | `func get_bound_fields() -> Array[StringName]:` |
| 方法 | [`get_field_value`](#member-gfformbinder-methods-get_field_value) | `func get_field_value(key: StringName, fallback: Variant = null) -> Variant:` |
| 方法 | [`set_field_value`](#member-gfformbinder-methods-set_field_value) | `func set_field_value(key: StringName, value: Variant) -> bool:` |
| 方法 | [`read_values`](#member-gfformbinder-methods-read_values) | `func read_values() -> Dictionary:` |
| 方法 | [`write_values`](#member-gfformbinder-methods-write_values) | `func write_values(data: Dictionary, ignore_missing_fields: bool = true) -> void:` |

## 信号

<a id="member-gfformbinder-signals-field_changed"></a>

### `field_changed`

- API：`public`

```gdscript
signal field_changed(key: StringName, value: Variant)
```

字段值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段键。 |
| `value` | 当前控件值。 |

结构：

- `value`: Variant，当前控件值，类型取决于绑定控件。

## 方法

<a id="member-gfformbinder-methods-bind_field"></a>

### `bind_field`

- API：`public`

```gdscript
func bind_field(key: StringName, control: Control, default_value: Variant = null) -> void:
```

绑定字段到控件。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段键。 |
| `control` | 控件节点。 |
| `default_value` | 控件失效或读取失败时的默认值。 |

结构：

- `default_value`: Variant，控件失效或读取失败时返回的默认值。

<a id="member-gfformbinder-methods-unbind_field"></a>

### `unbind_field`

- API：`public`

```gdscript
func unbind_field(key: StringName) -> void:
```

解绑字段。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段键。 |

<a id="member-gfformbinder-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有字段绑定。

<a id="member-gfformbinder-methods-get_bound_fields"></a>

### `get_bound_fields`

- API：`public`

```gdscript
func get_bound_fields() -> Array[StringName]:
```

获取绑定字段列表。

返回：字段键数组。

<a id="member-gfformbinder-methods-get_field_value"></a>

### `get_field_value`

- API：`public`

```gdscript
func get_field_value(key: StringName, fallback: Variant = null) -> Variant:
```

读取单个字段值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段键。 |
| `fallback` | 回退值。 |

返回：字段值。

结构：

- `fallback`: Variant，字段未绑定或控件无法读取时返回的回退值。
- `return`: Variant，字段当前值；无法读取时返回 fallback。

<a id="member-gfformbinder-methods-set_field_value"></a>

### `set_field_value`

- API：`public`

```gdscript
func set_field_value(key: StringName, value: Variant) -> bool:
```

写入单个字段值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段键。 |
| `value` | 字段值。 |

返回：成功写入时返回 true。

结构：

- `value`: Variant，要写入绑定控件的字段值。

<a id="member-gfformbinder-methods-read_values"></a>

### `read_values`

- API：`public`

```gdscript
func read_values() -> Dictionary:
```

读取全部字段值。

返回：字段值字典。

结构：

- `return`: Dictionary，键为字段 StringName，值为对应控件当前值。

<a id="member-gfformbinder-methods-write_values"></a>

### `write_values`

- API：`public`

```gdscript
func write_values(data: Dictionary, ignore_missing_fields: bool = true) -> void:
```

批量写入字段值。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字段值字典。 |
| `ignore_missing_fields` | true 时忽略未绑定字段，false 时输出 warning。 |

结构：

- `data`: Dictionary，键为字段名，值为要写入绑定控件的字段值。
