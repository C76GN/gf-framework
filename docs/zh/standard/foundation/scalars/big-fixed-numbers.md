# 大数、定点数与定点向量

`GFBigNumber`、`GFFixedDecimal`、`GFFixedVector2` 和 `GFFixedVector3` 解决不同数值问题：大数用于超大量级展示和近似计算，定点数用于固定小数位的精确累计，定点向量用于 deterministic 坐标、方向和稳定序列化。

## `GFBigNumber`

`GFBigNumber` 适合挂机/放置类游戏的超大数值。它使用尾数 + 指数的形式表达量级，可用于：

- 超出原生 `float` 直观显示范围的资源数量
- 跨数量级比较
- 高阶增长、收益结算、战力显示

```gdscript
var gold := GFBigNumber.from_string("1.25e18")
var bonus := GFBigNumber.from_string("2e17")
var total := gold.add(bonus)
print(total.to_scientific_string()) # 1.45e18
```

`GFBigNumber` 是显示和量级计算用的近似大数。它适合挂机资源、战力、收益预估和跨数量级比较，不适合作为付费货币、强精度经济结算、竞技排行榜最终判定或任何要求逐分逐厘精确的权威数据源。

零值只由规范尾数精确为 `0.0` 表示；`from_float()` 不会用固定绝对 epsilon 吞掉很小但有限的非零值。需要把运算噪声视作零时，应由业务在比较边界显式选择相对或绝对容差，而不是改变大数可表达的最小量级。

## `GFFixedDecimal`

`GFFixedDecimal` 适合货币、税率、百分比、经营数值这类对累计误差更敏感的场景。它内部用整数缩放保存值。

```gdscript
var price := GFFixedDecimal.from_string("12.34", 2)
var tax := GFFixedDecimal.from_string("0.08", 2)
var total := price.multiply(tax, 2).add(price)
print(total.to_decimal_string()) # 13.33
```

普通十进制字符串会走整数缩放解析；科学计数法字符串会先退回 float 路径再构建定点数，可能存在浮点舍入。需要严格十进制导入时，建议用普通十进制字符串，或在项目导表阶段把科学计数法预处理成固定小数文本。

`GFFixedDecimal` 也是 GF deterministic math 的定点数底座。需要保存到 JSON、存档或配置时，优先使用 `to_dict()` / `from_dict()`：状态字典包含 `type`、`version`、`raw_value` 和 `decimal_places`，其中 `raw_value` 固定为十进制字符串，避免 JSON 64 位整数精度丢失。需要不依赖 Godot `Variant` 编码的二进制 golden 输出时，使用 `to_bytes()` / `from_bytes()`；该格式固定为 `GFFD` magic、版本、小数位、符号位和 8 字节大端绝对 raw 值。

定点数 raw 值使用对称安全范围 `[-9223372036854775807, 9223372036854775807]`，而不是完整 int64 最小值。这可以保证绝对值、符号 magnitude 字节格式和溢出钳制规则在所有定点类型之间一致。

跨 `decimal_places` 比较会按十进制 magnitude 做无溢出对齐，保持等价、反对称和传递；除法在原生整数中间乘法无法容纳精确缩放时会切换到宽十进制路径，只在最终 raw 边界执行舍入和饱和。

直接写入 `raw_value` 或 `decimal_places` 也会触发同一套规范化规则；超出范围的 raw 值会被钳制，小数位会被限制到合法区间。二进制读取会拒绝“负号 + 零 magnitude”的非规范负零编码，避免同一个数值出现两种字节形态。

## `GFFixedVector2` / `GFFixedVector3`

`GFFixedVector2` 和 `GFFixedVector3` 用统一 `decimal_places` 管理多个 raw 分量，适合锁步、回放、路径 tie-break、稳定排序和 golden 测试中需要表达连续坐标的场景。它们不替代 `Vector2i` / `Vector3i` 格子坐标，也不替代 Godot `Vector2` / `Vector3` 在渲染、物理和编辑器里的浮点向量。

```gdscript
var a := GFFixedVector2.from_decimal_strings("1.20", "0.50", 2)
var b := GFFixedVector2.from_decimal_strings("0.35", "2.00", 2)
var dot := a.dot(b, 3)
print(dot.to_decimal_string()) # 1.420
```

定点向量的加减、标量乘、点积和长度平方都通过 `GFFixedDecimal` 执行缩放、舍入和溢出处理。需要与 Godot API 交互时可以显式调用 `from_vector2()`、`from_vector3()`、`to_vector2()` 或 `to_vector3()`，但这些入口会经过 `float`，不应作为 deterministic 真值来源。

`to_dict()` / `from_dict()` 使用 JSON 安全状态字典，raw 分量固定为字符串。`to_bytes()` / `from_bytes()` 使用固定二进制格式：`GFF2` 或 `GFF3` magic、版本、小数位，以及每个分量的符号位和 8 字节大端绝对 raw 值。定点向量分量和 `GFFixedDecimal.raw_value` 使用同一套 raw 范围、文本校验和 signed magnitude 编码规则。
