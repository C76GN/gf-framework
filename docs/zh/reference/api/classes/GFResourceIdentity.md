# GFResourceIdentity

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_identity.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

资源键、路径和 UID 的规范化身份快照。 该对象只描述资源身份，不加载资源、不拥有缓存，也不规定项目目录策略。 它适合用于资源解析、加载状态、诊断报告和后续缓存键迁移的统一数据边界。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCHEME_RES`](#member-gfresourceidentity-constants-scheme_res) | `const SCHEME_RES: StringName = &"res"` |
| 常量 | [`SCHEME_UID`](#member-gfresourceidentity-constants-scheme_uid) | `const SCHEME_UID: StringName = &"uid"` |
| 常量 | [`SCHEME_USER`](#member-gfresourceidentity-constants-scheme_user) | `const SCHEME_USER: StringName = &"user"` |
| 常量 | [`SCHEME_NONE`](#member-gfresourceidentity-constants-scheme_none) | `const SCHEME_NONE: StringName = &""` |
| 属性 | [`resource_key`](#member-gfresourceidentity-properties-resource_key) | `var resource_key: StringName = &""` |
| 属性 | [`raw_path`](#member-gfresourceidentity-properties-raw_path) | `var raw_path: String = ""` |
| 属性 | [`canonical_path`](#member-gfresourceidentity-properties-canonical_path) | `var canonical_path: String = ""` |
| 属性 | [`uid_path`](#member-gfresourceidentity-properties-uid_path) | `var uid_path: String = ""` |
| 属性 | [`type_hint`](#member-gfresourceidentity-properties-type_hint) | `var type_hint: String = ""` |
| 属性 | [`scheme`](#member-gfresourceidentity-properties-scheme) | `var scheme: StringName = SCHEME_NONE` |
| 属性 | [`extension`](#member-gfresourceidentity-properties-extension) | `var extension: String = ""` |
| 属性 | [`cache_key`](#member-gfresourceidentity-properties-cache_key) | `var cache_key: String = ""` |
| 属性 | [`exists`](#member-gfresourceidentity-properties-exists) | `var exists: bool = false` |
| 属性 | [`metadata`](#member-gfresourceidentity-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfresourceidentity-methods-configure) | `func configure( p_resource_key: StringName, p_path: String, p_type_hint: String = "", options: Dictionary = {} ) -> GFResourceIdentity:` |
| 方法 | [`has_identity`](#member-gfresourceidentity-methods-has_identity) | `func has_identity() -> bool:` |
| 方法 | [`to_dictionary`](#member-gfresourceidentity-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`duplicate_identity`](#member-gfresourceidentity-methods-duplicate_identity) | `func duplicate_identity() -> GFResourceIdentity:` |
| 方法 | [`from_path`](#member-gfresourceidentity-methods-from_path) | `static func from_path( path: String, p_resource_key: StringName = &"", p_type_hint: String = "", options: Dictionary = {} ) -> GFResourceIdentity:` |
| 方法 | [`from_dictionary`](#member-gfresourceidentity-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFResourceIdentity:` |

## 常量

<a id="member-gfresourceidentity-constants-scheme_res"></a>

### `SCHEME_RES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEME_RES: StringName = &"res"
```

普通项目资源路径 scheme。

<a id="member-gfresourceidentity-constants-scheme_uid"></a>

### `SCHEME_UID`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEME_UID: StringName = &"uid"
```

Godot UID 资源路径 scheme。

<a id="member-gfresourceidentity-constants-scheme_user"></a>

### `SCHEME_USER`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEME_USER: StringName = &"user"
```

用户数据路径 scheme。

<a id="member-gfresourceidentity-constants-scheme_none"></a>

### `SCHEME_NONE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEME_NONE: StringName = &""
```

没有可识别 scheme。

## 属性

<a id="member-gfresourceidentity-properties-resource_key"></a>

### `resource_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var resource_key: StringName = &""
```

稳定资源键；可为空。

<a id="member-gfresourceidentity-properties-raw_path"></a>

### `raw_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var raw_path: String = ""
```

调用方传入的原始路径文本。

<a id="member-gfresourceidentity-properties-canonical_path"></a>

### `canonical_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var canonical_path: String = ""
```

规范化路径。`uid://` 可解析时会回解为 Godot 当前记录的资源路径。

<a id="member-gfresourceidentity-properties-uid_path"></a>

### `uid_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var uid_path: String = ""
```

Godot UID 路径；无法取得 UID 时为空。

<a id="member-gfresourceidentity-properties-type_hint"></a>

### `type_hint`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var type_hint: String = ""
```

ResourceLoader 类型提示；可为空。

<a id="member-gfresourceidentity-properties-scheme"></a>

### `scheme`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var scheme: StringName = SCHEME_NONE
```

路径 scheme，例如 `res`、`uid` 或 `user`。

<a id="member-gfresourceidentity-properties-extension"></a>

### `extension`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var extension: String = ""
```

规范化路径扩展名，不含点号。

<a id="member-gfresourceidentity-properties-cache_key"></a>

### `cache_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var cache_key: String = ""
```

推荐缓存键。优先使用 UID，其次使用规范化路径，最后使用资源键。

<a id="member-gfresourceidentity-properties-exists"></a>

### `exists`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var exists: bool = false
```

当前工程中是否能确认该资源存在。

<a id="member-gfresourceidentity-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary with caller-defined identity metadata.

## 方法

<a id="member-gfresourceidentity-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_resource_key: StringName, p_path: String, p_type_hint: String = "", options: Dictionary = {} ) -> GFResourceIdentity:
```

配置资源身份。

参数：

| 名称 | 说明 |
|---|---|
| `p_resource_key` | 稳定资源键；可为空。 |
| `p_path` | 原始资源路径，支持 \`res://\`、\`uid://\` 和 \`user://\`。 |
| `p_type_hint` | 可选 ResourceLoader 类型提示。 |
| `options` | 可选项，支持 check_exists 和 metadata。 |

返回：当前身份对象。

结构：

- `options`: Dictionary with optional `check_exists: bool` and `metadata: Dictionary`.

<a id="member-gfresourceidentity-methods-has_identity"></a>

### `has_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_identity() -> bool:
```

检查身份是否有路径或资源键。

返回：有路径或资源键时返回 true。

<a id="member-gfresourceidentity-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

导出可序列化字典。

返回：资源身份字典。

结构：

- `return`: Dictionary with resource_key, raw_path, canonical_path, uid_path, type_hint, scheme, extension, cache_key, exists, and metadata.

<a id="member-gfresourceidentity-methods-duplicate_identity"></a>

### `duplicate_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_identity() -> GFResourceIdentity:
```

创建资源身份副本。

返回：身份副本。

<a id="member-gfresourceidentity-methods-from_path"></a>

### `from_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_path( path: String, p_resource_key: StringName = &"", p_type_hint: String = "", options: Dictionary = {} ) -> GFResourceIdentity:
```

由路径创建资源身份。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 原始资源路径。 |
| `p_resource_key` | 可选稳定资源键。 |
| `p_type_hint` | 可选 ResourceLoader 类型提示。 |
| `options` | 可选项，支持 check_exists 和 metadata。 |

返回：新身份对象。

结构：

- `options`: Dictionary with optional `check_exists: bool` and `metadata: Dictionary`.

<a id="member-gfresourceidentity-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFResourceIdentity:
```

从字典恢复资源身份快照。

参数：

| 名称 | 说明 |
|---|---|
| `data` | to_dictionary() 兼容字典。 |

返回：身份对象。

结构：

- `data`: Dictionary with resource_key, raw_path, canonical_path, uid_path, type_hint, scheme, extension, cache_key, exists, and metadata.
