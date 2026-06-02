# GFInputSequenceStep

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/sequences/gf_input_sequence_step.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

输入序列中的单个抽象动作步骤。 步骤只描述动作 ID、间隔和按住/释放条件，不绑定具体按键或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action_id`](#member-gfinputsequencestep-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`max_gap_seconds`](#member-gfinputsequencestep-properties-max_gap_seconds) | `var max_gap_seconds: float = -1.0:` |
| 属性 | [`min_hold_seconds`](#member-gfinputsequencestep-properties-min_hold_seconds) | `var min_hold_seconds: float = 0.0:` |
| 属性 | [`trigger_on_release`](#member-gfinputsequencestep-properties-trigger_on_release) | `var trigger_on_release: bool = false` |
| 方法 | [`duplicate_step`](#member-gfinputsequencestep-methods-duplicate_step) | `func duplicate_step() -> GFInputSequenceStep:` |
| 方法 | [`from_action_id`](#member-gfinputsequencestep-methods-from_action_id) | `static func from_action_id(p_action_id: StringName) -> GFInputSequenceStep:` |

## 属性

<a id="member-gfinputsequencestep-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

需要匹配的抽象动作 ID。

<a id="member-gfinputsequencestep-properties-max_gap_seconds"></a>

### `max_gap_seconds`

- API：`public`

```gdscript
var max_gap_seconds: float = -1.0:
```

从上一完成步骤到本步骤开始允许的最大间隔。小于 0 表示使用分支或触发器默认值，0 表示不限制。

<a id="member-gfinputsequencestep-properties-min_hold_seconds"></a>

### `min_hold_seconds`

- API：`public`

```gdscript
var min_hold_seconds: float = 0.0:
```

动作需要保持活跃的最短时间。

<a id="member-gfinputsequencestep-properties-trigger_on_release"></a>

### `trigger_on_release`

- API：`public`

```gdscript
var trigger_on_release: bool = false
```

是否在动作释放时完成本步骤。

## 方法

<a id="member-gfinputsequencestep-methods-duplicate_step"></a>

### `duplicate_step`

- API：`public`

```gdscript
func duplicate_step() -> GFInputSequenceStep:
```

创建当前步骤的深拷贝。

返回：步骤副本。

<a id="member-gfinputsequencestep-methods-from_action_id"></a>

### `from_action_id`

- API：`public`

```gdscript
static func from_action_id(p_action_id: StringName) -> GFInputSequenceStep:
```

创建只包含动作 ID 的步骤。

参数：

| 名称 | 说明 |
|---|---|
| `p_action_id` | 动作 ID。 |

返回：新步骤。
