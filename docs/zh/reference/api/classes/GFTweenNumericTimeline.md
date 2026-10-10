# GFTweenNumericTimeline

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/tween/gf_tween_numeric_timeline.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

有界、冻结的纯数值 Tween 时间轴。 捕获与采样不接受目标对象、Resource、Callable 或业务上下文。调用方负责时钟和提交值。 直接 int/float 根属性共享运行时编译核心；任何不支持或越界的成员导致整组拒绝。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`capture`](#member-gftweennumerictimeline-methods-capture) | `static func capture(definition: Dictionary, properties: Array[Dictionary]) -> GFTweenNumericTimeline:` |
| 方法 | [`get_error`](#member-gftweennumerictimeline-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_duration_seconds`](#member-gftweennumerictimeline-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`get_initial_values`](#member-gftweennumerictimeline-methods-get_initial_values) | `func get_initial_values() -> Dictionary:` |
| 方法 | [`sample`](#member-gftweennumerictimeline-methods-sample) | `func sample(time_seconds: float) -> Dictionary:` |

## 方法

<a id="member-gftweennumerictimeline-methods-capture"></a>

### `capture`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func capture(definition: Dictionary, properties: Array[Dictionary]) -> GFTweenNumericTimeline:
```

捕获独立的纯值时间轴；最多 128 步、32 次循环、4096 个展开步骤、120 秒。 单个步骤允许零时长，零总时长、并行同根/已知属性别名冲突和未知字段整组拒绝。 每个串行组开始时冻结 from，delay 不重新读取值，相对循环按冻结终点累计。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 闭合时间轴数据，不读取来源配置。 |
| `properties` | 唯一直接数值属性的初值与硬包络；不是 UI slider 范围。 |

返回：始终返回时间轴；get_error 非空表示没有部分可采样数据。

结构：

- `definition`: Dictionary，必需 steps: Array[Dictionary]；可选 loop_count: int=1、duration_scale: int/float=1.0、ping_pong: bool=false。步骤必需 property_name: NodePath、target_value: int/float；可选 duration: int/float=0.2、delay: int/float=0.0、as_relative/parallel: bool=false、transition_type: int=Tween.TRANS_CUBIC、ease_type: int=Tween.EASE_OUT、easing_curve_data: Dictionary={}（仅 positions: PackedVector2Array、tangents: PackedVector2Array、modes: PackedInt32Array、bake_resolution: int、value_range: Vector2）。不接受其他字段。
- `properties`: Array[Dictionary]，1 至 32 项，每项闭合 name: String（1..64 字符标识符）、type: int（TYPE_INT/TYPE_FLOAT）、initial: 同型有限 int/float、minimum/maximum: 有限 int/float（minimum < maximum，绝对值不超过 1000000，包含 initial）。

<a id="member-gftweennumerictimeline-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

返回捕获拒绝原因；空字符串表示成功。

返回：拒绝说明。

<a id="member-gftweennumerictimeline-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_seconds() -> float:
```

返回冻结的完整有限时间轴时长。

返回：成功时为正有限秒数，失败为零。

<a id="member-gftweennumerictimeline-methods-get_initial_values"></a>

### `get_initial_values`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_initial_values() -> Dictionary:
```

返回全部声明属性的独立初值快照。

返回：初值；拒绝时间轴返回空字典。

结构：

- `return`: Dictionary，String 直接属性名映射到声明类型的 int/float。

<a id="member-gftweennumerictimeline-methods-sample"></a>

### `sample`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func sample(time_seconds: float) -> Dictionary:
```

采样独立数值快照。有限越界时间收窄到端点；非有限时间或任何越界输出返回空字典。 不执行标记、完成回调或持久化；整数遵循运行时 PropertyTweener 的转换语义。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 有限采样秒数。 |

返回：全部声明属性值；失败没有部分输出。

结构：

- `return`: Dictionary，String 直接属性名映射到声明类型的有限 int/float，全部处于对应硬边界内；失败为空。
