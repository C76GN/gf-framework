# GFExtensionUsageAudit

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_usage_audit.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

检查禁用扩展是否仍被项目文件直接引用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_SCAN_ROOTS`](#member-gfextensionusageaudit-constants-default_scan_roots) | `const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]` |
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfextensionusageaudit-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_SCANNED_FILES`](#member-gfextensionusageaudit-constants-default_max_scanned_files) | `const DEFAULT_MAX_SCANNED_FILES: int = 10000` |
| 常量 | [`DEFAULT_IGNORED_ROOTS`](#member-gfextensionusageaudit-constants-default_ignored_roots) | `const DEFAULT_IGNORED_ROOTS: Array[String] = [` |
| 常量 | [`TEXT_FILE_EXTENSIONS`](#member-gfextensionusageaudit-constants-text_file_extensions) | `const TEXT_FILE_EXTENSIONS: Array[String] = [` |
| 方法 | [`audit_disabled_extensions`](#member-gfextensionusageaudit-methods-audit_disabled_extensions) | `static func audit_disabled_extensions( manifests: Array[GFExtensionManifest], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`find_references_to_root`](#member-gfextensionusageaudit-methods-find_references_to_root) | `static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:` |

## 常量

<a id="member-gfextensionusageaudit-constants-default_scan_roots"></a>

### `DEFAULT_SCAN_ROOTS`

- API：`public`

```gdscript
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]
```

默认扫描根目录。

<a id="member-gfextensionusageaudit-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认最大扫描深度。

<a id="member-gfextensionusageaudit-constants-default_max_scanned_files"></a>

### `DEFAULT_MAX_SCANNED_FILES`

- API：`public`

```gdscript
const DEFAULT_MAX_SCANNED_FILES: int = 10000
```

默认最大扫描文件数。

<a id="member-gfextensionusageaudit-constants-default_ignored_roots"></a>

### `DEFAULT_IGNORED_ROOTS`

- API：`public`

```gdscript
const DEFAULT_IGNORED_ROOTS: Array[String] = [
```

默认忽略的根目录。

<a id="member-gfextensionusageaudit-constants-text_file_extensions"></a>

### `TEXT_FILE_EXTENSIONS`

- API：`public`

```gdscript
const TEXT_FILE_EXTENSIONS: Array[String] = [
```

作为文本扫描的资源扩展名。

## 方法

<a id="member-gfextensionusageaudit-methods-audit_disabled_extensions"></a>

### `audit_disabled_extensions`

- API：`public`

```gdscript
static func audit_disabled_extensions( manifests: Array[GFExtensionManifest], options: Dictionary = {} ) -> Dictionary:
```

检查一组禁用扩展是否仍被项目文件直接引用。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 要检查的禁用扩展 manifest 列表。 |
| `options` | 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_scan_depth、max_scanned_files。 |

返回：引用审计报告。

结构：

- `options`: Dictionary controlling scan roots, ignored roots, reference limits, depth, and scanned file count.
- `return`: Dictionary containing ok, extension_count, reference_count, extensions, and references.

<a id="member-gfextensionusageaudit-methods-find_references_to_root"></a>

### `find_references_to_root`

- API：`public`

```gdscript
static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
```

查找项目文件中对指定扩展根目录的直接路径引用。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 扩展根目录。 |
| `options` | 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_scan_depth、max_scanned_files。 |

返回：引用列表。

结构：

- `options`: Dictionary controlling scan roots, ignored roots, reference limits, depth, and scanned file count.
- `return`: Array of Dictionary file reference records.
