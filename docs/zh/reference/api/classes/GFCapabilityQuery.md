# GFCapabilityQuery

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/core/gf_capability_query.gd`
- 模块：`Capability`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

可资源化的能力接收者查询条件。 用于把 required / rejected 能力类型、分组和子类匹配策略保存为 Resource， 便于编辑器工具、配置资源或项目脚本复用同一套查询声明。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`required_capability_types`](#member-gfcapabilityquery-properties-required_capability_types) | `var required_capability_types: Array[Script] = []` |
| 属性 | [`rejected_capability_types`](#member-gfcapabilityquery-properties-rejected_capability_types) | `var rejected_capability_types: Array[Script] = []` |
| 属性 | [`include_subclasses`](#member-gfcapabilityquery-properties-include_subclasses) | `var include_subclasses: bool = true` |
| 属性 | [`group_name`](#member-gfcapabilityquery-properties-group_name) | `var group_name: StringName = &""` |
| 属性 | [`metadata`](#member-gfcapabilityquery-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_receivers`](#member-gfcapabilityquery-methods-get_receivers) | `func get_receivers(capability_utility: GFCapabilityUtility) -> Array[Object]:` |
| 方法 | [`matches_receiver`](#member-gfcapabilityquery-methods-matches_receiver) | `func matches_receiver(capability_utility: GFCapabilityUtility, receiver: Object) -> bool:` |
| 方法 | [`duplicate_query`](#member-gfcapabilityquery-methods-duplicate_query) | `func duplicate_query() -> GFCapabilityQuery:` |
| 方法 | [`describe_query`](#member-gfcapabilityquery-methods-describe_query) | `func describe_query() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfcapabilityquery-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfcapabilityquery-properties-required_capability_types"></a>

### `required_capability_types`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var required_capability_types: Array[Script] = []
```

查询必须拥有的能力类型列表。

结构：

- `required_capability_types`: Array[Script]，元素为必须拥有的能力脚本类型。

<a id="member-gfcapabilityquery-properties-rejected_capability_types"></a>

### `rejected_capability_types`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var rejected_capability_types: Array[Script] = []
```

查询必须排除的能力类型列表。

结构：

- `rejected_capability_types`: Array[Script]，元素为必须排除的能力脚本类型。

<a id="member-gfcapabilityquery-properties-include_subclasses"></a>

### `include_subclasses`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var include_subclasses: bool = true
```

是否在 required / rejected 匹配中包含子类能力。

<a id="member-gfcapabilityquery-properties-group_name"></a>

### `group_name`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var group_name: StringName = &""
```

可选能力分组；非空时只在该分组内查询。

<a id="member-gfcapabilityquery-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目或工具自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目或工具附加信息。

## 方法

<a id="member-gfcapabilityquery-methods-get_receivers"></a>

### `get_receivers`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_receivers(capability_utility: GFCapabilityUtility) -> Array[Object]:
```

使用指定 Utility 执行当前查询。

参数：

| 名称 | 说明 |
|---|---|
| `capability_utility` | 能力 Utility。 |

返回：当前仍有效且满足条件的 receiver 列表。

结构：

- `return`: Array[Object]，元素为当前仍有效的能力接收对象。

<a id="member-gfcapabilityquery-methods-matches_receiver"></a>

### `matches_receiver`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func matches_receiver(capability_utility: GFCapabilityUtility, receiver: Object) -> bool:
```

判断指定 receiver 是否满足当前查询。

参数：

| 名称 | 说明 |
|---|---|
| `capability_utility` | 能力 Utility。 |
| `receiver` | 要检查的能力接收对象。 |

返回：满足查询返回 true。

<a id="member-gfcapabilityquery-methods-duplicate_query"></a>

### `duplicate_query`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func duplicate_query() -> GFCapabilityQuery:
```

创建同内容查询拷贝。

返回：新查询资源。

<a id="member-gfcapabilityquery-methods-describe_query"></a>

### `describe_query`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func describe_query() -> Dictionary:
```

导出查询声明摘要。

返回：查询声明字典。

结构：

- `return`: Dictionary，包含 required_capability_types、rejected_capability_types、include_subclasses、group_name 和 metadata。

<a id="member-gfcapabilityquery-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
```

导出查询声明的 JSON-safe 报告快照。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：查询报告字典。

结构：

- `options`: Dictionary with GFReportValueCodec encoding options.
- `return`: JSON-safe Dictionary based on describe_query().
