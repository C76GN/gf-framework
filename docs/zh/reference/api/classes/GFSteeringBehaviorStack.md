# GFSteeringBehaviorStack

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_steering_behavior_stack.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

资源化 steering 行为组合。 以 blend 或 priority 模式组合 GFSteeringBehaviorResource。它只返回加速度结果， 不负责移动节点、应用物理或解释项目 AI 状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CompositionMode`](#member-gfsteeringbehaviorstack-enums-compositionmode) | `enum CompositionMode` |
| 属性 | [`mode`](#member-gfsteeringbehaviorstack-properties-mode) | `var mode: CompositionMode = CompositionMode.BLEND` |
| 属性 | [`behaviors`](#member-gfsteeringbehaviorstack-properties-behaviors) | `var behaviors: Array[GFSteeringBehaviorResource] = []` |
| 属性 | [`max_linear`](#member-gfsteeringbehaviorstack-properties-max_linear) | `var max_linear: float = -1.0` |
| 属性 | [`max_angular`](#member-gfsteeringbehaviorstack-properties-max_angular) | `var max_angular: float = -1.0` |
| 属性 | [`priority_threshold`](#member-gfsteeringbehaviorstack-properties-priority_threshold) | `var priority_threshold: float = 0.001` |
| 方法 | [`add_behavior`](#member-gfsteeringbehaviorstack-methods-add_behavior) | `func add_behavior(behavior: GFSteeringBehaviorResource) -> bool:` |
| 方法 | [`is_empty`](#member-gfsteeringbehaviorstack-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`calculate`](#member-gfsteeringbehaviorstack-methods-calculate) | `func calculate(agent: GFSteeringAgent, context: Dictionary = {}) -> GFSteeringAcceleration:` |
| 方法 | [`duplicate_stack`](#member-gfsteeringbehaviorstack-methods-duplicate_stack) | `func duplicate_stack() -> Resource:` |

## 枚举

<a id="member-gfsteeringbehaviorstack-enums-compositionmode"></a>

### `CompositionMode`

- API：`public`

```gdscript
enum CompositionMode {
	## 按权重混合所有行为。
	BLEND,
	## 选择第一个超过阈值的行为。
	PRIORITY,
}
```

行为组合方式。

## 属性

<a id="member-gfsteeringbehaviorstack-properties-mode"></a>

### `mode`

- API：`public`

```gdscript
var mode: CompositionMode = CompositionMode.BLEND
```

组合方式。

<a id="member-gfsteeringbehaviorstack-properties-behaviors"></a>

### `behaviors`

- API：`public`

```gdscript
var behaviors: Array[GFSteeringBehaviorResource] = []
```

行为列表。

<a id="member-gfsteeringbehaviorstack-properties-max_linear"></a>

### `max_linear`

- API：`public`

```gdscript
var max_linear: float = -1.0
```

混合后最大线性加速度；小于 0 时使用 agent 上限。

<a id="member-gfsteeringbehaviorstack-properties-max_angular"></a>

### `max_angular`

- API：`public`

```gdscript
var max_angular: float = -1.0
```

混合后最大角加速度；小于 0 时使用 agent 上限。

<a id="member-gfsteeringbehaviorstack-properties-priority_threshold"></a>

### `priority_threshold`

- API：`public`

```gdscript
var priority_threshold: float = 0.001
```

Priority 模式下判断非零的阈值。

## 方法

<a id="member-gfsteeringbehaviorstack-methods-add_behavior"></a>

### `add_behavior`

- API：`public`

```gdscript
func add_behavior(behavior: GFSteeringBehaviorResource) -> bool:
```

添加行为。

参数：

| 名称 | 说明 |
|---|---|
| `behavior` | 行为资源。 |

返回：添加成功返回 true。

<a id="member-gfsteeringbehaviorstack-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查是否没有有效行为。

返回：没有有效行为时返回 true。

<a id="member-gfsteeringbehaviorstack-methods-calculate"></a>

### `calculate`

- API：`public`

```gdscript
func calculate(agent: GFSteeringAgent, context: Dictionary = {}) -> GFSteeringAcceleration:
```

计算组合后的 steering 加速度。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `context` | 传给每个行为的动态上下文。 |

返回：steering 加速度。

结构：

- `context`: Dictionary steering behavior context passed to each behavior.

<a id="member-gfsteeringbehaviorstack-methods-duplicate_stack"></a>

### `duplicate_stack`

- API：`public`

```gdscript
func duplicate_stack() -> Resource:
```

创建配置副本。

返回：新行为组合。
