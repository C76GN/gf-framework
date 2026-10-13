# 弹簧平滑数学

`GFSpringMath` 提供通用二阶弹簧步进。它只接收当前值、当前速度、目标值、时间步长和弹簧参数，成功返回下一帧的 `value` 与 `velocity`；调用方先检查结果非空，再保存两个字段供下一帧继续使用。

这个能力适合需要“有惯性地靠近目标”的纯数值场景，例如相机偏移、UI 指示器、输入缓冲值、反馈强度或任意项目自定义状态。GF 不提供节点跟随器，不创建 Tween，也不决定目标来源、归一化角度、碰撞或动画播放。

```gdscript
var state: Dictionary = GFSpringMath.step_vector2(
	current_offset,
	current_velocity,
	target_offset,
	delta,
	4.0,
	1.0
)
if not state.is_empty():
	current_offset = GFVariantData.get_option_vector2(state, "value")
	current_velocity = GFVariantData.get_option_vector2(state, "velocity")
```

改变目标时继续保存当前 `value` 与 `velocity`，下一次只传入新的目标。每帧把速度重置为零会丢失惯性，也会改变目标突变后的响应。项目决定切换目标不意味着弹簧状态需要重建；需要立即跳到目标时，由项目同时设置当前值和速度。

## 核心入口

- `step_float()`：标量弹簧步进。
- `step_angle()`：弧度角弹簧步进，会先按最短角度方向调整目标；返回值不自动归一化。
- `step_vector2()`：逐分量处理 `Vector2`。
- `step_vector3()`：逐分量处理 `Vector3`。

## 参数语义

- `frequency_hz` 越大，靠近目标越快；小于等于 0 的值会按极小正数处理，避免不稳定除零。
- `damping_ratio` 控制阻尼；`1.0` 接近临界阻尼，`0.0` 表示无阻尼，小于 0 的值会按 0 处理。
- `response` 控制目标速度前馈；不需要跟随移动目标速度时保持默认 `0.0`。
- `target_velocity` 是目标自身速度，只有在 `response` 非零时才会影响结果。

## 角度跨越边界

`step_angle()` 使用弧度和最短角差。例如当前为 `179°`，目标改为 `-179°` 时，会沿约 `2°` 的短方向靠近目标。继续保存返回的角速度；输出可以超过 `PI`，不因显示角度的表示边界而重置状态。

```gdscript
var state: Dictionary = GFSpringMath.step_angle(
	current_radians,
	angular_velocity,
	target_radians,
	delta,
	3.0,
	1.0
)
if not state.is_empty():
	current_radians = GFVariantData.get_option_float(state, "value")
	angular_velocity = GFVariantData.get_option_float(state, "velocity")
```

若 UI 需要显示 `-PI..PI` 内的角度，只对显示值做归一化，保留算法状态与速度。目标角速度也应使用弧度每秒；不要把角度数值或显示值跳变当作真实角速度前馈。

## 使用边界

`GFSpringMath` 是无状态纯算法。它不保存速度、不访问节点、不处理单位换算，也不替项目决定何时认为“已经到达”。需要在节点、相机或 UI 上使用时，应由项目或扩展把返回的 `value` 写回目标属性，并自行管理速度变量生命周期。

所有入口要求当前值、速度、目标、目标速度的全部分量，以及 delta、频率、阻尼和响应参数都是有限数。非有限输入返回空字典，并发出一次带方法上下文的 `spring_math.non_finite_input` 错误；有限输入导致算术溢出或原生向量转换后出现非有限分量时，也整组返回空字典，并发出一次 `spring_math.non_finite_result` 错误，没有部分结果。成功字典固定为 `value` / `velocity` 两个字段。

有限的 `delta <= 0` 保留原值与速度；有限负频率和阻尼仍按参数语义规范化。不要用 `NaN` / `Infinity` 表示暂停或重置，也不要在拒绝后把缺失字段的默认 `0` 当作成功状态。示例在拒绝时保留调用前状态；项目可以选择暂停更新、修正输入或显式重置，但应先处理输入原因。

不同时间步长的瞬态轨迹不保证完全一致。卡顿后的稳定策略也不等同于连续方程的解析解；需要精确物理轨迹、严格同步或权威仿真状态时，应按实际用途选择合适方法，不能只凭平滑外观替代验证。
