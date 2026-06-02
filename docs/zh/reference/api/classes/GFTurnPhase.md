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
| 属性 | [`is_finished`](#member-gfturnphase-properties-is_finished) | `var is_finished: bool = false` |
| 方法 | [`finish`](#member-gfturnphase-methods-finish) | `func finish() -> void:` |
| 方法 | [`reset`](#member-gfturnphase-methods-reset) | `func reset() -> void:` |

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

<a id="member-gfturnphase-properties-is_finished"></a>

### `is_finished`

- API：`public`

```gdscript
var is_finished: bool = false
```

当前阶段是否已经完成。

## 方法

<a id="member-gfturnphase-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

标记阶段完成。

<a id="member-gfturnphase-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置阶段运行状态。
