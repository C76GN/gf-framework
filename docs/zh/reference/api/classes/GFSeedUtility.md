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
| 方法 | [`get_rng`](#member-gfseedutility-methods-get_rng) | `func get_rng() -> RandomNumberGenerator:` |
| 方法 | [`get_state`](#member-gfseedutility-methods-get_state) | `func get_state() -> int:` |
| 方法 | [`set_state`](#member-gfseedutility-methods-set_state) | `func set_state(state: int) -> void:` |
| 方法 | [`get_full_state`](#member-gfseedutility-methods-get_full_state) | `func get_full_state() -> Dictionary:` |
| 方法 | [`set_full_state`](#member-gfseedutility-methods-set_full_state) | `func set_full_state(state: Dictionary) -> void:` |
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

<a id="member-gfseedutility-methods-get_rng"></a>

### `get_rng`

- API：`public`

```gdscript
func get_rng() -> RandomNumberGenerator:
```

获取主随机数生成器。 调用方可以直接使用该实例生成随机数；生成行为会推进主 RNG 状态。

返回：主随机数生成器实例。

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

基于主 RNG 当前状态与字符串标签，派生 GF 固定算法随机源。 每次调用只推进 deterministic 分支计数，不推进主 RNG 的随机序列， 也不影响 `get_branched_rng()` 的 Godot RNG 分支计数。

参数：

| 名称 | 说明 |
|---|---|
| `string_seed` | 用于标识确定性子随机流用途的字符串。 |

返回：一个已完成种子初始化的独立 GFDeterministicRandom 实例。
