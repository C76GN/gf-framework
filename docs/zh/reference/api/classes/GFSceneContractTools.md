# GFSceneContractTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_contract_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用场景根节点契约检查工具。 用于编辑器工具、导入预检、CI 和测试在加载场景后检查根节点的通用形状。 它只验证调用方显式声明的类型、脚本继承、分组、名称和路径约束， 不约定实体/组件目录、玩法字段或项目生命周期方法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCENE_EXTENSIONS`](#member-gfscenecontracttools-constants-scene_extensions) | `const SCENE_EXTENSIONS: PackedStringArray = ["tscn", "scn"]` |
| 常量 | [`KEY_BASE_CLASS`](#member-gfscenecontracttools-constants-key_base_class) | `const KEY_BASE_CLASS: StringName = &"base_class"` |
| 常量 | [`KEY_BASE_SCRIPT`](#member-gfscenecontracttools-constants-key_base_script) | `const KEY_BASE_SCRIPT: StringName = &"base_script"` |
| 常量 | [`KEY_REQUIRED_GROUPS`](#member-gfscenecontracttools-constants-key_required_groups) | `const KEY_REQUIRED_GROUPS: StringName = &"required_groups"` |
| 常量 | [`KEY_FORBIDDEN_GROUPS`](#member-gfscenecontracttools-constants-key_forbidden_groups) | `const KEY_FORBIDDEN_GROUPS: StringName = &"forbidden_groups"` |
| 常量 | [`KEY_NAME_PREFIX`](#member-gfscenecontracttools-constants-key_name_prefix) | `const KEY_NAME_PREFIX: StringName = &"name_prefix"` |
| 常量 | [`KEY_NAME_SUFFIX`](#member-gfscenecontracttools-constants-key_name_suffix) | `const KEY_NAME_SUFFIX: StringName = &"name_suffix"` |
| 常量 | [`KEY_PATH_PREFIX`](#member-gfscenecontracttools-constants-key_path_prefix) | `const KEY_PATH_PREFIX: StringName = &"path_prefix"` |
| 常量 | [`KEY_PATH_SUFFIX`](#member-gfscenecontracttools-constants-key_path_suffix) | `const KEY_PATH_SUFFIX: StringName = &"path_suffix"` |
| 常量 | [`KEY_SCRIPT_STRUCTURE`](#member-gfscenecontracttools-constants-key_script_structure) | `const KEY_SCRIPT_STRUCTURE: StringName = &"script_structure"` |
| 方法 | [`scan_scene_paths`](#member-gfscenecontracttools-methods-scan_scene_paths) | `static func scan_scene_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:` |
| 方法 | [`check_node`](#member-gfscenecontracttools-methods-check_node) | `static func check_node(root: Node, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`check_packed_scene`](#member-gfscenecontracttools-methods-check_packed_scene) | `static func check_packed_scene( packed_scene: PackedScene, contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`check_scene_path`](#member-gfscenecontracttools-methods-check_scene_path) | `static func check_scene_path(scene_path: String, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`check_scene_paths`](#member-gfscenecontracttools-methods-check_scene_paths) | `static func check_scene_paths( paths: PackedStringArray, contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`check_scene_directory`](#member-gfscenecontracttools-methods-check_scene_directory) | `static func check_scene_directory( root_path: String = "res://", contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_validation_rule`](#member-gfscenecontracttools-methods-make_validation_rule) | `static func make_validation_rule(contract: Dictionary = {}, options: Dictionary = {}) -> GFValidationRule:` |

## 常量

<a id="member-gfscenecontracttools-constants-scene_extensions"></a>

### `SCENE_EXTENSIONS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCENE_EXTENSIONS: PackedStringArray = ["tscn", "scn"]
```

默认场景扩展名白名单，不包含点号。

<a id="member-gfscenecontracttools-constants-key_base_class"></a>

### `KEY_BASE_CLASS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_BASE_CLASS: StringName = &"base_class"
```

契约字段：根节点必须是该 Godot 类或其子类。

<a id="member-gfscenecontracttools-constants-key_base_script"></a>

### `KEY_BASE_SCRIPT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_BASE_SCRIPT: StringName = &"base_script"
```

契约字段：根节点脚本必须等于或继承该脚本。

<a id="member-gfscenecontracttools-constants-key_required_groups"></a>

### `KEY_REQUIRED_GROUPS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_REQUIRED_GROUPS: StringName = &"required_groups"
```

契约字段：根节点必须属于的分组列表。

<a id="member-gfscenecontracttools-constants-key_forbidden_groups"></a>

### `KEY_FORBIDDEN_GROUPS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_FORBIDDEN_GROUPS: StringName = &"forbidden_groups"
```

契约字段：根节点不能属于的分组列表。

<a id="member-gfscenecontracttools-constants-key_name_prefix"></a>

### `KEY_NAME_PREFIX`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_NAME_PREFIX: StringName = &"name_prefix"
```

契约字段：根节点名称前缀。

<a id="member-gfscenecontracttools-constants-key_name_suffix"></a>

### `KEY_NAME_SUFFIX`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_NAME_SUFFIX: StringName = &"name_suffix"
```

契约字段：根节点名称后缀。

<a id="member-gfscenecontracttools-constants-key_path_prefix"></a>

### `KEY_PATH_PREFIX`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_PATH_PREFIX: StringName = &"path_prefix"
```

契约字段：场景路径前缀。

<a id="member-gfscenecontracttools-constants-key_path_suffix"></a>

### `KEY_PATH_SUFFIX`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_PATH_SUFFIX: StringName = &"path_suffix"
```

契约字段：场景路径后缀。

<a id="member-gfscenecontracttools-constants-key_script_structure"></a>

### `KEY_SCRIPT_STRUCTURE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KEY_SCRIPT_STRUCTURE: StringName = &"script_structure"
```

契约字段：传给 GFScriptStructureTools.check_script_structure() 的根脚本结构声明。

## 方法

<a id="member-gfscenecontracttools-methods-scan_scene_paths"></a>

### `scan_scene_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func scan_scene_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
```

扫描场景路径。 exclude_patterns、pattern_base_path、include_hidden、max_scan_depth、max_resource_paths 和 extensions 字段。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res:// 下的目录。 |
| `options` | 可选项，支持 GFResourceRegistryTools.scan_resource_paths() 的扫描选项；extensions 默认固定为 tscn/scn。 |

返回：排序后的场景路径。

结构：

- `options`: Dictionary，可包含 recursive、include_addons、excluded_paths、include_patterns、

<a id="member-gfscenecontracttools-methods-check_node"></a>

### `check_node`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func check_node(root: Node, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

检查一个已存在的场景根节点。 name_prefix、name_suffix、path_prefix、path_suffix 和 script_structure。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 场景根节点。 |
| `contract` | 契约声明，可包含 base_class、base_script、required_groups、forbidden_groups、 |
| `options` | 可选项，支持 scene_path、subject 和 script_structure_options。 |

返回：检查报告。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary scene contract check options.
- `return`: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。

<a id="member-gfscenecontracttools-methods-check_packed_scene"></a>

### `check_packed_scene`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func check_packed_scene( packed_scene: PackedScene, contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

实例化 PackedScene 并检查根节点契约。

参数：

| 名称 | 说明 |
|---|---|
| `packed_scene` | 待检查场景。 |
| `contract` | 契约声明。 |
| `options` | 可选项，支持 scene_path、subject、free_instance、gen_edit_state 和 script_structure_options。 |

返回：检查报告。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary packed scene contract check options.
- `return`: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。

<a id="member-gfscenecontracttools-methods-check_scene_path"></a>

### `check_scene_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func check_scene_path(scene_path: String, contract: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

加载场景路径并检查根节点契约。

参数：

| 名称 | 说明 |
|---|---|
| `scene_path` | 待检查场景资源路径。 |
| `contract` | 契约声明。 |
| `options` | 可选项，支持 check_packed_scene() 的选项。 |

返回：检查报告。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary scene path contract check options.
- `return`: Dictionary，包含 ok、scene_path、root_name、root_class、root_script_path、issues、counts 与 summary 字段。

<a id="member-gfscenecontracttools-methods-check_scene_paths"></a>

### `check_scene_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func check_scene_paths( paths: PackedStringArray, contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

批量检查场景路径。 counts 与 summary 字段。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 场景路径列表。 |
| `contract` | 契约声明。 |
| `options` | 可选项，支持 check_scene_path() 的选项。 |

返回：聚合检查报告。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary scene path batch contract check options.
- `return`: Dictionary，包含 ok、checked_count、passed_count、failed_count、entries、issues、

<a id="member-gfscenecontracttools-methods-check_scene_directory"></a>

### `check_scene_directory`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func check_scene_directory( root_path: String = "res://", contract: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

扫描目录并批量检查场景契约。 counts 与 summary 字段。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扫描起点，通常是 res:// 下的目录。 |
| `contract` | 契约声明。 |
| `options` | 可选项，同时支持 scan_scene_paths() 与 check_scene_path() 的选项。 |

返回：聚合检查报告。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary scene scan and contract check options.
- `return`: Dictionary，包含 ok、checked_count、passed_count、failed_count、entries、issues、

<a id="member-gfscenecontracttools-methods-make_validation_rule"></a>

### `make_validation_rule`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_validation_rule(contract: Dictionary = {}, options: Dictionary = {}) -> GFValidationRule:
```

创建可加入 GFValidationSuite 的根节点契约规则。 默认 target_kind 为 GFValidationRule.TargetKind.NODE，适合配合 GFValidationRunner 的 PackedScene 根节点实例化流程使用。 check_node() 的选项。

参数：

| 名称 | 说明 |
|---|---|
| `contract` | 契约声明。 |
| `options` | 可选项，支持 rule_id、description、target_kind、severity、metadata 和 |

返回：校验规则。

结构：

- `contract`: Dictionary scene root contract fields.
- `options`: Dictionary validation rule and contract check options.
