# GFDeterministicRandom

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`5.0.0`

固定 xorshift32 算法的确定性随机源。 该类型使用 GF 自有的 32-bit 状态转换，不依赖 Godot 全局随机状态或 RandomNumberGenerator 的内部算法。它适合锁步、回放、黄金测试和需要固定序列的 纯算法工具；不提供密码学安全随机。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`from_seed`](#member-gfdeterministicrandom-methods-from_seed) | `static func from_seed(seed_value: int) -> GFDeterministicRandom:` |
| 方法 | [`from_dict`](#member-gfdeterministicrandom-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFDeterministicRandom:` |
| 方法 | [`set_seed`](#member-gfdeterministicrandom-methods-set_seed) | `func set_seed(seed_value: int) -> void:` |
| 方法 | [`get_initial_seed`](#member-gfdeterministicrandom-methods-get_initial_seed) | `func get_initial_seed() -> int:` |
| 方法 | [`get_state`](#member-gfdeterministicrandom-methods-get_state) | `func get_state() -> int:` |
| 方法 | [`set_state`](#member-gfdeterministicrandom-methods-set_state) | `func set_state(state_value: int) -> bool:` |
| 方法 | [`next_u32`](#member-gfdeterministicrandom-methods-next_u32) | `func next_u32() -> int:` |
| 方法 | [`next_int_range`](#member-gfdeterministicrandom-methods-next_int_range) | `func next_int_range(min_value: int, max_value: int) -> int:` |
| 方法 | [`next_float_unit`](#member-gfdeterministicrandom-methods-next_float_unit) | `func next_float_unit() -> float:` |
| 方法 | [`next_float_range`](#member-gfdeterministicrandom-methods-next_float_range) | `func next_float_range(min_value: float, max_value: float) -> float:` |
| 方法 | [`next_bool`](#member-gfdeterministicrandom-methods-next_bool) | `func next_bool() -> bool:` |
| 方法 | [`skip`](#member-gfdeterministicrandom-methods-skip) | `func skip(count: int) -> void:` |
| 方法 | [`fork`](#member-gfdeterministicrandom-methods-fork) | `func fork(stream_id: int) -> GFDeterministicRandom:` |
| 方法 | [`to_dict`](#member-gfdeterministicrandom-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfdeterministicrandom-methods-apply_dict) | `func apply_dict(data: Dictionary) -> bool:` |

## 方法

<a id="member-gfdeterministicrandom-methods-from_seed"></a>

### `from_seed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_seed(seed_value: int) -> GFDeterministicRandom:
```

从种子创建确定性随机源。

参数：

| 名称 | 说明 |
|---|---|
| `seed_value` | 初始种子；0 会映射到稳定默认种子，避免 xorshift32 零状态。 |

返回：新随机源实例。

<a id="member-gfdeterministicrandom-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFDeterministicRandom:
```

使用字典创建确定性随机源。

参数：

| 名称 | 说明 |
|---|---|
| `data` | \`to_dict()\` 输出的状态字典。 |

返回：新随机源实例。

结构：

- `data`: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.

<a id="member-gfdeterministicrandom-methods-set_seed"></a>

### `set_seed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_seed(seed_value: int) -> void:
```

重置种子和当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `seed_value` | 初始种子；0 会映射到稳定默认种子。 |

<a id="member-gfdeterministicrandom-methods-get_initial_seed"></a>

### `get_initial_seed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_initial_seed() -> int:
```

获取初始种子。

返回：当前随机源最近一次设置的非零 u32 种子。

<a id="member-gfdeterministicrandom-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_state() -> int:
```

获取当前内部状态。

返回：非零 u32 状态值。

<a id="member-gfdeterministicrandom-methods-set_state"></a>

### `set_state`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_state(state_value: int) -> bool:
```

覆盖当前内部状态。

参数：

| 名称 | 说明 |
|---|---|
| `state_value` | 非零 u32 状态值。 |

返回：状态有效并已应用时返回 true。

<a id="member-gfdeterministicrandom-methods-next_u32"></a>

### `next_u32`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func next_u32() -> int:
```

生成下一个 u32。

返回：范围为 0 到 4294967295 的整数。

<a id="member-gfdeterministicrandom-methods-next_int_range"></a>

### `next_int_range`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func next_int_range(min_value: int, max_value: int) -> int:
```

生成闭区间内的整数。

参数：

| 名称 | 说明 |
|---|---|
| `min_value` | 闭区间下界。 |
| `max_value` | 闭区间上界；小于 \`min_value\` 时会自动交换。 |

返回：位于闭区间内的整数；区间跨度超过 u32 时返回下界并报错。

<a id="member-gfdeterministicrandom-methods-next_float_unit"></a>

### `next_float_unit`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func next_float_unit() -> float:
```

生成 0.0 到 1.0 之间的浮点数，包含 0.0 但不包含 1.0。

返回：基于固定 u32 输出缩放得到的浮点数。浮点几何算法仍不应作为定点锁步真值。

<a id="member-gfdeterministicrandom-methods-next_float_range"></a>

### `next_float_range`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func next_float_range(min_value: float, max_value: float) -> float:
```

生成指定范围内的浮点数。

参数：

| 名称 | 说明 |
|---|---|
| `min_value` | 范围下界。 |
| `max_value` | 范围上界；小于 \`min_value\` 时会自动交换。 |

返回：基于固定 u32 输出缩放得到的范围内浮点数。

<a id="member-gfdeterministicrandom-methods-next_bool"></a>

### `next_bool`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func next_bool() -> bool:
```

生成布尔值。

返回：随机布尔值。

<a id="member-gfdeterministicrandom-methods-skip"></a>

### `skip`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func skip(count: int) -> void:
```

跳过若干次输出。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 要跳过的输出数量；小于等于 0 时不改变状态。 |

<a id="member-gfdeterministicrandom-methods-fork"></a>

### `fork`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func fork(stream_id: int) -> GFDeterministicRandom:
```

派生子随机源。

参数：

| 名称 | 说明 |
|---|---|
| `stream_id` | 子流标识；同一父状态和同一标识会得到同一种子。 |

返回：派生随机源。

<a id="member-gfdeterministicrandom-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_dict() -> Dictionary:
```

导出当前状态字典。

返回：可稳定恢复随机源的字典。

结构：

- `return`: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.

<a id="member-gfdeterministicrandom-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func apply_dict(data: Dictionary) -> bool:
```

应用状态字典。

参数：

| 名称 | 说明 |
|---|---|
| `data` | \`to_dict()\` 输出的状态字典。 |

返回：状态有效并已应用时返回 true。

结构：

- `data`: Dictionary with `algorithm: String`, `version: int`, `seed: int`, and `state: int` fields.
