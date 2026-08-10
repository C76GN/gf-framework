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
| 常量 | [`PATH_SEARCH_STATUS_SEARCHING`](#member-gfgraphmath-constants-path_search_status_searching) | `const PATH_SEARCH_STATUS_SEARCHING: StringName = GFGraphPathSearchState.STATUS_SEARCHING` |
| 常量 | [`PATH_SEARCH_STATUS_FOUND`](#member-gfgraphmath-constants-path_search_status_found) | `const PATH_SEARCH_STATUS_FOUND: StringName = GFGraphPathSearchState.STATUS_FOUND` |
| 常量 | [`PATH_SEARCH_STATUS_UNREACHABLE`](#member-gfgraphmath-constants-path_search_status_unreachable) | `const PATH_SEARCH_STATUS_UNREACHABLE: StringName = GFGraphPathSearchState.STATUS_UNREACHABLE` |
| 常量 | [`PATH_SEARCH_STATUS_INVALID`](#member-gfgraphmath-constants-path_search_status_invalid) | `const PATH_SEARCH_STATUS_INVALID: StringName = GFGraphPathSearchState.STATUS_INVALID` |
| 方法 | [`find_path_dijkstra`](#member-gfgraphmath-methods-find_path_dijkstra) | `static func find_path_dijkstra( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Array[Variant]:` |
| 方法 | [`find_path_a_star`](#member-gfgraphmath-methods-find_path_a_star) | `static func find_path_a_star( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> Array[Variant]:` |
| 方法 | [`begin_path_search`](#member-gfgraphmath-methods-begin_path_search) | `static func begin_path_search( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> GFGraphPathSearchState:` |
| 方法 | [`advance_path_search`](#member-gfgraphmath-methods-advance_path_search) | `static func advance_path_search(search_state: GFGraphPathSearchState, max_iterations: int = 64) -> Dictionary:` |
| 方法 | [`build_distance_map`](#member-gfgraphmath-methods-build_distance_map) | `static func build_distance_map( start: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), max_cost: float = INF ) -> Dictionary:` |
| 方法 | [`find_reachable`](#member-gfgraphmath-methods-find_reachable) | `static func find_reachable( start: Variant, max_cost: float, get_neighbors: Callable, get_step_cost: Callable = Callable() ) -> Dictionary:` |
| 方法 | [`sort_topological`](#member-gfgraphmath-methods-sort_topological) | `static func sort_topological(nodes: Array, get_dependencies: Callable) -> Dictionary:` |
| 方法 | [`find_connected_components`](#member-gfgraphmath-methods-find_connected_components) | `static func find_connected_components(nodes: Array, get_neighbors: Callable) -> Dictionary:` |
| 方法 | [`find_minimum_spanning_tree`](#member-gfgraphmath-methods-find_minimum_spanning_tree) | `static func find_minimum_spanning_tree( nodes: Array, get_neighbors: Callable, get_edge_weight: Callable = Callable() ) -> Dictionary:` |

## 常量

<a id="member-gfgraphmath-constants-path_search_status_searching"></a>

### `PATH_SEARCH_STATUS_SEARCHING`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const PATH_SEARCH_STATUS_SEARCHING: StringName = GFGraphPathSearchState.STATUS_SEARCHING
```

分步路径搜索仍可继续推进。

<a id="member-gfgraphmath-constants-path_search_status_found"></a>

### `PATH_SEARCH_STATUS_FOUND`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const PATH_SEARCH_STATUS_FOUND: StringName = GFGraphPathSearchState.STATUS_FOUND
```

分步路径搜索已找到路径。

<a id="member-gfgraphmath-constants-path_search_status_unreachable"></a>

### `PATH_SEARCH_STATUS_UNREACHABLE`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const PATH_SEARCH_STATUS_UNREACHABLE: StringName = GFGraphPathSearchState.STATUS_UNREACHABLE
```

分步路径搜索已耗尽可达节点且不可达。

<a id="member-gfgraphmath-constants-path_search_status_invalid"></a>

### `PATH_SEARCH_STATUS_INVALID`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const PATH_SEARCH_STATUS_INVALID: StringName = GFGraphPathSearchState.STATUS_INVALID
```

分步路径搜索状态或回调无效。

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
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_step_cost` | 可选代价回调，签名为 \`func(from: Variant, to: Variant) -> float\`；返回负数表示不可通行。 |

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
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_step_cost` | 可选代价回调，签名为 \`func(from: Variant, to: Variant) -> float\`；返回负数表示不可通行。 |
| `heuristic` | 可选启发回调，签名为 \`func(node: Variant, goal: Variant) -> float\`。 |

返回：包含起点与终点的路径；无法到达时返回空数组。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.
- `return`: Array graph node path from start to goal.

<a id="member-gfgraphmath-methods-begin_path_search"></a>

### `begin_path_search`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func begin_path_search( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> GFGraphPathSearchState:
```

创建可分步推进的 A* / Dijkstra 搜索状态。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `goal` | 终点节点。 |
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_step_cost` | 可选代价回调，签名为 \`func(from: Variant, to: Variant) -> float\`；返回负数表示不可通行。 |
| `heuristic` | 可选启发回调，签名为 \`func(node: Variant, goal: Variant) -> float\`；为空时退化为 Dijkstra。 |

返回：运行期搜索状态句柄；传给 `advance_path_search()` 后会推进同一个句柄。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.
- `return`: GFGraphPathSearchState runtime handle. It contains Callable values and mutable search state, so it is not a save format.

<a id="member-gfgraphmath-methods-advance_path_search"></a>

### `advance_path_search`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func advance_path_search(search_state: GFGraphPathSearchState, max_iterations: int = 64) -> Dictionary:
```

按最大迭代次数推进分步路径搜索状态。 每次迭代最多弹出并扩展一个节点；`max_iterations <= 0` 时只返回当前报告。 `search_state` 是运行期句柄，因此可以跨帧保存同一个引用继续推进。

参数：

| 名称 | 说明 |
|---|---|
| `search_state` | \`begin_path_search()\` 返回的状态句柄。 |
| `max_iterations` | 本次最多扩展多少个节点。 |

返回：搜索报告，包含 status、finished、found、iterations、frontier_count、expanded_count、path 和 cost。

结构：

- `search_state`: GFGraphPathSearchState runtime handle returned by `begin_path_search()`. It contains Callable values and must not be serialized as save data.
- `return`: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.

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
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_step_cost` | 可选代价回调，签名为 \`func(from: Variant, to: Variant) -> float\`；返回负数表示不可通行。 |
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
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_step_cost` | 可选代价回调，签名为 \`func(from: Variant, to: Variant) -> float\`；返回负数表示不可通行。 |

返回：字典，键为可达节点，值为从起点到该节点的最低代价。

结构：

- `start`: Variant graph node identity.
- `return`: Dictionary mapping reachable graph nodes to lowest float costs.

<a id="member-gfgraphmath-methods-sort_topological"></a>

### `sort_topological`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func sort_topological(nodes: Array, get_dependencies: Callable) -> Dictionary:
```

对节点执行稳定拓扑排序。 `get_dependencies` 签名为 `func(node: Variant) -> Array`，返回该节点依赖的节点。 只会排序 `nodes` 中声明的节点；外部依赖会进入报告但不会导致失败。

参数：

| 名称 | 说明 |
|---|---|
| `nodes` | 需要排序的节点列表；重复节点会按首次出现去重。 |
| `get_dependencies` | 依赖回调，签名为 \`func(node: Variant) -> Array\`。 |

返回：排序报告，包含 ok、reason、order、cycles、cycle_count、node_count、external_dependencies 和 external_dependency_count。

结构：

- `nodes`: Array graph node identities.
- `return`: Dictionary with ok, reason, order, cycles, cycle_count, node_count, external_dependencies, and external_dependency_count.

<a id="member-gfgraphmath-methods-find_connected_components"></a>

### `find_connected_components`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func find_connected_components(nodes: Array, get_neighbors: Callable) -> Dictionary:
```

查找声明节点集中的连通分量。 邻居回调只用于描述节点之间的边；只有 `nodes` 中声明的节点会参与分量计算。 节点之间的边按无向边处理，适合资源图、地图拓扑、流程子图和生成前诊断。

参数：

| 名称 | 说明 |
|---|---|
| `nodes` | 需要分组的节点列表；重复节点会按首次出现去重。 |
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |

返回：连通分量报告，包含 ok、reason、components、component_indices、isolated_nodes、external_neighbors 等字段。

结构：

- `nodes`: Array graph node identities.
- `return`: Dictionary with ok, reason, components, component_count, component_indices, node_count, all_connected, isolated_nodes, isolated_node_count, external_neighbors, and external_neighbor_count.

<a id="member-gfgraphmath-methods-find_minimum_spanning_tree"></a>

### `find_minimum_spanning_tree`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func find_minimum_spanning_tree( nodes: Array, get_neighbors: Callable, get_edge_weight: Callable = Callable() ) -> Dictionary:
```

查找声明节点集的最小生成树。 图按无向加权边处理；`get_neighbors` 只要在任一方向返回邻居即可建立边。 图不连通时会返回最小生成森林，并通过 `all_connected` 标记结果不是单棵树。

参数：

| 名称 | 说明 |
|---|---|
| `nodes` | 需要纳入生成树的节点列表；重复节点会按首次出现去重。 |
| `get_neighbors` | 邻居回调，签名为 \`func(node: Variant) -> Array\`。 |
| `get_edge_weight` | 可选权重回调，签名为 \`func(from: Variant, to: Variant) -> float\`；为空时每条边权重为 1。 |

返回：最小生成树报告，包含 selected_edges、total_weight、components、isolated_nodes、external_neighbors 等字段。

结构：

- `nodes`: Array graph node identities.
- `return`: Dictionary with ok, reason, selected_edges, selected_edge_count, total_weight, components, component_count, component_indices, node_count, all_connected, isolated_nodes, isolated_node_count, external_neighbors, external_neighbor_count, invalid_edges, and invalid_edge_count.
