# GFGraphMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_graph_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

面向任意节点类型的纯图搜索算法。 节点可以是 Vector、StringName、Resource、对象引用或项目自定义值。 图结构由回调提供，框架只负责遍历、代价累计和路径重建。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`find_path_dijkstra`](#member-gfgraphmath-methods-find_path_dijkstra) | `static func find_path_dijkstra( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Array[Variant]:` |
| 方法 | [`find_path_a_star`](#member-gfgraphmath-methods-find_path_a_star) | `static func find_path_a_star( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> Array[Variant]:` |
| 方法 | [`build_distance_map`](#member-gfgraphmath-methods-build_distance_map) | `static func build_distance_map( start: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), max_cost: float = INF ) -> Dictionary:` |
| 方法 | [`find_reachable`](#member-gfgraphmath-methods-find_reachable) | `static func find_reachable( start: Variant, max_cost: float, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Dictionary:` |

## 方法

<a id="member-gfgraphmath-methods-find_path_dijkstra"></a>

### `find_path_dijkstra`

- API：`public`

```gdscript
static func find_path_dijkstra( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Array[Variant]:
```

使用 Dijkstra 查找一条最低代价路径。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `goal` | 终点节点。 |
| `get_neighbors` | 邻居回调，签名为 `func(node: Variant) -> Array`。 |
| `get_step_cost` | 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.
- `return`: Array graph node path from start to goal.

<a id="member-gfgraphmath-methods-find_path_a_star"></a>

### `find_path_a_star`

- API：`public`

```gdscript
static func find_path_a_star( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> Array[Variant]:
```

使用 A* 查找一条低代价路径。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `goal` | 终点节点。 |
| `get_neighbors` | 邻居回调，签名为 `func(node: Variant) -> Array`。 |
| `get_step_cost` | 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。 |
| `heuristic` | 可选启发回调，签名为 `func(node: Variant, goal: Variant) -> float`。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.
- `return`: Array graph node path from start to goal.

<a id="member-gfgraphmath-methods-build_distance_map"></a>

### `build_distance_map`

- API：`public`

```gdscript
static func build_distance_map( start: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), max_cost: float = INF ) -> Dictionary:
```

从起点生成距离图。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `get_neighbors` | 邻居回调，签名为 `func(node: Variant) -> Array`。 |
| `get_step_cost` | 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。 |
| `max_cost` | 最大累计代价，超过后停止扩展。 |

返回：字典，键为可达节点，值为从起点到该节点的最低代价。

结构：

- `start`: Variant graph node identity.
- `return`: Dictionary mapping reachable graph nodes to lowest float costs.

<a id="member-gfgraphmath-methods-find_reachable"></a>

### `find_reachable`

- API：`public`

```gdscript
static func find_reachable( start: Variant, max_cost: float, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Dictionary:
```

查找指定代价内可达的节点。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `max_cost` | 最大累计代价。 |
| `get_neighbors` | 邻居回调，签名为 `func(node: Variant) -> Array`。 |
| `get_step_cost` | 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。 |

返回：字典，键为可达节点，值为从起点到该节点的最低代价。

结构：

- `start`: Variant graph node identity.
- `return`: Dictionary mapping reachable graph nodes to lowest float costs.
