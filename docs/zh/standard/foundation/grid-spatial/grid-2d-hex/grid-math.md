# 规则 2D 网格

`GFGridMath` 是面向网格类小游戏和棋盘逻辑的纯算法工具，适合消消乐、连连看、推箱子、战棋格子等玩法原型。它不依赖 `GFArchitecture`，可以在 `Model`、`System`、测试或编辑器工具中直接静态调用。

## 核心能力

- 范围、外环、矩形和直线格子：适合 AOE、候选选区、格子画刷和视线检测。
- BFS 路径查找：适合无权重网格。
- A* 路径查找：适合带通行代价的网格。
- 分步 A*：适合大网格或编辑器工具按帧预算推进。
- 视线抽稀：适合把格子路径压缩为更少转角。
- Flow Field：适合大量单位朝一个或多个目标移动。
- 最大转弯连接：适合连连看、管线连接和棋盘路径判定。

旋转、镜像或对角翻转格子模板时，使用同组的 `GFGridTransform2D`，避免把模板变换逻辑混进寻路或范围查询。

## 范围与形状

```gdscript
var move_area := GFGridMath.get_range(unit_cell, 2, board_size)
var diagonal_area := GFGridMath.get_range(unit_cell, 2, board_size, true)
var footprint := GFGridMath.get_rectangle_cells(Vector2i(2, 2), Vector2i(4, 3), board_size)

var visible := GFGridMath.has_line_of_sight(
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return wall_cells.has(cell)
)
```

`get_range()` 和 `get_ring()` 默认使用四方向移动对应的曼哈顿距离；`include_diagonal` 为 `true` 时改用八方向移动对应的切比雪夫距离。`get_line()` 使用 Bresenham 格子直线，适合离散网格上的普通射线、指示线和简单视线判断。

## 路径与连接

```gdscript
var path := GFGridMath.find_path_bfs(
	Vector2i(8, 8),
	Vector2i(0, 0),
	Vector2i(5, 4),
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell)
)

var can_link := GFGridMath.can_connect_with_max_turns(
	Vector2i(10, 6),
	Vector2i(1, 1),
	Vector2i(8, 4),
	func(cell: Vector2i) -> bool:
		return board[cell.y][cell.x] == null
)
```

同步 `find_path_bfs()` / `find_path_a_star()` 适合小图或一次性查询。需要跨帧预算时，使用 `GFGraphPathSearchState` 分步搜索句柄：

```gdscript
var search := GFGridMath.begin_path_a_star_search(
	Vector2i(64, 64),
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell),
	false,
	func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
		return terrain_costs.get(to_cell, 1.0)
)

var report := {}
while not report.get("finished", false):
	report = GFGraphMath.advance_path_search(search, 48)
```

分步句柄复用 `GFGraphMath` 推进，`GFGridMath` 只负责网格边界、邻居、通行、代价和启发函数适配。

## 代价与流场

```gdscript
var path := GFGridMath.find_path_a_star(
	Vector2i(32, 32),
	unit_cell,
	target_cell,
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell),
	false,
	func(_from_cell: Vector2i, to_cell: Vector2i) -> float:
		return terrain_costs.get(to_cell, 1.0)
)

var field := GFGridMath.build_flow_field(
	Vector2i(32, 32),
	[target_cell],
	func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell)
)

var direction := (field["directions"] as Dictionary).get(unit_cell, Vector2i.ZERO)
```

## 路径抽稀

路径已经找到后，可以用现有视线规则移除多余中间格：

```gdscript
var simplified := GFGridMath.simplify_path_line_of_sight(
	path,
	func(cell: Vector2i) -> bool:
		return wall_cells.has(cell)
)
```

抽稀只判断格子直线是否被阻挡，不执行单位移动、不避让动态碰撞，也不替项目解释转向动画。

## 使用边界

`GFGridMath` 只接收通行、代价、阻挡和候选回调，不规定障碍、阵营、地形、棋子语义、移动动画或胜负规则。项目层负责把自己的地图数据转换成回调，并解释返回的范围、直线、路径、方向或连接结果。
