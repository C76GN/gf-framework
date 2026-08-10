# 调试绘制命令缓冲

`GFDebugDrawUtility` 用于在开发期收集 2D/3D 调试绘制命令，例如路径、范围、碰撞盒、文本标注。它只维护命令、频道和生命周期，不规定具体 Overlay 或渲染节点。

## 基本用法

```gdscript
var debug_draw := Gf.get_utility(GFDebugDrawUtility) as GFDebugDrawUtility
var velocity := Vector2(120.0, -20.0)
debug_draw.draw_line_2d(Vector2.ZERO, Vector2(64, 0), Color.RED, 0.2, &"path")
debug_draw.draw_box_3d(AABB(Vector3.ZERO, Vector3.ONE), Color.GREEN, 1.0, &"physics")
debug_draw.draw_vector_2d(Vector2.ZERO, velocity, Color.CYAN, 0.0, &"motion", 2.0, {
	"length_mode": "clamp",
	"max_length": 96.0,
	"draw_components": true,
})

for item in debug_draw.get_items(&"path"):
	print(item)
```

项目可以按频道开关命令，再用自己的 `CanvasItem`、`Node3D` 或编辑器面板消费 `get_items()` 返回的数据。

## 向量绘制

`draw_vector_2d()` / `draw_vector_3d()` 是线段命令的便捷封装，用于速度、加速度、力、朝向或寻路方向这类开发期观察。它们不会新增业务语义或专用渲染器；主向量、分量线和 2D 箭头都会拆成普通 line item，项目已有的调试 Overlay 可以继续只处理 `LINE_2D` / `LINE_3D`。

常用选项包括：

- `scale`：显示缩放，不改变原始向量。
- `length_mode`：`normal`、`clamp` 或 `normalize`。
- `max_length`：`clamp` / `normalize` 使用的目标长度。
- `centered`：把 `origin` 作为向量中心。
- `draw_components`：绘制轴向分量线。
- `arrowhead`：仅 2D 向量绘制箭头线。

## 生命周期

`enabled = false` 会让默认读取返回空数组，但不删除已有命令；`get_items(channel, true)` 可用于调试面板查看被禁用频道的数据。

生命周期规则：单条命令传入负数时使用 `default_lifetime_seconds`，默认值为 `0.0`，表示等待下一次 `tick()` 后清理；`default_lifetime_seconds < 0` 表示永久保留。NaN/Infinity 生命周期会被拒绝并返回 `0`，非有限 `tick(delta)` 会被忽略，非有限默认生命周期赋值也不会污染已有配置。

`max_items` 可限制缓冲区规模，超过后会丢弃最旧命令。当前 `max_items <= 0` 表示不限制，只适合受信开发工具；面向不可信输入时必须保持正数上限。
