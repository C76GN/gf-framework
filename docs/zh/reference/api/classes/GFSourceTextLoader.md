# GFSourceTextLoader

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_source_text_loader.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

受根路径约束的源码文本加载器。 将逻辑 key 解析、文本加载、内存注册文本、缓存 key 和诊断报告拆开， 供生成器、导入器、编辑器工具或校验器读取 UTF-8 文本。文件访问默认要求 root_path，避免 include 或片段加载越过调用方声明的根目录。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`root_path`](#member-gfsourcetextloader-properties-root_path) | `var root_path: String = ""` |
| 属性 | [`allow_registered_text`](#member-gfsourcetextloader-properties-allow_registered_text) | `var allow_registered_text: bool = true` |
| 属性 | [`allow_custom_loaders`](#member-gfsourcetextloader-properties-allow_custom_loaders) | `var allow_custom_loaders: bool = true` |
| 属性 | [`allow_file_access`](#member-gfsourcetextloader-properties-allow_file_access) | `var allow_file_access: bool = true` |
| 属性 | [`cache_enabled`](#member-gfsourcetextloader-properties-cache_enabled) | `var cache_enabled: bool = true` |
| 属性 | [`max_bytes`](#member-gfsourcetextloader-properties-max_bytes) | `var max_bytes: int = 0` |
| 属性 | [`metadata`](#member-gfsourcetextloader-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`_init`](#member-gfsourcetextloader-methods-_init) | `func _init(p_root_path: String = "", options: Dictionary = {}) -> void:` |
| 方法 | [`configure`](#member-gfsourcetextloader-methods-configure) | `func configure(p_root_path: String = "", options: Dictionary = {}) -> GFSourceTextLoader:` |
| 方法 | [`clear`](#member-gfsourcetextloader-methods-clear) | `func clear() -> void:` |
| 方法 | [`clear_cache`](#member-gfsourcetextloader-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`register_text`](#member-gfsourcetextloader-methods-register_text) | `func register_text(source_key: String, text: String, entry_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_text`](#member-gfsourcetextloader-methods-unregister_text) | `func unregister_text(source_key: String) -> bool:` |
| 方法 | [`add_custom_loader`](#member-gfsourcetextloader-methods-add_custom_loader) | `func add_custom_loader(loader: Callable, loader_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`clear_custom_loaders`](#member-gfsourcetextloader-methods-clear_custom_loaders) | `func clear_custom_loaders() -> void:` |
| 方法 | [`resolve_key`](#member-gfsourcetextloader-methods-resolve_key) | `func resolve_key(source_key: String, caller_span: Variant = null) -> Dictionary:` |
| 方法 | [`load_text`](#member-gfsourcetextloader-methods-load_text) | `func load_text(source_key: String, caller_span: Variant = null) -> Dictionary:` |
| 方法 | [`get_report`](#member-gfsourcetextloader-methods-get_report) | `func get_report() -> GFValidationReport:` |
| 方法 | [`duplicate_report`](#member-gfsourcetextloader-methods-duplicate_report) | `func duplicate_report() -> GFValidationReport:` |
| 方法 | [`get_debug_snapshot`](#member-gfsourcetextloader-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfsourcetextloader-properties-root_path"></a>

### `root_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var root_path: String = ""
```

文件加载根路径；读取文件时必须非空。

<a id="member-gfsourcetextloader-properties-allow_registered_text"></a>

### `allow_registered_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var allow_registered_text: bool = true
```

是否允许读取通过 register_text() 注册的内存文本。

<a id="member-gfsourcetextloader-properties-allow_custom_loaders"></a>

### `allow_custom_loaders`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var allow_custom_loaders: bool = true
```

是否允许调用自定义文本加载器。

<a id="member-gfsourcetextloader-properties-allow_file_access"></a>

### `allow_file_access`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var allow_file_access: bool = true
```

是否允许文件系统访问。

<a id="member-gfsourcetextloader-properties-cache_enabled"></a>

### `cache_enabled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var cache_enabled: bool = true
```

是否缓存加载结果。

<a id="member-gfsourcetextloader-properties-max_bytes"></a>

### `max_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_bytes: int = 0
```

最大文本字节数；小于等于 0 表示不限制。

<a id="member-gfsourcetextloader-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary，包含调用方定义的加载器上下文。

## 方法

<a id="member-gfsourcetextloader-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(p_root_path: String = "", options: Dictionary = {}) -> void:
```

创建源码文本加载器。

参数：

| 名称 | 说明 |
|---|---|
| `p_root_path` | 文件加载根路径。 |
| `options` | 可选配置，支持 allow_registered_text、allow_custom_loaders、allow_file_access、cache_enabled、max_bytes、subject 和 metadata。 |

结构：

- `options`: Dictionary，包含加载器配置。

<a id="member-gfsourcetextloader-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(p_root_path: String = "", options: Dictionary = {}) -> GFSourceTextLoader:
```

配置加载器并清空诊断。

参数：

| 名称 | 说明 |
|---|---|
| `p_root_path` | 文件加载根路径。 |
| `options` | 可选配置，支持 allow_registered_text、allow_custom_loaders、allow_file_access、cache_enabled、max_bytes、subject 和 metadata。 |

返回：当前加载器。

结构：

- `options`: Dictionary，包含加载器配置。

<a id="member-gfsourcetextloader-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空注册文本、自定义加载器、缓存和诊断。

<a id="member-gfsourcetextloader-methods-clear_cache"></a>

### `clear_cache`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_cache() -> void:
```

清空加载结果缓存。

<a id="member-gfsourcetextloader-methods-register_text"></a>

### `register_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_text(source_key: String, text: String, entry_metadata: Dictionary = {}) -> bool:
```

注册内存文本。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 逻辑 key。 |
| `text` | 文本内容。 |
| `entry_metadata` | 条目元数据。 |

返回：注册成功时返回 true。

结构：

- `entry_metadata`: Dictionary，包含调用方定义的文本条目上下文。

<a id="member-gfsourcetextloader-methods-unregister_text"></a>

### `unregister_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unregister_text(source_key: String) -> bool:
```

移除注册文本。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 逻辑 key。 |

返回：移除成功时返回 true。

<a id="member-gfsourcetextloader-methods-add_custom_loader"></a>

### `add_custom_loader`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_custom_loader(loader: Callable, loader_metadata: Dictionary = {}) -> bool:
```

添加一个自定义文本加载器。

参数：

| 名称 | 说明 |
|---|---|
| `loader` | 自定义加载回调。 |
| `loader_metadata` | 加载器元数据。 |

返回：添加成功时返回 true。

结构：

- `loader`: Callable，会以 (source_key: String, context: Dictionary) 调用；返回 null 或 { "handled": false } 表示继续尝试后续来源，返回 String、PackedByteArray，或包含 text/content/bytes 的 Dictionary 表示已加载。
- `loader_metadata`: Dictionary，会复制进回调上下文和加载结果。

<a id="member-gfsourcetextloader-methods-clear_custom_loaders"></a>

### `clear_custom_loaders`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_custom_loaders() -> void:
```

清空全部自定义文本加载器和缓存。

<a id="member-gfsourcetextloader-methods-resolve_key"></a>

### `resolve_key`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func resolve_key(source_key: String, caller_span: Variant = null) -> Dictionary:
```

解析逻辑 key。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 逻辑 key 或 root_path 内的相对路径。 |
| `caller_span` | 可选调用点源码定位。 |

返回：解析结果字典。

结构：

- `caller_span`: Variant，可传 GFSourceSpan 或兼容字典。
- `return`: Dictionary，包含 ok、source_key、resolved_path、cache_key、registered 和 report。

<a id="member-gfsourcetextloader-methods-load_text"></a>

### `load_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func load_text(source_key: String, caller_span: Variant = null) -> Dictionary:
```

加载 UTF-8 文本。

参数：

| 名称 | 说明 |
|---|---|
| `source_key` | 逻辑 key 或 root_path 内的相对路径。 |
| `caller_span` | 可选调用点源码定位。 |

返回：加载结果字典。

结构：

- `caller_span`: Variant，可传 GFSourceSpan 或兼容字典。
- `return`: Dictionary，包含 ok、text、content_hash、byte_size、source_key、resolved_path、registered、custom_loader、from_cache 和 report。

<a id="member-gfsourcetextloader-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report() -> GFValidationReport:
```

获取当前报告。

返回：校验报告。

<a id="member-gfsourcetextloader-methods-duplicate_report"></a>

### `duplicate_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_report() -> GFValidationReport:
```

创建报告副本。

返回：校验报告副本。

<a id="member-gfsourcetextloader-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：加载器状态字典。

结构：

- `return`: Dictionary，包含 root、缓存和注册文本状态。
