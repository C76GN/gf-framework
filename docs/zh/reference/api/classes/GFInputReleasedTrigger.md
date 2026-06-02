# GFInputReleasedTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/triggers/gf_input_released_trigger.gd`
- 模块：`Standard`
- 继承：`GFInputTrigger`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

释放瞬间触发器。 输入从活跃变为非活跃时触发一次，适合蓄力释放、松手确认等通用交互。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`reset_trigger_state`](#member-gfinputreleasedtrigger-methods-reset_trigger_state) | `func reset_trigger_state(state: Dictionary) -> void:` |
| 方法 | [`update`](#member-gfinputreleasedtrigger-methods-update) | `func update(raw_active: bool, _value: Variant, _delta: float, state: Dictionary) -> TriggerState:` |

## 方法

<a id="member-gfinputreleasedtrigger-methods-reset_trigger_state"></a>

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

- `state`: Dictionary，由输入运行时持有，包含 was_active: bool。

<a id="member-gfinputreleasedtrigger-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(raw_active: bool, _value: Variant, _delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否处于激活状态。 |
| `_value` | 输入值，默认实现不直接使用。 |
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |
| `state` | 触发器运行时状态字典。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `state`: Dictionary，由输入运行时持有，包含 was_active: bool。
