# GFSeedUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/random/gf_seed_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

全局随机数种子管理器。 内部维护一个主 RandomNumberGenerator，并支持基于字符串标签派生 出独立的 Godot RNG 或 GF 固定算法随机源。Godot RNG 分支只承诺 同一 Godot 运行时随机算法下的复现；需要长期、跨运行时强确定性时， 使用 deterministic 分支。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`init`](#member-gfseedutility-methods-init) | `func init() -> void:` |
| 方法 | [`set_global_seed`](#member-gfseedutility-methods-set_global_seed) | `func set_global_seed(seed_hash: int) -> void:` |
| 方法 | [`get_global_seed`](#member-gfseedutility-methods-get_global_seed) | `func get_global_seed() -> int:` |
| 方法 | [`next_uint32`](#member-gfseedutility-methods-next_uint32) | `func next_uint32() -> int:` |
| 方法 | [`next_float`](#member-gfseedutility-methods-next_float) | `func next_float() -> float:` |
| 方法 | [`next_int_range`](#member-gfseedutility-methods-next_int_range) | `func next_int_range(from: int, to: int) -> int:` |
| 方法 | [`next_float_range`](#member-gfseedutility-methods-next_float_range) | `func next_float_range(from: float, to: float) -> float:` |
| 方法 | [`get_state`](#member-gfseedutility-methods-get_state) | `func get_state() -> int:` |
| 方法 | [`set_state`](#member-gfseedutility-methods-set_state) | `func set_state(state: int) -> void:` |
| 方法 | [`get_full_state`](#member-gfseedutility-methods-get_full_state) | `func get_full_state() -> Dictionary:` |
| 方法 | [`set_full_state`](#member-gfseedutility-methods-set_full_state) | `func set_full_state(state: Dictionary) -> void:` |
| 方法 | [`make_stable_text_seed`](#member-gfseedutility-methods-make_stable_text_seed) | `static func make_stable_text_seed(text: String) -> int:` |
| 方法 | [`try_make_stable_seed`](#member-gfseedutility-methods-try_make_stable_seed) | `static func try_make_stable_seed(parts: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_stable_seed`](#member-gfseedutility-methods-make_stable_seed) | `static func make_stable_seed(parts: Array, options: Dictionary = {}) -> int:` |
| 方法 | [`make_stable_grid_seed`](#member-gfseedutility-methods-make_stable_grid_seed) | `static func make_stable_grid_seed(cell: Vector2i, seed_value: int = 0, namespace_id: String = "") -> int:` |
| 方法 | [`get_branched_rng`](#member-gfseedutility-methods-get_branched_rng) | `func get_branched_rng(string_seed: String) -> RandomNumberGenerator:` |
| 方法 | [`get_branched_godot_rng`](#member-gfseedutility-methods-get_branched_godot_rng) | `func get_branched_godot_rng(string_seed: String) -> RandomNumberGenerator:` |
| 方法 | [`get_branched_deterministic_random`](#member-gfseedutility-methods-get_branched_deterministic_random) | `func get_branched_deterministic_random(string_seed: String) -> GFDeterministicRandom:` |

## 方法

<a id="member-gfseedutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化：创建主 RNG 实例。

<a id="member-gfseedutility-methods-set_global_seed"></a>

### `set_global_seed`

- API：`public`

```gdscript
func set_global_seed(seed_hash: int) -> void:
```

设置全局主种子，并同步应用到主 RNG。

参数：

| 名称 | 说明 |
|---|---|
| `seed_hash` | 用于驱动主随机数序列的整数种子。 |

<a id="member-gfseedutility-methods-get_global_seed"></a>

### `get_global_seed`

- API：`public`

```gdscript
func get_global_seed() -> int:
```

获取当前全局主种子。

返回：当前全局主种子。

<a id="member-gfseedutility-methods-next_uint32"></a>

### `next_uint32`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func next_uint32() -> int:
```

推进主随机流并返回无符号 32 位随机值。

返回：0 到 4294967295 范围内的随机值。

<a id="member-gfseedutility-methods-next_float"></a>

### `next_float`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func next_float() -> float:
```

推进主随机流并返回 [0, 1) 浮点值。

返回：[0, 1) 范围内的随机值。

<a id="member-gfseedutility-methods-next_int_range"></a>

### `next_int_range`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func next_int_range(from: int, to: int) -> int:
```

推进主随机流并返回闭区间整数值。

参数：

| 名称 | 说明 |
|---|---|
| `from` | 最小值。 |
| `to` | 最大值。 |

返回：闭区间随机整数。

<a id="member-gfseedutility-methods-next_float_range"></a>

### `next_float_range`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func next_float_range(from: float, to: float) -> float:
```

推进主随机流并返回指定浮点区间值。

参数：

| 名称 | 说明 |
|---|---|
| `from` | 最小值。 |
| `to` | 最大值。 |

返回：指定区间内的随机浮点值。

<a id="member-gfseedutility-methods-get_state"></a>

### `get_state`

- API：`public`

```gdscript
func get_state() -> int:
```

获取当前主 RNG 的内部精确状态。

返回：当前的内部状态值。

<a id="member-gfseedutility-methods-set_state"></a>

### `set_state`

- API：`public`

```gdscript
func set_state(state: int) -> void:
```

恢复主 RNG 的内部精确状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 要恢复的内部状态值。 |

<a id="member-gfseedutility-methods-get_full_state"></a>

### `get_full_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_full_state() -> Dictionary:
```

获取包含主种子、主 RNG 状态与分支计数的完整随机状态。 返回的 64 位整数状态会以十进制字符串保存，确保默认 JSON 存储可精确往返。

返回：JSON 安全的完整随机状态。

结构：

- `return`: Dictionary with `state_schema_version: int`, `global_seed: String`, `rng_state: String`, `branch_counters: Dictionary[String, String]`, and `deterministic_branch_counters: Dictionary[String, String]`.

<a id="member-gfseedutility-methods-set_full_state"></a>

### `set_full_state`

- API：`public`

```gdscript
func set_full_state(state: Dictionary) -> void:
```

恢复完整随机状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | get_full_state() 产生的字典。 |

结构：

- `state`: Dictionary produced by get_full_state().

<a id="member-gfseedutility-methods-make_stable_text_seed"></a>

### `make_stable_text_seed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_stable_text_seed(text: String) -> int:
```

将文本稳定映射为 32-bit seed。 该入口使用 GF 固定 FNV-32 哈希，适合把关卡名、规则 ID 或生成命名空间映射到可复现随机种子；不适合作为安全随机或防作弊来源。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 参与 seed 派生的文本。 |

返回：0 到 4294967295 范围内的稳定整数 seed。

<a id="member-gfseedutility-methods-try_make_stable_seed"></a>

### `try_make_stable_seed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func try_make_stable_seed(parts: Array, options: Dictionary = {}) -> Dictionary:
```

将纯 Variant 部件稳定映射为 32-bit seed。 输入会先经过 GFDeterministicVariantSerializer 的规范编码，因此 Dictionary key 顺序不会影响结果。默认拒绝 float、Object、Resource、Callable 和循环引用。

参数：

| 名称 | 说明 |
|---|---|
| `parts` | 参与 seed 派生的纯数据部件。 |
| `options` | 确定性编码选项。 |

返回：seed 派生结果。

结构：

- `parts`: Array of deterministic Variant values accepted by GFDeterministicVariantSerializer.to_canonical_value().
- `options`: Dictionary with optional `allow_floats: bool` and `max_depth: int`.
- `return`: Dictionary with `ok: bool`, `seed: int`, and `error: String`. ok 为 false 时 seed 为 0，error 为稳定错误码。

<a id="member-gfseedutility-methods-make_stable_seed"></a>

### `make_stable_seed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_stable_seed(parts: Array, options: Dictionary = {}) -> int:
```

将纯 Variant 部件稳定映射为 32-bit seed。 输入会先经过 GFDeterministicVariantSerializer 的规范编码，因此 Dictionary key 顺序不会影响结果。默认拒绝 float、Object、Resource、Callable 和循环引用。 需要区分编码失败与合法 0 seed 时使用 try_make_stable_seed()。

参数：

| 名称 | 说明 |
|---|---|
| `parts` | 参与 seed 派生的纯数据部件。 |
| `options` | 确定性编码选项。 |

返回：派生 seed；输入无法规范编码时返回 0。

结构：

- `parts`: Array of deterministic Variant values accepted by GFDeterministicVariantSerializer.to_canonical_value().
- `options`: Dictionary with optional `allow_floats: bool` and `max_depth: int`.

<a id="member-gfseedutility-methods-make_stable_grid_seed"></a>

### `make_stable_grid_seed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_stable_grid_seed(cell: Vector2i, seed_value: int = 0, namespace_id: String = "") -> int:
```

将 2D 网格坐标稳定映射为 32-bit seed。 适合 tile 变体、程序化摆放、刷点或规则 tie-break。namespace_id 用于隔离不同系统，seed_value 用于接入项目主种子或配置种子。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 参与派生的网格坐标。 |
| `seed_value` | 上游种子；相同坐标和 namespace 下不同 seed_value 会得到不同结果。 |
| `namespace_id` | 可选命名空间，用于隔离不同用途。 |

返回：0 到 4294967295 范围内的稳定整数 seed。

<a id="member-gfseedutility-methods-get_branched_rng"></a>

### `get_branched_rng`

- API：`public`
- 首次版本：`3.17.0`
- 弃用：`5.2.0 Use get_branched_godot_rng() when a Godot RandomNumberGenerator stream is required; use get_branched_deterministic_random() for long-term deterministic simulation.`

```gdscript
func get_branched_rng(string_seed: String) -> RandomNumberGenerator:
```

基于主 RNG 当前状态与字符串标签，派生出一个独立的 Godot 子 RNG。 每次调用只推进当前标签的分支计数，不推进主 RNG 的随机序列。 同一主状态、同一标签和同一调用序号会在同一 Godot 随机算法下产生可复现的子随机序列。

参数：

| 名称 | 说明 |
|---|---|
| `string_seed` | 用于标识子随机流用途的字符串（如 "loot_table"、"enemy_ai"）。 |

返回：一个已完成种子初始化的独立 RandomNumberGenerator 实例。

<a id="member-gfseedutility-methods-get_branched_godot_rng"></a>

### `get_branched_godot_rng`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_branched_godot_rng(string_seed: String) -> RandomNumberGenerator:
```

基于主 RNG 当前状态与字符串标签，派生出一个独立的 Godot 子 RNG。 每次调用只推进当前标签的 Godot RNG 分支计数，不推进主 RNG 的随机序列。 该入口返回 Godot `RandomNumberGenerator`，适合非锁步玩法、编辑器工具和同一 Godot 版本内复现；不作为跨 Godot 版本固定序列契约。

参数：

| 名称 | 说明 |
|---|---|
| `string_seed` | 用于标识子随机流用途的字符串。 |

返回：一个已完成种子初始化的独立 RandomNumberGenerator 实例。

<a id="member-gfseedutility-methods-get_branched_deterministic_random"></a>

### `get_branched_deterministic_random`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_branched_deterministic_random(string_seed: String) -> GFDeterministicRandom:
```

基于主种子与字符串标签，派生 GF 固定算法随机源。 每次调用只推进 deterministic 分支计数，不推进主 RNG 的随机序列， 也不影响 `get_branched_rng()` 的 Godot RNG 分支计数。

参数：

| 名称 | 说明 |
|---|---|
| `string_seed` | 用于标识确定性子随机流用途的字符串。 |

返回：一个已完成种子初始化的独立 GFDeterministicRandom 实例。
