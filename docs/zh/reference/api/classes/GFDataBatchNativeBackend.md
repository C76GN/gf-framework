# GFDataBatchNativeBackend

[API Reference](../index.md) / [Data Batch](../extensions-data-batch.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/data_batch/runtime/gf_data_batch_native_backend.gd`
- 模块：`Data Batch`
- 继承：`GFDataBatchBackend`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`12.0.0`

连接可选的原生 PackedArray gather 服务。 发布者默认在主线程查找由 GDExtension 注册的 GfPackedGatherBackend 引擎服务，确认服务提供 gather 方法且协议版本为 1。 项目也可调用 create() 显式连接。服务未加载或不兼容时，create() 返回 null，默认发布者使用 GDScript。各平台和架构的安装包见同版本手册「入门 → 快速开始 → 安装与 AutoLoad」。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfdatabatchnativebackend-methods-create) | `static func create() -> GFDataBatchNativeBackend:` |
| 方法 | [`get_protocol_version`](#member-gfdatabatchnativebackend-methods-get_protocol_version) | `func get_protocol_version() -> int:` |
| 方法 | [`supports_type`](#member-gfdatabatchnativebackend-methods-supports_type) | `func supports_type(numeric_type: int) -> bool:` |
| 方法 | [`gather`](#member-gfdatabatchnativebackend-methods-gather) | `func gather( columns: Array, indices: PackedInt32Array, source_count: int ) -> Array:` |

## 方法

<a id="member-gfdatabatchnativebackend-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func create() -> GFDataBatchNativeBackend:
```

在主线程连接已加载的参考后端。每次调用创建独立适配器，计算服务由引擎管理。

返回：已加载的协议 1 后端。其他线程、服务缺失或协议不兼容时返回 null。

<a id="member-gfdatabatchnativebackend-methods-get_protocol_version"></a>

### `get_protocol_version`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_protocol_version() -> int:
```

返回参考后端的固定协议身份。

返回：已连接为 1，否则为零。

<a id="member-gfdatabatchnativebackend-methods-supports_type"></a>

### `supports_type`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func supports_type(numeric_type: int) -> bool:
```

参考后端只支持精确 Int32 和 Int64 gather。

参数：

| 名称 | 说明 |
|---|---|
| `numeric_type` | GFDataBatchSchema.NumericType 值。 |

返回：已连接且类型受支持时为 true。

<a id="member-gfdatabatchnativebackend-methods-gather"></a>

### `gather`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func gather( columns: Array, indices: PackedInt32Array, source_count: int ) -> Array:
```

同步跨原生边界一次，返回完整输出或失败空数组。

参数：

| 名称 | 说明 |
|---|---|
| `columns` | 调用期间只读的有序 PackedArray 列。 |
| `indices` | 保留顺序和重复的已校验选择。 |
| `source_count` | 有效前缀长度。 |

返回：精确类型的独立列；原生调用拒绝时为空。

结构：

- `columns`: Array of PackedInt32Array or PackedInt64Array with source_count valid elements.
- `return`: Array matching input column types, each length equal to indices.size, or empty on failure.
