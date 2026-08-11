# GFStorageSettingsStoreUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings_storage/gf_storage_settings_store_utility.gd`
- 模块：`Standard`
- 继承：`GFSettingsStoreUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

GFStorageUtility 的设置持久化适配器。 该 Utility 声明显式 Storage 生命周期依赖，只在依赖完成 ready 后缓存并同步转发 设置读取和写入；释放依赖时清理缓存，避免在 Storage quiesce 或 dispose 后继续访问。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`ready`](#member-gfstoragesettingsstoreutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`release_dependencies`](#member-gfstoragesettingsstoreutility-methods-release_dependencies) | `func release_dependencies() -> void:` |
| 方法 | [`get_required_utilities`](#member-gfstoragesettingsstoreutility-methods-get_required_utilities) | `func get_required_utilities() -> Array[Script]:` |
| 方法 | [`is_persistence_enabled`](#member-gfstoragesettingsstoreutility-methods-is_persistence_enabled) | `func is_persistence_enabled() -> bool:` |
| 方法 | [`read_settings`](#member-gfstoragesettingsstoreutility-methods-read_settings) | `func read_settings(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`write_settings`](#member-gfstoragesettingsstoreutility-methods-write_settings) | `func write_settings(file_name: String, data: Dictionary) -> Error:` |

## 方法

<a id="member-gfstoragesettingsstoreutility-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func ready() -> void:
```

在已声明的 Storage 依赖完成 ready 后缓存其实例。

<a id="member-gfstoragesettingsstoreutility-methods-release_dependencies"></a>

### `release_dependencies`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release_dependencies() -> void:
```

释放缓存的 Storage 引用和架构依赖作用域。

<a id="member-gfstoragesettingsstoreutility-methods-get_required_utilities"></a>

### `get_required_utilities`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_required_utilities() -> Array[Script]:
```

声明同步设置持久化所需的 Storage Utility。

返回：只包含 GFStorageUtility 的依赖声明。

<a id="member-gfstoragesettingsstoreutility-methods-is_persistence_enabled"></a>

### `is_persistence_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_persistence_enabled() -> bool:
```

检查 ready 阶段是否已经解析到 Storage Utility。

返回：Storage 依赖已缓存时返回 true。

<a id="member-gfstoragesettingsstoreutility-methods-read_settings"></a>

### `read_settings`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func read_settings(file_name: String) -> GFStorageReadResult:
```

通过缓存的 GFStorageUtility 同步读取设置。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | Storage root 内的逻辑文件名。 |

返回：GFStorageUtility 的隔离读取结果；依赖不可用时返回 UNAVAILABLE。

<a id="member-gfstoragesettingsstoreutility-methods-write_settings"></a>

### `write_settings`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func write_settings(file_name: String, data: Dictionary) -> Error:
```

通过缓存的 GFStorageUtility 同步写入设置。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | Storage root 内的逻辑文件名。 |
| `data` | 已由 Settings Utility 序列化的设置字典。 |

返回：GFStorageUtility 返回的 Godot Error 结果码；依赖不可用时返回 ERR_UNAVAILABLE。

结构：

- `data`: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
