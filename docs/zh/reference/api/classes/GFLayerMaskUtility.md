# GFLayerMaskUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_layer_mask_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.21.0`

层名与 bitmask 互转工具。 提供通用层名数组到整数 bitmask 的稳定转换，也可读取 Godot 项目的 2D / 3D Physics Layer Names。它只处理名称、索引和整数掩码， 不写入节点属性，也不绑定具体碰撞、射线、阵营或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_LAYER_COUNT`](#member-gflayermaskutility-constants-default_layer_count) | `const DEFAULT_LAYER_COUNT: int = 32` |
| 常量 | [`INVALID_LAYER_INDEX`](#member-gflayermaskutility-constants-invalid_layer_index) | `const INVALID_LAYER_INDEX: int = -1` |
| 方法 | [`names_to_mask`](#member-gflayermaskutility-methods-names_to_mask) | `static func names_to_mask(names: Array, layer_names: Array, case_sensitive: bool = true) -> int:` |
| 方法 | [`mask_to_names`](#member-gflayermaskutility-methods-mask_to_names) | `static func mask_to_names(mask: int, layer_names: Array, include_unnamed: bool = false) -> PackedStringArray:` |
| 方法 | [`find_layer_index`](#member-gflayermaskutility-methods-find_layer_index) | `static func find_layer_index(layer_name: String, layer_names: Array, case_sensitive: bool = true) -> int:` |
| 方法 | [`layer_index_to_mask`](#member-gflayermaskutility-methods-layer_index_to_mask) | `static func layer_index_to_mask(layer_index: int) -> int:` |
| 方法 | [`is_layer_index_valid`](#member-gflayermaskutility-methods-is_layer_index_valid) | `static func is_layer_index_valid(layer_index: int, layer_count: int = DEFAULT_LAYER_COUNT) -> bool:` |
| 方法 | [`get_missing_names`](#member-gflayermaskutility-methods-get_missing_names) | `static func get_missing_names(names: Array, layer_names: Array, case_sensitive: bool = true) -> PackedStringArray:` |
| 方法 | [`get_project_physics_layer_names`](#member-gflayermaskutility-methods-get_project_physics_layer_names) | `static func get_project_physics_layer_names( dimension: int = 2, fallback_to_default_names: bool = false ) -> PackedStringArray:` |

## 常量

<a id="member-gflayermaskutility-constants-default_layer_count"></a>

### `DEFAULT_LAYER_COUNT`

- API：`public`

```gdscript
const DEFAULT_LAYER_COUNT: int = 32
```

Godot 物理层 bitmask 的默认层数量。

<a id="member-gflayermaskutility-constants-invalid_layer_index"></a>

### `INVALID_LAYER_INDEX`

- API：`public`

```gdscript
const INVALID_LAYER_INDEX: int = -1
```

无效层索引哨兵值。

## 方法

<a id="member-gflayermaskutility-methods-names_to_mask"></a>

### `names_to_mask`

- API：`public`

```gdscript
static func names_to_mask(names: Array, layer_names: Array, case_sensitive: bool = true) -> int:
```

将层名列表转换为 bitmask。

参数：

| 名称 | 说明 |
|---|---|
| `names` | 要启用的层名列表。 |
| `layer_names` | 按层索引排列的层名表；索引 0 对应第 1 层。 |
| `case_sensitive` | 是否区分大小写。 |

返回：对应 bitmask；未知名称会被忽略。

结构：

- `names`: Array of String or StringName layer names.
- `layer_names`: Array of String or StringName layer names ordered by layer index.

<a id="member-gflayermaskutility-methods-mask_to_names"></a>

### `mask_to_names`

- API：`public`

```gdscript
static func mask_to_names(mask: int, layer_names: Array, include_unnamed: bool = false) -> PackedStringArray:
```

将 bitmask 转换为层名列表。

参数：

| 名称 | 说明 |
|---|---|
| `mask` | 要解析的 bitmask。 |
| `layer_names` | 按层索引排列的层名表；索引 0 对应第 1 层。 |
| `include_unnamed` | 是否为未命名但启用的层返回默认名称。 |

返回：按层索引排序的层名列表。

结构：

- `layer_names`: Array of String or StringName layer names ordered by layer index.

<a id="member-gflayermaskutility-methods-find_layer_index"></a>

### `find_layer_index`

- API：`public`

```gdscript
static func find_layer_index(layer_name: String, layer_names: Array, case_sensitive: bool = true) -> int:
```

查找层名对应的零基索引。

参数：

| 名称 | 说明 |
|---|---|
| `layer_name` | 要查找的层名。 |
| `layer_names` | 按层索引排列的层名表；索引 0 对应第 1 层。 |
| `case_sensitive` | 是否区分大小写。 |

返回：找到时返回零基索引；否则返回 INVALID_LAYER_INDEX。

结构：

- `layer_names`: Array of String or StringName layer names ordered by layer index.

<a id="member-gflayermaskutility-methods-layer_index_to_mask"></a>

### `layer_index_to_mask`

- API：`public`

```gdscript
static func layer_index_to_mask(layer_index: int) -> int:
```

将零基层索引转换为单层 bitmask。

参数：

| 名称 | 说明 |
|---|---|
| `layer_index` | 零基层索引。 |

返回：对应单层 bitmask；无效索引返回 0。

<a id="member-gflayermaskutility-methods-is_layer_index_valid"></a>

### `is_layer_index_valid`

- API：`public`

```gdscript
static func is_layer_index_valid(layer_index: int, layer_count: int = DEFAULT_LAYER_COUNT) -> bool:
```

判断零基层索引是否在有效范围内。

参数：

| 名称 | 说明 |
|---|---|
| `layer_index` | 零基层索引。 |
| `layer_count` | 可用层数量，上限为 DEFAULT_LAYER_COUNT。 |

返回：有效时返回 true。

<a id="member-gflayermaskutility-methods-get_missing_names"></a>

### `get_missing_names`

- API：`public`

```gdscript
static func get_missing_names(names: Array, layer_names: Array, case_sensitive: bool = true) -> PackedStringArray:
```

获取输入层名中无法解析的名称。

参数：

| 名称 | 说明 |
|---|---|
| `names` | 要检查的层名列表。 |
| `layer_names` | 按层索引排列的层名表；索引 0 对应第 1 层。 |
| `case_sensitive` | 是否区分大小写。 |

返回：未找到的层名列表，按首次出现顺序去重。

结构：

- `names`: Array of String or StringName layer names.
- `layer_names`: Array of String or StringName layer names ordered by layer index.

<a id="member-gflayermaskutility-methods-get_project_physics_layer_names"></a>

### `get_project_physics_layer_names`

- API：`public`

```gdscript
static func get_project_physics_layer_names( dimension: int = 2, fallback_to_default_names: bool = false ) -> PackedStringArray:
```

读取项目的 2D 或 3D 物理层名称。

参数：

| 名称 | 说明 |
|---|---|
| `dimension` | 物理维度，只支持 2 或 3。 |
| `fallback_to_default_names` | 未命名层是否返回 `Layer N`。 |

返回：长度为 DEFAULT_LAYER_COUNT 的层名列表；维度无效时返回空列表。
