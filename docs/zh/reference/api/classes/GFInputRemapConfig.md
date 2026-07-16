# GFInputRemapConfig

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/rebinding/gf_input_remap_config.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入重映射配置。 只保存玩家或项目层覆盖过的输入事件，默认绑定仍来自 GFInputContext。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`remapped_events`](#member-gfinputremapconfig-properties-remapped_events) | `var remapped_events: Dictionary = {}` |
| 属性 | [`custom_data`](#member-gfinputremapconfig-properties-custom_data) | `var custom_data: Dictionary = {}` |
| 方法 | [`set_binding`](#member-gfinputremapconfig-methods-set_binding) | `func set_binding( context_id: StringName, action_id: StringName, binding_index: int, input_event: InputEvent ) -> void:` |
| 方法 | [`unbind`](#member-gfinputremapconfig-methods-unbind) | `func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:` |
| 方法 | [`clear_binding`](#member-gfinputremapconfig-methods-clear_binding) | `func clear_binding(context_id: StringName, action_id: StringName, binding_index: int) -> void:` |
| 方法 | [`has_binding`](#member-gfinputremapconfig-methods-has_binding) | `func has_binding(context_id: StringName, action_id: StringName, binding_index: int) -> bool:` |
| 方法 | [`get_bound_event_or_null`](#member-gfinputremapconfig-methods-get_bound_event_or_null) | `func get_bound_event_or_null(context_id: StringName, action_id: StringName, binding_index: int) -> InputEvent:` |
| 方法 | [`set_custom_data`](#member-gfinputremapconfig-methods-set_custom_data) | `func set_custom_data(key: Variant, value: Variant) -> void:` |
| 方法 | [`get_custom_data`](#member-gfinputremapconfig-methods-get_custom_data) | `func get_custom_data(key: Variant, default_value: Variant = null) -> Variant:` |
| 方法 | [`to_dict`](#member-gfinputremapconfig-methods-to_dict) | `func to_dict(json_compatible: bool = true) -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinputremapconfig-methods-apply_dict) | `func apply_dict(data: Dictionary, json_compatible: bool = true) -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfinputremapconfig-methods-from_dict) | `static func from_dict(data: Dictionary, json_compatible: bool = true) -> GFInputRemapConfig:` |
| 方法 | [`duplicate_config`](#member-gfinputremapconfig-methods-duplicate_config) | `func duplicate_config() -> GFInputRemapConfig:` |

## 属性

<a id="member-gfinputremapconfig-properties-remapped_events"></a>

### `remapped_events`

- API：`public`

```gdscript
var remapped_events: Dictionary = {}
```

重绑定输入。结构为 context_id -> action_id -> binding_index -> InputEvent 或 null。

结构：

- `remapped_events`: Dictionary，按 context_id、action_id、binding_index 分层索引，值为 InputEvent 或表示显式解绑的 null。

<a id="member-gfinputremapconfig-properties-custom_data"></a>

### `custom_data`

- API：`public`

```gdscript
var custom_data: Dictionary = {}
```

项目自定义数据。框架不解释该字段。

结构：

- `custom_data`: Dictionary，项目持有的 profile 标签、设备元数据或 UI 状态。

## 方法

<a id="member-gfinputremapconfig-methods-set_binding"></a>

### `set_binding`

- API：`public`

```gdscript
func set_binding( context_id: StringName, action_id: StringName, binding_index: int, input_event: InputEvent ) -> void:
```

设置绑定覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |
| `input_event` | 新输入事件；null 表示显式解绑。 |

<a id="member-gfinputremapconfig-methods-unbind"></a>

### `unbind`

- API：`public`

```gdscript
func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:
```

显式解绑某个绑定。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

<a id="member-gfinputremapconfig-methods-clear_binding"></a>

### `clear_binding`

- API：`public`

```gdscript
func clear_binding(context_id: StringName, action_id: StringName, binding_index: int) -> void:
```

清除某个覆盖，使其回退到默认绑定。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

<a id="member-gfinputremapconfig-methods-has_binding"></a>

### `has_binding`

- API：`public`

```gdscript
func has_binding(context_id: StringName, action_id: StringName, binding_index: int) -> bool:
```

检查是否存在覆盖记录。显式解绑也会返回 true。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

返回：是否存在覆盖。

<a id="member-gfinputremapconfig-methods-get_bound_event_or_null"></a>

### `get_bound_event_or_null`

- API：`public`

```gdscript
func get_bound_event_or_null(context_id: StringName, action_id: StringName, binding_index: int) -> InputEvent:
```

获取覆盖输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

返回：覆盖事件；显式解绑或未覆盖时均可能返回 null，应先调用 has_binding() 区分。

<a id="member-gfinputremapconfig-methods-set_custom_data"></a>

### `set_custom_data`

- API：`public`

```gdscript
func set_custom_data(key: Variant, value: Variant) -> void:
```

设置自定义数据。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `value` | 值。 |

结构：

- `key`: Variant，项目侧自定义数据键。
- `value`: Variant，项目侧自定义数据值。

<a id="member-gfinputremapconfig-methods-get_custom_data"></a>

### `get_custom_data`

- API：`public`

```gdscript
func get_custom_data(key: Variant, default_value: Variant = null) -> Variant:
```

获取自定义数据。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `default_value` | 默认值。 |

返回：自定义数据。

结构：

- `key`: Variant，项目侧自定义数据键。
- `default_value`: Variant，key 不存在时返回的默认值。
- `return`: Variant，自定义数据值或 default_value。

<a id="member-gfinputremapconfig-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict(json_compatible: bool = true) -> Dictionary:
```

转换为可写入 JSON/存档的 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时将 custom_data 转为 JSON 兼容值。 |

返回：重映射配置字典。

结构：

- `return`: Dictionary，包含 remapped_events 和 custom_data；remapped_events 为 context_id -> action_id -> binding_index -> event record。

<a id="member-gfinputremapconfig-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary, json_compatible: bool = true) -> Dictionary:
```

应用由 to_dict() 生成的重映射配置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 重映射配置字典。 |
| `json_compatible` | 为 true 时会先恢复 custom_data 的 JSON 兼容值。 |

返回：应用报告；任一记录无效时不修改当前配置。

结构：

- `data`: Dictionary，包含 remapped_events 和 custom_data。
- `return`: Dictionary with ok, committed, binding_count, bound_count, unbound_count, and issues.

<a id="member-gfinputremapconfig-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary, json_compatible: bool = true) -> GFInputRemapConfig:
```

从 Dictionary 创建重映射配置。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 重映射配置字典。 |
| `json_compatible` | 为 true 时会先恢复 custom_data 的 JSON 兼容值。 |

返回：新重映射配置。

结构：

- `data`: Dictionary，包含 remapped_events 和 custom_data。

<a id="member-gfinputremapconfig-methods-duplicate_config"></a>

### `duplicate_config`

- API：`public`

```gdscript
func duplicate_config() -> GFInputRemapConfig:
```

复制重映射配置。

返回：深拷贝后的重映射配置。
