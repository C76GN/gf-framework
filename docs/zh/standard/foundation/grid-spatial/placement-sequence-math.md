# 连续放置序列数学

`GFPlacementSequenceMath` 根据已经确认的放置点或格子预测下一次候选位置。它适合编辑器画刷、关卡摆放、运行时生成序列、棋盘/方块模板连续铺排等场景；框架只返回纯数据报告，不创建节点、不加载场景，也不决定碰撞、重叠、撤销或吸附策略。

```gdscript
var report := GFPlacementSequenceMath.predict_next_position_2d([
	Vector2(120.0, 80.0),
	Vector2(160.0, 96.0),
], Vector2.ZERO, {
	"max_step_length": 96.0,
})

if report["ok"]:
	var next_position: Vector2 = report["position"]
```

## 预测规则

连续位置和离散格子使用同一套稳定规则：

- 没有历史值时返回 `fallback`，`mode == MODE_FALLBACK`。
- 只有一个历史值时复用最后一次位置，`mode == MODE_REPEAT_LAST`。
- 至少两个历史值时使用 `last + (last - previous)`，`mode == MODE_EXTRAPOLATED`。

2D / 3D 连续位置分别使用 `predict_next_position_2d()` 和 `predict_next_position_3d()`；离散格子分别使用 `predict_next_cell_2d()` 和 `predict_next_cell_3d()`。

## 步长限制

连续位置预测支持 `max_step_length`。当最近两次放置距离过大时，工具会把外推步长限制到该长度并在报告里写入 `clamped == true`。小于等于 0 的值表示不限制；NaN 或 Inf 会被当作 0 处理，避免诊断报告或 JSON 输出传播非法数值。

```gdscript
var clamped := GFPlacementSequenceMath.predict_next_position_3d(
	[Vector3.ZERO, Vector3(10.0, 0.0, 0.0)],
	Vector3.ZERO,
	{ "max_step_length": 2.5 }
)
```

## 返回报告

连续位置报告包含 `ok`、`mode`、`position`、`step`、`source_count`、`valid_count`、`ignored_invalid_count`、`clamped`、`max_step_length` 和 `error`。离散格子报告包含 `ok`、`mode`、`cell`、`step`、`source_count`、`valid_count`、`ignored_invalid_count` 和 `error`。

连续位置会忽略包含 NaN 或 Inf 的历史点；如果没有可用历史且 fallback 也无效，报告会返回 `ok == false`，并把候选位置收敛到零向量。

## 使用边界

`GFPlacementSequenceMath` 不保存历史，也不判断预测结果是否可放置。项目层应负责维护放置历史、处理旋转/缩放、执行网格吸附、检测占用或碰撞，并在需要时把结果交给 `GFEditorCommand`、对象池、发射器或自己的运行时生成系统。
