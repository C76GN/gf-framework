# GFConfigProviderAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_provider_adapter.gd`
- 模块：`Standard`
- 继承：`GFResourceConfigProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

外部配置来源的显式捕获适配器。 注册仅建立来源清单；prepare_tables() 捕获引用闭包，load_tables() 验收后发布。 查询继承已发布快照协议，不执行加载器。生成对象提供整表方法，或明确的 record_ids 与记录方法；对象记录通过 record_projector 转为 Dictionary。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_table_source`](#member-gfconfigprovideradapter-methods-register_table_source) | `func register_table_source( table_name: StringName, source: Variant, options: Dictionary = {} ) -> bool:` |
| 方法 | [`unregister_table_source`](#member-gfconfigprovideradapter-methods-unregister_table_source) | `func unregister_table_source(table_name: StringName) -> bool:` |
| 方法 | [`clear_table_sources`](#member-gfconfigprovideradapter-methods-clear_table_sources) | `func clear_table_sources() -> void:` |
| 方法 | [`has_table_source`](#member-gfconfigprovideradapter-methods-has_table_source) | `func has_table_source(table_name: StringName) -> bool:` |
| 方法 | [`get_source_ids`](#member-gfconfigprovideradapter-methods-get_source_ids) | `func get_source_ids() -> PackedStringArray:` |
| 方法 | [`prepare_tables`](#member-gfconfigprovideradapter-methods-prepare_tables) | `func prepare_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`load_tables`](#member-gfconfigprovideradapter-methods-load_tables) | `func load_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_load_report`](#member-gfconfigprovideradapter-methods-get_load_report) | `func get_load_report(table_name: StringName) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfconfigprovideradapter-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfconfigprovideradapter-methods-register_table_source"></a>

### `register_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_table_source( table_name: StringName, source: Variant, options: Dictionary = {} ) -> bool:
```

注册或替换来源，不改变已发布的表。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 非空表名。 |
| `source` | 在显式准备时读取的来源。 |
| `options` | 来源声明；集合和 schema 在注册时复制。 |

返回：声明合法时为 true；失败保留原来源。

结构：

- `source`: Array、按 ID 索引的 Dictionary、Object 或 Callable；Callable 接收 table_name、metadata 并返回上述数据。
- `options`: Dictionary，可包含 schema: GFConfigTableSchema、id_field: StringName、table_method: StringName（默认 get_table）、record_method: StringName（默认 get_record）、record_ids: Array、record_projector: Callable（接收单条记录并返回 Dictionary）、metadata: Dictionary、content_version: String。

<a id="member-gfconfigprovideradapter-methods-unregister_table_source"></a>

### `unregister_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unregister_table_source(table_name: StringName) -> bool:
```

注销来源；活动表通过 update_tables() 显式移除。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 来源表名。 |

返回：是否移除了来源。

<a id="member-gfconfigprovideradapter-methods-clear_table_sources"></a>

### `clear_table_sources`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_table_sources() -> void:
```

释放来源和准备报告；已有快照仍可查询。

<a id="member-gfconfigprovideradapter-methods-has_table_source"></a>

### `has_table_source`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_table_source(table_name: StringName) -> bool:
```

检查来源是否存在，与活动表是否已加载分别查询。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 来源表名。 |

返回：是否已注册来源。

<a id="member-gfconfigprovideradapter-methods-get_source_ids"></a>

### `get_source_ids`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_ids() -> PackedStringArray:
```

返回来源清单；get_table_ids() 返回已发布清单。

返回：排序后的来源表名。

<a id="member-gfconfigprovideradapter-methods-prepare_tables"></a>

### `prepare_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:
```

捕获指定来源及 schema 引用闭包，不发布候选。 每次请求重新捕获选定闭包；其他活动表复用旧快照。循环引用按集合捕获， 加载器递归准备则失败。加载器是同步可信代码；异步 IO 由项目完成后再注册。

参数：

| 名称 | 说明 |
|---|---|
| `table_names` | 本次请求的根表。 |
| `options` | 内容版本、移除项和共享工作预算。 |

返回：候选及其发布代际，失败不影响活动数据。

结构：

- `options`: Dictionary，与 prepare_update() 相同；非空来源 content_version 必须匹配 version。
- `return`: Dictionary，含 ok、error_kind、snapshot、expected_generation；成功另含 prepared_tables、source_generation、validation_report、work_report。

<a id="member-gfconfigprovideradapter-methods-load_tables"></a>

### `load_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func load_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:
```

显式准备并发布指定闭包，失败保留原活动快照。

参数：

| 名称 | 说明 |
|---|---|
| `table_names` | 请求的根表。 |
| `options` | 与 prepare_tables() 相同。 |

返回：准备诊断与发布结果。

结构：

- `options`: Dictionary，可包含 version、removed_tables、work_budget 或 work_limits。
- `return`: Dictionary，含 ok、error_kind、generation，以及准备结果中的诊断字段。

<a id="member-gfconfigprovideradapter-methods-get_load_report"></a>

### `get_load_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_load_report(table_name: StringName) -> Dictionary:
```

查询来源、最近准备结果与活动数据状态，不触发加载。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：独立报告副本。

结构：

- `return`: Dictionary，含 status: StringName（registered/prepared/failed/missing）、error_kind: StringName、registered: bool、loaded: bool、generation: int。

<a id="member-gfconfigprovideradapter-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

返回不触发加载的来源与活动快照概况。

返回：独立诊断字典。

结构：

- `return`: Dictionary，含 source_ids: PackedStringArray、loaded_table_ids: PackedStringArray、source_generation: int、generation: int。
