# GFFlowPort

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/resources/gf_flow_port.gd`
- 模块：`Flow`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

流程节点端口描述。 端口只描述节点对外暴露的输入/输出能力，供编辑器、校验器或项目层 构建可视化流程使用；运行时如何解释端口数据仍由具体节点决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Direction`](#member-gfflowport-enums-direction) | `enum Direction` |
| 枚举 | [`ValueType`](#member-gfflowport-enums-valuetype) | `enum ValueType` |
| 属性 | [`port_id`](#member-gfflowport-properties-port_id) | `var port_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfflowport-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`direction`](#member-gfflowport-properties-direction) | `var direction: Direction = Direction.OUTPUT` |
| 属性 | [`value_type`](#member-gfflowport-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`allow_multiple`](#member-gfflowport-properties-allow_multiple) | `var allow_multiple: bool = false` |
| 属性 | [`editor_color`](#member-gfflowport-properties-editor_color) | `var editor_color: Color = Color.TRANSPARENT` |
| 属性 | [`type_hint`](#member-gfflowport-properties-type_hint) | `var type_hint: StringName = &""` |
| 属性 | [`class_name_hint`](#member-gfflowport-properties-class_name_hint) | `var class_name_hint: StringName = &""` |
| 属性 | [`semantic_tags`](#member-gfflowport-properties-semantic_tags) | `var semantic_tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfflowport-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_port_id`](#member-gfflowport-methods-get_port_id) | `func get_port_id() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfflowport-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`has_semantic_tag`](#member-gfflowport-methods-has_semantic_tag) | `func has_semantic_tag(tag: StringName) -> bool:` |
| 方法 | [`is_compatible_with`](#member-gfflowport-methods-is_compatible_with) | `func is_compatible_with(target_port: GFFlowPort) -> bool:` |
| 方法 | [`get_compatibility_report`](#member-gfflowport-methods-get_compatibility_report) | `func get_compatibility_report(target_port: GFFlowPort) -> Dictionary:` |
| 方法 | [`describe`](#member-gfflowport-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfflowport-enums-direction"></a>

### `Direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum Direction {
	## 输入端口。
	INPUT,
	## 输出端口。
	OUTPUT,
}
```

端口方向。

<a id="member-gfflowport-enums-valuetype"></a>

### `ValueType`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum ValueType {
	## 任意值。
	ANY,
	## 布尔。
	BOOL,
	## 数值。
	NUMBER,
	## 字符串。
	STRING,
	## Vector2。
	VECTOR2,
	## Vector3。
	VECTOR3,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
	## Object 或 Resource。
	OBJECT,
}
```

端口值类型提示。

## 属性

<a id="member-gfflowport-properties-port_id"></a>

### `port_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var port_id: StringName = &""
```

端口稳定标识。

<a id="member-gfflowport-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var display_name: String = ""
```

显示名称。

<a id="member-gfflowport-properties-direction"></a>

### `direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var direction: Direction = Direction.OUTPUT
```

端口方向。

<a id="member-gfflowport-properties-value_type"></a>

### `value_type`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var value_type: ValueType = ValueType.ANY
```

值类型提示。

<a id="member-gfflowport-properties-allow_multiple"></a>

### `allow_multiple`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var allow_multiple: bool = false
```

是否允许多条连接。

<a id="member-gfflowport-properties-editor_color"></a>

### `editor_color`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var editor_color: Color = Color.TRANSPARENT
```

编辑器或可视化工具使用的端口颜色。透明色表示由工具自行决定。

<a id="member-gfflowport-properties-type_hint"></a>

### `type_hint`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var type_hint: StringName = &""
```

更细粒度的值类型提示，例如项目自定义数据结构名。框架不解释该字段。

<a id="member-gfflowport-properties-class_name_hint"></a>

### `class_name_hint`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var class_name_hint: StringName = &""
```

Object / Resource 端口的类名提示。仅在项目或校验器显式使用时参与兼容性判断。

<a id="member-gfflowport-properties-semantic_tags"></a>

### `semantic_tags`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var semantic_tags: PackedStringArray = PackedStringArray()
```

语义标签列表，供搜索、编辑器过滤或项目工具使用。

<a id="member-gfflowport-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfflowport-methods-get_port_id"></a>

### `get_port_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_port_id() -> StringName:
```

获取端口标识。

返回：端口标识。

<a id="member-gfflowport-methods-get_display_name"></a>

### `get_display_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_display_name() -> String:
```

获取显示名称。

返回：显示名称。

<a id="member-gfflowport-methods-has_semantic_tag"></a>

### `has_semantic_tag`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func has_semantic_tag(tag: StringName) -> bool:
```

检查是否包含语义标签。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签。 |

返回：包含返回 true。

<a id="member-gfflowport-methods-is_compatible_with"></a>

### `is_compatible_with`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_compatible_with(target_port: GFFlowPort) -> bool:
```

判断当前端口是否可连接到目标端口。

参数：

| 名称 | 说明 |
|---|---|
| `target_port` | 目标端口。 |

返回：兼容返回 true。

<a id="member-gfflowport-methods-get_compatibility_report"></a>

### `get_compatibility_report`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_compatibility_report(target_port: GFFlowPort) -> Dictionary:
```

获取当前端口连接到目标端口的兼容性报告。

参数：

| 名称 | 说明 |
|---|---|
| `target_port` | 目标端口。 |

返回：兼容性报告。

结构：

- `return`: 包含 ok、reason、message、source_port_id、source_value_type、target_port_id 和 target_value_type 字段的 Dictionary。

<a id="member-gfflowport-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe() -> Dictionary:
```

描述端口。

返回：端口描述字典。

结构：

- `return`: 包含 port_id、display_name、direction、value_type、allow_multiple、editor_color、type_hint、class_name_hint、semantic_tags 和 metadata 字段的 Dictionary。
