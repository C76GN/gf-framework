# GFGraphPathSearchState

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_graph_path_search_state.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`5.0.0`

可预算推进的图路径搜索运行期句柄。 该对象保存 A* / Dijkstra 分步搜索所需的回调、frontier、分数和路径重建状态。 它只适合运行期跨帧推进，不是存档格式，也不应写入网络同步 payload。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_SEARCHING`](#member-gfgraphpathsearchstate-constants-status_searching) | `const STATUS_SEARCHING: StringName = &"searching"` |
| 常量 | [`STATUS_FOUND`](#member-gfgraphpathsearchstate-constants-status_found) | `const STATUS_FOUND: StringName = &"found"` |
| 常量 | [`STATUS_UNREACHABLE`](#member-gfgraphpathsearchstate-constants-status_unreachable) | `const STATUS_UNREACHABLE: StringName = &"unreachable"` |
| 常量 | [`STATUS_INVALID`](#member-gfgraphpathsearchstate-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 方法 | [`create`](#member-gfgraphpathsearchstate-methods-create) | `static func create( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> GFGraphPathSearchState:` |
| 方法 | [`make_invalid`](#member-gfgraphpathsearchstate-methods-make_invalid) | `static func make_invalid(start: Variant, goal: Variant, reason: StringName) -> GFGraphPathSearchState:` |
| 方法 | [`advance`](#member-gfgraphpathsearchstate-methods-advance) | `func advance(max_iterations: int = 64) -> Dictionary:` |
| 方法 | [`make_report`](#member-gfgraphpathsearchstate-methods-make_report) | `func make_report(iterations: int = 0) -> Dictionary:` |
| 方法 | [`is_valid`](#member-gfgraphpathsearchstate-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`is_finished`](#member-gfgraphpathsearchstate-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`get_status`](#member-gfgraphpathsearchstate-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_reason`](#member-gfgraphpathsearchstate-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_path`](#member-gfgraphpathsearchstate-methods-get_path) | `func get_path() -> Array:` |
| 方法 | [`get_cost`](#member-gfgraphpathsearchstate-methods-get_cost) | `func get_cost() -> float:` |

## 常量

<a id="member-gfgraphpathsearchstate-constants-status_searching"></a>

### `STATUS_SEARCHING`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const STATUS_SEARCHING: StringName = &"searching"
```

分步路径搜索仍可继续推进。

<a id="member-gfgraphpathsearchstate-constants-status_found"></a>

### `STATUS_FOUND`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const STATUS_FOUND: StringName = &"found"
```

分步路径搜索已找到路径。

<a id="member-gfgraphpathsearchstate-constants-status_unreachable"></a>

### `STATUS_UNREACHABLE`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const STATUS_UNREACHABLE: StringName = &"unreachable"
```

分步路径搜索已耗尽可达节点且不可达。

<a id="member-gfgraphpathsearchstate-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

分步路径搜索状态或回调无效。

## 方法

<a id="member-gfgraphpathsearchstate-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func create( start: Variant, goal: Variant, get_neighbors: Callable, get_step_cost: Callable = Callable(), heuristic: Callable = Callable() ) -> GFGraphPathSearchState:
```

创建可分步推进的 A* / Dijkstra 搜索状态。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `goal` | 终点节点。 |
| `get_neighbors` | 邻居回调，签名为 `func(node: Variant) -> Array`。 |
| `get_step_cost` | 可选代价回调，签名为 `func(from: Variant, to: Variant) -> float`；返回负数表示不可通行。 |
| `heuristic` | 可选启发回调，签名为 `func(node: Variant, goal: Variant) -> float`；为空时退化为 Dijkstra。 |

返回：搜索状态句柄。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.

<a id="member-gfgraphpathsearchstate-methods-make_invalid"></a>

### `make_invalid`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func make_invalid(start: Variant, goal: Variant, reason: StringName) -> GFGraphPathSearchState:
```

创建已结束的无效搜索状态。

参数：

| 名称 | 说明 |
|---|---|
| `start` | 起点节点。 |
| `goal` | 终点节点。 |
| `reason` | 无效原因。 |

返回：已标记为 invalid 的搜索状态句柄。

结构：

- `start`: Variant graph node identity.
- `goal`: Variant graph node identity.

<a id="member-gfgraphpathsearchstate-methods-advance"></a>

### `advance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func advance(max_iterations: int = 64) -> Dictionary:
```

按最大迭代次数推进分步路径搜索状态。 每次迭代最多弹出并扩展一个节点；`max_iterations <= 0` 时只返回当前报告。

参数：

| 名称 | 说明 |
|---|---|
| `max_iterations` | 本次最多扩展多少个节点。 |

返回：搜索报告，包含 status、finished、found、iterations、frontier_count、expanded_count、path 和 cost。

结构：

- `return`: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.

<a id="member-gfgraphpathsearchstate-methods-make_report"></a>

### `make_report`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func make_report(iterations: int = 0) -> Dictionary:
```

生成当前搜索报告，不推进搜索。

参数：

| 名称 | 说明 |
|---|---|
| `iterations` | 本次调用实际扩展的节点数。 |

返回：当前搜索报告。

结构：

- `return`: Dictionary with ok, status, finished, found, reason, iterations, frontier_count, expanded_count, path, and cost.

<a id="member-gfgraphpathsearchstate-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_valid() -> bool:
```

判断该状态是否满足搜索句柄基本格式。

返回：状态格式有效时返回 true。

<a id="member-gfgraphpathsearchstate-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_finished() -> bool:
```

判断搜索是否已经结束。

返回：搜索已结束时返回 true。

<a id="member-gfgraphpathsearchstate-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_status() -> StringName:
```

获取当前搜索状态。

返回：当前状态枚举值。

<a id="member-gfgraphpathsearchstate-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_reason() -> StringName:
```

获取当前结束或失败原因。

返回：reason 字段。

<a id="member-gfgraphpathsearchstate-methods-get_path"></a>

### `get_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_path() -> Array:
```

获取当前找到的路径副本。

返回：路径节点数组副本。

结构：

- `return`: Array graph node path from start to goal.

<a id="member-gfgraphpathsearchstate-methods-get_cost"></a>

### `get_cost`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_cost() -> float:
```

获取当前路径成本。

返回：已找到路径的累计成本；未找到时为 INF。
