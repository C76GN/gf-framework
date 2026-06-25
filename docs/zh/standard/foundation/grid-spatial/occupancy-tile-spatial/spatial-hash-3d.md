# 3D 空间哈希

`GFSpatialHash3D` 是面向 3D 实体的纯逻辑空间哈希。它只维护调用方传入的 `AABB` 索引，适合在 `System` 中做大量动态实体的粗筛查询，例如感知范围、区域触发、编辑器预览或轻量服务器模拟。

```gdscript
var spatial_hash := GFSpatialHash3D.new(4.0)
spatial_hash.insert(unit_id, AABB(unit_position, Vector3.ONE))

for entity in spatial_hash.query_radius(Vector3.ZERO, 12.0):
	# 项目层自行做精确规则判断
	pass
```

需要以固定空间桶做流式加载、兴趣管理或编辑器预览时，可以把世界坐标映射为哈希格子，再按格子范围取候选：

```gdscript
var center_cell := spatial_hash.get_cell_for_position(camera.global_position)

for entity in spatial_hash.query_cell_range(center_cell, Vector3i(2, 0, 2)):
	# 项目层自行决定加载、显示、同步或进一步过滤
	pass
```

`query_cell()` 与 `query_cell_range()` 返回的是桶内粗筛候选，适合快速定位一批可能相关的实体；它们不替代 `query_aabb()` / `query_radius()` 的几何过滤，也不规定 chunk 生命周期、网络可见性或存档策略。需要观察索引规模时，可读取 `get_debug_snapshot()` 获取 `entity_count`、`bucket_count` 和桶大小统计。

它不依赖物理节点，也不负责碰撞、阵营、视线或目标选择规则；这些语义仍应留在项目自己的 `System` 或规则对象中。

`GFGridMath` 的连线访问状态、`GFGridOccupancy` 的格子索引和 `GFSpatialHash3D` 的空间桶索引都使用坐标值作为内部 key，避免在高频网格/空间查询中反复拼接临时字符串。

调用方仍只依赖公开方法；如果需要序列化格子坐标，应在项目层或专门缓存结构中显式转换成稳定文本。
