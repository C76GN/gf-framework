# GFDriftReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_drift_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`7.0.0`

通用集合与目录漂移报告辅助。 用于比较两个来源中的 ID 或条目，输出 matched、missing、extra 和 stale 结果。它不绑定资源、配置、包或编辑器业务语义，调用方负责提供稳定 key。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_MISSING`](#member-gfdriftreport-constants-kind_missing) | `const KIND_MISSING: StringName = &"drift_missing"` |
| 常量 | [`KIND_EXTRA`](#member-gfdriftreport-constants-kind_extra) | `const KIND_EXTRA: StringName = &"drift_extra"` |
| 常量 | [`KIND_STALE`](#member-gfdriftreport-constants-kind_stale) | `const KIND_STALE: StringName = &"drift_stale"` |
| 方法 | [`compare_ids`](#member-gfdriftreport-methods-compare_ids) | `static func compare_ids( expected_ids: PackedStringArray, actual_ids: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`compare_entries`](#member-gfdriftreport-methods-compare_entries) | `static func compare_entries( expected_entries: Dictionary, actual_entries: Dictionary, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfdriftreport-constants-kind_missing"></a>

### `KIND_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_MISSING: StringName = &"drift_missing"
```

期望来源中存在，但实际来源中缺失。

<a id="member-gfdriftreport-constants-kind_extra"></a>

### `KIND_EXTRA`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_EXTRA: StringName = &"drift_extra"
```

实际来源中存在，但期望来源中不存在。

<a id="member-gfdriftreport-constants-kind_stale"></a>

### `KIND_STALE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_STALE: StringName = &"drift_stale"
```

两个来源都存在同一 key，但条目内容不同。

## 方法

<a id="member-gfdriftreport-methods-compare_ids"></a>

### `compare_ids`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func compare_ids( expected_ids: PackedStringArray, actual_ids: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

比较两个 ID 集合。 只比较 key 是否存在，不比较条目值。

参数：

| 名称 | 说明 |
|---|---|
| `expected_ids` | 期望来源 ID。 |
| `actual_ids` | 实际来源 ID。 |
| `options` | 报告选项，支持 subject、expected_label、actual_label、metadata、missing_severity 和 extra_severity。 |

返回：漂移报告字典。

结构：

- `options`: Dictionary controlling labels, metadata, and issue severities.
- `return`: Dictionary report payload with matched、missing、extra、stale and count fields.

<a id="member-gfdriftreport-methods-compare_entries"></a>

### `compare_entries`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func compare_entries( expected_entries: Dictionary, actual_entries: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

比较两个 key -> entry 字典。 默认会比较同名 key 的值；如果只需要集合差异，可传入 `{ "compare_values": false }`。

参数：

| 名称 | 说明 |
|---|---|
| `expected_entries` | 期望来源条目。 |
| `actual_entries` | 实际来源条目。 |
| `options` | 报告选项，支持 subject、expected_label、actual_label、metadata、compare_values、include_values、numeric_epsilon、match_string_names、missing_severity、extra_severity 和 stale_severity。 |

返回：漂移报告字典。

结构：

- `expected_entries`: Dictionary keyed by stable entry id.
- `actual_entries`: Dictionary keyed by stable entry id.
- `options`: Dictionary controlling labels, value comparison, metadata, and issue severities.
- `return`: Dictionary report payload with matched、missing、extra、stale and count fields.
