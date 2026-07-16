# GFGridConnectionMath2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_connection_math_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

2D 网格连接判定工具。 提供最大转折次数连接判断，适合连连看类规则或需要限制折线转向次数的 纯逻辑检测。它不负责寻路移动、动画、碰撞响应或实体状态变更。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`can_connect_with_max_turns`](#member-gfgridconnectionmath2d-methods-can_connect_with_max_turns) | `static func can_connect_with_max_turns( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, max_turns: int = 2, allow_outer_border: bool = true ) -> bool:` |

## 方法

<a id="member-gfgridconnectionmath2d-methods-can_connect_with_max_turns"></a>

### `can_connect_with_max_turns`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func can_connect_with_max_turns( grid_size: Vector2i, start: Vector2i, goal: Vector2i, is_walkable: Callable, max_turns: int = 2, allow_outer_border: bool = true ) -> bool:
```

判断两个格子是否能在指定转折次数内连通。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `start` | 起点格子。 |
| `goal` | 终点格子。 |
| `is_walkable` | 可通行回调，签名为 `func(cell: Vector2i) -> bool`；起点与终点可不通行。 |
| `max_turns` | 最大转折次数，连连看常用值为 2。 |
| `allow_outer_border` | 是否允许路径经过网格外一圈虚拟空格。 |

返回：可连通时返回 true。
