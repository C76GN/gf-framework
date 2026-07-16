# 任意拓扑图搜索

`GFGraphMath` 面向任意节点类型的图搜索。它不要求节点必须是格子坐标：`StringName`、`Vector2i`、`Resource`、对象引用或项目自定义值都可以作为节点，只要邻居和代价由回调返回即可。

适合对话跳转、技能依赖、地图连接、任务拓扑、资源生产链等“不是规则网格”的路径/可达性问题。

```gdscript
var path := GFGraphMath.find_path_a_star(
	start_node,
	goal_node,
	func(node):
		return graph.get(node, []),
	func(from_node, to_node):
		return edge_costs.get([from_node, to_node], 1.0),
	func(node, goal):
		return estimated_costs.get(node, {}).get(goal, 0.0)
)

var reachable := GFGraphMath.find_reachable(
	start_node,
	5.0,
	func(node):
		return graph.get(node, [])
)
```

`get_step_cost()` 返回负数时表示该边不可通行；启发函数为空时 A* 会退化为 Dijkstra。

## 最小生成树

当一组节点已经有候选连接边，但项目只需要保留低成本主干时，使用 `find_minimum_spanning_tree()`。它按无向加权图处理邻居关系；邻居只要在任一方向返回即可建立边。图不连通时会返回最小生成森林，`all_connected` 为 false。

```gdscript
var report := GFGraphMath.find_minimum_spanning_tree(
	rooms,
	func(room):
		return candidate_links.get(room, []),
	func(from_room, to_room):
		return link_costs.get([from_room, to_room], 1.0)
)

var trunk_edges := report.selected_edges
var total_cost := report.total_weight
```

返回的 `selected_edges` 每项包含 `from`、`to` 和 `weight`。这个入口适合地图区域主路、房间主干、任务节点连接、资源网络预处理或编辑器生成计划；它不负责创建节点、打通走廊、绘制线段或解释边的业务含义。

## 拓扑排序

当图表示“先依赖、后使用”的关系时，使用 `sort_topological()` 得到稳定加载顺序。回调返回当前节点依赖的节点；只在传入 `nodes` 内的依赖参与排序，外部依赖会进入报告，方便调用方决定是忽略、补齐还是报错。

```gdscript
var report := GFGraphMath.sort_topological(
	[&"gameplay", &"core", &"ui"],
	func(node):
		return dependencies.get(node, [])
)

if report.get("ok", false):
	var ordered_nodes := report["order"]
else:
	var cycles := report["cycles"]
```

排序结果保证依赖节点排在使用者之前；若检测到循环，`ok` 为 false，`reason` 为 `cycle_detected`，`cycles` 中保留可诊断的环路节点序列。

## 连通分量

当项目需要检查一组节点是否被拆成多个互不连通的子图时，使用 `find_connected_components()`。它只计算传入 `nodes` 中声明的节点，邻居里出现的外部节点会进入报告，但不会被自动加入图。

```gdscript
var report := GFGraphMath.find_connected_components(
	[&"start", &"shop", &"boss", &"secret"],
	func(node):
		return graph.get(node, [])
)

if not report.all_connected:
	var islands := report.components
	var missing_links := report.external_neighbors
```

这个入口按无向边处理连通性，适合地图房间、资源子图、编辑器生成计划或 Flow 子图的结构诊断。若项目图是有向图，并且希望按弱连通关系检查，需要让邻居回调返回足够的出边或反向边；若要检查依赖顺序和循环，仍应使用 `sort_topological()`。

## 分步搜索

大图或编辑器工具不适合一帧内完成搜索时，使用 `begin_path_search()` 创建 `GFGraphPathSearchState` 运行期句柄，再用 `advance_path_search()` 按预算推进。

```gdscript
var search := GFGraphMath.begin_path_search(
	start_node,
	goal_node,
	func(node):
		return graph.get(node, []),
	func(from_node, to_node):
		return edge_costs.get([from_node, to_node], 1.0),
	func(node, goal):
		return estimated_costs.get(node, {}).get(goal, 0.0)
)

var report := {}
while not report.get("finished", false):
	report = GFGraphMath.advance_path_search(search, 32)

if report.get("found", false):
	var path := report["path"]
```

分步搜索状态是 `GFGraphPathSearchState` 运行期句柄，内部包含回调和 frontier 队列状态；它用于跨帧暂停/恢复，不是存档格式。需要序列化项目自己的图状态时，应只保存项目节点、边和种子等纯数据，再重新创建搜索句柄。

GF 不缓存图，也不维护节点生命周期，避免把项目的业务拓扑绑定进框架。
