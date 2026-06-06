# 多项式数学

`GFPolynomialMath` 提供高阶到低阶系数的纯多项式计算工具，适合命中预测、曲线分析、配置校验或工具链里的数值求解。它不解析字符串表达式，不执行脚本，也不绑定具体玩法公式。

```gdscript
var coefficients := GFPolynomialMath.from_roots(PackedFloat64Array([1.0, 2.0, 3.0]))
var roots := GFPolynomialMath.real_roots(coefficients)
```

系数顺序固定为高阶到低阶。`x^2 - 5x + 6` 写作 `PackedFloat64Array([1.0, -5.0, 6.0])`；`evaluate(coefficients, 2.0)` 会返回采样值，`derivative(coefficients)` 会返回导函数系数。

`real_roots()` 默认用系数估算搜索范围，并通过导函数临界点切分区间来查找实根。需要限制工具只关心的区间时，可传入 `min_x` 和 `max_x`；需要调整数值容差时，可传入 `epsilon`、`root_merge_epsilon` 和 `max_iterations`。

```gdscript
var roots := GFPolynomialMath.real_roots(
	PackedFloat64Array([1.0, -5.0, 6.0]),
	{
		"min_x": 0.0,
		"max_x": 4.0,
		"epsilon": 0.00001,
	}
)
```

重复根会按 `root_merge_epsilon` 合并。高次数或近重根多项式可能需要项目提高容差或提供更窄范围；GF 只返回实根，不返回复根，也不替项目决定公式含义。
