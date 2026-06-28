# 通用数值修饰

`GFNumericModifierMath` 用于把一组通用修饰按 `priority` 应用到基础数值上。它只定义 add、multiply、divide 的计算顺序和诊断报告，不解释这些数值来自属性、装备、难度、配置表还是调试工具。

```gdscript
var modifiers := [
	GFNumericModifierMath.make_modifier(5.0, GFNumericModifierMath.Operation.ADD, 0, true, &"flat"),
	GFNumericModifierMath.make_modifier(1.2, GFNumericModifierMath.Operation.MULTIPLY, 10, true, &"ratio"),
]

var report := GFNumericModifierMath.calculate(10.0, modifiers, {
	"clamp_enabled": true,
	"min_value": 0.0,
	"max_value": 30.0,
})

if report.ok:
	print(report.value)
else:
	push_warning(str(report.issues))
```

## 报告优先

`calculate()` 会返回 `ok`、`value`、`unclamped_value`、`applied_modifiers`、`skipped_modifiers` 和 `issues`。除零、无效操作、`NaN` / `Infinity` 输入或无效 clamp 范围都会进入 `issues`，并且报告本身保持 JSON 友好，不会把非有限 float 直接交给 `JSON.stringify()`。

只需要最终数值时可用 `calculate_value()`，但需要在编辑器工具、配置预检或战斗调试面板中解释来源时应优先保留完整报告。

## 使用边界

- 适合配置表、编辑器预检、调试面板、通用属性面板或项目自定义资源读取后做纯数值叠加。
- 不负责修饰生命周期、来源去重、Buff 叠层、属性名解析或网络同步；这些仍由项目层或更高层扩展决定。
- 需要固定业务公式时，应在项目层先把业务规则归一成通用 modifier，再交给该工具计算。
