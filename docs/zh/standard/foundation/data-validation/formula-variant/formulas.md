# 资源化公式

资源化公式适合把可替换的计算策略从 System、Command 或配置驱动流程中抽离出来。GF 只提供抽象容器，不规定伤害、命中、价格、评分等具体语义。

```gdscript
## 项目评分公式；只读取传入参数，不持有模型或场景节点。
class_name ScoreFormula
extends GFFormula


## 计算基础分乘倍率；缺少参数对象时沿用公式资源的 fallback_value。
func calculate(parameter: GFFormulaParameter = null) -> Variant:
	if parameter == null:
		return fallback_value

	var base := float(parameter.get_value(&"base", 0.0))
	var multiplier := float(parameter.get_value(&"multiplier", 1.0))
	return base * multiplier
```

```gdscript
var formulas := GFFormulaSet.new()
formulas.set_formula(&"score", ScoreFormula.new())

var parameter := GFFormulaParameter.new()
parameter.set_value(&"base", 10.0)
parameter.set_value(&"multiplier", 2.5)

var result := formulas.calculate(&"score", parameter, 0.0)
```

`calculate_float()`、`calculate_int()`、`calculate_bool()` 提供稳定的类型兜底，适合项目层在读取用户配置或可编辑资源时降低防御代码噪声。字符串转 float 会先检查 `is_valid_float()`，非法数字文本会返回传入的 fallback，而不会静默变成 `0.0`。
