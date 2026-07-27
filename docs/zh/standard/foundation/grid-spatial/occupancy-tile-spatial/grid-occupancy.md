# 格子占用

`GFGridOccupancy` 是面向格子运行时状态的占用与预约结构。它是普通 `RefCounted`，不参与 `GFArchitecture` 生命周期，适合由项目自己的 `System` 持有，用来表达“谁当前占着哪个格子”“谁预定了下一步目标格”这类通用机制。

它不负责地图生成、寻路策略、碰撞检测、棋子规则或胜负判定，因此可以用于推箱子、战棋、棋盘解谜、消除棋盘等不同项目。

## 基本用法

```gdscript
var occupancy := GFGridOccupancy.new(Vector2i(8, 8))

occupancy.occupy(player, Vector2i(1, 1))

if occupancy.reserve_cell(player, Vector2i(2, 1)):
	# 项目层自行播放移动表现或执行命令
	occupancy.confirm_reservation(player)

var blocked := occupancy.is_cell_occupied(Vector2i(3, 1))
```

## 查询与事务边界

批量查询入口可用于生成候选格、调试面板、保存运行时快照或构建可视化覆盖层。`get_occupied_cells()` 与 `get_reserved_cells()` 返回按 y/x 稳定排序的格子快照；`get_occupiable_cells(receiver)` 会按当前容量、边界和预约归属返回指定接收者可占用的格子。所有查询都是无副作用快照：它们会忽略已释放的对象记录，但不会清理索引或发出释放信号。

```gdscript
var spawn_token := &"item_spawn"
var candidates := occupancy.get_occupiable_cells(spawn_token)
if not candidates.is_empty():
	var cell := candidates[randi() % candidates.size()]
	occupancy.reserve_cell(spawn_token, cell)
```

`occupy()`、`release_cell()`、`reserve_cell()` 与 `confirm_reservation()` 等写入入口以单次事务更新占用、预约和接收者反向索引，再同步发出对应信号。因此信号回调可以查询完整提交后的状态，但不能在同一通知调用栈中再次修改这个 `GFGridOccupancy`；重入写入会明确失败，`bool` 入口返回 `false`，`void` 入口保持无操作。公开信号只描述实际状态变化：接收者已经占用或有效预约目标格时，重复调用对应入口仍返回 `true`，但不会重复发出释放、占用或预约信号。调用方若需要为每次请求发送确认，应在项目流程中根据返回值显式确认，不应把状态变化信号当作逐请求回执。需要连锁移动、批量放置或响应式规则时，应先在项目 `System` 中计算完整计划，再按确定顺序提交后续事务，而不是在占用信号里继续写入。

`grid_size` 与 `max_occupants_per_cell` 的直接赋值同样属于写事务：值实际变化时会清空既有占用与预约，容量会钳制到至少 1；通知期间的直接赋值会失败关闭。需要同时修改两个配置时优先调用 `configure()`，避免分别赋值造成两次清理。

## 生命周期与标识

receiver 只接受 `Object`、非空 `StringName`、非空 `String` 或 `int`。这些类型与 `GFSpatialQueryIdentity` 使用同一稳定 key 规则；`StringName` 与 `String` 即使文本相同也属于不同身份。`Array`、`Dictionary`、空 `StringName` / `String` 和其他 Variant 类型会失败关闭，不能作为长期身份。项目若持有复合业务数据，应另外分配稳定 ID 或使用拥有该数据的 `Object`，不要让可变内容本身参与索引。

对象接收者以实例 ID 建立身份并使用弱引用记录，因此对象字段在同步通知回调中变化也不会让占用失去可达性。需要回收已释放对象留下的索引并通知缓存消费者时，显式调用 `prune_invalid_receivers()`，或等待下一次占用/预约事务在提交前执行清理；失效对象释放占用时会发出 `cell_released(null, cell)`。不要依赖任意查询触发清理信号。
