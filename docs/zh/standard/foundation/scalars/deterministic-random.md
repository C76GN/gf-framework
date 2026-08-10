# 确定性随机源

`GFDeterministicRandom` 是 foundation 层的可变确定性随机流。它使用 GF 固定的 `xorshift32` 状态转换，不依赖 Godot `RandomNumberGenerator` 的内部实现，适合锁步、回放、黄金测试和需要固定序列的纯算法工具。

## 使用方式

```gdscript
var rng := GFDeterministicRandom.from_seed(42)
var first := rng.next_u32()
var roll := rng.next_int_range(1, 100)
var unit := rng.next_float_unit()
var offset := rng.next_float_range(-1.0, 1.0)

var snapshot := rng.to_dict()
var restored := GFDeterministicRandom.from_dict(snapshot)
```

`next_float_unit()` 与 `next_float_range()` 只是把固定 u32 序列缩放为浮点数，便于 Poisson-disc、采样和编辑器工具复用同一个稳定随机源。涉及锁步真值、网络对账或长期存档 hash 时，仍应优先使用整数、`GFFixedDecimal` 或定点向量表达结果，不要把浮点几何结果当作 deterministic math 的最终真值。

`to_dict()` 会保存算法名、状态版本、初始种子和当前状态。状态为非零 u32；传入 0 种子时会映射到稳定默认种子，避免 xorshift32 零状态锁死。`apply_dict()` 要求 `algorithm`、`version`、`seed` 和 `state` 四个字段全部显式存在；缺失身份不会被默认解释成当前算法或版本。任一字段缺失、类型/范围非法或 `state = 0` 时，入口返回 `false` 并重置为默认随机源。

## 与 GFSeedUtility 的关系

`GFSeedUtility` 是运行时 Utility，负责项目级主 RNG、状态恢复和按标签派生 Godot `RandomNumberGenerator`。它适合普通项目随机流管理、调试复现和运行时服务注入。

`GFDeterministicRandom` 是 foundation runtime handle，只承诺固定算法、可保存状态和固定 golden 序列。它不注册到 `GFArchitecture`，不管理项目全局随机状态，也不替代 `GFSeedUtility`。

需要把固定算法随机流纳入项目主种子、完整状态保存和分支调用计数时，使用 `GFSeedUtility.get_branched_deterministic_random()` 派生实例。这样 deterministic 分支会和 Godot RNG 分支分开计数，相同标签不会互相消耗。

## 使用边界

- 需要跨版本固定输出序列时使用 `GFDeterministicRandom`。
- 只需要 Godot 环境内可复现随机流时，可以继续使用 `GFSeedUtility` 或显式传入 `RandomNumberGenerator`。
- 不要把它用于密码学安全随机、系统熵、UUID 生成或安全令牌。
- 后续定点随机、确定性序列化、寻路 tie-break 和 broadphase 稳定排序可以基于它构建。
- `GFFixedDecimal` 已作为 deterministic math 的定点数底座；需要稳定保存时使用它的 `to_dict()` / `from_dict()` 或 `to_bytes()` / `from_bytes()`。
- `GFFixedVector2` / `GFFixedVector3` 已作为 deterministic math 的定点向量底座；它们通过 `GFFixedDecimal` 处理分量运算，并提供 JSON 安全状态和固定字节格式。
- 需要对随机状态、定点状态、数组和字典生成稳定 JSON、bytes 或 SHA-256 时，使用 `GFDeterministicVariantSerializer`；它消费这些类型的 `to_dict()` 纯数据状态，不直接反射对象。
