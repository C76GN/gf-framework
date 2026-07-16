# GFTurnPhase

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/resources/gf_turn_phase.gd`
- 模块：`Turn Based`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用回合阶段基类。 阶段只提供 _enter/_execute/_exit 生命周期和完成信号， 不绑定任何具体游戏流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`finished`](#member-gfturnphase-signals-finished) | `signal finished` |
| 属性 | [`phase_id`](#member-gfturnphase-properties-phase_id) | `var phase_id: StringName = &""` |
| 属性 | [`auto_finish`](#member-gfturnphase-properties-auto_finish) | `var auto_finish: bool = true` |
| 方法 | [`finish`](#member-gfturnphase-methods-finish) | `func finish(context: GFTurnContext = null) -> void:` |
| 方法 | [`is_finished_for`](#member-gfturnphase-methods-is_finished_for) | `func is_finished_for(context: GFTurnContext) -> bool:` |
| 方法 | [`_enter`](#member-gfturnphase-methods-_enter) | `func _enter(_context: GFTurnContext) -> void:` |
| 方法 | [`_execute`](#member-gfturnphase-methods-_execute) | `func _execute(_context: GFTurnContext) -> Variant:` |
| 方法 | [`_exit`](#member-gfturnphase-methods-_exit) | `func _exit(_context: GFTurnContext) -> void:` |

## 信号

<a id="member-gfturnphase-signals-finished"></a>

### `finished`

- API：`public`

```gdscript
signal finished
```

阶段完成时发出。

## 属性

<a id="member-gfturnphase-properties-phase_id"></a>

### `phase_id`

- API：`public`

```gdscript
var phase_id: StringName = &""
```

阶段标识。

<a id="member-gfturnphase-properties-auto_finish"></a>

### `auto_finish`

- API：`public`

```gdscript
var auto_finish: bool = true
```

`_execute()` 返回后是否自动完成阶段。

## 方法

<a id="member-gfturnphase-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func finish(context: GFTurnContext = null) -> void:
```

标记指定上下文的阶段运行完成。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 活动 Flow 的上下文；只有一个运行态时可省略。 |

<a id="member-gfturnphase-methods-is_finished_for"></a>

### `is_finished_for`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_finished_for(context: GFTurnContext) -> bool:
```

查询指定上下文的阶段是否完成。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 活动 Flow 的上下文。 |

返回：对应运行态存在且已经完成时返回 true。

<a id="member-gfturnphase-methods-_enter"></a>

### `_enter`

- API：`protected`

```gdscript
func _enter(_context: GFTurnContext) -> void:
```

进入阶段时由 GFTurnFlowSystem 调用。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 回合上下文。 |

<a id="member-gfturnphase-methods-_execute"></a>

### `_execute`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _execute(_context: GFTurnContext) -> Variant:
```

执行阶段逻辑时由 GFTurnFlowSystem 调用。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 回合上下文。 |

返回：可等待结果。

结构：

- `return`: Variant that is null or a Signal awaited before phase completion.

<a id="member-gfturnphase-methods-_exit"></a>

### `_exit`

- API：`protected`

```gdscript
func _exit(_context: GFTurnContext) -> void:
```

退出阶段时由 GFTurnFlowSystem 调用。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 回合上下文。 |
