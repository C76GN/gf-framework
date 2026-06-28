# GFResourceFeatureRemapTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_feature_remap_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.1.0`

资源 feature 重映射计划工具。 根据调用方提供的 feature 集合与 remap 声明，生成纯数据解析计划。 它不读取 ProjectSettings、不注册导出插件、不写文件，也不决定平台策略； 编辑器导出、资源打包或项目 Installer 可在审查计划后自行执行替换。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`normalize_remaps`](#member-gfresourcefeatureremaptools-methods-normalize_remaps) | `static func normalize_remaps(remaps: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`select_remap_for_path`](#member-gfresourcefeatureremaptools-methods-select_remap_for_path) | `static func select_remap_for_path( path: String, remaps: Variant, active_features: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_remap_plan`](#member-gfresourcefeatureremaptools-methods-build_remap_plan) | `static func build_remap_plan( remaps: Variant, active_features: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfresourcefeatureremaptools-methods-normalize_remaps"></a>

### `normalize_remaps`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func normalize_remaps(remaps: Variant, options: Dictionary = {}) -> Dictionary:
```

归一化资源 feature 重映射声明。 支持 `Dictionary[source_path] = entries` 或条目数组。每个 entry 可为 `[feature, target_path]`、`PackedStringArray([feature, target_path])`， 或包含 `feature` / `features` 与 `target_path` / `path` / `remap_path` 的 Dictionary； source 值也可直接使用单条 `[feature, target_path]` 简写。

参数：

| 名称 | 说明 |
|---|---|
| `remaps` | 待归一化的 remap 声明。 |
| `options` | 可选项，支持 keep_invalid_entries。 |

返回：归一化报告。

结构：

- `remaps`: Dictionary 或 Array 形式的资源 feature remap 声明。
- `options`: Dictionary，可包含 keep_invalid_entries 字段。
- `return`: Dictionary，包含 ok、remaps、sources、issues、source_count、entry_count、issue_count、error_count、warning_count 与 summary 字段。

<a id="member-gfresourcefeatureremaptools-methods-select_remap_for_path"></a>

### `select_remap_for_path`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func select_remap_for_path( path: String, remaps: Variant, active_features: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

为单个资源路径选择第一个命中的 feature 重映射。 entry 顺序就是优先级；当多个 active feature 同时命中时，返回声明中最靠前的 entry。 未命中时 `selected=false`，`resolved_path` 保持为原始路径。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 待解析的原始资源路径。 |
| `remaps` | 资源 feature remap 声明。 |
| `active_features` | 当前启用的 feature 集合。 |
| `options` | 传给 normalize_remaps() 的可选项。 |

返回：路径解析报告。

结构：

- `remaps`: Dictionary 或 Array 形式的资源 feature remap 声明。
- `options`: Dictionary，可包含 keep_invalid_entries 字段。
- `return`: Dictionary，包含 ok、selected、source_path、target_path、resolved_path、feature、entry、entry_index、issues 与计数字段。

<a id="member-gfresourcefeatureremaptools-methods-build_remap_plan"></a>

### `build_remap_plan`

- API：`public`
- 首次版本：`6.1.0`

```gdscript
static func build_remap_plan( remaps: Variant, active_features: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

生成一组资源 feature 重映射的执行计划。 计划报告只描述 source 到 target 的选择结果、未命中 source，以及可由外层工具跳过的 unused target 路径；调用方仍需自行决定如何替换 Resource、原始文件或导出包内容。

参数：

| 名称 | 说明 |
|---|---|
| `remaps` | 资源 feature remap 声明。 |
| `active_features` | 当前启用的 feature 集合。 |
| `options` | 可选项，支持 keep_invalid_entries、resource_extensions、exported_paths、protected_paths、protect_original_paths、protect_selected_targets、skip_unused_targets 与 include_unmatched。 |

返回：重映射计划报告。

结构：

- `remaps`: Dictionary 或 Array 形式的资源 feature remap 声明。
- `options`: Dictionary，可包含归一化、资源扩展名、导出路径和 skip 保护选项。
- `return`: Dictionary，包含 ok、active_features、selected_targets、resolved、unmatched、skip_paths、issues 与计数字段。
