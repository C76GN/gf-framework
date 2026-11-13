# GFNumberFormatPolicy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formatting/gf_number_format_policy.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

冻结的数字显示政策。 小数位与有效位共同限定显示精度，舍入只影响展示，不改变原始数值或交易判定。 单位缩放、整数分组、分隔符和自动记法分别配置；默认保留科学计数法回退。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfnumberformatpolicy-methods-create) | `static func create(options: Dictionary = {}) -> GFNumberFormatPolicy:` |
| 方法 | [`try_create`](#member-gfnumberformatpolicy-methods-try_create) | `static func try_create(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_default_suffixes`](#member-gfnumberformatpolicy-methods-get_default_suffixes) | `static func get_default_suffixes(group_base: int = 1000) -> PackedStringArray:` |
| 方法 | [`to_record`](#member-gfnumberformatpolicy-methods-to_record) | `func to_record() -> Dictionary:` |

## 方法

<a id="member-gfnumberformatpolicy-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(options: Dictionary = {}) -> GFNumberFormatPolicy:
```

创建政策并复制单位表，不接受隐式类型转换。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 显示政策。 |

返回：冻结政策；无效输入返回 null。

结构：

- `options`: 封闭 Dictionary，可选 notation:String（auto/full/compact/scientific/engineering，默认auto）、group_base:int（1000或10000，默认1000）、suffixes:PackedStringArray（默认对应单位表）、decimal_places:int[0,18]（默认2）、significant_digits:int[0,18]（0关闭）、rounding:String（half_up/half_even/toward_zero/floor/ceiling，默认half_up）、trim_zeroes:bool（默认true）、use_grouping:bool（默认false）、scientific_style:String（e/E/power，默认e）。grouping_size:int[1,8192] 默认按group_base取3或4；group_separator:String默认逗号、0..4字符；decimal_separator:String默认句点、1..4字符，分隔符不含控制字符且只影响展示。auto_scientific_below:int[-1000000,0]默认-4，auto_compact_from:int[0,1000000]默认0，按原始非零值的绝对十进制数量级选择，先判断科学下限，再判断紧凑下限，其余full。fallback_notation:String为scientific（默认）或error。后缀1..64项，每项最多32字符，第一项为空，其余非空且不重复。

<a id="member-gfnumberformatpolicy-methods-try_create"></a>

### `try_create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func try_create(options: Dictionary = {}) -> Dictionary:
```

创建政策并返回具体失败字段；失败不产生政策，也不输出日志。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 与 create 相同的显示声明。 |

返回：政策或可解释的失败结果，修改结果字典不影响已创建政策。

结构：

- `options`: Dictionary，字段、默认值与预算见 create.options。
- `return`: 封闭 Dictionary，ok:bool、policy:GFNumberFormatPolicy或null、error_kind:String、path:String；成功时后两项为空，失败为invalid_type/unknown_option/invalid_value及options字段路径，不回显配置值。

<a id="member-gfnumberformatpolicy-methods-get_default_suffixes"></a>

### `get_default_suffixes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_default_suffixes(group_base: int = 1000) -> PackedStringArray:
```

获取框架单位表的隔离副本。

参数：

| 名称 | 说明 |
|---|---|
| `group_base` | 1000或10000；其他输入返回空数组。 |

返回：第0项为空的单位表。

<a id="member-gfnumberformatpolicy-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

获取完整政策副本。

返回：完整实际政策；未经工厂创建的实例返回空字典。

结构：

- `return`: Dictionary，包含 create.options 的全部实际字段，省略的选项已填入默认值，容器与政策内部隔离。
