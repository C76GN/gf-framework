# GFSafeResourceCodecPolicy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_safe_resource_codec_policy.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

安全资源图编解码策略。 定义对象图编解码允许的类、脚本路径、资源路径和大小上限。 默认策略不允许实例化对象；调用方必须显式加入 allowlist，避免把存档、 网络载荷或工具缓存变成任意对象创建入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`allowed_classes`](#member-gfsaferesourcecodecpolicy-properties-allowed_classes) | `var allowed_classes: PackedStringArray = PackedStringArray()` |
| 属性 | [`allowed_script_paths`](#member-gfsaferesourcecodecpolicy-properties-allowed_script_paths) | `var allowed_script_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`allowed_resource_paths`](#member-gfsaferesourcecodecpolicy-properties-allowed_resource_paths) | `var allowed_resource_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`max_depth`](#member-gfsaferesourcecodecpolicy-properties-max_depth) | `var max_depth: int = 32:` |
| 属性 | [`max_items`](#member-gfsaferesourcecodecpolicy-properties-max_items) | `var max_items: int = 4096:` |
| 属性 | [`allow_external_resource_paths`](#member-gfsaferesourcecodecpolicy-properties-allow_external_resource_paths) | `var allow_external_resource_paths: bool = true` |
| 属性 | [`allow_object_identity_references`](#member-gfsaferesourcecodecpolicy-properties-allow_object_identity_references) | `var allow_object_identity_references: bool = true` |
| 方法 | [`allow_class`](#member-gfsaferesourcecodecpolicy-methods-allow_class) | `func allow_class(class_id: String) -> GFSafeResourceCodecPolicy:` |
| 方法 | [`allow_script_path`](#member-gfsaferesourcecodecpolicy-methods-allow_script_path) | `func allow_script_path(script_path: String) -> GFSafeResourceCodecPolicy:` |
| 方法 | [`allow_resource_path`](#member-gfsaferesourcecodecpolicy-methods-allow_resource_path) | `func allow_resource_path(path_pattern: String) -> GFSafeResourceCodecPolicy:` |
| 方法 | [`allows_class`](#member-gfsaferesourcecodecpolicy-methods-allows_class) | `func allows_class(class_id: String) -> bool:` |
| 方法 | [`allows_script_path`](#member-gfsaferesourcecodecpolicy-methods-allows_script_path) | `func allows_script_path(script_path: String) -> bool:` |
| 方法 | [`allows_resource_path`](#member-gfsaferesourcecodecpolicy-methods-allows_resource_path) | `func allows_resource_path(path: String) -> bool:` |
| 方法 | [`duplicate_policy`](#member-gfsaferesourcecodecpolicy-methods-duplicate_policy) | `func duplicate_policy() -> GFSafeResourceCodecPolicy:` |
| 方法 | [`get_debug_snapshot`](#member-gfsaferesourcecodecpolicy-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfsaferesourcecodecpolicy-properties-allowed_classes"></a>

### `allowed_classes`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_classes: PackedStringArray = PackedStringArray()
```

允许编解码的原生类名或通配模式。

结构：

- `allowed_classes`: PackedStringArray of ClassDB class names or wildcard patterns.

<a id="member-gfsaferesourcecodecpolicy-properties-allowed_script_paths"></a>

### `allowed_script_paths`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_script_paths: PackedStringArray = PackedStringArray()
```

允许设置到对象上的脚本路径或通配模式。

结构：

- `allowed_script_paths`: PackedStringArray of res:// script paths or wildcard patterns.

<a id="member-gfsaferesourcecodecpolicy-properties-allowed_resource_paths"></a>

### `allowed_resource_paths`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_resource_paths: PackedStringArray = PackedStringArray()
```

允许按路径引用或加载的外部资源路径或通配模式。

结构：

- `allowed_resource_paths`: PackedStringArray of res:// resource paths or wildcard patterns.

<a id="member-gfsaferesourcecodecpolicy-properties-max_depth"></a>

### `max_depth`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var max_depth: int = 32:
```

允许递归编解码的最大深度。

<a id="member-gfsaferesourcecodecpolicy-properties-max_items"></a>

### `max_items`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var max_items: int = 4096:
```

允许处理的最大节点、集合项和属性项总数。

<a id="member-gfsaferesourcecodecpolicy-properties-allow_external_resource_paths"></a>

### `allow_external_resource_paths`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allow_external_resource_paths: bool = true
```

是否允许把外部 Resource 编码为 resource_path 引用。

<a id="member-gfsaferesourcecodecpolicy-properties-allow_object_identity_references"></a>

### `allow_object_identity_references`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allow_object_identity_references: bool = true
```

是否允许对象图中的重复引用被编码为 identity reference。

## 方法

<a id="member-gfsaferesourcecodecpolicy-methods-allow_class"></a>

### `allow_class`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allow_class(class_id: String) -> GFSafeResourceCodecPolicy:
```

添加允许的类。

参数：

| 名称 | 说明 |
|---|---|
| `class_id` | ClassDB 类名或通配模式。 |

返回：当前策略。

<a id="member-gfsaferesourcecodecpolicy-methods-allow_script_path"></a>

### `allow_script_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allow_script_path(script_path: String) -> GFSafeResourceCodecPolicy:
```

添加允许的脚本路径。

参数：

| 名称 | 说明 |
|---|---|
| `script_path` | res:// 脚本路径或通配模式。 |

返回：当前策略。

<a id="member-gfsaferesourcecodecpolicy-methods-allow_resource_path"></a>

### `allow_resource_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allow_resource_path(path_pattern: String) -> GFSafeResourceCodecPolicy:
```

添加允许的资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `path_pattern` | res:// 资源路径或通配模式。 |

返回：当前策略。

<a id="member-gfsaferesourcecodecpolicy-methods-allows_class"></a>

### `allows_class`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allows_class(class_id: String) -> bool:
```

检查类是否允许。

参数：

| 名称 | 说明 |
|---|---|
| `class_id` | ClassDB 类名。 |

返回：允许时返回 true。

<a id="member-gfsaferesourcecodecpolicy-methods-allows_script_path"></a>

### `allows_script_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allows_script_path(script_path: String) -> bool:
```

检查脚本路径是否允许。

参数：

| 名称 | 说明 |
|---|---|
| `script_path` | res:// 脚本路径。 |

返回：允许时返回 true。

<a id="member-gfsaferesourcecodecpolicy-methods-allows_resource_path"></a>

### `allows_resource_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func allows_resource_path(path: String) -> bool:
```

检查资源路径是否允许。

参数：

| 名称 | 说明 |
|---|---|
| `path` | res:// 资源路径。 |

返回：允许时返回 true。

<a id="member-gfsaferesourcecodecpolicy-methods-duplicate_policy"></a>

### `duplicate_policy`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func duplicate_policy() -> GFSafeResourceCodecPolicy:
```

复制策略。

返回：新策略。

<a id="member-gfsaferesourcecodecpolicy-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with allowlists and limits.
