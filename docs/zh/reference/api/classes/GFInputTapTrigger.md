# GFInputTapTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/triggers/gf_input_tap_trigger.gd`
- 模块：`Standard`
- 继承：`GFInputTrigger`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

短按触发器。 输入按下后在指定时间窗口内释放时触发一次。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`min_tap_seconds`](#member-gfinputtaptrigger-properties-min_tap_seconds) | `var min_tap_seconds: float = 0.0:` |
| 属性 | [`max_tap_seconds`](#member-gfinputtaptrigger-properties-max_tap_seconds) | `var max_tap_seconds: float = 0.25:` |
| 方法 | [`reset_trigger_state`](#member-gfinputtaptrigger-methods-reset_trigger_state) | `func reset_trigger_state(state: Dictionary) -> void:` |
| 方法 | [`update`](#member-gfinputtaptrigger-methods-update) | `func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:` |

## 属性

<a id="member-gfinputtaptrigger-properties-min_tap_seconds"></a>

### `min_tap_seconds`

- API：`public`

```gdscript
var min_tap_seconds: float = 0.0:
```

最短按住时间。

<a id="member-gfinputtaptrigger-properties-max_tap_seconds"></a>

### `max_tap_seconds`

- API：`public`

```gdscript
var max_tap_seconds: float = 0.25:
```

最长按住时间。

## 方法

<a id="member-gfinputtaptrigger-methods-reset_trigger_state"></a>

### `reset_trigger_state`

- API：`public`

```gdscript
func reset_trigger_state(state: Dictionary) -> void:
```

重置输入触发器运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 触发器运行时状态字典。 |

结构：

- `state`: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。

<a id="member-gfinputtaptrigger-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否处于激活状态。 |
| `_value` | 输入值，默认实现不直接使用。 |
| `delta` | 本帧时间增量（秒）。 |
| `state` | 触发器运行时状态字典。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `state`: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。
