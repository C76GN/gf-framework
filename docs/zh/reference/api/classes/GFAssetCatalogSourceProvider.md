# GFAssetCatalogSourceProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog_source_provider.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

资产目录来源 provider 基类。 项目、工具或扩展可以继承该类，把文件夹扫描、资源注册表、内容包、外部库 或自定义数据库转换为 `GFAssetCatalog`。Provider 只贡献可重建的索引数据， 不负责素材库 UI、下载、导出或项目业务解释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source_id`](#member-gfassetcatalogsourceprovider-properties-source_id) | `var source_id: StringName = &""` |
| 属性 | [`priority`](#member-gfassetcatalogsourceprovider-properties-priority) | `var priority: int = 0` |
| 方法 | [`configure`](#member-gfassetcatalogsourceprovider-methods-configure) | `func configure(p_source_id: StringName, options: Dictionary = {}) -> GFAssetCatalogSourceProvider:` |
| 方法 | [`get_source_id`](#member-gfassetcatalogsourceprovider-methods-get_source_id) | `func get_source_id() -> StringName:` |
| 方法 | [`get_priority`](#member-gfassetcatalogsourceprovider-methods-get_priority) | `func get_priority() -> int:` |
| 方法 | [`build_catalog`](#member-gfassetcatalogsourceprovider-methods-build_catalog) | `func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:` |
| 方法 | [`get_debug_snapshot`](#member-gfassetcatalogsourceprovider-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfassetcatalogsourceprovider-properties-source_id"></a>

### `source_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var source_id: StringName = &""
```

来源稳定 ID。

<a id="member-gfassetcatalogsourceprovider-properties-priority"></a>

### `priority`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var priority: int = 0
```

来源优先级。数值越大越先合并；同 ID 条目默认被高优先级来源覆盖。

## 方法

<a id="member-gfassetcatalogsourceprovider-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure(p_source_id: StringName, options: Dictionary = {}) -> GFAssetCatalogSourceProvider:
```

配置来源 provider 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_id` | 来源稳定 ID。 |
| `options` | 可选项，支持 priority。 |

返回：当前 provider。

结构：

- `options`: Dictionary with optional priority: int.

<a id="member-gfassetcatalogsourceprovider-methods-get_source_id"></a>

### `get_source_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_source_id() -> StringName:
```

获取来源 ID。

返回：来源稳定 ID。

<a id="member-gfassetcatalogsourceprovider-methods-get_priority"></a>

### `get_priority`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_priority() -> int:
```

获取来源优先级。

返回：来源优先级。

<a id="member-gfassetcatalogsourceprovider-methods-build_catalog"></a>

### `build_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
```

构建资产目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | provider 自定义选项；GF 不解释字段。 |

返回：来源导出的资产目录。

结构：

- `options`: Dictionary with provider-defined fields.

<a id="member-gfassetcatalogsourceprovider-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取来源诊断快照。

返回：来源诊断字典。

结构：

- `return`: Dictionary with source_id, priority, and provider_class.
