# GFInputFormatterRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_formatter_registry.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

输入格式化 provider 注册表。 为文本和图标 provider 提供可排序、可 owner 绑定、可显式释放的注册生命周期。 GFInputFormatter 的静态入口会使用默认 registry；测试、编辑器工具或局部 UI 可创建独立 registry 避免全局污染。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_text_provider`](#member-gfinputformatterregistry-methods-register_text_provider) | `func register_text_provider( provider: GFInputTextProvider, owner: Object = null ) -> GFInputProviderRegistration:` |
| 方法 | [`register_icon_provider`](#member-gfinputformatterregistry-methods-register_icon_provider) | `func register_icon_provider( provider: GFInputIconProvider, owner: Object = null ) -> GFInputProviderRegistration:` |
| 方法 | [`add_text_provider`](#member-gfinputformatterregistry-methods-add_text_provider) | `func add_text_provider(provider: GFInputTextProvider, owner: Object = null) -> void:` |
| 方法 | [`add_icon_provider`](#member-gfinputformatterregistry-methods-add_icon_provider) | `func add_icon_provider(provider: GFInputIconProvider, owner: Object = null) -> void:` |
| 方法 | [`remove_text_provider`](#member-gfinputformatterregistry-methods-remove_text_provider) | `func remove_text_provider(provider: GFInputTextProvider) -> bool:` |
| 方法 | [`remove_icon_provider`](#member-gfinputformatterregistry-methods-remove_icon_provider) | `func remove_icon_provider(provider: GFInputIconProvider) -> bool:` |
| 方法 | [`clear_text_providers`](#member-gfinputformatterregistry-methods-clear_text_providers) | `func clear_text_providers() -> void:` |
| 方法 | [`clear_icon_providers`](#member-gfinputformatterregistry-methods-clear_icon_providers) | `func clear_icon_providers() -> void:` |
| 方法 | [`get_text_providers`](#member-gfinputformatterregistry-methods-get_text_providers) | `func get_text_providers() -> Array[GFInputTextProvider]:` |
| 方法 | [`get_icon_providers`](#member-gfinputformatterregistry-methods-get_icon_providers) | `func get_icon_providers() -> Array[GFInputIconProvider]:` |
| 方法 | [`prune_invalid_provider_owners`](#member-gfinputformatterregistry-methods-prune_invalid_provider_owners) | `func prune_invalid_provider_owners() -> int:` |
| 方法 | [`dispose`](#member-gfinputformatterregistry-methods-dispose) | `func dispose() -> void:` |

## 方法

<a id="member-gfinputformatterregistry-methods-register_text_provider"></a>

### `register_text_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_text_provider( provider: GFInputTextProvider, owner: Object = null ) -> GFInputProviderRegistration:
```

注册文本 provider 并返回释放句柄。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 文本 provider。 |
| `owner` | 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。 |

返回：注册句柄；provider 为空时返回非活动句柄。

<a id="member-gfinputformatterregistry-methods-register_icon_provider"></a>

### `register_icon_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_icon_provider( provider: GFInputIconProvider, owner: Object = null ) -> GFInputProviderRegistration:
```

注册图标 provider 并返回释放句柄。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 图标 provider。 |
| `owner` | 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。 |

返回：注册句柄；provider 为空时返回非活动句柄。

<a id="member-gfinputformatterregistry-methods-add_text_provider"></a>

### `add_text_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_text_provider(provider: GFInputTextProvider, owner: Object = null) -> void:
```

注册文本 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 文本 provider。 |
| `owner` | 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。 |

<a id="member-gfinputformatterregistry-methods-add_icon_provider"></a>

### `add_icon_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_icon_provider(provider: GFInputIconProvider, owner: Object = null) -> void:
```

注册图标 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 图标 provider。 |
| `owner` | 可选拥有者；拥有者释放后该注册会在下一次查询或 prune 时失效。 |

<a id="member-gfinputformatterregistry-methods-remove_text_provider"></a>

### `remove_text_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_text_provider(provider: GFInputTextProvider) -> bool:
```

移除文本 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 文本 provider。 |

返回：移除了至少一个注册时返回 true。

<a id="member-gfinputformatterregistry-methods-remove_icon_provider"></a>

### `remove_icon_provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_icon_provider(provider: GFInputIconProvider) -> bool:
```

移除图标 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 图标 provider。 |

返回：移除了至少一个注册时返回 true。

<a id="member-gfinputformatterregistry-methods-clear_text_providers"></a>

### `clear_text_providers`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_text_providers() -> void:
```

清空文本 provider。

<a id="member-gfinputformatterregistry-methods-clear_icon_providers"></a>

### `clear_icon_providers`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_icon_providers() -> void:
```

清空图标 provider。

<a id="member-gfinputformatterregistry-methods-get_text_providers"></a>

### `get_text_providers`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_text_providers() -> Array[GFInputTextProvider]:
```

获取文本 provider 列表。

返回：provider 列表副本，按优先级从高到低排序。

<a id="member-gfinputformatterregistry-methods-get_icon_providers"></a>

### `get_icon_providers`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_icon_providers() -> Array[GFInputIconProvider]:
```

获取图标 provider 列表。

返回：provider 列表副本，按优先级从高到低排序。

<a id="member-gfinputformatterregistry-methods-prune_invalid_provider_owners"></a>

### `prune_invalid_provider_owners`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prune_invalid_provider_owners() -> int:
```

裁剪拥有者已经释放的 provider 注册。

返回：被裁剪的注册数量。

<a id="member-gfinputformatterregistry-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

清理 registry 中的所有 provider 注册。
