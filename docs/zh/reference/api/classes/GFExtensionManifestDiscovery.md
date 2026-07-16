# GFExtensionManifestDiscovery

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_manifest_discovery.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

GF 扩展 manifest 发现快照缓存。 在 `GFExtensionCatalog` 的无状态 manifest 读取能力之上维护快照缓存， 并通过扩展根目录、manifest 路径和 manifest 内容摘要自动判断缓存是否仍然有效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_snapshot`](#member-gfextensionmanifestdiscovery-methods-get_snapshot) | `static func get_snapshot( extra_root_paths: Array[String] = [], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear_cache`](#member-gfextensionmanifestdiscovery-methods-clear_cache) | `static func clear_cache() -> void:` |

## 方法

<a id="member-gfextensionmanifestdiscovery-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_snapshot( extra_root_paths: Array[String] = [], options: Dictionary = {} ) -> Dictionary:
```

获取当前扩展 manifest 发现快照。 默认会复用仍然有效的快照；当扩展根目录、manifest 路径集合或 manifest 内容摘要变化时， 自动重新扫描并替换缓存。

参数：

| 名称 | 说明 |
|---|---|
| `extra_root_paths` | 额外扩展集合根目录列表，每个根目录下一层为独立扩展目录。 |
| `options` | 发现选项。 |

返回：manifest 发现快照。

结构：

- `options`: Dictionary，支持 force_refresh；为 true 时跳过现有缓存并重新扫描。
- `return`: Dictionary，包含 ok、manifests、manifest_load_errors、manifest_validation_errors、invalid_manifests、external_roots、discovery_roots、signature、signature_hash、revision、manual、manifest_count、valid_manifest_count 和 invalid_manifest_count；错误条目包含 stage、extension_id、source_path 和 errors。

<a id="member-gfextensionmanifestdiscovery-methods-clear_cache"></a>

### `clear_cache`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func clear_cache() -> void:
```

清空 manifest 发现快照缓存。
