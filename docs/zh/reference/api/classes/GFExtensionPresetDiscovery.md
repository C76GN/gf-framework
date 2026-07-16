# GFExtensionPresetDiscovery

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_preset_discovery.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

GF 扩展 preset 发现快照缓存。 基于 manifest 集合和项目 preset 路径生成可缓存的 preset snapshot， 统一内置 preset、项目 preset、重复 ID、无效文件和未知扩展 ID 的报告边界。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_snapshot`](#member-gfextensionpresetdiscovery-methods-get_snapshot) | `static func get_snapshot( manifests: Array[GFExtensionManifest] = [], configured_paths: Array[String] = [], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear_cache`](#member-gfextensionpresetdiscovery-methods-clear_cache) | `static func clear_cache() -> void:` |

## 方法

<a id="member-gfextensionpresetdiscovery-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_snapshot( manifests: Array[GFExtensionManifest] = [], configured_paths: Array[String] = [], options: Dictionary = {} ) -> Dictionary:
```

获取当前扩展 preset 发现快照。 默认会复用仍然有效的快照；当 manifest ID/default 状态、preset 路径集合或 preset 文件内容变化时， 自动重新扫描并替换缓存。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 当前可发现的扩展 manifest 列表。 |
| `configured_paths` | 项目配置中的 preset 路径列表，可包含无效路径以便生成诊断。 |
| `options` | 发现选项。 |

返回：preset 发现快照。

结构：

- `options`: Dictionary，支持 force_refresh；为 true 时跳过现有缓存并重新扫描。
- `return`: Dictionary，包含 ok、presets、report、configured_paths、signature、signature_hash、revision、preset_count 和 issue_count。

<a id="member-gfextensionpresetdiscovery-methods-clear_cache"></a>

### `clear_cache`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func clear_cache() -> void:
```

清空 preset 发现快照缓存。
