# 权重表

`GFWeightedTable` 是通用权重选择原语。它只管理候选值、权重、随机源和可选元数据，不解释这些值是奖励、AI 决策、音效变体还是关卡片段。

需要接入项目运行时随机流时，显式传入随机源：普通 Godot 随机流使用 `RandomNumberGenerator`，例如来自 `GFSeedUtility.get_branched_godot_rng()` 的分支 RNG；长期固定序列使用 `GFDeterministicRandom`，例如来自 `GFSeedUtility.get_branched_deterministic_random()` 的分支 RNG。需要不传 RNG 也得到 GF 固定算法序列时，设置表上的 `deterministic_seed`；这一路会使用 `GFDeterministicRandom` 作为后备随机源。

```gdscript
var table := GFWeightedTable.new()
table.add_entry(&"small", 70.0)
table.add_entry(&"medium", 25.0)
table.add_entry(&"large", 5.0)

var rng := RandomNumberGenerator.new()
rng.seed = 12345
var picked_value := table.pick_value(rng)
var batch := table.pick_many(3, rng, false)

var fixed_rng := GFDeterministicRandom.from_seed(12345)
var deterministic_batch := table.pick_many(3, fixed_rng)
```

`pick_value()` 每次调用都会解析一次后备随机源；如果只设置 `deterministic_seed` 且不传入 rng，连续单次调用会从同一个固定种子的第一步开始。需要一段连续随机序列时，优先使用 `pick_many()`，或在项目层传入同一个 `RandomNumberGenerator` / `GFDeterministicRandom` 分支 RNG。

资源化条目适合编辑器配置或导表后转换；字典序列化方法只保留通用字段，项目层可以自由决定 `value` 与 `metadata` 的结构。

权重必须是有限正数。`GFWeightedEntry.weight` 收到 `NaN`、`Infinity` 或负值时会归一到 `0.0` 并让条目不参与抽取，避免无效数值污染总权重或 JSON 诊断报告。

复杂业务校验仍应放在项目自己的配置管线中，而不是塞进权重表。
