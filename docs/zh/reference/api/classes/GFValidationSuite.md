# GFValidationSuite

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_suite.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用校验套件资源。 保存一组规则与可选资源路径筛选条件。套件只描述“要检查什么”，实际加载、 实例化和报告聚合由 GFValidationRunner 完成。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`GFValidationRuleBase`](#member-gfvalidationsuite-constants-gfvalidationrulebase) | `const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfvalidationsuite-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_COLLECTED_PATHS`](#member-gfvalidationsuite-constants-default_max_collected_paths) | `const DEFAULT_MAX_COLLECTED_PATHS: int = 10_000` |
| 属性 | [`suite_id`](#member-gfvalidationsuite-properties-suite_id) | `var suite_id: StringName = &""` |
| 属性 | [`description`](#member-gfvalidationsuite-properties-description) | `var description: String = ""` |
| 属性 | [`enabled`](#member-gfvalidationsuite-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`treat_warnings_as_errors`](#member-gfvalidationsuite-properties-treat_warnings_as_errors) | `var treat_warnings_as_errors: bool = false` |
| 属性 | [`rules`](#member-gfvalidationsuite-properties-rules) | `var rules: Array[GFValidationRuleBase] = []` |
| 属性 | [`include_paths`](#member-gfvalidationsuite-properties-include_paths) | `var include_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`exclude_paths`](#member-gfvalidationsuite-properties-exclude_paths) | `var exclude_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`resource_extensions`](#member-gfvalidationsuite-properties-resource_extensions) | `var resource_extensions: PackedStringArray = PackedStringArray(["tres", "res"])` |
| 属性 | [`scene_extensions`](#member-gfvalidationsuite-properties-scene_extensions) | `var scene_extensions: PackedStringArray = PackedStringArray(["tscn", "scn"])` |
| 属性 | [`recursive`](#member-gfvalidationsuite-properties-recursive) | `var recursive: bool = true` |
| 属性 | [`include_hidden`](#member-gfvalidationsuite-properties-include_hidden) | `var include_hidden: bool = false` |
| 属性 | [`max_scan_depth`](#member-gfvalidationsuite-properties-max_scan_depth) | `var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH:` |
| 属性 | [`max_collected_paths`](#member-gfvalidationsuite-properties-max_collected_paths) | `var max_collected_paths: int = DEFAULT_MAX_COLLECTED_PATHS:` |
| 属性 | [`metadata`](#member-gfvalidationsuite-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_rule`](#member-gfvalidationsuite-methods-add_rule) | `func add_rule(rule: GFValidationRuleBase) -> bool:` |
| 方法 | [`remove_rule`](#member-gfvalidationsuite-methods-remove_rule) | `func remove_rule(rule: GFValidationRuleBase) -> bool:` |
| 方法 | [`get_enabled_rules`](#member-gfvalidationsuite-methods-get_enabled_rules) | `func get_enabled_rules() -> Array[GFValidationRuleBase]:` |
| 方法 | [`matches_path`](#member-gfvalidationsuite-methods-matches_path) | `func matches_path(path: String) -> bool:` |
| 方法 | [`collect_paths`](#member-gfvalidationsuite-methods-collect_paths) | `func collect_paths() -> PackedStringArray:` |
| 方法 | [`duplicate_suite`](#member-gfvalidationsuite-methods-duplicate_suite) | `func duplicate_suite() -> GFValidationSuite:` |

## 常量

<a id="member-gfvalidationsuite-constants-gfvalidationrulebase"></a>

### `GFValidationRuleBase`

- API：`public`

```gdscript
const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")
```

校验规则脚本基类。

<a id="member-gfvalidationsuite-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认递归扫描目录深度上限。

<a id="member-gfvalidationsuite-constants-default_max_collected_paths"></a>

### `DEFAULT_MAX_COLLECTED_PATHS`

- API：`public`

```gdscript
const DEFAULT_MAX_COLLECTED_PATHS: int = 10_000
```

默认单次路径收集数量上限。

## 属性

<a id="member-gfvalidationsuite-properties-suite_id"></a>

### `suite_id`

- API：`public`

```gdscript
var suite_id: StringName = &""
```

套件标识。

<a id="member-gfvalidationsuite-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

套件说明。

<a id="member-gfvalidationsuite-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用套件。

<a id="member-gfvalidationsuite-properties-treat_warnings_as_errors"></a>

### `treat_warnings_as_errors`

- API：`public`

```gdscript
var treat_warnings_as_errors: bool = false
```

是否把警告提升为错误。

<a id="member-gfvalidationsuite-properties-rules"></a>

### `rules`

- API：`public`

```gdscript
var rules: Array[GFValidationRuleBase] = []
```

校验规则列表。

<a id="member-gfvalidationsuite-properties-include_paths"></a>

### `include_paths`

- API：`public`

```gdscript
var include_paths: PackedStringArray = PackedStringArray()
```

需要扫描的路径。可以是文件或目录；为空时不自动扫描。

<a id="member-gfvalidationsuite-properties-exclude_paths"></a>

### `exclude_paths`

- API：`public`

```gdscript
var exclude_paths: PackedStringArray = PackedStringArray()
```

需要排除的路径或通配模式。

<a id="member-gfvalidationsuite-properties-resource_extensions"></a>

### `resource_extensions`

- API：`public`

```gdscript
var resource_extensions: PackedStringArray = PackedStringArray(["tres", "res"])
```

资源文件扩展名，不含点号。

<a id="member-gfvalidationsuite-properties-scene_extensions"></a>

### `scene_extensions`

- API：`public`

```gdscript
var scene_extensions: PackedStringArray = PackedStringArray(["tscn", "scn"])
```

场景文件扩展名，不含点号。

<a id="member-gfvalidationsuite-properties-recursive"></a>

### `recursive`

- API：`public`

```gdscript
var recursive: bool = true
```

扫描目录时是否递归。

<a id="member-gfvalidationsuite-properties-include_hidden"></a>

### `include_hidden`

- API：`public`

```gdscript
var include_hidden: bool = false
```

扫描目录时是否包含隐藏目录和文件。

<a id="member-gfvalidationsuite-properties-max_scan_depth"></a>

### `max_scan_depth`

- API：`public`

```gdscript
var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH:
```

递归扫描的最大目录深度。0 表示不限制。

<a id="member-gfvalidationsuite-properties-max_collected_paths"></a>

### `max_collected_paths`

- API：`public`

```gdscript
var max_collected_paths: int = DEFAULT_MAX_COLLECTED_PATHS:
```

单次 collect_paths() 最多收集的路径数量。0 表示不限制。

<a id="member-gfvalidationsuite-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary of caller-defined suite metadata.

## 方法

<a id="member-gfvalidationsuite-methods-add_rule"></a>

### `add_rule`

- API：`public`

```gdscript
func add_rule(rule: GFValidationRuleBase) -> bool:
```

添加规则。

参数：

| 名称 | 说明 |
|---|---|
| `rule` | 规则资源。 |

返回：添加成功返回 true。

<a id="member-gfvalidationsuite-methods-remove_rule"></a>

### `remove_rule`

- API：`public`

```gdscript
func remove_rule(rule: GFValidationRuleBase) -> bool:
```

移除规则。

参数：

| 名称 | 说明 |
|---|---|
| `rule` | 规则资源。 |

返回：移除成功返回 true。

<a id="member-gfvalidationsuite-methods-get_enabled_rules"></a>

### `get_enabled_rules`

- API：`public`

```gdscript
func get_enabled_rules() -> Array[GFValidationRuleBase]:
```

获取启用的规则。

返回：规则数组副本。

<a id="member-gfvalidationsuite-methods-matches_path"></a>

### `matches_path`

- API：`public`

```gdscript
func matches_path(path: String) -> bool:
```

检查路径是否会被套件扫描。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源或场景路径。 |

返回：匹配返回 true。

<a id="member-gfvalidationsuite-methods-collect_paths"></a>

### `collect_paths`

- API：`public`

```gdscript
func collect_paths() -> PackedStringArray:
```

收集 include_paths 中匹配的资源和场景路径。

返回：已排序路径列表。

<a id="member-gfvalidationsuite-methods-duplicate_suite"></a>

### `duplicate_suite`

- API：`public`

```gdscript
func duplicate_suite() -> GFValidationSuite:
```

创建套件配置副本。

返回：新套件。
