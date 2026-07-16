# GFAssetPreloadPlan

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_preload_plan.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

通用资源预加载计划。 用 Resource 形式描述一组可预热资源、分组标识和加载约束，便于项目把资源暖机清单保存、校验并交给 GFAssetUtility 执行。 该类只表达通用资源路径和调度选项，不绑定资源包、远程下载或项目业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`plan_id`](#member-gfassetpreloadplan-properties-plan_id) | `var plan_id: StringName = &""` |
| 属性 | [`group_id`](#member-gfassetpreloadplan-properties-group_id) | `var group_id: StringName = &""` |
| 属性 | [`entries`](#member-gfassetpreloadplan-properties-entries) | `var entries: Array[Dictionary] = []` |
| 属性 | [`pin_cache`](#member-gfassetpreloadplan-properties-pin_cache) | `var pin_cache: bool = true` |
| 属性 | [`lane_id`](#member-gfassetpreloadplan-properties-lane_id) | `var lane_id: StringName = &""` |
| 属性 | [`max_concurrent_loads`](#member-gfassetpreloadplan-properties-max_concurrent_loads) | `var max_concurrent_loads: int = 0:` |
| 属性 | [`metadata`](#member-gfassetpreloadplan-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfassetpreloadplan-methods-configure) | `func configure( p_group_id: StringName, p_entries: Array = [], options: Dictionary = {} ) -> GFAssetPreloadPlan:` |
| 方法 | [`add_path`](#member-gfassetpreloadplan-methods-add_path) | `func add_path( path: String, type_hint: String = "", entry_metadata: Dictionary = {}, enabled: bool = true ) -> int:` |
| 方法 | [`add_entry`](#member-gfassetpreloadplan-methods-add_entry) | `func add_entry(entry: Dictionary) -> int:` |
| 方法 | [`set_entries`](#member-gfassetpreloadplan-methods-set_entries) | `func set_entries(p_entries: Array) -> int:` |
| 方法 | [`clear`](#member-gfassetpreloadplan-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfassetpreloadplan-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_entry_count`](#member-gfassetpreloadplan-methods-get_entry_count) | `func get_entry_count(include_disabled: bool = false) -> int:` |
| 方法 | [`normalize_entry`](#member-gfassetpreloadplan-methods-normalize_entry) | `static func normalize_entry(entry: Dictionary) -> Dictionary:` |
| 方法 | [`get_entries`](#member-gfassetpreloadplan-methods-get_entries) | `func get_entries() -> Array[Dictionary]:` |
| 方法 | [`to_preload_options`](#member-gfassetpreloadplan-methods-to_preload_options) | `func to_preload_options(extra_options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate`](#member-gfassetpreloadplan-methods-validate) | `func validate() -> Dictionary:` |
| 方法 | [`describe`](#member-gfassetpreloadplan-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`duplicate_plan`](#member-gfassetpreloadplan-methods-duplicate_plan) | `func duplicate_plan() -> GFAssetPreloadPlan:` |
| 方法 | [`to_dictionary`](#member-gfassetpreloadplan-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gfassetpreloadplan-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFAssetPreloadPlan:` |

## 属性

<a id="member-gfassetpreloadplan-properties-plan_id"></a>

### `plan_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var plan_id: StringName = &""
```

计划稳定标识，便于诊断和回调报告归因。

<a id="member-gfassetpreloadplan-properties-group_id"></a>

### `group_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var group_id: StringName = &""
```

预加载完成后注册到 GFAssetUtility 的资源分组。

<a id="member-gfassetpreloadplan-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var entries: Array[Dictionary] = []
```

预加载条目列表。禁用或空路径条目会保留在计划中，但不会提交给加载器。

结构：

- `entries`: Array[Dictionary] where each entry contains `path: String`, optional `type_hint: String`, optional `enabled: bool`, and optional `metadata: Dictionary`.

<a id="member-gfassetpreloadplan-properties-pin_cache"></a>

### `pin_cache`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var pin_cache: bool = true
```

成功加载后是否以分组名义锁定缓存。

<a id="member-gfassetpreloadplan-properties-lane_id"></a>

### `lane_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var lane_id: StringName = &""
```

可选加载通道；为空时由 GFAssetUtility 使用分组和并发配置兜底。

<a id="member-gfassetpreloadplan-properties-max_concurrent_loads"></a>

### `max_concurrent_loads`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_concurrent_loads: int = 0:
```

该计划默认最大并发加载数；0 表示不覆盖工具默认值。

<a id="member-gfassetpreloadplan-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary for caller-defined preload plan metadata.

## 方法

<a id="member-gfassetpreloadplan-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_group_id: StringName, p_entries: Array = [], options: Dictionary = {} ) -> GFAssetPreloadPlan:
```

配置预加载计划。

参数：

| 名称 | 说明 |
|---|---|
| `p_group_id` | 预加载分组标识。 |
| `p_entries` | 预加载条目数组。 |
| `options` | 计划选项，支持 plan_id、pin_cache、lane_id、max_concurrent_loads 和 metadata。 |

返回：当前计划。

结构：

- `p_entries`: Array[String|Dictionary] where Dictionary entries follow the entries schema.
- `options`: Dictionary with optional `plan_id: StringName`, `pin_cache: bool`, `lane_id: StringName`, `max_concurrent_loads: int`, and `metadata: Dictionary`.

<a id="member-gfassetpreloadplan-methods-add_path"></a>

### `add_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_path( path: String, type_hint: String = "", entry_metadata: Dictionary = {}, enabled: bool = true ) -> int:
```

添加路径条目。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `type_hint` | ResourceLoader 类型提示。 |
| `entry_metadata` | 条目元数据。 |
| `enabled` | 是否参与预加载。 |

返回：添加后的条目索引；路径为空时返回 -1。

结构：

- `entry_metadata`: Dictionary copied into the entry metadata.

<a id="member-gfassetpreloadplan-methods-add_entry"></a>

### `add_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_entry(entry: Dictionary) -> int:
```

添加字典条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 输入条目。 |

返回：添加后的条目索引。

结构：

- `entry`: Dictionary with `path`, optional `type_hint`, optional `enabled`, and optional `metadata`.

<a id="member-gfassetpreloadplan-methods-set_entries"></a>

### `set_entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_entries(p_entries: Array) -> int:
```

批量替换条目。

参数：

| 名称 | 说明 |
|---|---|
| `p_entries` | 新条目数组。 |

返回：写入的条目数量。

结构：

- `p_entries`: Array[String|Dictionary] where String values are treated as paths.

<a id="member-gfassetpreloadplan-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear() -> void:
```

清空计划条目。

<a id="member-gfassetpreloadplan-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_empty() -> bool:
```

检查计划是否没有可执行条目。

返回：没有启用且路径有效的条目时返回 true。

<a id="member-gfassetpreloadplan-methods-get_entry_count"></a>

### `get_entry_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_entry_count(include_disabled: bool = false) -> int:
```

获取条目数量。

参数：

| 名称 | 说明 |
|---|---|
| `include_disabled` | 为 true 时统计原始条目，否则只统计启用且路径有效的条目。 |

返回：条目数量。

<a id="member-gfassetpreloadplan-methods-normalize_entry"></a>

### `normalize_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func normalize_entry(entry: Dictionary) -> Dictionary:
```

规范化条目字典。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 输入条目。 |

返回：规范化条目。

结构：

- `entry`: Dictionary with `path`, optional `type_hint`, optional `enabled`, and optional `metadata`.
- `return`: Dictionary with `path: String`, `type_hint: String`, `enabled: bool`, and `metadata: Dictionary`.

<a id="member-gfassetpreloadplan-methods-get_entries"></a>

### `get_entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_entries() -> Array[Dictionary]:
```

获取可提交给 GFAssetUtility 的启用条目副本。

返回：预加载条目数组。

结构：

- `return`: Array[Dictionary] where each entry contains `path`, `type_hint`, and `metadata`.

<a id="member-gfassetpreloadplan-methods-to_preload_options"></a>

### `to_preload_options`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_preload_options(extra_options: Dictionary = {}) -> Dictionary:
```

转换为 GFAssetUtility.preload_group_async() 选项。

参数：

| 名称 | 说明 |
|---|---|
| `extra_options` | 调用方覆盖选项。 |

返回：合并后的加载选项。

结构：

- `extra_options`: Dictionary with GFAssetUtility preload options.
- `return`: Dictionary with optional `pin_cache`, `lane_id`, and `max_concurrent_loads`.

<a id="member-gfassetpreloadplan-methods-validate"></a>

### `validate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate() -> Dictionary:
```

校验计划并返回结构化报告。

返回：校验报告。

结构：

- `return`: Dictionary with `ok`, `plan_id`, `group_id`, `entry_count`, `enabled_count`, `disabled_count`, `invalid_count`, `duplicate_paths`, `issues`, and `metadata`.

<a id="member-gfassetpreloadplan-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func describe() -> Dictionary:
```

描述计划当前内容。

返回：计划描述。

结构：

- `return`: Dictionary with plan_id, group_id, pin_cache, lane_id, max_concurrent_loads, entry_count, executable_entry_count, entries, validation, and metadata.

<a id="member-gfassetpreloadplan-methods-duplicate_plan"></a>

### `duplicate_plan`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_plan() -> GFAssetPreloadPlan:
```

复制计划。

返回：计划副本。

<a id="member-gfassetpreloadplan-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为可序列化字典。

返回：计划字典。

结构：

- `return`: Dictionary with `plan_id`, `group_id`, `entries`, `pin_cache`, `lane_id`, `max_concurrent_loads`, and `metadata`.

<a id="member-gfassetpreloadplan-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFAssetPreloadPlan:
```

从字典创建计划。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 计划字典。 |

返回：计划对象。

结构：

- `data`: Dictionary with `plan_id`, `group_id`, `entries`, `pin_cache`, `lane_id`, `max_concurrent_loads`, and `metadata`.
