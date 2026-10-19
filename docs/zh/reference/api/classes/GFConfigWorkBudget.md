# GFConfigWorkBudget

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_work_budget.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次配置操作及批次共享的有限工作预算。 句柄只累计、不重置；首次失败锁存。它约束受信任配置代码的协作工作量， 不隔离自定义代码，也不统计 Resource 属性或引擎内部全部内存。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfconfigworkbudget-methods-_init) | `func _init(limits: Dictionary = {}) -> void:` |
| 方法 | [`from_options`](#member-gfconfigworkbudget-methods-from_options) | `static func from_options(options: Dictionary = {}) -> GFConfigWorkBudget:` |
| 方法 | [`check_input_bytes`](#member-gfconfigworkbudget-methods-check_input_bytes) | `func check_input_bytes(amount: int, context: String = "") -> bool:` |
| 方法 | [`consume_input_bytes`](#member-gfconfigworkbudget-methods-consume_input_bytes) | `func consume_input_bytes(amount: int, context: String = "") -> bool:` |
| 方法 | [`consume_output_bytes`](#member-gfconfigworkbudget-methods-consume_output_bytes) | `func consume_output_bytes(amount: int, context: String = "") -> bool:` |
| 方法 | [`consume_work`](#member-gfconfigworkbudget-methods-consume_work) | `func consume_work(amount: int = 1, context: String = "") -> bool:` |
| 方法 | [`check_depth`](#member-gfconfigworkbudget-methods-check_depth) | `func check_depth(depth: int, context: String = "") -> bool:` |
| 方法 | [`admit_value`](#member-gfconfigworkbudget-methods-admit_value) | `func admit_value(value: Variant, context: String = "") -> bool:` |
| 方法 | [`is_ok`](#member-gfconfigworkbudget-methods-is_ok) | `func is_ok() -> bool:` |
| 方法 | [`get_report`](#member-gfconfigworkbudget-methods-get_report) | `func get_report() -> Dictionary:` |

## 方法

<a id="member-gfconfigworkbudget-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func _init(limits: Dictionary = {}) -> void:
```

创建不可重置的操作预算；非法限额创建失败句柄。

参数：

| 名称 | 说明 |
|---|---|
| `limits` | 覆盖默认容量的字段。 |

结构：

- `limits`: Dictionary，仅接受 max_input_bytes、max_depth、max_work_units、max_value_bytes、max_output_bytes 的正整数；max_depth 最大为 256。

<a id="member-gfconfigworkbudget-methods-from_options"></a>

### `from_options`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_options(options: Dictionary = {}) -> GFConfigWorkBudget:
```

从入口选项取得共享句柄；不得同时声明限额与句柄。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用入口选项，其他业务选项不参与预算解析。 |

返回：新建或原有句柄；非法选项返回失败句柄，并锁存可识别的原句柄。

结构：

- `options`: Dictionary，work_limits 为构造函数限额字典，work_budget 为 GFConfigWorkBudget；两字段互斥，省略时创建默认有限句柄。

<a id="member-gfconfigworkbudget-methods-check_input_bytes"></a>

### `check_input_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func check_input_bytes(amount: int, context: String = "") -> bool:
```

读取或分配前检查剩余输入字节容量，不扣除额度。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 本次准备读取的非负字节数。 |
| `context` | 诊断位置。 |

返回：本次读取仍在剩余额度内时为 true。

<a id="member-gfconfigworkbudget-methods-consume_input_bytes"></a>

### `consume_input_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func consume_input_bytes(amount: int, context: String = "") -> bool:
```

累计原始输入字节；一个来源由读取者或解析者中的一方记账。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 本次新增的非负字节数。 |
| `context` | 诊断位置。 |

返回：接受本次输入时为 true。

<a id="member-gfconfigworkbudget-methods-consume_output_bytes"></a>

### `consume_output_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func consume_output_bytes(amount: int, context: String = "") -> bool:
```

累计序列化输出的 UTF-8 字节，供构造输出片段前预留容量。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 本次新增的非负字节数。 |
| `context` | 诊断位置。 |

返回：接受本次输出时为 true。

<a id="member-gfconfigworkbudget-methods-consume_work"></a>

### `consume_work`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func consume_work(amount: int = 1, context: String = "") -> bool:
```

累计显式工作单元，内部复用 GFExecutionBudget。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 本次执行的非负工作单元数。 |
| `context` | 诊断位置。 |

返回：本次工作在剩余额度内时为 true。

<a id="member-gfconfigworkbudget-methods-check_depth"></a>

### `check_depth`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func check_depth(depth: int, context: String = "") -> bool:
```

检查当前绝对嵌套深度；根值深度为 0。

参数：

| 名称 | 说明 |
|---|---|
| `depth` | 当前非负深度。 |
| `context` | 诊断位置。 |

返回：深度合法且句柄未失败时为 true。

<a id="member-gfconfigworkbudget-methods-admit_value"></a>

### `admit_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func admit_value(value: Variant, context: String = "") -> bool:
```

复制或遍历前准入数据图，重复调用按实际访问量累计，不缓存已检查身份。 Dictionary 键和值及 Array 元素各计一个节点；Packed 元素与祖先身份比较也计工作量。 PackedByteArray 按每 1024 字节一个工作块向上取整，完整字节仍计入载荷。 String/StringName 计 UTF-8 载荷；NodePath 按名称、子名称及分隔符计 UTF-8 载荷，并累计组件访问与文字扫描工作。 数值 Packed 数组计保守存储字节。 仅拒绝当前祖先链循环，共享子容器合法。Resource 作为叶引用保留，不读取其属性； 其余 Object、Callable、Signal、RID 不属于可准入的配置值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要准入的配置值。 |
| `context` | 诊断位置。 |

返回：完整数据图通过准入时为 true，失败不会复制输入。

结构：

- `value`: Variant，支持无循环容器、原生值及 Resource 叶引用。

<a id="member-gfconfigworkbudget-methods-is_ok"></a>

### `is_ok`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_ok() -> bool:
```

检查句柄是否仍可使用。

返回：首次失败前为 true。

<a id="member-gfconfigworkbudget-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_report() -> Dictionary:
```

取得独立报告；修改报告不会改变预算状态。

返回：预算状态及计数。

结构：

- `return`: Dictionary，含 ok、error_kind、error、context、limits 与 usage；usage 含 work_units、input_bytes、value_bytes、output_bytes、peak_depth。
