# GFConfigProviderAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_provider_adapter.gd`
- 模块：`Standard`
- 继承：`GFConfigProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用配置表 Provider 适配器。 用于把项目自己的生成表对象、字典表、数组表或懒加载 Callable 接入 GFConfigProvider。 适配器只负责统一查询协议、懒加载缓存和诊断报告，不绑定具体导表工具、文件格式或业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_REGISTERED`](#member-gfconfigprovideradapter-constants-status_registered) | `const STATUS_REGISTERED: StringName = &"registered"` |
| 常量 | [`STATUS_LOADED`](#member-gfconfigprovideradapter-constants-status_loaded) | `const STATUS_LOADED: StringName = &"loaded"` |
| 常量 | [`STATUS_MISSING`](#member-gfconfigprovideradapter-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_FAILED`](#member-gfconfigprovideradapter-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 方法 | [`register_table_source`](#member-gfconfigprovideradapter-methods-register_table_source) | `func register_table_source(table_name: StringName, source: Variant, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_table_source`](#member-gfconfigprovideradapter-methods-unregister_table_source) | `func unregister_table_source(table_name: StringName) -> bool:` |
| 方法 | [`clear_table_sources`](#member-gfconfigprovideradapter-methods-clear_table_sources) | `func clear_table_sources() -> void:` |
| 方法 | [`has_table_source`](#member-gfconfigprovideradapter-methods-has_table_source) | `func has_table_source(table_name: StringName) -> bool:` |
| 方法 | [`get_table_ids`](#member-gfconfigprovideradapter-methods-get_table_ids) | `func get_table_ids() -> PackedStringArray:` |
| 方法 | [`preload_table`](#member-gfconfigprovideradapter-methods-preload_table) | `func preload_table(table_name: StringName) -> Dictionary:` |
| 方法 | [`clear_table_cache`](#member-gfconfigprovideradapter-methods-clear_table_cache) | `func clear_table_cache(table_name: StringName) -> bool:` |
| 方法 | [`clear_cache`](#member-gfconfigprovideradapter-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`get_record`](#member-gfconfigprovideradapter-methods-get_record) | `func get_record(table_name: StringName, record_id: Variant) -> Variant:` |
| 方法 | [`get_table`](#member-gfconfigprovideradapter-methods-get_table) | `func get_table(table_name: StringName) -> Variant:` |
| 方法 | [`get_load_report`](#member-gfconfigprovideradapter-methods-get_load_report) | `func get_load_report(table_name: StringName) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfconfigprovideradapter-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfconfigprovideradapter-constants-status_registered"></a>

### `STATUS_REGISTERED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REGISTERED: StringName = &"registered"
```

表源已经注册。

<a id="member-gfconfigprovideradapter-constants-status_loaded"></a>

### `STATUS_LOADED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_LOADED: StringName = &"loaded"
```

表源已经加载。

<a id="member-gfconfigprovideradapter-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

表源不存在。

<a id="member-gfconfigprovideradapter-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

表源加载失败。

## 方法

<a id="member-gfconfigprovideradapter-methods-register_table_source"></a>

### `register_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_table_source(table_name: StringName, source: Variant, options: Dictionary = {}) -> bool:
```

注册一个配置表源。 source 可以是 Array、Dictionary、自定义 Object 或 Callable。Callable 会在首次查询时以 `(table_name: StringName, metadata: Dictionary)` 调用，并返回实际表数据。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `source` | 表源。 |
| `options` | 注册选项。 |

返回：注册成功返回 true。

结构：

- `source`: Variant，支持 Array、Dictionary、Object 或 Callable；Object 可通过 table_method/record_method 适配。
- `options`: Dictionary，可包含 schema: GFConfigTableSchema、id_field: StringName/String、table_method: StringName/String、record_method: StringName/String、cache: bool、duplicate_values: bool 和 metadata: Dictionary。

<a id="member-gfconfigprovideradapter-methods-unregister_table_source"></a>

### `unregister_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unregister_table_source(table_name: StringName) -> bool:
```

注销一个配置表源。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：找到并注销时返回 true。

<a id="member-gfconfigprovideradapter-methods-clear_table_sources"></a>

### `clear_table_sources`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_table_sources() -> void:
```

清空所有表源、缓存和 schema。

<a id="member-gfconfigprovideradapter-methods-has_table_source"></a>

### `has_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_table_source(table_name: StringName) -> bool:
```

检查是否注册了表源。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已注册返回 true。

<a id="member-gfconfigprovideradapter-methods-get_table_ids"></a>

### `get_table_ids`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_table_ids() -> PackedStringArray:
```

获取已注册表名。

返回：排序后的表名列表。

<a id="member-gfconfigprovideradapter-methods-preload_table"></a>

### `preload_table`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func preload_table(table_name: StringName) -> Dictionary:
```

预加载指定表源并返回加载报告。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：加载报告。

结构：

- `return`: Dictionary，包含 ok、status、table_name、loaded、record_count、cached 和 error。

<a id="member-gfconfigprovideradapter-methods-clear_table_cache"></a>

### `clear_table_cache`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_table_cache(table_name: StringName) -> bool:
```

清理指定表的懒加载缓存。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：找到并清理缓存时返回 true。

<a id="member-gfconfigprovideradapter-methods-clear_cache"></a>

### `clear_cache`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_cache() -> void:
```

清理全部懒加载缓存。

<a id="member-gfconfigprovideradapter-methods-get_record"></a>

### `get_record`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_record(table_name: StringName, record_id: Variant) -> Variant:
```

根据表名和 ID 获取单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record_id` | 记录 ID。 |

返回：记录数据；未命中时返回 null。

结构：

- `record_id`: Variant，项目配置表使用的记录键。
- `return`: Variant，通常为 Dictionary 或项目自定义记录对象。

<a id="member-gfconfigprovideradapter-methods-get_table"></a>

### `get_table`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_table(table_name: StringName) -> Variant:
```

根据表名获取整张表数据。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：表数据；未命中时返回 null。

结构：

- `return`: Variant，通常为 Array、Dictionary 或项目自定义表对象。

<a id="member-gfconfigprovideradapter-methods-get_load_report"></a>

### `get_load_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_load_report(table_name: StringName) -> Dictionary:
```

获取指定表的最近加载报告。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：加载报告。

结构：

- `return`: Dictionary，包含 ok、status、table_name、loaded、record_count、cached 和 error。

<a id="member-gfconfigprovideradapter-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取适配器调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 table_count、loaded_count、table_ids、loaded_table_ids 和 load_reports。
