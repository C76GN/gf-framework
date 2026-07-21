# GFTrajectoryMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_trajectory_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

通用运动预测、拦截和公式轨迹采样工具。 运动预测和拦截入口是 GF 内部无节点副作用的纯计算，不负责绘制、物理推进、目标选择或业务策略。 公式采样会同步执行项目显式提供的可信 Callable，并在调用前执行硬预算校验；GF 本身不访问节点， 但回调的副作用、阻塞与计算成本由调用方负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REASON_NONE`](#member-gftrajectorymath-constants-reason_none) | `const REASON_NONE: StringName = &""` |
| 常量 | [`REASON_INVALID_ARGUMENT`](#member-gftrajectorymath-constants-reason_invalid_argument) | `const REASON_INVALID_ARGUMENT: StringName = &"invalid_argument"` |
| 常量 | [`REASON_NO_SOLUTION`](#member-gftrajectorymath-constants-reason_no_solution) | `const REASON_NO_SOLUTION: StringName = &"no_solution"` |
| 常量 | [`REASON_BEYOND_HORIZON`](#member-gftrajectorymath-constants-reason_beyond_horizon) | `const REASON_BEYOND_HORIZON: StringName = &"beyond_horizon"` |
| 常量 | [`REASON_INVALID_PROVIDER`](#member-gftrajectorymath-constants-reason_invalid_provider) | `const REASON_INVALID_PROVIDER: StringName = &"invalid_provider"` |
| 常量 | [`REASON_SAMPLE_LIMIT_EXCEEDED`](#member-gftrajectorymath-constants-reason_sample_limit_exceeded) | `const REASON_SAMPLE_LIMIT_EXCEEDED: StringName = &"sample_limit_exceeded"` |
| 常量 | [`REASON_PROVIDER_FAILED`](#member-gftrajectorymath-constants-reason_provider_failed) | `const REASON_PROVIDER_FAILED: StringName = &"provider_failed"` |
| 常量 | [`DEFAULT_EPSILON`](#member-gftrajectorymath-constants-default_epsilon) | `const DEFAULT_EPSILON: float = 0.000001` |
| 常量 | [`DEFAULT_MAX_SAMPLE_COUNT`](#member-gftrajectorymath-constants-default_max_sample_count) | `const DEFAULT_MAX_SAMPLE_COUNT: int = 1024` |
| 常量 | [`ABSOLUTE_MAX_SAMPLE_COUNT`](#member-gftrajectorymath-constants-absolute_max_sample_count) | `const ABSOLUTE_MAX_SAMPLE_COUNT: int = 16_384` |
| 方法 | [`predict_motion_2d`](#member-gftrajectorymath-methods-predict_motion_2d) | `static func predict_motion_2d( initial_position: Vector2, initial_velocity: Vector2, acceleration: Vector2, time_seconds: float ) -> Dictionary:` |
| 方法 | [`predict_motion_3d`](#member-gftrajectorymath-methods-predict_motion_3d) | `static func predict_motion_3d( initial_position: Vector3, initial_velocity: Vector3, acceleration: Vector3, time_seconds: float ) -> Dictionary:` |
| 方法 | [`solve_intercept_2d`](#member-gftrajectorymath-methods-solve_intercept_2d) | `static func solve_intercept_2d( source_position: Vector2, projectile_speed: float, target_position: Vector2, target_velocity: Vector2, max_time_seconds: float = -1.0, epsilon: float = DEFAULT_EPSILON ) -> Dictionary:` |
| 方法 | [`solve_intercept_3d`](#member-gftrajectorymath-methods-solve_intercept_3d) | `static func solve_intercept_3d( source_position: Vector3, projectile_speed: float, target_position: Vector3, target_velocity: Vector3, max_time_seconds: float = -1.0, epsilon: float = DEFAULT_EPSILON ) -> Dictionary:` |
| 方法 | [`sample_formula_2d`](#member-gftrajectorymath-methods-sample_formula_2d) | `static func sample_formula_2d( position_provider: Callable, start_time_seconds: float, end_time_seconds: float, sample_count: int, max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT ) -> Dictionary:` |
| 方法 | [`sample_formula_3d`](#member-gftrajectorymath-methods-sample_formula_3d) | `static func sample_formula_3d( position_provider: Callable, start_time_seconds: float, end_time_seconds: float, sample_count: int, max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT ) -> Dictionary:` |

## 常量

<a id="member-gftrajectorymath-constants-reason_none"></a>

### `REASON_NONE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_NONE: StringName = &""
```

表示计算成功，没有失败原因。

<a id="member-gftrajectorymath-constants-reason_invalid_argument"></a>

### `REASON_INVALID_ARGUMENT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_ARGUMENT: StringName = &"invalid_argument"
```

表示输入参数无效、包含非有限数字，或计算结果无法保持有限。

<a id="member-gftrajectorymath-constants-reason_no_solution"></a>

### `REASON_NO_SOLUTION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_NO_SOLUTION: StringName = &"no_solution"
```

表示拦截方程不存在非负实数解。

<a id="member-gftrajectorymath-constants-reason_beyond_horizon"></a>

### `REASON_BEYOND_HORIZON`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BEYOND_HORIZON: StringName = &"beyond_horizon"
```

表示拦截解超出调用方给定的时间窗口。

<a id="member-gftrajectorymath-constants-reason_invalid_provider"></a>

### `REASON_INVALID_PROVIDER`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_INVALID_PROVIDER: StringName = &"invalid_provider"
```

表示轨迹公式 Callable 无效。

<a id="member-gftrajectorymath-constants-reason_sample_limit_exceeded"></a>

### `REASON_SAMPLE_LIMIT_EXCEEDED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_SAMPLE_LIMIT_EXCEEDED: StringName = &"sample_limit_exceeded"
```

表示请求采样数量超过本次预算。

<a id="member-gftrajectorymath-constants-reason_provider_failed"></a>

### `REASON_PROVIDER_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_PROVIDER_FAILED: StringName = &"provider_failed"
```

表示公式返回了错误类型或非有限坐标。

<a id="member-gftrajectorymath-constants-default_epsilon"></a>

### `DEFAULT_EPSILON`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_EPSILON: float = 0.000001
```

默认浮点容差。

<a id="member-gftrajectorymath-constants-default_max_sample_count"></a>

### `DEFAULT_MAX_SAMPLE_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_SAMPLE_COUNT: int = 1024
```

单次公式采样的默认点数预算。

<a id="member-gftrajectorymath-constants-absolute_max_sample_count"></a>

### `ABSOLUTE_MAX_SAMPLE_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SAMPLE_COUNT: int = 16_384
```

单次公式采样不可绕过的绝对点数上限。

## 方法

<a id="member-gftrajectorymath-methods-predict_motion_2d"></a>

### `predict_motion_2d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func predict_motion_2d( initial_position: Vector2, initial_velocity: Vector2, acceleration: Vector2, time_seconds: float ) -> Dictionary:
```

按恒定加速度预测 2D 未来位置和速度。

参数：

| 名称 | 说明 |
|---|---|
| `initial_position` | 当前世界或局部位置，由调用方保证坐标空间一致。 |
| `initial_velocity` | 当前速度。 |
| `acceleration` | 在预测区间内保持恒定的加速度。 |
| `time_seconds` | 非负预测秒数。 |

返回：运动预测报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空或 invalid_argument）、error: String、time_seconds: float、position: Vector2、velocity: Vector2；成功时 time_seconds 等于请求值，失败时 time_seconds 为 0 且向量为零。

<a id="member-gftrajectorymath-methods-predict_motion_3d"></a>

### `predict_motion_3d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func predict_motion_3d( initial_position: Vector3, initial_velocity: Vector3, acceleration: Vector3, time_seconds: float ) -> Dictionary:
```

按恒定加速度预测 3D 未来位置和速度。

参数：

| 名称 | 说明 |
|---|---|
| `initial_position` | 当前世界或局部位置，由调用方保证坐标空间一致。 |
| `initial_velocity` | 当前速度。 |
| `acceleration` | 在预测区间内保持恒定的加速度。 |
| `time_seconds` | 非负预测秒数。 |

返回：运动预测报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空或 invalid_argument）、error: String、time_seconds: float、position: Vector3、velocity: Vector3；成功时 time_seconds 等于请求值，失败时 time_seconds 为 0 且向量为零。

<a id="member-gftrajectorymath-methods-solve_intercept_2d"></a>

### `solve_intercept_2d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func solve_intercept_2d( source_position: Vector2, projectile_speed: float, target_position: Vector2, target_velocity: Vector2, max_time_seconds: float = -1.0, epsilon: float = DEFAULT_EPSILON ) -> Dictionary:
```

求恒速发射体拦截匀速 2D 目标的最早非负解。 发射速度使用当前坐标空间中的绝对速度，不隐式继承发射者速度。若发射体需要继承恒定的 source_velocity，应传入 target_velocity - source_velocity；此时 launch_velocity 是相对发射者的速度， 世界速度为 source_velocity + launch_velocity，世界命中点为 position + source_velocity * time_seconds。 该方法不计算发射体加速度、重力或障碍物。

参数：

| 名称 | 说明 |
|---|---|
| `source_position` | 发射位置。 |
| `projectile_speed` | 发射体恒定速率，必须大于零。 |
| `target_position` | 目标当前位置。 |
| `target_velocity` | 目标恒定速度。 |
| `max_time_seconds` | 最大预测秒数；负值表示不限制。 |
| `epsilon` | 浮点判定容差；非正值使用 DEFAULT_EPSILON。 |

返回：最早拦截解报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、no_solution 或 beyond_horizon）、error: String、time_seconds: float、position: Vector2、launch_velocity: Vector2、distance: float；成功时 time_seconds >= 0，正时间解的 launch_velocity 长度等于 projectile_speed，t=0 时为零；失败时 time_seconds 为 -1，其余数值结果为零。

<a id="member-gftrajectorymath-methods-solve_intercept_3d"></a>

### `solve_intercept_3d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func solve_intercept_3d( source_position: Vector3, projectile_speed: float, target_position: Vector3, target_velocity: Vector3, max_time_seconds: float = -1.0, epsilon: float = DEFAULT_EPSILON ) -> Dictionary:
```

求恒速发射体拦截匀速 3D 目标的最早非负解。 发射速度使用当前坐标空间中的绝对速度，不隐式继承发射者速度。若发射体需要继承恒定的 source_velocity，应传入 target_velocity - source_velocity；此时 launch_velocity 是相对发射者的速度， 世界速度为 source_velocity + launch_velocity，世界命中点为 position + source_velocity * time_seconds。 该方法不计算发射体加速度、重力或障碍物。

参数：

| 名称 | 说明 |
|---|---|
| `source_position` | 发射位置。 |
| `projectile_speed` | 发射体恒定速率，必须大于零。 |
| `target_position` | 目标当前位置。 |
| `target_velocity` | 目标恒定速度。 |
| `max_time_seconds` | 最大预测秒数；负值表示不限制。 |
| `epsilon` | 浮点判定容差；非正值使用 DEFAULT_EPSILON。 |

返回：最早拦截解报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、no_solution 或 beyond_horizon）、error: String、time_seconds: float、position: Vector3、launch_velocity: Vector3、distance: float；成功时 time_seconds >= 0，正时间解的 launch_velocity 长度等于 projectile_speed，t=0 时为零；失败时 time_seconds 为 -1，其余数值结果为零。

<a id="member-gftrajectorymath-methods-sample_formula_2d"></a>

### `sample_formula_2d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func sample_formula_2d( position_provider: Callable, start_time_seconds: float, end_time_seconds: float, sample_count: int, max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT ) -> Dictionary:
```

在闭区间内均匀调用同步公式并生成 2D 轨迹点。 sample_count 为 1 时只采样 start_time_seconds；否则首尾时间都会被包含。 反向时间区间是合法的。公式必须快速、同步且返回有限 Vector2。

参数：

| 名称 | 说明 |
|---|---|
| `position_provider` | 接收一个 float 秒数并返回 Vector2 的同步 Callable。 |
| `start_time_seconds` | 起始采样时间。 |
| `end_time_seconds` | 结束采样时间。 |
| `sample_count` | 请求采样点数量，必须大于零。 |
| `max_sample_count` | 本次预算，必须位于 1 到 ABSOLUTE_MAX_SAMPLE_COUNT。 |

返回：有界 2D 采样报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、invalid_provider、sample_limit_exceeded 或 provider_failed）、error: String、start_time_seconds: float、end_time_seconds: float、requested_sample_count: int、sample_limit: int、sampled_count: int、failed_sample_index: int、times: PackedFloat64Array、points: PackedVector2Array；始终满足 sampled_count == times.size() == points.size()；成功时 failed_sample_index 为 -1，运行中失败时为首个失败索引并保留此前有效前缀，预检失败时数组为空且索引为 -1。

<a id="member-gftrajectorymath-methods-sample_formula_3d"></a>

### `sample_formula_3d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func sample_formula_3d( position_provider: Callable, start_time_seconds: float, end_time_seconds: float, sample_count: int, max_sample_count: int = DEFAULT_MAX_SAMPLE_COUNT ) -> Dictionary:
```

在闭区间内均匀调用同步公式并生成 3D 轨迹点。 sample_count 为 1 时只采样 start_time_seconds；否则首尾时间都会被包含。 反向时间区间是合法的。公式必须快速、同步且返回有限 Vector3。

参数：

| 名称 | 说明 |
|---|---|
| `position_provider` | 接收一个 float 秒数并返回 Vector3 的同步 Callable。 |
| `start_time_seconds` | 起始采样时间。 |
| `end_time_seconds` | 结束采样时间。 |
| `sample_count` | 请求采样点数量，必须大于零。 |
| `max_sample_count` | 本次预算，必须位于 1 到 ABSOLUTE_MAX_SAMPLE_COUNT。 |

返回：有界 3D 采样报告。

结构：

- `return`: Dictionary，字段为 ok: bool、reason: StringName（空、invalid_argument、invalid_provider、sample_limit_exceeded 或 provider_failed）、error: String、start_time_seconds: float、end_time_seconds: float、requested_sample_count: int、sample_limit: int、sampled_count: int、failed_sample_index: int、times: PackedFloat64Array、points: PackedVector3Array；始终满足 sampled_count == times.size() == points.size()；成功时 failed_sample_index 为 -1，运行中失败时为首个失败索引并保留此前有效前缀，预检失败时数组为空且索引为 -1。
