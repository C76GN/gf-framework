# GFNetworkLobbyQuery

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_query.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

平台中立的 lobby 查询条件。 查询对象只描述通用过滤条件，由具体 backend 决定如何映射到平台查询、 局域网发现或自建服务请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`query_id`](#member-gfnetworklobbyquery-properties-query_id) | `var query_id: StringName = &""` |
| 属性 | [`search_text`](#member-gfnetworklobbyquery-properties-search_text) | `var search_text: String = ""` |
| 属性 | [`required_tags`](#member-gfnetworklobbyquery-properties-required_tags) | `var required_tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`required_metadata`](#member-gfnetworklobbyquery-properties-required_metadata) | `var required_metadata: Dictionary = {}` |
| 属性 | [`max_results`](#member-gfnetworklobbyquery-properties-max_results) | `var max_results: int = 0` |
| 属性 | [`include_full_lobbies`](#member-gfnetworklobbyquery-properties-include_full_lobbies) | `var include_full_lobbies: bool = false` |
| 属性 | [`include_unjoinable_lobbies`](#member-gfnetworklobbyquery-properties-include_unjoinable_lobbies) | `var include_unjoinable_lobbies: bool = false` |
| 属性 | [`metadata`](#member-gfnetworklobbyquery-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`matches`](#member-gfnetworklobbyquery-methods-matches) | `func matches(lobby: GFNetworkLobbyDescriptor) -> bool:` |
| 方法 | [`to_dict`](#member-gfnetworklobbyquery-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbyquery-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_query`](#member-gfnetworklobbyquery-methods-duplicate_query) | `func duplicate_query() -> GFNetworkLobbyQuery:` |
| 方法 | [`from_dict`](#member-gfnetworklobbyquery-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyQuery:` |

## 属性

<a id="member-gfnetworklobbyquery-properties-query_id"></a>

### `query_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var query_id: StringName = &""
```

查询稳定标识。

<a id="member-gfnetworklobbyquery-properties-search_text"></a>

### `search_text`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var search_text: String = ""
```

可选搜索文本。backend 可用它匹配显示名或平台自定义字段。

<a id="member-gfnetworklobbyquery-properties-required_tags"></a>

### `required_tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var required_tags: PackedStringArray = PackedStringArray()
```

必须同时具备的 tag。

<a id="member-gfnetworklobbyquery-properties-required_metadata"></a>

### `required_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var required_metadata: Dictionary = {}
```

必须匹配的 metadata 键值。

结构：

- `required_metadata`: Dictionary metadata key/value filters.

<a id="member-gfnetworklobbyquery-properties-max_results"></a>

### `max_results`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_results: int = 0
```

最大结果数。小于等于 0 表示不限制。

<a id="member-gfnetworklobbyquery-properties-include_full_lobbies"></a>

### `include_full_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var include_full_lobbies: bool = false
```

是否包含已满 lobby。

<a id="member-gfnetworklobbyquery-properties-include_unjoinable_lobbies"></a>

### `include_unjoinable_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var include_unjoinable_lobbies: bool = false
```

是否包含不可加入 lobby。

<a id="member-gfnetworklobbyquery-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义查询选项。

结构：

- `metadata`: Dictionary caller-defined query metadata.

## 方法

<a id="member-gfnetworklobbyquery-methods-matches"></a>

### `matches`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func matches(lobby: GFNetworkLobbyDescriptor) -> bool:
```

检查 lobby 是否满足本地可判断的查询条件。

参数：

| 名称 | 说明 |
|---|---|
| `lobby` | Lobby 快照。 |

返回：满足条件返回 true。

<a id="member-gfnetworklobbyquery-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：查询字典。

结构：

- `return`: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.

<a id="member-gfnetworklobbyquery-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用查询字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 查询字典。 |

结构：

- `data`: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.

<a id="member-gfnetworklobbyquery-methods-duplicate_query"></a>

### `duplicate_query`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_query() -> GFNetworkLobbyQuery:
```

创建查询深拷贝。

返回：新查询。

<a id="member-gfnetworklobbyquery-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyQuery:
```

从字典创建查询。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 查询字典。 |

返回：新查询。

结构：

- `data`: Dictionary with query_id, search_text, required_tags, required_metadata, max_results, include_full_lobbies, include_unjoinable_lobbies, and metadata.
