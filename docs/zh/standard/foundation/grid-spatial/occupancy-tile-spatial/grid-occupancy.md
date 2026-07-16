# 格子占用

`GFGridOccupancy` 是面向格子运行时状态的占用与预约结构。它是普通 `RefCounted`，不参与 `GFArchitecture` 生命周期，适合由项目自己的 `System` 持有，用来表达“谁当前占着哪个格子”“谁预定了下一步目标格”这类通用机制。

它不负责地图生成、寻路策略、碰撞检测、棋子规则或胜负判定，因此可以用于推箱子、战棋、棋盘解谜、消除棋盘等不同项目。

```gdscript
var occupancy := GFGridOccupancy.new(Vector2i(8, 8))

occupancy.occupy(player, Vector2i(1, 1))

if occupancy.reserve_cell(player, Vector2i(2, 1)):
	# 项目层自行播放移动表现或执行命令
	occupancy.confirm_reservation(player)

var blocked := occupancy.is_cell_occupied(Vector2i(3, 1))
```

批量查询入口可用于生成候选格、调试面板、保存运行时快照或构建可视化覆盖层。`get_occupied_cells()` 与 `get_reserved_cells()` 返回按 y/x 稳定排序的格子快照；`get_occupiable_cells(receiver)` 会按当前容量、边界和预约归属返回指定接收者可占用的格子。

```gdscript
var spawn_token := &"item_spawn"
var candidates := occupancy.get_occupiable_cells(spawn_token)
if not candidates.is_empty():
	var cell := candidates[randi() % candidates.size()]
	occupancy.reserve_cell(spawn_token, cell)
```

对象接收者使用弱引用记录，`prune_invalid_receivers()` 可清理已释放对象留下的占用或预约；失效对象释放占用时也会发出 `cell_released(null, cell)`，方便 UI 或棋盘缓存同步刷新。

非 `Object` 接收者会以 `typeof + str(value)` 生成内部 key，推荐使用 `StringName`、`int`、稳定字符串或 `Object`，不要直接把 `Dictionary` / `Array` 当作长期唯一标识。
