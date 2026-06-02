# GFGraphLayoutUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_graph_layout_utility.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用图布局辅助。 根据节点标识和连接关系生成编辑器坐标。它只产出布局建议， 不依赖 GraphEdit、Resource 或具体业务图类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`make_layered_layout`](#member-gfgraphlayoututility-methods-make_layered_layout) | `static func make_layered_layout( node_ids: PackedStringArray, connections: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_grid_layout`](#member-gfgraphlayoututility-methods-make_grid_layout) | `static func make_grid_layout(node_ids: PackedStringArray, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfgraphlayoututility-methods-make_layered_layout"></a>

### `make_layered_layout`

- API：`public`

```gdscript
static func make_layered_layout( node_ids: PackedStringArray, connections: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

生成分层布局。

参数：

| 名称 | 说明 |
|---|---|
| `node_ids` | 节点标识列表。 |
| `connections` | 连接列表，默认读取 from_node_id 与 to_node_id。 |
| `options` | 选项，支持 x_spacing、y_spacing、origin、from_key 与 to_key。 |

返回：node_id 字符串到 Vector2 的映射。

结构：

- `connections`: Array of Dictionary records containing source and target node ids.
- `options`: Dictionary layout options including x_spacing, y_spacing, origin, from_key, and to_key.
- `return`: Dictionary mapping node id strings to Vector2 positions.

<a id="member-gfgraphlayoututility-methods-make_grid_layout"></a>

### `make_grid_layout`

- API：`public`

```gdscript
static func make_grid_layout(node_ids: PackedStringArray, options: Dictionary = {}) -> Dictionary:
```

生成简单网格布局。

参数：

| 名称 | 说明 |
|---|---|
| `node_ids` | 节点标识列表。 |
| `options` | 选项，支持 columns、x_spacing、y_spacing 与 origin。 |

返回：node_id 字符串到 Vector2 的映射。

结构：

- `options`: Dictionary layout options including columns, x_spacing, y_spacing, and origin.
- `return`: Dictionary mapping node id strings to Vector2 positions.
