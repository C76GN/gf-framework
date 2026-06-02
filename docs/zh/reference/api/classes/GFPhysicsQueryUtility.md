# GFPhysicsQueryUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial/gf_physics_query_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.1.0`

通用物理查询辅助。 提供不绑定玩法语义的物理查询方法。调用方负责决定命中结果如何排序、 过滤、解释和分发；本工具只封装稳定的查询流程和结果补充字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_RAYCAST_RESULTS`](#member-gfphysicsqueryutility-constants-default_max_raycast_results) | `const DEFAULT_MAX_RAYCAST_RESULTS: int = 32` |
| 常量 | [`DEFAULT_RAYCAST_MARGIN`](#member-gfphysicsqueryutility-constants-default_raycast_margin) | `const DEFAULT_RAYCAST_MARGIN: float = 0.01` |
| 方法 | [`raycast_all_3d`](#member-gfphysicsqueryutility-methods-raycast_all_3d) | `func raycast_all_3d( world: World3D, from: Vector3, to: Vector3, options: Dictionary = {} ) -> Array[Dictionary]:` |

## 常量

<a id="member-gfphysicsqueryutility-constants-default_max_raycast_results"></a>

### `DEFAULT_MAX_RAYCAST_RESULTS`

- API：`public`

```gdscript
const DEFAULT_MAX_RAYCAST_RESULTS: int = 32
```

多命中射线查询的默认最大命中数。

<a id="member-gfphysicsqueryutility-constants-default_raycast_margin"></a>

### `DEFAULT_RAYCAST_MARGIN`

- API：`public`

```gdscript
const DEFAULT_RAYCAST_MARGIN: float = 0.01
```

多命中射线查询命中后沿射线推进的默认距离。

## 方法

<a id="member-gfphysicsqueryutility-methods-raycast_all_3d"></a>

### `raycast_all_3d`

- API：`public`

```gdscript
func raycast_all_3d( world: World3D, from: Vector3, to: Vector3, options: Dictionary = {} ) -> Array[Dictionary]:
```

沿一条 3D 射线收集多个命中结果。 每次命中后会把命中的 RID 加入本次查询的排除列表，并沿射线方向推进 margin，直到没有更多命中、到达终点或达到 max_results。 返回的每个 Dictionary 保留 Godot `intersect_ray()` 的原始字段，并额外包含 `index` 与 `distance` 字段。

参数：

| 名称 | 说明 |
|---|---|
| `world` | 用于执行查询的 World3D。 |
| `from` | 射线起点。 |
| `to` | 射线终点。 |
| `options` | 可选查询参数。 |

返回：按射线方向排序的命中结果列表。

结构：

- `options`: Dictionary，支持 collision_mask: int、exclude: Array[RID or CollisionObject3D]、max_results: int、margin: float、collide_with_bodies: bool、collide_with_areas: bool、hit_back_faces: bool 和 hit_from_inside: bool。
- `return`: Array[Dictionary]，每项包含 Godot intersect_ray() 返回字段，并额外包含 index: int 与 distance: float。
