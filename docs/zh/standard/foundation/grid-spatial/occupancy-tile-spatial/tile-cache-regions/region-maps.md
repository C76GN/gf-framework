# 区域映射

`GFRegionMap2D` 提供更粗粒度的区域分块映射：调用方按格坐标写入任意值，结构会根据 `region_size` 归入区域，并记录被修改过的脏区域。

它适合大地图局部保存、编辑器批量处理、运行时地图缓存或导出预处理；GF 只维护 `region -> cell -> value` 和 dirty 标记，不解释地形、区块加载或存档策略。

```gdscript
var regions := GFRegionMap2D.new()
regions.region_size = Vector2i(32, 32)
regions.set_cell(Vector2i(40, 2), { "cost": 3 })

for region_key in regions.get_dirty_region_keys():
	var snapshot := regions.get_region_snapshot(region_key)
	# 项目层自行决定如何保存或刷新该区域。
	pass
```

## 3D 区域映射

`GFRegionMap3D` 提供同一概念的三维版本，使用 `Vector3i` 格坐标与三维区域键。它只管理数据与脏区域，不绑定 TileMap、渲染、碰撞或项目规则。

两种区域映射的 `clear()` 都会保留尚未消费的删除脏标记；连续清空或先删除最后一个格子再清空，也不会丢掉通知。消费者完成同步后再调用 `clear_dirty()` 确认。

```gdscript
var regions_3d := GFRegionMap3D.new()
regions_3d.region_size = Vector3i(16, 16, 16)
regions_3d.set_cell(Vector3i(33, 2, -1), { "state": &"occupied" })

var touched_regions := regions_3d.get_region_keys_for_cell_bounds(
	Vector3i(30, 0, -4),
	Vector3i(40, 8, 4)
)
var dirty_regions_3d := regions_3d.get_dirty_region_keys()
regions_3d.clear_dirty()
```
