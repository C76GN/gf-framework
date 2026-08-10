# GFContentPackageUtility

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/runtime/gf_content_package_utility.gd`
- 模块：`Extensions / Content Package`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

内容包发现、目录构建和资源解析注册服务。 维护显式 source root 列表，加载其中的 `gf_content_package.json`，构建 GFContentPackageCatalog， 并把内容包资源键映射同步到 GFResourceResolverUtility。它不下载内容、不扫描全项目、不决定包启用策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`catalog_rebuilt`](#member-gfcontentpackageutility-signals-catalog_rebuilt) | `signal catalog_rebuilt(catalog: GFContentPackageCatalog)` |
| 常量 | [`DEFAULT_SOURCE_ROOT_OWNER_ID`](#member-gfcontentpackageutility-constants-default_source_root_owner_id) | `const DEFAULT_SOURCE_ROOT_OWNER_ID: StringName = &"gf.content_package.manual"` |
| 方法 | [`register_source_root`](#member-gfcontentpackageutility-methods-register_source_root) | `func register_source_root(root_path: String) -> bool:` |
| 方法 | [`unregister_source_root`](#member-gfcontentpackageutility-methods-unregister_source_root) | `func unregister_source_root(root_path: String) -> bool:` |
| 方法 | [`clear_source_roots`](#member-gfcontentpackageutility-methods-clear_source_roots) | `func clear_source_roots() -> void:` |
| 方法 | [`register_source_root_for_owner`](#member-gfcontentpackageutility-methods-register_source_root_for_owner) | `func register_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:` |
| 方法 | [`unregister_source_root_for_owner`](#member-gfcontentpackageutility-methods-unregister_source_root_for_owner) | `func unregister_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:` |
| 方法 | [`replace_owner_source_roots`](#member-gfcontentpackageutility-methods-replace_owner_source_roots) | `func replace_owner_source_roots( owner_id: StringName, root_paths: PackedStringArray ) -> GFValidationReport:` |
| 方法 | [`clear_owner_source_roots`](#member-gfcontentpackageutility-methods-clear_owner_source_roots) | `func clear_owner_source_roots(owner_id: StringName) -> int:` |
| 方法 | [`get_owner_source_roots`](#member-gfcontentpackageutility-methods-get_owner_source_roots) | `func get_owner_source_roots(owner_id: StringName) -> PackedStringArray:` |
| 方法 | [`get_source_root_owner_ids`](#member-gfcontentpackageutility-methods-get_source_root_owner_ids) | `func get_source_root_owner_ids() -> PackedStringArray:` |
| 方法 | [`get_source_roots`](#member-gfcontentpackageutility-methods-get_source_roots) | `func get_source_roots() -> PackedStringArray:` |
| 方法 | [`get_catalog`](#member-gfcontentpackageutility-methods-get_catalog) | `func get_catalog() -> GFContentPackageCatalog:` |
| 方法 | [`discover_manifest_paths`](#member-gfcontentpackageutility-methods-discover_manifest_paths) | `func discover_manifest_paths(root_path: String = "") -> PackedStringArray:` |
| 方法 | [`load_manifest`](#member-gfcontentpackageutility-methods-load_manifest) | `func load_manifest(path: String) -> GFContentPackageManifest:` |
| 方法 | [`rebuild_catalog`](#member-gfcontentpackageutility-methods-rebuild_catalog) | `func rebuild_catalog(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`set_manifests`](#member-gfcontentpackageutility-methods-set_manifests) | `func set_manifests( manifests: Array[GFContentPackageManifest], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`register_resources`](#member-gfcontentpackageutility-methods-register_resources) | `func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfcontentpackageutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfcontentpackageutility-signals-catalog_rebuilt"></a>

### `catalog_rebuilt`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
signal catalog_rebuilt(catalog: GFContentPackageCatalog)
```

当内容包目录重建后发出。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 当前内容包目录的隔离快照。 |

## 常量

<a id="member-gfcontentpackageutility-constants-default_source_root_owner_id"></a>

### `DEFAULT_SOURCE_ROOT_OWNER_ID`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_SOURCE_ROOT_OWNER_ID: StringName = &"gf.content_package.manual"
```

register_source_root() 等便捷入口使用的显式 owner scope。

## 方法

<a id="member-gfcontentpackageutility-methods-register_source_root"></a>

### `register_source_root`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func register_source_root(root_path: String) -> bool:
```

把内容包 source root 注册到默认 manual owner scope。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | \`res://\` 或 \`user://\` 下的内容包根目录。该目录自身或其直接子目录可包含 \`gf_content_package.json\`。 |

返回：注册成功返回 true。

<a id="member-gfcontentpackageutility-methods-unregister_source_root"></a>

### `unregister_source_root`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func unregister_source_root(root_path: String) -> bool:
```

从默认 manual owner scope 注销内容包 source root。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 已注册的 source root。 |

返回：注销成功返回 true。

<a id="member-gfcontentpackageutility-methods-clear_source_roots"></a>

### `clear_source_roots`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_source_roots() -> void:
```

清空默认 manual owner scope 的内容包 source root。

<a id="member-gfcontentpackageutility-methods-register_source_root_for_owner"></a>

### `register_source_root_for_owner`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func register_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:
```

为稳定 owner 注册内容包 source root。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 非空 owner ID，用于批量释放来源。 |
| `root_path` | \`res://\` 或 \`user://\` 根目录。 |

返回：owner 首次取得该 root 时返回 true。

<a id="member-gfcontentpackageutility-methods-unregister_source_root_for_owner"></a>

### `unregister_source_root_for_owner`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func unregister_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:
```

从稳定 owner 注销一个内容包 source root。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 注册时使用的 owner ID。 |
| `root_path` | 已注册 root。 |

返回：找到并释放时返回 true。

<a id="member-gfcontentpackageutility-methods-replace_owner_source_roots"></a>

### `replace_owner_source_roots`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func replace_owner_source_roots( owner_id: StringName, root_paths: PackedStringArray ) -> GFValidationReport:
```

原子替换一个 owner 的全部 source root。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 非空 owner ID。 |
| `root_paths` | 新 root 集合；空集合表示释放 owner。 |

返回：类型化验证报告；任一 root 无效时不修改现有状态。

<a id="member-gfcontentpackageutility-methods-clear_owner_source_roots"></a>

### `clear_owner_source_roots`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_owner_source_roots(owner_id: StringName) -> int:
```

释放一个 owner 的全部 source root。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 要释放的 owner ID。 |

返回：释放的 owner-root 关系数量。

<a id="member-gfcontentpackageutility-methods-get_owner_source_roots"></a>

### `get_owner_source_roots`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_owner_source_roots(owner_id: StringName) -> PackedStringArray:
```

获取一个 owner 持有的 source root。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | owner ID。 |

返回：排序后的 root 副本。

<a id="member-gfcontentpackageutility-methods-get_source_root_owner_ids"></a>

### `get_source_root_owner_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_source_root_owner_ids() -> PackedStringArray:
```

获取当前持有 source root 的 owner ID。

返回：排序后的 owner ID 文本。

<a id="member-gfcontentpackageutility-methods-get_source_roots"></a>

### `get_source_roots`

- API：`public`

```gdscript
func get_source_roots() -> PackedStringArray:
```

获取内容包 source root 列表。

返回：source root 副本。

<a id="member-gfcontentpackageutility-methods-get_catalog"></a>

### `get_catalog`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_catalog() -> GFContentPackageCatalog:
```

获取当前内容包目录。

返回：当前内容包目录的深拷贝。

<a id="member-gfcontentpackageutility-methods-discover_manifest_paths"></a>

### `discover_manifest_paths`

- API：`public`

```gdscript
func discover_manifest_paths(root_path: String = "") -> PackedStringArray:
```

发现 source root 中的内容包 manifest 路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 可选 source root；为空时使用全部已注册 source root。 |

返回：manifest 路径列表。

<a id="member-gfcontentpackageutility-methods-load_manifest"></a>

### `load_manifest`

- API：`public`

```gdscript
func load_manifest(path: String) -> GFContentPackageManifest:
```

从 manifest 路径加载内容包。

参数：

| 名称 | 说明 |
|---|---|
| `path` | manifest 文件路径。 |

返回：内容包 manifest；加载失败返回 null。

<a id="member-gfcontentpackageutility-methods-rebuild_catalog"></a>

### `rebuild_catalog`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func rebuild_catalog(options: Dictionary = {}) -> Dictionary:
```

从已注册 source root 重建内容包目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项，透传给 GFContentPackageCatalog。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids、rejected_manifest_count 和 rejected_manifest_inputs。

<a id="member-gfcontentpackageutility-methods-set_manifests"></a>

### `set_manifests`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func set_manifests( manifests: Array[GFContentPackageManifest], options: Dictionary = {} ) -> Dictionary:
```

手动替换内容包目录。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 内容包 manifest 列表。 |
| `options` | 校验选项，透传给 GFContentPackageCatalog。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `manifests`: Array[GFContentPackageManifest]，无效项会被拒绝并进入诊断。
- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids、rejected_manifest_count 和 rejected_manifest_inputs。

<a id="member-gfcontentpackageutility-methods-register_resources"></a>

### `register_resources`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:
```

把当前内容包目录同步到资源解析器。

参数：

| 名称 | 说明 |
|---|---|
| `resolver` | 标准资源解析器。 |
| `options` | 注册选项。\`base_priority\` 默认为 0；校验选项透传给 manifest。 |

返回：GFValidationReportDictionary 兼容报告，并包含 registered_count。

结构：

- `options`: Dictionary，可包含 base_priority: int、check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 registered_count。

<a id="member-gfcontentpackageutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取内容包服务调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 source_roots、source_root_owners 和 catalog。
