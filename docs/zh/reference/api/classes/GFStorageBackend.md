# GFStorageBackend

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_backend.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存储后端扩展接口。 该类只定义通用后端协议，不绑定本地、云、平台 SDK 或同步策略。 默认实现返回不可用结果；项目可继承它并由自定义 Utility 或派生的 GFStorageUtility 组合使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`initialize`](#member-gfstoragebackend-methods-initialize) | `func initialize(config: Dictionary = {}) -> Error:` |
| 方法 | [`shutdown`](#member-gfstoragebackend-methods-shutdown) | `func shutdown() -> void:` |
| 方法 | [`save_data`](#member-gfstoragebackend-methods-save_data) | `func save_data(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> Error:` |
| 方法 | [`load_data`](#member-gfstoragebackend-methods-load_data) | `func load_data(file_name: String) -> Dictionary:` |
| 方法 | [`delete_data`](#member-gfstoragebackend-methods-delete_data) | `func delete_data(file_name: String) -> Error:` |
| 方法 | [`has_data`](#member-gfstoragebackend-methods-has_data) | `func has_data(file_name: String) -> bool:` |
| 方法 | [`list_data`](#member-gfstoragebackend-methods-list_data) | `func list_data() -> Array[Dictionary]:` |
| 方法 | [`get_capabilities`](#member-gfstoragebackend-methods-get_capabilities) | `func get_capabilities() -> Dictionary:` |

## 方法

<a id="member-gfstoragebackend-methods-initialize"></a>

### `initialize`

- API：`public`

```gdscript
func initialize(config: Dictionary = {}) -> Error:
```

初始化后端。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 后端配置字典。 |

返回：Godot Error 结果码。

结构：

- `config`: Dictionary，包含后端特定的初始化选项。

<a id="member-gfstoragebackend-methods-shutdown"></a>

### `shutdown`

- API：`public`

```gdscript
func shutdown() -> void:
```

关闭后端并释放资源。

<a id="member-gfstoragebackend-methods-save_data"></a>

### `save_data`

- API：`public`

```gdscript
func save_data(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> Error:
```

保存纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `data` | 要保存的数据。 |
| `metadata` | 可选元数据。 |

返回：Godot Error 结果码。

结构：

- `data`: Dictionary，存储后端持有的数据载荷。
- `metadata`: Dictionary，包含时间戳或修订号等后端特定元数据。

<a id="member-gfstoragebackend-methods-load_data"></a>

### `load_data`

- API：`public`

```gdscript
func load_data(file_name: String) -> Dictionary:
```

读取纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：结果字典，包含 ok、data、metadata、error。

结构：

- `return`: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary 和 error: String。

<a id="member-gfstoragebackend-methods-delete_data"></a>

### `delete_data`

- API：`public`

```gdscript
func delete_data(file_name: String) -> Error:
```

删除纯字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：Godot Error 结果码。

<a id="member-gfstoragebackend-methods-has_data"></a>

### `has_data`

- API：`public`

```gdscript
func has_data(file_name: String) -> bool:
```

判断逻辑文件是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：存在时返回 true。

<a id="member-gfstoragebackend-methods-list_data"></a>

### `list_data`

- API：`public`

```gdscript
func list_data() -> Array[Dictionary]:
```

枚举后端中的逻辑文件。

返回：文件摘要数组。

结构：

- `return`: Array，包含 file_name: String 和可选 metadata: Dictionary 的 Dictionary 条目。

<a id="member-gfstoragebackend-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`

```gdscript
func get_capabilities() -> Dictionary:
```

获取后端能力描述。

返回：能力字典副本。

结构：

- `return`: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
