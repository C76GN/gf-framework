# GFCollisionBroadphase3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_collision_broadphase_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

纯 3D AABB broadphase 候选对生成工具。 使用 `AABB` body 记录生成可能相交的候选对，提供暴力枚举、Sweep and Prune 和自动组合入口。它只做 AABB 粗筛，不执行 SAT、GJK、接触点计算、 物理响应、命中分发或玩法规则判断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ALGORITHM_BRUTE_FORCE`](#member-gfcollisionbroadphase3d-constants-algorithm_brute_force) | `const ALGORITHM_BRUTE_FORCE: StringName = &"bruteforce"` |
| 常量 | [`ALGORITHM_SAP`](#member-gfcollisionbroadphase3d-constants-algorithm_sap) | `const ALGORITHM_SAP: StringName = &"sap"` |
| 常量 | [`ALGORITHM_AUTO`](#member-gfcollisionbroadphase3d-constants-algorithm_auto) | `const ALGORITHM_AUTO: StringName = &"auto"` |
| 常量 | [`DEFAULT_COLLISION_LAYER`](#member-gfcollisionbroadphase3d-constants-default_collision_layer) | `const DEFAULT_COLLISION_LAYER: int = 1` |
| 常量 | [`DEFAULT_COLLISION_MASK`](#member-gfcollisionbroadphase3d-constants-default_collision_mask) | `const DEFAULT_COLLISION_MASK: int = 0xffffffff` |
| 方法 | [`make_body`](#member-gfcollisionbroadphase3d-methods-make_body) | `static func make_body( entity: Variant, bounds: AABB, collision_layer: int = DEFAULT_COLLISION_LAYER, collision_mask: int = DEFAULT_COLLISION_MASK, enabled: bool = true, metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`find_pairs_bruteforce`](#member-gfcollisionbroadphase3d-methods-find_pairs_bruteforce) | `static func find_pairs_bruteforce(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`find_pairs_sap`](#member-gfcollisionbroadphase3d-methods-find_pairs_sap) | `static func find_pairs_sap(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`find_pairs_combined`](#member-gfcollisionbroadphase3d-methods-find_pairs_combined) | `static func find_pairs_combined(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`build_pair_report`](#member-gfcollisionbroadphase3d-methods-build_pair_report) | `static func build_pair_report(bodies: Array, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfcollisionbroadphase3d-constants-algorithm_brute_force"></a>

### `ALGORITHM_BRUTE_FORCE`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const ALGORITHM_BRUTE_FORCE: StringName = &"bruteforce"
```

暴力枚举 broadphase。

<a id="member-gfcollisionbroadphase3d-constants-algorithm_sap"></a>

### `ALGORITHM_SAP`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const ALGORITHM_SAP: StringName = &"sap"
```

Sweep and Prune broadphase。

<a id="member-gfcollisionbroadphase3d-constants-algorithm_auto"></a>

### `ALGORITHM_AUTO`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const ALGORITHM_AUTO: StringName = &"auto"
```

自动选择 broadphase。

<a id="member-gfcollisionbroadphase3d-constants-default_collision_layer"></a>

### `DEFAULT_COLLISION_LAYER`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_COLLISION_LAYER: int = 1
```

默认碰撞层。

<a id="member-gfcollisionbroadphase3d-constants-default_collision_mask"></a>

### `DEFAULT_COLLISION_MASK`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_COLLISION_MASK: int = 0xffffffff
```

默认碰撞掩码。

## 方法

<a id="member-gfcollisionbroadphase3d-methods-make_body"></a>

### `make_body`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func make_body( entity: Variant, bounds: AABB, collision_layer: int = DEFAULT_COLLISION_LAYER, collision_mask: int = DEFAULT_COLLISION_MASK, enabled: bool = true, metadata: Dictionary = {} ) -> Dictionary:
```

创建 3D broadphase body 记录。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 调用方实体标识。 |
| `bounds` | 轴对齐包围盒；负尺寸会被归一化。 |
| `collision_layer` | 当前 body 所在层。 |
| `collision_mask` | 当前 body 可匹配的层。 |
| `enabled` | 为 false 时默认不会参与候选对生成。 |
| `metadata` | 调用方附加元数据；候选对不会解释这些字段。 |

返回：body 字典。

结构：

- `entity`: Variant entity identity copied into generated pair reports.
- `metadata`: Dictionary caller metadata copied by value.
- `return`: Dictionary with `entity`, `bounds: AABB`, `collision_layer: int`, `collision_mask: int`, `enabled: bool`, and `metadata: Dictionary`.

<a id="member-gfcollisionbroadphase3d-methods-find_pairs_bruteforce"></a>

### `find_pairs_bruteforce`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func find_pairs_bruteforce(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
```

使用暴力枚举生成 3D AABB 候选对。

参数：

| 名称 | 说明 |
|---|---|
| `bodies` | body 字典数组，建议由 `make_body()` 创建。 |
| `options` | 可选控制，支持 `include_touching`、`use_collision_masks`、`enabled_only` 与 `max_pairs`。 |

返回：候选对数组。

结构：

- `bodies`: Array[Dictionary] broadphase body records.
- `options`: Dictionary with optional `include_touching: bool`, `use_collision_masks: bool`, `enabled_only: bool`, and `max_pairs: int`.
- `return`: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.

<a id="member-gfcollisionbroadphase3d-methods-find_pairs_sap"></a>

### `find_pairs_sap`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func find_pairs_sap(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
```

使用 Sweep and Prune 生成 3D AABB 候选对。

参数：

| 名称 | 说明 |
|---|---|
| `bodies` | body 字典数组，建议由 `make_body()` 创建。 |
| `options` | 可选控制，支持 `include_touching`、`use_collision_masks`、`enabled_only` 与 `max_pairs`。 |

返回：候选对数组。

结构：

- `bodies`: Array[Dictionary] broadphase body records.
- `options`: Dictionary with optional `include_touching: bool`, `use_collision_masks: bool`, `enabled_only: bool`, and `max_pairs: int`.
- `return`: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.

<a id="member-gfcollisionbroadphase3d-methods-find_pairs_combined"></a>

### `find_pairs_combined`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func find_pairs_combined(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
```

按选定或自动算法生成 3D AABB 候选对。

参数：

| 名称 | 说明 |
|---|---|
| `bodies` | body 字典数组，建议由 `make_body()` 创建。 |
| `options` | 可选控制，支持 `algorithm: StringName` 以及各算法选项。 |

返回：候选对数组。

结构：

- `bodies`: Array[Dictionary] broadphase body records.
- `options`: Dictionary with optional `algorithm: StringName` plus bruteforce or SAP options.
- `return`: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.

<a id="member-gfcollisionbroadphase3d-methods-build_pair_report"></a>

### `build_pair_report`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func build_pair_report(bodies: Array, options: Dictionary = {}) -> Dictionary:
```

生成包含算法、输入数量和候选对的 3D broadphase 报告。

参数：

| 名称 | 说明 |
|---|---|
| `bodies` | body 字典数组，建议由 `make_body()` 创建。 |
| `options` | 可选控制，支持 `algorithm: StringName` 以及各算法选项。 |

返回：broadphase 报告。

结构：

- `bodies`: Array[Dictionary] broadphase body records.
- `options`: Dictionary with optional `algorithm: StringName` plus bruteforce or SAP options.
- `return`: Dictionary with `algorithm: StringName`, `body_count: int`, `pair_count: int`, and `pairs: Array[Dictionary]`.
