# 数字格式化

用 `GFNumberFormatPolicy` 声明显示政策，再调用 `GFNumberFormatter.format_number(value, policy)`。格式化只影响文本；余额比较、售价校验和交易继续使用原始精确数值。

```gdscript
var compact: GFNumberFormatPolicy = GFNumberFormatPolicy.create({
	"notation": "compact", "group_base": 10000, "decimal_places": 1,
	"rounding": "toward_zero"
})
var text: String = GFNumberFormatter.format_number("99999950", compact)
# 9999.9万：正数截断不会把显示值高估为1亿。
```

政策创建时严格验证类型、字段与预算，并冻结后缀副本，可复用于多个控件。无政策参数时使用默认 auto、1000单位、2位小数、half_up 和裁剪尾零。`create()` 对非法政策返回 null；`try_create()` 同时返回 `ok/policy/error_kind/path`，可以定位拼错的字段或无效值。不要将失败的 null 直接传给格式化入口：null 在该入口表示采用默认政策。从用户设置读取字典时可直接用 `try_format_options(value, options)`，无效政策会返回错误，不会变成默认显示。切换语言后缀或用户显示设置时创建另一份政策即可，无须修改已经冻结的对象。

## 记法与单位

| notation | 行为 |
|---|---|
| `full` | 普通十进制，可独立设置整数分组和分隔符。超出8192字符预算时默认改用科学计数法。 |
| `compact` | 按1000或10000缩放并追加单位，后缀耗尽时默认改用科学计数法。 |
| `scientific` | 一位整数尾数与十进制指数。 |
| `engineering` | 指数为3的整数倍，支持负指数。 |
| `auto` | 按原始值绝对量级选择；默认小于10^-4的非零值用科学计数法，其他值保持原有紧凑显示效果。阈值可独立配置。 |

1000默认后缀为 k、M、B 等；10000默认后缀为万、亿、兆等。`GFNumberFormatPolicy.get_default_suffixes(group_base)` 返回副本，也可传入自定义 PackedStringArray：1..64项，第一项为空，其余非空且不重复，每项最多32字符。政策不负责自动选择语言、货币符号或业务单位。

`scientific_style` 可选 e、E 或 power，分别产生 `1.23e7`、`1.23E7` 或 `1.23 x 10^7`。`use_grouping` 只作用于普通显示的整数部分。`grouping_size` 可单独指定每组位数，范围1..8192；省略时兼容原行为，按 group_base 取3或4。`group_separator` 默认逗号，可为0..4字符；`decimal_separator` 默认句点，可为1..4字符，二者不接受控制字符。分隔符只渲染数字部分，不改变自定义后缀、指数、输入解析或业务数值。

```gdscript
var display: Dictionary = GFNumberFormatter.try_format_options("123456789.25", {
	"notation": "full", "group_base": 10000, "use_grouping": true,
	"grouping_size": 3, "group_separator": ".", "decimal_separator": ","
})
# display.text 为 123.456.789,25；切换 compact 后仍使用万/亿单位。
```

`auto_scientific_below` 指定科学记法下限的十进制指数，范围-1000000..0，默认-4；`auto_compact_from` 指定进入紧凑规则的下限指数，范围0..1000000，默认0。先判断科学下限，再判断紧凑下限，其余使用full，零始终普通显示。判断使用原始值的绝对数量级，不转float、不先舍入；例如设为-6和4时，0.000001普通显示、0.0000001用科学记法，9999完整显示、10000进入紧凑规则。默认紧凑下限0让原有999.999舍入为1k的行为保持兼容；提高阈值后，阈值以下的值即使舍入跨界也仍按full显示。

预算和后缀不足时，`fallback_notation` 可选 `scientific`（默认）或 `error`。后者让项目自行显示占位符、上限说明或其他界面；失败结果文本为空，不能把它当作真实零。分隔符产生的额外字符也计入8192字符输出预算。该配置不开放无限输出。

## 精度与舍入

`decimal_places` 为0..18的小数位上限。`significant_digits` 为0..18，0表示不另限有效位；开启后与小数位上限同时生效，采用其中更粗的精度。例如123456的3位有效数字显示为123000；0.00123456在3位有效数字、8位小数时显示0.00123，在最多2位小数时显示0。

| rounding | 含义 |
|---|---|
| `half_up` | 最近值，恰好一半时远离零。 |
| `half_even` | 最近值，恰好一半时取末位偶数。 |
| `toward_zero` | 向零截断。 |
| `floor` | 向负无穷方向。 |
| `ceiling` | 向正无穷方向。 |

`trim_zeroes` 决定是否裁掉小数尾零。单位边界和有效位进位都重新对原始数值舍入，不把已经舍入的显示文本作为新输入。例如999950在1000单位、1位小数下显示1M；toward_zero则显示999.9k。负零规范化为零，明确传入的正号在非零文本中保留。

## 精确值与近似值

int、String数值和 GFFixedDecimal 从解析、缩放、舍入到进位都不经过 float，包括紧凑和科学显示。`9007199254740993` 可以精确显示为 `9.007199254740993e15`。文本支持经过严格校验的逗号或下划线分隔，以及科学指数；最多4096个原始字符，首尾空白也计入预算。输入指数与数量级范围均为±1000000，极限数量级的舍入可能使输出指数增加一位。

float 和 GFBigNumber 的浮点尾数本身是近似数。格式化展开其可往返的实际浮点文本，再应用政策；增加显示精度不会恢复先前丢失的十进制位，可能显示二进制浮点误差。需要十进制金额或精确阈值时，应从 String 或 GFFixedDecimal 开始。这里采用 Godot JSON 的 full_precision 浮点输出，语义见 [Godot JSON 文档](https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-stringify)。

`format_number()` 对非法输入或拒绝回退输出错误并返回稳定fallback 0。需要区分真实零与错误时使用 `try_format()`：原有 `ok/text/error` 保留，新增 `notation_used` 和 `fallback_reason`，分别说明实际记法和 `output_budget` / `suffix_exhausted` 回退原因；正常显示的回退原因为空。失败文本与实际记法为空且不记录日志。`try_format_options()` 还用 `policy_error_kind/path` 定位政策错误；非政策错误时这两个字段为空。bool、任意对象、非有限浮点数、非法文本和超预算输入都被拒绝。

## 入口迁移

原 `format_full`、`format_compact`、`format_scientific`、`format_auto` 及枚举入口统一为 `format_number(value, policy)`，相应能力由 notation、scientific_style 和其他政策字段选择。`use_truncation=true` 改为 `rounding: "toward_zero"`，默认后缀入口移到政策类型。原有完整显示、定点数、显式正负号、分组、科学风格、自定义单位与超大数回退能力均保留。

`GFDecimalStringFormatter` 是框架内部共享的十进制分量、量化和文本校验实现。项目使用上述公开政策入口，不依赖内部参数或解析记录结构。
