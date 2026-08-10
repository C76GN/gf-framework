# GFExtensionCatalog

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_catalog.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

GF 扩展 manifest 发现与读取辅助。 扫描 GF 内置扩展目录和项目声明的额外扩展集合根目录， 读取下一层扩展目录中的 `gf_extension.json`，供编辑器工具或项目侧扩展管理界面使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`EXTENSIONS_PATH`](#member-gfextensioncatalog-constants-extensions_path) | `const EXTENSIONS_PATH: String = "res://addons/gf/extensions"` |
| 方法 | [`load_extension_manifests`](#member-gfextensioncatalog-methods-load_extension_manifests) | `static func load_extension_manifests(options: Dictionary = {}) -> Array[GFExtensionManifest]:` |
| 方法 | [`load_all_manifests`](#member-gfextensioncatalog-methods-load_all_manifests) | `static func load_all_manifests( extra_root_paths: Array[String] = [], options: Dictionary = {} ) -> Array[GFExtensionManifest]:` |
| 方法 | [`load_manifests_in`](#member-gfextensioncatalog-methods-load_manifests_in) | `static func load_manifests_in( root_path: String, options: Dictionary = {} ) -> Array[GFExtensionManifest]:` |
| 方法 | [`get_manifest_paths`](#member-gfextensioncatalog-methods-get_manifest_paths) | `static func get_manifest_paths(root_path: String) -> Array[String]:` |

## 常量

<a id="member-gfextensioncatalog-constants-extensions_path"></a>

### `EXTENSIONS_PATH`

- API：`public`

```gdscript
const EXTENSIONS_PATH: String = "res://addons/gf/extensions"
```

GF 内置可选扩展根目录。

## 方法

<a id="member-gfextensioncatalog-methods-load_extension_manifests"></a>

### `load_extension_manifests`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
static func load_extension_manifests(options: Dictionary = {}) -> Array[GFExtensionManifest]:
```

读取 GF 内置可选扩展 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选 JSON 预算，只能收紧框架硬上限。 |

返回：扩展 manifest 列表。

结构：

- `options`: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。

<a id="member-gfextensioncatalog-methods-load_all_manifests"></a>

### `load_all_manifests`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
static func load_all_manifests( extra_root_paths: Array[String] = [], options: Dictionary = {} ) -> Array[GFExtensionManifest]:
```

读取所有 GF 可选扩展 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `extra_root_paths` | 额外扩展集合根目录列表，每个根目录下一层为独立扩展目录。 |
| `options` | 可选 JSON 预算，只能收紧框架硬上限。 |

返回：扩展 manifest 列表。

结构：

- `options`: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。

<a id="member-gfextensioncatalog-methods-load_manifests_in"></a>

### `load_manifests_in`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
static func load_manifests_in( root_path: String, options: Dictionary = {} ) -> Array[GFExtensionManifest]:
```

读取指定根目录下一层扩展目录中的 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扩展集合根目录。 |
| `options` | 可选 JSON 预算，只能收紧框架硬上限。 |

返回：扩展 manifest 列表。

结构：

- `options`: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。

<a id="member-gfextensioncatalog-methods-get_manifest_paths"></a>

### `get_manifest_paths`

- API：`public`

```gdscript
static func get_manifest_paths(root_path: String) -> Array[String]:
```

获取指定根目录下一层扩展目录中的 manifest 路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扩展集合根目录。 |

返回：manifest 路径列表。
