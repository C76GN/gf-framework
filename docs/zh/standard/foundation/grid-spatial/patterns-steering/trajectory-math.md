# 轨迹预测与公式采样

`GFTrajectoryMath` 提供不依赖节点实例的 2D/3D 运动计算与受控公式采样。GF 自身不访问场景树；它适合弹道预览、移动目标瞄准、航线提示、AI 追踪候选和编辑器轨迹可视化，但不负责绘制、移动节点或解释玩法规则。公式回调的副作用与阻塞边界见下文。

## 预测未来位置

`predict_motion_2d()` 和 `predict_motion_3d()` 使用恒定加速度公式，同时返回目标时刻的位置和速度。重力可以直接作为加速度传入。

```gdscript
var prediction := GFTrajectoryMath.predict_motion_2d(
	projectile.global_position,
	projectile.velocity,
	Vector2(0.0, 980.0),
	0.75
)

if prediction["ok"]:
	var future_position: Vector2 = prediction["position"]
	var future_velocity: Vector2 = prediction["velocity"]
```

时间必须大于等于零，位置、速度、加速度和时间都必须是有限数字。失败报告使用 `reason = "invalid_argument"`，不会把 NaN 或 Infinity 继续传给绘制和物理层。

## 计算移动目标拦截点

`solve_intercept_2d()` 和 `solve_intercept_3d()` 求“恒速发射体追上匀速目标”的最早非负时间。比如塔防炮塔需要瞄准敌人将来所在的位置，而不是敌人当前的位置：

```gdscript
var solution := GFTrajectoryMath.solve_intercept_2d(
	turret.global_position,
	bullet_speed,
	enemy.global_position,
	enemy.velocity,
	3.0
)

if solution["ok"]:
	var aim_position: Vector2 = solution["position"]
	var launch_velocity: Vector2 = solution["launch_velocity"]
```

`max_time_seconds` 是可选预测窗口；负值表示不限制。报告会明确区分：

- `no_solution`：目标持续远离且无法追上，或方程没有非负实数解；
- `beyond_horizon`：存在数学解，但发生时间超过项目允许的预测窗口；
- `invalid_argument`：速度、坐标、时间窗口或容差非法。

这个解假设发射体从 `source_position` 开始以固定世界空间速率运动，不自动继承发射者速度，也不处理重力、加速、制导和障碍。

飞船、载具或移动炮台若要让弹体继承发射者的恒定速度，需要明确切换到相对发射者的参考系。假设发射者世界速度为 `source_velocity`，调用时传入 `enemy.velocity - source_velocity`。此时报告里的 `launch_velocity` 是弹体相对发射者的速度，`position` 也是平移参考系中的命中点；转换回世界空间的方式是：

```gdscript
var relative_solution := GFTrajectoryMath.solve_intercept_2d(
	launcher.global_position,
	bullet_relative_speed,
	enemy.global_position,
	enemy.velocity - source_velocity
)

if relative_solution["ok"]:
	var time_seconds: float = relative_solution["time_seconds"]
	var world_launch_velocity: Vector2 = source_velocity + relative_solution["launch_velocity"]
	var world_hit_position: Vector2 = relative_solution["position"] + source_velocity * time_seconds
```

这里假设 `source_velocity` 在拦截区间内恒定。带重力弹道应使用项目公式采样或专门的弹道求解器。

## 采样任意项目公式

`sample_formula_2d()` 和 `sample_formula_3d()` 在闭区间中均匀采样一个同步 `Callable(time_seconds)`。这允许项目表达圆、正弦、指数、参数曲线或自己的轨道公式，而不要求 GF 认识这些业务含义。

```gdscript
var orbit_center := Vector2(640.0, 360.0)
var radius := 180.0
var orbit_formula := func(time_seconds: float) -> Vector2:
	return orbit_center + Vector2(cos(time_seconds), sin(time_seconds)) * radius

var sample := GFTrajectoryMath.sample_formula_2d(
	orbit_formula,
	0.0,
	TAU,
	128
)

if sample["ok"]:
	var points: PackedVector2Array = sample["points"]
	# 项目可以把 points 交给 Line2D、编辑器 Overlay 或自己的渲染器。
```

采样数量必须在本次 `max_sample_count` 内，且不能超过 `ABSOLUTE_MAX_SAMPLE_COUNT`。预算校验会在执行项目回调前完成；超限时返回 `sample_limit_exceeded`，不会先执行一部分公式。公式返回错误类型或非有限坐标时返回 `provider_failed`，并保留失败前的有效点和对应时间，便于定位具体采样位置。

公式回调属于项目提供的受信任同步代码。它应保持快速、确定、无副作用，不应在其中等待信号、访问网络或改变场景树。如果计算需要分帧、取消或后台执行，应由项目的任务层分批调用纯数学入口。

## 与其他模块的关系

- `GFCurve2DMath` / `GFCurve3DMath` 处理已经得到的折线长度、姿态、投影和简化；`GFTrajectoryMath` 负责按时间产生点。
- `GFSteeringMath.pursue()` 是面向 steering 加速度的轻量追逐启发式；需要明确拦截时间和发射速度时使用 `solve_intercept_2d()` / `solve_intercept_3d()`。
- `Line2D`、`ImmediateMesh`、地图编辑器画布和调试 Overlay 属于展示层，不由轨迹数学自动创建。
- 天体力学、N 体模拟、制导策略、武器参数和命中规则仍属于项目或独立扩展。
