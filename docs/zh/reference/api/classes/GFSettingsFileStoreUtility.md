# GFSettingsFileStoreUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_settings_file_store_utility.gd`
- 模块：`Standard`
- 继承：`GFSettingsStoreUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`11.0.0`

基于 `user://` 的设置文件 Store。 该实现保留 GFSettingsUtility 历史 fallback 的同步 JSON 语义，只接受不含路径、 `..`、盘符或前后空白的简单 basename，并返回严格 GFStorageReadResult。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_persistence_enabled`](#member-gfsettingsfilestoreutility-methods-is_persistence_enabled) | `func is_persistence_enabled() -> bool:` |
| 方法 | [`read_settings`](#member-gfsettingsfilestoreutility-methods-read_settings) | `func read_settings(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`write_settings`](#member-gfsettingsfilestoreutility-methods-write_settings) | `func write_settings(file_name: String, data: Dictionary) -> Error:` |

## 方法

<a id="member-gfsettingsfilestoreutility-methods-is_persistence_enabled"></a>

### `is_persistence_enabled`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_persistence_enabled() -> bool:
```

检查当前 FileAccess Store 是否可以接纳同步持久化请求。

返回：始终返回 true；单次文件错误由读写结果报告。

<a id="member-gfsettingsfilestoreutility-methods-read_settings"></a>

### `read_settings`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func read_settings(file_name: String) -> GFStorageReadResult:
```

从 `user://` 读取一个 JSON 设置载荷。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 不含目录部分的安全文件名。 |

返回：区分成功空载荷、缺失、损坏、无效请求与 IO 失败的读取结果。

<a id="member-gfsettingsfilestoreutility-methods-write_settings"></a>

### `write_settings`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func write_settings(file_name: String, data: Dictionary) -> Error:
```

向 `user://` 写入一个 JSON 设置载荷。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 不含目录部分的安全文件名。 |
| `data` | 已由 Settings Utility 序列化的设置字典。 |

返回：Godot Error 结果码。

结构：

- `data`: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
