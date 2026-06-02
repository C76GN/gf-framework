# GFAssetHandle

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_handle.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

GFAssetUtility 创建的资源所有权句柄。 句柄只表达“某个调用方正在持有某个资源路径”，不规定资源业务语义。 调用 release() 会把引用归还给 GFAssetUtility；句柄释放前，对应缓存路径不会被 LRU 淘汰。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`path`](#member-gfassethandle-properties-path) | `var path: String = ""` |
| 属性 | [`type_hint`](#member-gfassethandle-properties-type_hint) | `var type_hint: String = ""` |
| 属性 | [`group_id`](#member-gfassethandle-properties-group_id) | `var group_id: StringName = &""` |
| 属性 | [`resource`](#member-gfassethandle-properties-resource) | `var resource: Resource = null` |
| 方法 | [`get_resource`](#member-gfassethandle-methods-get_resource) | `func get_resource() -> Resource:` |
| 方法 | [`get_owner_id`](#member-gfassethandle-methods-get_owner_id) | `func get_owner_id() -> int:` |
| 方法 | [`is_released`](#member-gfassethandle-methods-is_released) | `func is_released() -> bool:` |
| 方法 | [`is_valid`](#member-gfassethandle-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`release`](#member-gfassethandle-methods-release) | `func release() -> bool:` |

## 属性

<a id="member-gfassethandle-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

资源路径。

<a id="member-gfassethandle-properties-type_hint"></a>

### `type_hint`

- API：`public`

```gdscript
var type_hint: String = ""
```

请求时使用的类型提示。

<a id="member-gfassethandle-properties-group_id"></a>

### `group_id`

- API：`public`

```gdscript
var group_id: StringName = &""
```

可选资源分组。

<a id="member-gfassethandle-properties-resource"></a>

### `resource`

- API：`public`

```gdscript
var resource: Resource = null
```

资源实例。

## 方法

<a id="member-gfassethandle-methods-get_resource"></a>

### `get_resource`

- API：`public`

```gdscript
func get_resource() -> Resource:
```

获取资源实例。

返回：资源实例；句柄已释放时返回 null。

<a id="member-gfassethandle-methods-get_owner_id"></a>

### `get_owner_id`

- API：`public`

```gdscript
func get_owner_id() -> int:
```

获取拥有者实例 ID。

返回：拥有者实例 ID；未绑定 owner 时为 0。

<a id="member-gfassethandle-methods-is_released"></a>

### `is_released`

- API：`public`

```gdscript
func is_released() -> bool:
```

检查句柄是否已释放。

返回：已释放返回 true。

<a id="member-gfassethandle-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
func is_valid() -> bool:
```

检查句柄当前是否仍能访问资源。

返回：可访问资源返回 true。

<a id="member-gfassethandle-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release() -> bool:
```

释放句柄持有的资源引用。

返回：成功释放返回 true。
