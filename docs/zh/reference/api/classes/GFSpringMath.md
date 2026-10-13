# GFSpringMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_spring_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.1.0`

通用二阶弹簧平滑数学工具。 提供 float、角度、Vector2 与 Vector3 的稳定弹簧步进计算。 它只根据当前值、速度、目标值和参数输出下一帧状态，不持有节点、不创建 Tween， 也不解释相机、UI、角色移动或反馈表现语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`step_float`](#member-gfspringmath-methods-step_float) | `static func step_float( current_value: float, velocity: float, target_value: float, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: float = 0.0 ) -> Dictionary:` |
| 方法 | [`step_angle`](#member-gfspringmath-methods-step_angle) | `static func step_angle( current_radians: float, velocity: float, target_radians: float, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: float = 0.0 ) -> Dictionary:` |
| 方法 | [`step_vector2`](#member-gfspringmath-methods-step_vector2) | `static func step_vector2( current_value: Vector2, velocity: Vector2, target_value: Vector2, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: Vector2 = Vector2.ZERO ) -> Dictionary:` |
| 方法 | [`step_vector3`](#member-gfspringmath-methods-step_vector3) | `static func step_vector3( current_value: Vector3, velocity: Vector3, target_value: Vector3, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: Vector3 = Vector3.ZERO ) -> Dictionary:` |

## 方法

<a id="member-gfspringmath-methods-step_float"></a>

### `step_float`

- API：`public`
- 首次版本：`4.1.0`

```gdscript
static func step_float( current_value: float, velocity: float, target_value: float, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: float = 0.0 ) -> Dictionary:
```

对 float 值执行一次二阶弹簧步进。 全部输入须有限；非有限输入或结果发出一次错误并返回空字典，不提供部分状态。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |
| `velocity` | 当前速度；调用方应保存返回的 \`velocity\` 用于下一次步进。 |
| `target_value` | 目标值。 |
| `delta_seconds` | 本次步进时间；小于等于 0 时返回原状态。 |
| `frequency_hz` | 弹簧频率，越大越快接近目标；会被限制为大于 0。 |
| `damping_ratio` | 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。 |
| `response` | 目标速度响应系数；0 表示忽略 \`target_velocity\` 的前馈。 |
| `target_velocity` | 目标值自身速度。 |

返回：成功包含下一帧 value 与 velocity；非有限输入或计算结果返回空字典。

结构：

- `return`: Dictionary，失败为空，成功仅包含有限 value: float 与 velocity: float。

<a id="member-gfspringmath-methods-step_angle"></a>

### `step_angle`

- API：`public`
- 首次版本：`4.1.0`

```gdscript
static func step_angle( current_radians: float, velocity: float, target_radians: float, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: float = 0.0 ) -> Dictionary:
```

对弧度角执行一次二阶弹簧步进，并沿最短角度方向靠近目标。 全部输入先做有限准入；非有限输入或角差/步进结果发出一次错误并返回空字典。

参数：

| 名称 | 说明 |
|---|---|
| `current_radians` | 当前角度（弧度）。 |
| `velocity` | 当前角速度；调用方应保存返回的 \`velocity\` 用于下一次步进。 |
| `target_radians` | 目标角度（弧度）。 |
| `delta_seconds` | 本次步进时间；小于等于 0 时返回原状态。 |
| `frequency_hz` | 弹簧频率，越大越快接近目标；会被限制为大于 0。 |
| `damping_ratio` | 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。 |
| `response` | 目标角速度响应系数；0 表示忽略 \`target_velocity\` 的前馈。 |
| `target_velocity` | 目标角度自身速度。 |

返回：成功包含下一帧 value 与 velocity，value 不会自动归一化；非有限输入或结果为空字典。

结构：

- `return`: Dictionary，失败为空，成功仅包含有限 value: float 与 velocity: float。

<a id="member-gfspringmath-methods-step_vector2"></a>

### `step_vector2`

- API：`public`
- 首次版本：`4.1.0`

```gdscript
static func step_vector2( current_value: Vector2, velocity: Vector2, target_value: Vector2, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: Vector2 = Vector2.ZERO ) -> Dictionary:
```

对 Vector2 值执行一次逐分量二阶弹簧步进。 全部输入分量与参数须有限；最终原生向量也须有限，失败发出一次错误并返回空字典。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |
| `velocity` | 当前速度；调用方应保存返回的 \`velocity\` 用于下一次步进。 |
| `target_value` | 目标值。 |
| `delta_seconds` | 本次步进时间；小于等于 0 时返回原状态。 |
| `frequency_hz` | 弹簧频率，越大越快接近目标；会被限制为大于 0。 |
| `damping_ratio` | 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。 |
| `response` | 目标速度响应系数；0 表示忽略 \`target_velocity\` 的前馈。 |
| `target_velocity` | 目标值自身速度。 |

返回：成功包含完整下一帧 value 与 velocity；非有限输入或任一结果分量为空字典。

结构：

- `return`: Dictionary，失败为空，成功仅包含分量均有限的 value: Vector2 与 velocity: Vector2。

<a id="member-gfspringmath-methods-step_vector3"></a>

### `step_vector3`

- API：`public`
- 首次版本：`4.1.0`

```gdscript
static func step_vector3( current_value: Vector3, velocity: Vector3, target_value: Vector3, delta_seconds: float, frequency_hz: float = 3.0, damping_ratio: float = 1.0, response: float = 0.0, target_velocity: Vector3 = Vector3.ZERO ) -> Dictionary:
```

对 Vector3 值执行一次逐分量二阶弹簧步进。 全部输入分量与参数须有限；最终原生向量也须有限，失败发出一次错误并返回空字典。

参数：

| 名称 | 说明 |
|---|---|
| `current_value` | 当前值。 |
| `velocity` | 当前速度；调用方应保存返回的 \`velocity\` 用于下一次步进。 |
| `target_value` | 目标值。 |
| `delta_seconds` | 本次步进时间；小于等于 0 时返回原状态。 |
| `frequency_hz` | 弹簧频率，越大越快接近目标；会被限制为大于 0。 |
| `damping_ratio` | 阻尼比；1 表示接近临界阻尼，0 表示无阻尼。 |
| `response` | 目标速度响应系数；0 表示忽略 \`target_velocity\` 的前馈。 |
| `target_velocity` | 目标值自身速度。 |

返回：成功包含完整下一帧 value 与 velocity；非有限输入或任一结果分量为空字典。

结构：

- `return`: Dictionary，失败为空，成功仅包含分量均有限的 value: Vector3 与 velocity: Vector3。
