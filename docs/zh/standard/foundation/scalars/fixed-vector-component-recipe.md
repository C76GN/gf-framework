# 定点向量逐项运算兼容配方

GF 12 的 `GFFixedVector2` / `GFFixedVector3.dot()` 与 `length_squared()` 默认执行完整归约：保留全部乘积及其和，最后只舍入、饱和一次。适合数学点积与长度平方的结果精度语义，详见[大数、定点数与定点向量](big-fixed-numbers.md)。

旧版本会对每个分量乘积先舍入并饱和，再顺序执行有界加法。项目若需要读取历史回放、匹配旧 golden，或明确需要逐项量化后汇总，可把下面两个方法放入项目自己的辅助脚本。它们只组合已有公开 API，GF 不新增公开的旧算法入口。

## 项目侧兼容方法

```gdscript
# 项目侧历史数值兼容工具；left 必须为有效向量。
# 每个乘积先完成量化，再按旧版本的顺序相加，不可改排运算顺序。
extends RefCounted


## 复现旧二维点积；null 右值返回 left 精度的零，忽略目标精度。
## target_decimal_places 和 rounding_mode 原样传给每个分量乘法。
static func legacy_dot2(
	left: GFFixedVector2,
	right: GFFixedVector2,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if right == null:
		return GFFixedDecimal.new(0, left.decimal_places)
	var x_product: GFFixedDecimal = left.get_x_decimal().multiply(
		right.get_x_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var y_product: GFFixedDecimal = left.get_y_decimal().multiply(
		right.get_y_decimal(),
		target_decimal_places,
		rounding_mode
	)
	return x_product.add(y_product)


## 复现旧三维点积；先完成 X、Y、Z 乘法，再执行 (X+Y)+Z。
## 中间饱和不能被最后的抵消恢复，这是兼容历史结果所需的边界。
static func legacy_dot3(
	left: GFFixedVector3,
	right: GFFixedVector3,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if right == null:
		return GFFixedDecimal.new(0, left.decimal_places)
	var x_product: GFFixedDecimal = left.get_x_decimal().multiply(
		right.get_x_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var y_product: GFFixedDecimal = left.get_y_decimal().multiply(
		right.get_y_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var z_product: GFFixedDecimal = left.get_z_decimal().multiply(
		right.get_z_decimal(),
		target_decimal_places,
		rounding_mode
	)
	return x_product.add(y_product).add(z_product)
```

旧长度平方使用同一方法，把向量自身同时作为左右参数传入，例如 `legacy_dot2(value, value, 1)` 或 `legacy_dot3(value, value, 1)`。不要用新的 `length_squared()` 代替这一步，否则会改为完整归约。

## 精度、舍入与诊断

- 省略目标精度或传 `-1` 时，每个乘积沿用两个输入中较高的小数位；长度平方因两侧相同而沿用自身精度。显式目标精度仍交给既有 `GFFixedDecimal.multiply()` 规范化。
- 默认 `HALF_UP` 在正负半值时朝远离零的方向进位。传入 `HALF_EVEN`、`FLOOR`、`CEIL` 或 `TRUNCATE` 时，每个乘积分别执行该策略。
- 每个乘积都会先限制在 raw 对称 int64 范围内。三维加法严格按 `(X+Y)+Z` 左结合，中间越界仍会饱和，不应为了减少误差重排抵消项。
- 兼容方法保留基础运算的 `multiply` / `add` 钳制错误消息、数量及先后顺序；调用栈中的项目辅助方法位置会不同。新的默认归约只在最终超界时报告一次 `dot` 钳制错误。

| 输入与目标 | 逐项兼容配方 | GF 12 默认完整归约 |
| --- | --- | --- |
| `(0.4,0.4)` 长度平方，保留一位，HALF_UP | `0.4` | `0.3` |
| `(0.5,0.5)` 长度平方，保留零位，HALF_UP | `0` | `1` |
| `(0.5,0.5)·(0.5,-0.5)`，保留零位，FLOOR | `-1` | `0` |

逐项汇总是另一种计算合同。项目只有在明确需要该合同或历史兼容时才选用本配方，普通点积继续使用默认入口。

## 锁步与回放迁移

两种算法在各自固定规则下都可重复执行，但同一输入可能得到不同 raw 结果，进而改变阈值分支、排序、状态哈希和后续演算。升级前应在项目会话或回放头中固定运算版本，决定继续采用逐项配方、迁移基准，或明确拒绝不兼容回放。

定点向量的状态字典、raw 分量、`GFF2` / `GFF3` 字节格式和格式版本保持不变。载入旧分量不会恢复旧算法，序列化版本也不能代替项目运算版本。若项目重写过向量分量 getter 或点积方法，还需单独确认自定义行为；本配方复现的是 GF 原有基础运算顺序。
