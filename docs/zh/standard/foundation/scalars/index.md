# Foundation 数值、成长与权重

这些 Foundation 能力提供数值表达、格式化、成长曲线和权重表等纯数据或纯算法基础件，不参与 `GFArchitecture` 生命周期。

## 阅读入口

- [大数、定点数与定点向量](big-fixed-numbers.md)：`GFBigNumber`、`GFFixedDecimal`、`GFFixedVector2` 与 `GFFixedVector3`。
- [确定性随机源](deterministic-random.md)：`GFDeterministicRandom` 的固定 xorshift32 序列、状态恢复和适用边界。
- [确定性序列化](deterministic-serialization.md)：`GFDeterministicVariantSerializer` 的 canonical value、JSON、bytes 和 SHA-256。
- [数字格式化](number-formatting.md)：`GFNumberFormatter` 与 `GFDecimalStringFormatter`。
- [成长曲线](progression-math/index.md)：`GFProgressionMath` 的价格曲线、收益曲线和离线收益。
- [多项式数学](polynomial-math.md)：`GFPolynomialMath` 的系数生成、采样、导数和实根求解。
- [权重表](weighted-table.md)：`GFWeightedEntry` / `GFWeightedTable` 的候选值、权重和随机选择。
- [层名与 Bitmask](layer-mask.md)：`GFLayerMaskUtility` 的层名、索引和整数掩码互转。

## 使用边界

这些类型只处理通用数值、文本格式、确定性编码和纯算法。货币精度策略、排行榜判定、资源流转、掉落配置、业务校验、碰撞层语义、多项式公式含义和本地化单位仍由项目层决定。
