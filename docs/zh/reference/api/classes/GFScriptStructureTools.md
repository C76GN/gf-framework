# GFScriptStructureTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_script_structure_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.1.0`

脚本结构扫描和契约检查工具。 面向编辑器工具、导入器、测试和构建脚本复用；它只描述脚本公开的 常量、方法、属性、信号和继承关系，不实例化对象，也不规定组件架构、数据库或业务层模型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCRIPT_EXTENSIONS`](#member-gfscriptstructuretools-constants-script_extensions) | `const SCRIPT_EXTENSIONS: PackedStringArray = ["gd"]` |
| 常量 | [`DEFAULT_MAX_BASE_CHAIN_DEPTH`](#member-gfscriptstructuretools-constants-default_max_base_chain_depth) | `const DEFAULT_MAX_BASE_CHAIN_DEPTH: int = 32` |
| 方法 | [`scan_script_paths`](#member-gfscriptstructuretools-methods-scan_script_paths) | `static func scan_script_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`describe_script`](#member-gfscriptstructuretools-methods-describe_script) | `static func describe_script(target_script: Script, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`format_method_signature`](#member-gfscriptstructuretools-methods-format_method_signature) | `static func format_method_signature(method: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`format_method_stub`](#member-gfscriptstructuretools-methods-format_method_stub) | `static func format_method_stub(method: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`check_script_structure`](#member-gfscriptstructuretools-methods-check_script_structure) | `static func check_script_structure( target_script: Script, structure: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfscriptstructuretools-constants-script_extensions"></a>

### `SCRIPT_EXTENSIONS`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
const SCRIPT_EXTENSIONS: PackedStringArray = ["gd"]
```

GDScript 扩展名白名单，不包含点号。

<a id="member-gfscriptstructuretools-constants-default_max_base_chain_depth"></a>

### `DEFAULT_MAX_BASE_CHAIN_DEPTH`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
const DEFAULT_MAX_BASE_CHAIN_DEPTH: int = 32
```

默认脚本继承链扫描深度上限。

## 方法

<a id="member-gfscriptstructuretools-methods-scan_script_paths"></a>

### `scan_script_paths`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func scan_script_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
```

扫描脚本路径，并按目录深度优先、同层字典序排序。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res:// 下的目录。 |
| `options` | 可选项，支持 GFResourceRegistryTools.scan_resource_paths() 的扫描选项，extensions 默认固定为 gd。 |

返回：排序后的脚本路径。

结构：

- `options`: Dictionary，可包含 recursive、include_addons、excluded_paths、include_patterns、exclude_patterns、pattern_base_path、include_hidden、max_scan_depth、max_resource_paths 和 extensions 字段。

<a id="member-gfscriptstructuretools-methods-describe_script"></a>

### `describe_script`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func describe_script(target_script: Script, options: Dictionary = {}) -> Dictionary:
```

描述脚本公开结构。

参数：

| 名称 | 说明 |
|---|---|
| `target_script` | 待描述脚本。 |
| `options` | 可选项，支持 include_private_members、include_constants、include_methods、include_properties、include_signals、include_base_chain、include_constant_values 和 max_base_chain_depth。 |

返回：脚本结构描述报告。

结构：

- `options`: Dictionary，可控制成员、继承链和常量值是否写入描述报告。
- `return`: Dictionary，包含 ok、script_path、global_name、instance_base_type、can_instantiate、constants、methods、properties、signals、base_chain、counts、issues 与 summary 字段。

<a id="member-gfscriptstructuretools-methods-format_method_signature"></a>

### `format_method_signature`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func format_method_signature(method: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将 Godot 方法元数据格式化为 GDScript 函数签名。 method 通常来自 Script.get_script_method_list()、ClassDB.class_get_method_list() 或 describe_script() 返回的 methods 条目。该方法只生成文本片段，不读取或修改脚本源码。

参数：

| 名称 | 说明 |
|---|---|
| `method` | 方法元数据。 |
| `options` | 可选项，支持 include_func_keyword、include_return_type、include_void_return 和 include_variant_type_for_untyped。 |

返回：方法签名格式化报告。

结构：

- `method`: Dictionary，可包含 name、args、arguments、default_args、return、return_type、return_class_name、return_hint 和 return_hint_string 字段。
- `options`: Dictionary，可控制是否输出 func 关键字、返回类型、void 返回类型和未标注参数的 Variant 类型。
- `return`: Dictionary，包含 ok、name、signature、stub、argument_count、return_type、return_type_name、issues、counts 与 summary 字段。

<a id="member-gfscriptstructuretools-methods-format_method_stub"></a>

### `format_method_stub`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func format_method_stub(method: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将 Godot 方法元数据格式化为可插入生成器输出的 GDScript 方法桩。 默认主体会为有返回值的方法生成安全默认返回值；无返回值或无法判断返回值时生成 pass。 调用方可通过 body_lines 提供自定义主体行。

参数：

| 名称 | 说明 |
|---|---|
| `method` | 方法元数据。 |
| `options` | 可选项，支持 format_method_signature() 的选项，以及 indent、body_lines 和 include_trailing_newline。 |

返回：方法桩格式化报告。

结构：

- `method`: Dictionary，可包含 name、args、arguments、default_args、return、return_type、return_class_name、return_hint 和 return_hint_string 字段。
- `options`: Dictionary，可控制签名输出、缩进文本、自定义主体行和是否追加末尾换行；body_lines 可为 Array、PackedStringArray 或单行 String。
- `return`: Dictionary，包含 ok、name、signature、stub、argument_count、return_type、return_type_name、issues、counts 与 summary 字段。

<a id="member-gfscriptstructuretools-methods-check_script_structure"></a>

### `check_script_structure`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func check_script_structure( target_script: Script, structure: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

检查脚本是否满足结构声明。 structure 可声明 base_script、base_class、can_instantiate、required_constants、 required_methods、required_properties 与 required_signals。required_* 条目可使用名称字符串， 也可使用包含 name、type、class_name、usage、argument_count 或 min_argument_count 的 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `target_script` | 待检查脚本。 |
| `structure` | 结构声明。 |
| `options` | 传给 describe_script() 的可选项。 |

返回：结构检查报告。

结构：

- `structure`: Dictionary，可包含 base_script、base_class、can_instantiate 和 required_* 成员声明。
- `options`: Dictionary，可控制成员描述与检查细节。
- `return`: Dictionary，包含 ok、script_path、description、issues、counts 与 summary 字段。
