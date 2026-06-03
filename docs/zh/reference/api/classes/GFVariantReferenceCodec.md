# GFVariantReferenceCodec

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_variant_reference_codec.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.3.0`

Resource 与 Node 引用的显式编码器。 只把 Resource 路径 / UID 或相对 root 的 NodePath 转成可持久化标记， 不序列化对象图、不加载任意脚本，也不从场景树全局搜索节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REFERENCE_MARKER_KEY`](#member-gfvariantreferencecodec-constants-reference_marker_key) | `const REFERENCE_MARKER_KEY: String = "__gf_reference__"` |
| 常量 | [`REFERENCE_VERSION_KEY`](#member-gfvariantreferencecodec-constants-reference_version_key) | `const REFERENCE_VERSION_KEY: String = "version"` |
| 常量 | [`REFERENCE_KIND_KEY`](#member-gfvariantreferencecodec-constants-reference_kind_key) | `const REFERENCE_KIND_KEY: String = "kind"` |
| 常量 | [`REFERENCE_PATH_KEY`](#member-gfvariantreferencecodec-constants-reference_path_key) | `const REFERENCE_PATH_KEY: String = "path"` |
| 常量 | [`REFERENCE_UID_KEY`](#member-gfvariantreferencecodec-constants-reference_uid_key) | `const REFERENCE_UID_KEY: String = "uid"` |
| 常量 | [`REFERENCE_TYPE_HINT_KEY`](#member-gfvariantreferencecodec-constants-reference_type_hint_key) | `const REFERENCE_TYPE_HINT_KEY: String = "type_hint"` |
| 常量 | [`REFERENCE_NODE_PATH_KEY`](#member-gfvariantreferencecodec-constants-reference_node_path_key) | `const REFERENCE_NODE_PATH_KEY: String = "node_path"` |
| 常量 | [`REFERENCE_UNSUPPORTED_CLASS_KEY`](#member-gfvariantreferencecodec-constants-reference_unsupported_class_key) | `const REFERENCE_UNSUPPORTED_CLASS_KEY: String = "class"` |
| 常量 | [`OPTION_ROOT_NODE`](#member-gfvariantreferencecodec-constants-option_root_node) | `const OPTION_ROOT_NODE: String = "reference_root_node"` |
| 常量 | [`REFERENCE_KIND_RESOURCE`](#member-gfvariantreferencecodec-constants-reference_kind_resource) | `const REFERENCE_KIND_RESOURCE: String = "Resource"` |
| 常量 | [`REFERENCE_KIND_NODE`](#member-gfvariantreferencecodec-constants-reference_kind_node) | `const REFERENCE_KIND_NODE: String = "Node"` |
| 常量 | [`REFERENCE_KIND_UNSUPPORTED_OBJECT`](#member-gfvariantreferencecodec-constants-reference_kind_unsupported_object) | `const REFERENCE_KIND_UNSUPPORTED_OBJECT: String = "UnsupportedObject"` |
| 方法 | [`is_reference_marker`](#member-gfvariantreferencecodec-methods-is_reference_marker) | `static func is_reference_marker(value: Variant) -> bool:` |
| 方法 | [`is_unsupported_reference_marker`](#member-gfvariantreferencecodec-methods-is_unsupported_reference_marker) | `static func is_unsupported_reference_marker(value: Variant) -> bool:` |
| 方法 | [`get_reference_marker`](#member-gfvariantreferencecodec-methods-get_reference_marker) | `static func get_reference_marker(value: Variant) -> Dictionary:` |
| 方法 | [`encode_resource`](#member-gfvariantreferencecodec-methods-encode_resource) | `static func encode_resource(resource: Resource) -> Dictionary:` |
| 方法 | [`encode_node`](#member-gfvariantreferencecodec-methods-encode_node) | `static func encode_node(node: Node, root_node: Node) -> Dictionary:` |
| 方法 | [`encode_reference`](#member-gfvariantreferencecodec-methods-encode_reference) | `static func encode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`decode_reference`](#member-gfvariantreferencecodec-methods-decode_reference) | `static func decode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfvariantreferencecodec-constants-reference_marker_key"></a>

### `REFERENCE_MARKER_KEY`

- API：`public`

```gdscript
const REFERENCE_MARKER_KEY: String = "__gf_reference__"
```

引用标记根字段。

<a id="member-gfvariantreferencecodec-constants-reference_version_key"></a>

### `REFERENCE_VERSION_KEY`

- API：`public`

```gdscript
const REFERENCE_VERSION_KEY: String = "version"
```

引用标记格式版本字段。

<a id="member-gfvariantreferencecodec-constants-reference_kind_key"></a>

### `REFERENCE_KIND_KEY`

- API：`public`

```gdscript
const REFERENCE_KIND_KEY: String = "kind"
```

引用类型字段。

<a id="member-gfvariantreferencecodec-constants-reference_path_key"></a>

### `REFERENCE_PATH_KEY`

- API：`public`

```gdscript
const REFERENCE_PATH_KEY: String = "path"
```

Resource 路径字段。

<a id="member-gfvariantreferencecodec-constants-reference_uid_key"></a>

### `REFERENCE_UID_KEY`

- API：`public`

```gdscript
const REFERENCE_UID_KEY: String = "uid"
```

Resource UID 字段。

<a id="member-gfvariantreferencecodec-constants-reference_type_hint_key"></a>

### `REFERENCE_TYPE_HINT_KEY`

- API：`public`

```gdscript
const REFERENCE_TYPE_HINT_KEY: String = "type_hint"
```

Resource 类型提示字段。

<a id="member-gfvariantreferencecodec-constants-reference_node_path_key"></a>

### `REFERENCE_NODE_PATH_KEY`

- API：`public`

```gdscript
const REFERENCE_NODE_PATH_KEY: String = "node_path"
```

NodePath 字段。

<a id="member-gfvariantreferencecodec-constants-reference_unsupported_class_key"></a>

### `REFERENCE_UNSUPPORTED_CLASS_KEY`

- API：`public`

```gdscript
const REFERENCE_UNSUPPORTED_CLASS_KEY: String = "class"
```

不支持对象的 class 字段。

<a id="member-gfvariantreferencecodec-constants-option_root_node"></a>

### `OPTION_ROOT_NODE`

- API：`public`

```gdscript
const OPTION_ROOT_NODE: String = "reference_root_node"
```

options 中传入引用 root Node 的字段。

<a id="member-gfvariantreferencecodec-constants-reference_kind_resource"></a>

### `REFERENCE_KIND_RESOURCE`

- API：`public`

```gdscript
const REFERENCE_KIND_RESOURCE: String = "Resource"
```

Resource 引用类型。

<a id="member-gfvariantreferencecodec-constants-reference_kind_node"></a>

### `REFERENCE_KIND_NODE`

- API：`public`

```gdscript
const REFERENCE_KIND_NODE: String = "Node"
```

Node 引用类型。

<a id="member-gfvariantreferencecodec-constants-reference_kind_unsupported_object"></a>

### `REFERENCE_KIND_UNSUPPORTED_OBJECT`

- API：`public`

```gdscript
const REFERENCE_KIND_UNSUPPORTED_OBJECT: String = "UnsupportedObject"
```

不支持对象引用类型。

## 方法

<a id="member-gfvariantreferencecodec-methods-is_reference_marker"></a>

### `is_reference_marker`

- API：`public`

```gdscript
static func is_reference_marker(value: Variant) -> bool:
```

判断 value 是否为 GF 引用标记。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查的值。 |

返回：是引用标记时返回 true。

结构：

- `value`: Variant value that may contain a reference marker.

<a id="member-gfvariantreferencecodec-methods-is_unsupported_reference_marker"></a>

### `is_unsupported_reference_marker`

- API：`public`

```gdscript
static func is_unsupported_reference_marker(value: Variant) -> bool:
```

判断 value 是否为不支持对象标记。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查的值。 |

返回：是不支持对象标记时返回 true。

结构：

- `value`: Variant value that may contain a reference marker.

<a id="member-gfvariantreferencecodec-methods-get_reference_marker"></a>

### `get_reference_marker`

- API：`public`

```gdscript
static func get_reference_marker(value: Variant) -> Dictionary:
```

提取引用标记内容。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 引用标记字典。 |

返回：标记内容；不是引用标记时返回空字典。

结构：

- `value`: Dictionary with a __gf_reference__ marker.
- `return`: Dictionary containing kind, version, and reference-specific fields.

<a id="member-gfvariantreferencecodec-methods-encode_resource"></a>

### `encode_resource`

- API：`public`

```gdscript
static func encode_resource(resource: Resource) -> Dictionary:
```

编码 Resource 引用。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 要编码的资源。 |

返回：引用标记；资源为空或没有可保存路径时返回 UnsupportedObject 标记。

结构：

- `return`: Dictionary reference marker with kind Resource or UnsupportedObject.

<a id="member-gfvariantreferencecodec-methods-encode_node"></a>

### `encode_node`

- API：`public`

```gdscript
static func encode_node(node: Node, root_node: Node) -> Dictionary:
```

编码 Node 引用。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 要编码的节点。 |
| `root_node` | NodePath 的解析 root；必须等于 node 或为 node 的祖先。 |

返回：引用标记；节点不在 root_node 下时返回 UnsupportedObject 标记。

结构：

- `return`: Dictionary reference marker with kind Node or UnsupportedObject.

<a id="member-gfvariantreferencecodec-methods-encode_reference"></a>

### `encode_reference`

- API：`public`

```gdscript
static func encode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:
```

编码 Object 引用。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要编码的值。 |
| `options` | 可选项；reference_root_node 用于编码 Node 的相对路径。 |

返回：引用标记；不支持的对象返回 UnsupportedObject 标记。

结构：

- `value`: Variant Resource or Node reference.
- `options`: Dictionary with optional reference_root_node: Node.
- `return`: Dictionary reference marker.

<a id="member-gfvariantreferencecodec-methods-decode_reference"></a>

### `decode_reference`

- API：`public`

```gdscript
static func decode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:
```

解码引用标记。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 引用标记字典。 |
| `options` | 可选项；reference_root_node 用于解析 NodePath。 |

返回：解码结果。

结构：

- `value`: Dictionary reference marker produced by encode_reference().
- `options`: Dictionary with optional reference_root_node: Node.
- `return`: Dictionary with ok: bool, value: Variant, error: String, and kind: String.
