# GFConfigPipelineConsumerTarget

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_consumer_target.gd`
- 模块：`Tools`
- 继承：`Resource`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

项目声明的配置消费目标。 根表与每表可见顶层字段均显式列出。字段是完整值单元，包含其结构化类型； 不按行内容推测依赖，不通过引用自动授权其他字段。未声明表或字段默认不可见。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_id`](#member-gfconfigpipelineconsumertarget-properties-target_id) | `var target_id: StringName = &""` |
| 属性 | [`root_tables`](#member-gfconfigpipelineconsumertarget-properties-root_tables) | `var root_tables: PackedStringArray = []` |
| 属性 | [`visible_fields`](#member-gfconfigpipelineconsumertarget-properties-visible_fields) | `var visible_fields: Dictionary = {}` |
| 属性 | [`output_path`](#member-gfconfigpipelineconsumertarget-properties-output_path) | `var output_path: String = ""` |
| 属性 | [`access_output_path`](#member-gfconfigpipelineconsumertarget-properties-access_output_path) | `var access_output_path: String = ""` |
| 方法 | [`capture`](#member-gfconfigpipelineconsumertarget-methods-capture) | `func capture() -> Dictionary:` |
| 方法 | [`duplicate_target`](#member-gfconfigpipelineconsumertarget-methods-duplicate_target) | `func duplicate_target() -> GFConfigPipelineConsumerTarget:` |

## 属性

<a id="member-gfconfigpipelineconsumertarget-properties-target_id"></a>

### `target_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var target_id: StringName = &""
```

项目定义的唯一消费目标名称。

<a id="member-gfconfigpipelineconsumertarget-properties-root_tables"></a>

### `root_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var root_tables: PackedStringArray = []
```

必须纳入该目标的根表；引用闭包从这些表出发。

<a id="member-gfconfigpipelineconsumertarget-properties-visible_fields"></a>

### `visible_fields`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var visible_fields: Dictionary = {}
```

各表获准导出的完整顶层字段。引用目标同样必须声明字段。

结构：

- `visible_fields`: Dictionary[String, PackedStringArray/Array[String]]，每表非空、无重复字段名；最多4096表、每表4096字段、总计65536字段。名称非空、无控制字符、无首尾空白且最多256字符；不支持通配符或嵌套字段路径。

<a id="member-gfconfigpipelineconsumertarget-properties-output_path"></a>

### `output_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var output_path: String = ""
```

该目标数据库的输出 URI；选中目标后替代 Profile 的默认路径。

<a id="member-gfconfigpipelineconsumertarget-properties-access_output_path"></a>

### `access_output_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var access_output_path: String = ""
```

该目标的可选访问器输出 URI；空值表示不生成访问器。

## 方法

<a id="member-gfconfigpipelineconsumertarget-methods-capture"></a>

### `capture`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture() -> Dictionary:
```

验证声明并捕获隔离的纯数据，不读取表或文件。

返回：声明快照或失败原因；输出 URI 由既有输出路径策略在导出前校验。

结构：

- `return`: 封闭 Dictionary，success:bool、target:Dictionary、error:String。成功 target 含 target_id:String、root_tables:PackedStringArray（排序）、visible_fields:Dictionary[String,PackedStringArray]（字段排序）、output_path:String、access_output_path:String；失败 target 为空。

<a id="member-gfconfigpipelineconsumertarget-methods-duplicate_target"></a>

### `duplicate_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_target() -> GFConfigPipelineConsumerTarget:
```

创建独立的作者声明副本，不改变或自动修复无效声明。

返回：与当前声明隔离的副本；循环或超出复制预算时返回null。
