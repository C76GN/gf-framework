# GFRuntimeTunableProperty

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_runtime_tunable_property.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

运行时可调属性声明。 用显式 schema 描述一个目标对象上允许被运行时工具读取或写入的属性。 它不自动扫描业务对象，也不决定具体调参界面。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueKind`](#member-gfruntimetunableproperty-enums-valuekind) | `enum ValueKind` |
| 属性 | [`property_id`](#member-gfruntimetunableproperty-properties-property_id) | `var property_id: StringName = &""` |
| 属性 | [`label`](#member-gfruntimetunableproperty-properties-label) | `var label: String = ""` |
| 属性 | [`group`](#member-gfruntimetunableproperty-properties-group) | `var group: String = "Runtime"` |
| 属性 | [`property_name`](#member-gfruntimetunableproperty-properties-property_name) | `var property_name: NodePath = NodePath("")` |
| 属性 | [`value_kind`](#member-gfruntimetunableproperty-properties-value_kind) | `var value_kind: ValueKind = ValueKind.ANY` |
| 属性 | [`read_only`](#member-gfruntimetunableproperty-properties-read_only) | `var read_only: bool = false` |
| 属性 | [`visible`](#member-gfruntimetunableproperty-properties-visible) | `var visible: bool = true` |
| 属性 | [`has_min_value`](#member-gfruntimetunableproperty-properties-has_min_value) | `var has_min_value: bool = false` |
| 属性 | [`min_value`](#member-gfruntimetunableproperty-properties-min_value) | `var min_value: float = 0.0` |
| 属性 | [`has_max_value`](#member-gfruntimetunableproperty-properties-has_max_value) | `var has_max_value: bool = false` |
| 属性 | [`max_value`](#member-gfruntimetunableproperty-properties-max_value) | `var max_value: float = 0.0` |
| 属性 | [`step`](#member-gfruntimetunableproperty-properties-step) | `var step: float = 1.0` |
| 属性 | [`options`](#member-gfruntimetunableproperty-properties-options) | `var options: Array = []` |
| 属性 | [`metadata`](#member-gfruntimetunableproperty-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`getter`](#member-gfruntimetunableproperty-properties-getter) | `var getter: Callable` |
| 属性 | [`setter`](#member-gfruntimetunableproperty-properties-setter) | `var setter: Callable` |
| 属性 | [`validator`](#member-gfruntimetunableproperty-properties-validator) | `var validator: Callable` |
| 方法 | [`setup`](#member-gfruntimetunableproperty-methods-setup) | `func setup( p_property_id: StringName, p_property_name: NodePath = NodePath(""), p_value_kind: ValueKind = ValueKind.ANY ) -> GFRuntimeTunableProperty:` |
| 方法 | [`with_range`](#member-gfruntimetunableproperty-methods-with_range) | `func with_range(p_min_value: float, p_max_value: float, p_step: float = 1.0) -> GFRuntimeTunableProperty:` |
| 方法 | [`with_options`](#member-gfruntimetunableproperty-methods-with_options) | `func with_options(p_options: Array) -> GFRuntimeTunableProperty:` |
| 方法 | [`read_value`](#member-gfruntimetunableproperty-methods-read_value) | `func read_value(target: Object) -> Variant:` |
| 方法 | [`write_value`](#member-gfruntimetunableproperty-methods-write_value) | `func write_value(target: Object, value: Variant) -> bool:` |
| 方法 | [`normalize_value`](#member-gfruntimetunableproperty-methods-normalize_value) | `func normalize_value(value: Variant) -> Variant:` |
| 方法 | [`to_schema`](#member-gfruntimetunableproperty-methods-to_schema) | `func to_schema() -> Dictionary:` |

## 枚举

<a id="member-gfruntimetunableproperty-enums-valuekind"></a>

### `ValueKind`

- API：`public`

```gdscript
enum ValueKind { ## 不转换类型。 ANY, ## 布尔值。 BOOL, ## 整数。 INT, ## 浮点数。 FLOAT, ## 字符串。 STRING, ## StringName。 STRING_NAME, ## Vector2。 VECTOR2, ## Vector3。 VECTOR3, ## Color。 COLOR, }
```

运行时值类型约束。

## 属性

<a id="member-gfruntimetunableproperty-properties-property_id"></a>

### `property_id`

- API：`public`

```gdscript
var property_id: StringName = &""
```

属性 ID，在同一目标内必须唯一。

<a id="member-gfruntimetunableproperty-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

展示标签；为空时使用 property_id。

<a id="member-gfruntimetunableproperty-properties-group"></a>

### `group`

- API：`public`

```gdscript
var group: String = "Runtime"
```

展示分组。

<a id="member-gfruntimetunableproperty-properties-property_name"></a>

### `property_name`

- API：`public`

```gdscript
var property_name: NodePath = NodePath("")
```

目标对象上的属性路径。使用 getter/setter 回调时可为空。

<a id="member-gfruntimetunableproperty-properties-value_kind"></a>

### `value_kind`

- API：`public`

```gdscript
var value_kind: ValueKind = ValueKind.ANY
```

值类型约束。

<a id="member-gfruntimetunableproperty-properties-read_only"></a>

### `read_only`

- API：`public`

```gdscript
var read_only: bool = false
```

是否只读。

<a id="member-gfruntimetunableproperty-properties-visible"></a>

### `visible`

- API：`public`

```gdscript
var visible: bool = true
```

是否默认出现在快照中。

<a id="member-gfruntimetunableproperty-properties-has_min_value"></a>

### `has_min_value`

- API：`public`

```gdscript
var has_min_value: bool = false
```

是否启用最小值限制，仅对 int/float 生效。

<a id="member-gfruntimetunableproperty-properties-min_value"></a>

### `min_value`

- API：`public`

```gdscript
var min_value: float = 0.0
```

最小值。

<a id="member-gfruntimetunableproperty-properties-has_max_value"></a>

### `has_max_value`

- API：`public`

```gdscript
var has_max_value: bool = false
```

是否启用最大值限制，仅对 int/float 生效。

<a id="member-gfruntimetunableproperty-properties-max_value"></a>

### `max_value`

- API：`public`

```gdscript
var max_value: float = 0.0
```

最大值。

<a id="member-gfruntimetunableproperty-properties-step"></a>

### `step`

- API：`public`

```gdscript
var step: float = 1.0
```

建议步长，仅供 UI 使用。

<a id="member-gfruntimetunableproperty-properties-options"></a>

### `options`

- API：`public`

```gdscript
var options: Array = []
```

可选值列表。非空时写入值必须归一到列表内。

结构：

- `options`: Array，保存允许写入的候选值。

<a id="member-gfruntimetunableproperty-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据。

结构：

- `metadata`: Dictionary，保存项目自定义属性元数据。

<a id="member-gfruntimetunableproperty-properties-getter"></a>

### `getter`

- API：`public`

```gdscript
var getter: Callable
```

可选读取回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty) -> Variant`。

<a id="member-gfruntimetunableproperty-properties-setter"></a>

### `setter`

- API：`public`

```gdscript
var setter: Callable
```

可选写入回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty, value: Variant) -> void`。

<a id="member-gfruntimetunableproperty-properties-validator"></a>

### `validator`

- API：`public`

```gdscript
var validator: Callable
```

可选校验回调，签名为 `func(target: Object, property: GFRuntimeTunableProperty, value: Variant) -> bool`。

## 方法

<a id="member-gfruntimetunableproperty-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup( p_property_id: StringName, p_property_name: NodePath = NodePath(""), p_value_kind: ValueKind = ValueKind.ANY ) -> GFRuntimeTunableProperty:
```

设置基础字段并返回自身，便于代码构造 schema。

参数：

| 名称 | 说明 |
|---|---|
| `p_property_id` | 属性 ID。 |
| `p_property_name` | 目标属性路径。 |
| `p_value_kind` | 值类型约束。 |

返回：当前属性声明。

<a id="member-gfruntimetunableproperty-methods-with_range"></a>

### `with_range`

- API：`public`

```gdscript
func with_range(p_min_value: float, p_max_value: float, p_step: float = 1.0) -> GFRuntimeTunableProperty:
```

设置数值范围并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_min_value` | 最小值。 |
| `p_max_value` | 最大值。 |
| `p_step` | 建议步长。 |

返回：当前属性声明。

<a id="member-gfruntimetunableproperty-methods-with_options"></a>

### `with_options`

- API：`public`

```gdscript
func with_options(p_options: Array) -> GFRuntimeTunableProperty:
```

设置可选值列表并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_options` | 可选值列表。 |

返回：当前属性声明。

结构：

- `p_options`: Array，保存允许写入的候选值。

<a id="member-gfruntimetunableproperty-methods-read_value"></a>

### `read_value`

- API：`public`

```gdscript
func read_value(target: Object) -> Variant:
```

读取目标对象当前值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |

返回：当前值；无法读取时返回 null。

结构：

- `return`: Variant，类型由 value_kind 和实际目标属性决定。

<a id="member-gfruntimetunableproperty-methods-write_value"></a>

### `write_value`

- API：`public`

```gdscript
func write_value(target: Object, value: Variant) -> bool:
```

写入目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `value` | 请求写入的值。 |

返回：写入成功返回 true。

结构：

- `value`: Variant，请求写入的原始值，会按 value_kind 和范围配置归一化。

<a id="member-gfruntimetunableproperty-methods-normalize_value"></a>

### `normalize_value`

- API：`public`

```gdscript
func normalize_value(value: Variant) -> Variant:
```

根据 schema 归一化写入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：归一化后的值。

结构：

- `value`: Variant，输入值。
- `return`: Variant，归一化后的值，类型由 value_kind 决定。

<a id="member-gfruntimetunableproperty-methods-to_schema"></a>

### `to_schema`

- API：`public`

```gdscript
func to_schema() -> Dictionary:
```

生成可序列化 schema 快照。

返回：schema 字典。

结构：

- `return`: Dictionary，包含 property_id、label、group、property_name、value_kind、read_only、visible、has_min_value、min_value、has_max_value、max_value、step、options 和 metadata 字段。
