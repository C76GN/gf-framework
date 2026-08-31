# GFSettingsStoreUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_settings_store_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`11.0.0`

设置持久化的同步物理端口。 该协议只定义设置载荷的读取、写入与能力查询，不绑定文件、Storage Utility、 云服务或平台 SDK。Architecture 模式且启用持久化时应注册一个派生 Store Utility； standalone 模式会由 GFSettingsUtility 自动持有 File Store。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_persistence_enabled`](#member-gfsettingsstoreutility-methods-is_persistence_enabled) | `func is_persistence_enabled() -> bool:` |
| 方法 | [`read_settings`](#member-gfsettingsstoreutility-methods-read_settings) | `func read_settings(file_name: String) -> GFStorageReadResult:` |
| 方法 | [`write_settings`](#member-gfsettingsstoreutility-methods-write_settings) | `func write_settings(file_name: String, data: Dictionary) -> Error:` |

## 方法

<a id="member-gfsettingsstoreutility-methods-is_persistence_enabled"></a>

### `is_persistence_enabled`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_persistence_enabled() -> bool:
```

检查当前 Store 是否可以接纳同步持久化请求。

返回：可以读取和写入设置时返回 true。

<a id="member-gfsettingsstoreutility-methods-read_settings"></a>

### `read_settings`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func read_settings(file_name: String) -> GFStorageReadResult:
```

读取一个设置载荷。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | Store 内的逻辑设置文件名。 |

返回：强类型读取结果；默认返回 UNAVAILABLE。

<a id="member-gfsettingsstoreutility-methods-write_settings"></a>

### `write_settings`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func write_settings(file_name: String, data: Dictionary) -> Error:
```

写入一个设置载荷。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | Store 内的逻辑设置文件名。 |
| `data` | 已由 Settings Utility 序列化的设置字典。 |

返回：Godot Error 结果码；默认返回 ERR_UNAVAILABLE。

结构：

- `data`: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
