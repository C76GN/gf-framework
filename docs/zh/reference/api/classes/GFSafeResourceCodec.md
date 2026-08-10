# GFSafeResourceCodec

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_safe_resource_codec.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

安全资源图编解码工具。 把 Variant、Array、Dictionary 和 allowlist 内的 Resource/Object 属性图 编码为纯 Dictionary，并在解码时按策略限制类、脚本、外部资源路径、深度和数量。 容器解码会在扫描或暂存完整形状前，用直接子节点基数预检剩余 max_items 预算。 该类不注册 ResourceFormatLoader/Saver，不加载未授权资源，也不执行脚本表达式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KEY_KIND`](#member-gfsaferesourcecodec-constants-key_kind) | `const KEY_KIND: String = "kind"` |
| 常量 | [`KEY_VARIANT_TYPE`](#member-gfsaferesourcecodec-constants-key_variant_type) | `const KEY_VARIANT_TYPE: String = "variant_type"` |
| 常量 | [`KEY_VALUE`](#member-gfsaferesourcecodec-constants-key_value) | `const KEY_VALUE: String = "value"` |
| 常量 | [`KEY_ITEMS`](#member-gfsaferesourcecodec-constants-key_items) | `const KEY_ITEMS: String = "items"` |
| 常量 | [`KEY_ENTRIES`](#member-gfsaferesourcecodec-constants-key_entries) | `const KEY_ENTRIES: String = "entries"` |
| 常量 | [`KEY_OBJECT_ID`](#member-gfsaferesourcecodec-constants-key_object_id) | `const KEY_OBJECT_ID: String = "object_id"` |
| 常量 | [`KEY_CLASS`](#member-gfsaferesourcecodec-constants-key_class) | `const KEY_CLASS: String = "class"` |
| 常量 | [`KEY_SCRIPT_PATH`](#member-gfsaferesourcecodec-constants-key_script_path) | `const KEY_SCRIPT_PATH: String = "script_path"` |
| 常量 | [`KEY_RESOURCE_PATH`](#member-gfsaferesourcecodec-constants-key_resource_path) | `const KEY_RESOURCE_PATH: String = "resource_path"` |
| 常量 | [`KEY_PROPERTIES`](#member-gfsaferesourcecodec-constants-key_properties) | `const KEY_PROPERTIES: String = "properties"` |
| 方法 | [`encode`](#member-gfsaferesourcecodec-methods-encode) | `static func encode(value: Variant, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`decode`](#member-gfsaferesourcecodec-methods-decode) | `static func decode(data: Dictionary, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_resource_policy`](#member-gfsaferesourcecodec-methods-make_resource_policy) | `static func make_resource_policy() -> GFSafeResourceCodecPolicy:` |

## 常量

<a id="member-gfsaferesourcecodec-constants-key_kind"></a>

### `KEY_KIND`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_KIND: String = "kind"
```

编码节点类型字段。

<a id="member-gfsaferesourcecodec-constants-key_variant_type"></a>

### `KEY_VARIANT_TYPE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_VARIANT_TYPE: String = "variant_type"
```

Variant 类型编号字段。

<a id="member-gfsaferesourcecodec-constants-key_value"></a>

### `KEY_VALUE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_VALUE: String = "value"
```

简单值字段。

<a id="member-gfsaferesourcecodec-constants-key_items"></a>

### `KEY_ITEMS`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_ITEMS: String = "items"
```

集合项字段。

<a id="member-gfsaferesourcecodec-constants-key_entries"></a>

### `KEY_ENTRIES`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_ENTRIES: String = "entries"
```

字典条目字段。

<a id="member-gfsaferesourcecodec-constants-key_object_id"></a>

### `KEY_OBJECT_ID`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_OBJECT_ID: String = "object_id"
```

对象编号字段。

<a id="member-gfsaferesourcecodec-constants-key_class"></a>

### `KEY_CLASS`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_CLASS: String = "class"
```

对象类字段。

<a id="member-gfsaferesourcecodec-constants-key_script_path"></a>

### `KEY_SCRIPT_PATH`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_SCRIPT_PATH: String = "script_path"
```

对象脚本路径字段。

<a id="member-gfsaferesourcecodec-constants-key_resource_path"></a>

### `KEY_RESOURCE_PATH`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_RESOURCE_PATH: String = "resource_path"
```

外部资源路径字段。

<a id="member-gfsaferesourcecodec-constants-key_properties"></a>

### `KEY_PROPERTIES`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_PROPERTIES: String = "properties"
```

对象属性字段。

## 方法

<a id="member-gfsaferesourcecodec-methods-encode"></a>

### `encode`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func encode(value: Variant, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:
```

编码值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要编码的值。 |
| `policy` | 安全策略；为 null 时使用空 allowlist。 |
| `options` | 编码选项。 |

返回：编码报告。

结构：

- `value`: Variant value, Array, Dictionary, Resource, or Object graph.
- `options`: Dictionary with encode_external_resources, max_depth, and max_items overrides.
- `return`: Dictionary with ok, data, issues, issue_count, and error.

<a id="member-gfsaferesourcecodec-methods-decode"></a>

### `decode`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func decode(data: Dictionary, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:
```

解码值。

参数：

| 名称 | 说明 |
|---|---|
| `data` | encode() 返回的 data 字典。 |
| `policy` | 安全策略；为 null 时使用空 allowlist。 |
| `options` | 解码选项。 |

返回：解码报告。

结构：

- `data`: Dictionary produced by encode().
- `options`: Dictionary with load_external_resources, max_depth, and max_items overrides.
- `return`: Dictionary with ok, value, issues, issue_count, and error.

<a id="member-gfsaferesourcecodec-methods-make_resource_policy"></a>

### `make_resource_policy`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_resource_policy() -> GFSafeResourceCodecPolicy:
```

创建允许 Resource 基类的策略。

返回：新策略。
