# GFNumberFormatter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formatting/gf_number_formatter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

由冻结政策控制的统一数字显示工具。 int、十进制文本和 GFFixedDecimal 使用精确文本运算。float 与 GFBigNumber 的 尾数本身是近似值，格式化不会恢复它们已经丢失的精度。输出仅用于展示。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`format_number`](#member-gfnumberformatter-methods-format_number) | `static func format_number(value: Variant, policy: GFNumberFormatPolicy = null) -> String:` |
| 方法 | [`try_format`](#member-gfnumberformatter-methods-try_format) | `static func try_format(value: Variant, policy: GFNumberFormatPolicy = null) -> Dictionary:` |
| 方法 | [`try_format_options`](#member-gfnumberformatter-methods-try_format_options) | `static func try_format_options(value: Variant, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnumberformatter-methods-format_number"></a>

### `format_number`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func format_number(value: Variant, policy: GFNumberFormatPolicy = null) -> String:
```

按政策格式化数值，不使用多组位置布尔参数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要显示的数值。 |
| `policy` | 冻结显示政策；null 使用默认 auto 政策。 |

返回：格式化字符串；非法输入报告错误并返回稳定fallback 0。需要区分错误与真实零时使用 try_format。

结构：

- `value`: int、有限float、最多4096字符的String数值、GFBigNumber或GFFixedDecimal。文本支持严格逗号/下划线分隔和科学指数，输入及数量级范围±1000000；不接受bool或任意对象。

<a id="member-gfnumberformatter-methods-try_format"></a>

### `try_format`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func try_format(value: Variant, policy: GFNumberFormatPolicy = null) -> Dictionary:
```

返回可检查的格式化结果，不输出日志也不把非法输入当作零。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 与 format_number 相同的数值域。 |
| `policy` | 冻结政策；null 使用默认政策。 |

返回：有界显示结果。

结构：

- `value`: int、有限float、String数值、GFBigNumber或GFFixedDecimal；预算与format_number.value相同。
- `return`: 封闭 Dictionary，ok:bool、text:String、error:String、notation_used:String、fallback_reason:String、policy_error_kind:String、path:String。成功文本最多8192字符，失败文本为空；notation_used为实际full/compact/scientific/engineering，失败为空；fallback_reason为output_budget/suffix_exhausted或空。默认科学回退，fallback_notation=error时拒绝回退。error为稳定原因标识；policy_error_kind/path由try_format_options报告政策错误，其余为空，不包含输入载荷。

<a id="member-gfnumberformatter-methods-try_format_options"></a>

### `try_format_options`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func try_format_options(value: Variant, options: Dictionary = {}) -> Dictionary:
```

直接验收显示声明后格式化，避免把政策创建失败的null解释成默认政策。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 与format_number相同的精确值或近似值。 |
| `options` | 本次显示声明；空字典采用默认政策。 |

返回：不记录日志的格式化结果；政策无效时不解析数值。

结构：

- `value`: int、有限float、String数值、GFBigNumber或GFFixedDecimal；范围见format_number.value。
- `options`: 封闭Dictionary，见GFNumberFormatPolicy.create.options。
- `return`: 与try_format.return相同；政策错误时ok=false、error=invalid_policy、policy_error_kind/path来自GFNumberFormatPolicy.try_create，text为空。
