# GFTagExpression

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/tags/gf_tag_expression.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.18.0`

可嵌套标签查询表达式资源。 在 GFTagQuery 的 all/any/none 单层查询之上提供组合表达式，适合描述 “任意一组条件成立”“全部子条件成立”或“没有子条件成立”等通用标签规则。 它只组合查询结果，不维护全局标签表，也不规定标签业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Operator`](#member-gftagexpression-enums-operator) | `enum Operator` |
| 属性 | [`operator`](#member-gftagexpression-properties-operator) | `var operator: Operator = Operator.QUERY` |
| 属性 | [`query`](#member-gftagexpression-properties-query) | `var query: GFTagQuery = null` |
| 属性 | [`expressions`](#member-gftagexpression-properties-expressions) | `var expressions: Array[Resource] = []` |
| 方法 | [`is_empty`](#member-gftagexpression-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`matches`](#member-gftagexpression-methods-matches) | `func matches(source: Variant) -> bool:` |
| 方法 | [`get_match_report`](#member-gftagexpression-methods-get_match_report) | `func get_match_report(source: Variant) -> Dictionary:` |
| 方法 | [`configure_query`](#member-gftagexpression-methods-configure_query) | `func configure_query(tag_query: GFTagQuery) -> GFTagExpression:` |
| 方法 | [`configure_all`](#member-gftagexpression-methods-configure_all) | `func configure_all(child_expressions: Array[GFTagExpression]) -> GFTagExpression:` |
| 方法 | [`configure_any`](#member-gftagexpression-methods-configure_any) | `func configure_any(child_expressions: Array[GFTagExpression]) -> GFTagExpression:` |
| 方法 | [`configure_none`](#member-gftagexpression-methods-configure_none) | `func configure_none(child_expressions: Array[GFTagExpression]) -> GFTagExpression:` |
| 方法 | [`duplicate_expression`](#member-gftagexpression-methods-duplicate_expression) | `func duplicate_expression() -> GFTagExpression:` |
| 方法 | [`to_dictionary`](#member-gftagexpression-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gftagexpression-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFTagExpression:` |
| 方法 | [`from_query`](#member-gftagexpression-methods-from_query) | `static func from_query(tag_query: GFTagQuery) -> GFTagExpression:` |

## 枚举

<a id="member-gftagexpression-enums-operator"></a>

### `Operator`

- API：`public`

```gdscript
enum Operator {
	## 使用 query 作为叶子查询。
	QUERY,
	## 全部子表达式都满足。
	ALL,
	## 任意子表达式满足。
	ANY,
	## 没有子表达式满足。
	NONE,
}
```

表达式运算类型。

## 属性

<a id="member-gftagexpression-properties-operator"></a>

### `operator`

- API：`public`

```gdscript
var operator: Operator = Operator.QUERY
```

当前表达式运算类型。

<a id="member-gftagexpression-properties-query"></a>

### `query`

- API：`public`

```gdscript
var query: GFTagQuery = null
```

叶子标签查询。operator 为 QUERY 时使用；为空时视为无条件通过。

<a id="member-gftagexpression-properties-expressions"></a>

### `expressions`

- API：`public`
- 首次版本：`3.18.0`

```gdscript
var expressions: Array[Resource] = []
```

子表达式列表。operator 为 ALL、ANY 或 NONE 时使用。公开语义只接受 GFTagExpression 或 null；其他 Resource 会保留索引并按 null_expression 失败， 不会被静默忽略。推荐通过 configure_all()、configure_any() 或 configure_none() 写入强类型子表达式。

结构：

- `expressions`: Array[GFTagExpression | null]，按数组顺序参与组合判断；底层使用 Array[Resource] 避免自引用 Resource 脚本被引擎永久保留。

## 方法

<a id="member-gftagexpression-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查表达式是否为空。

返回：无叶子查询且无子表达式时返回 true。

<a id="member-gftagexpression-methods-matches"></a>

### `matches`

- API：`public`
- 首次版本：`3.18.0`

```gdscript
func matches(source: Variant) -> bool:
```

匹配标签源。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：表达式满足时返回 true。

结构：

- `source`: Variant accepted by GFTagSourceAdapter through GFTagQuery.

<a id="member-gftagexpression-methods-get_match_report"></a>

### `get_match_report`

- API：`public`
- 首次版本：`3.18.0`

```gdscript
func get_match_report(source: Variant) -> Dictionary:
```

获取匹配报告。 `valid` 表示表达式结构可安全求值，`matched` 表示在结构有效的前提下计算出的 逻辑匹配结果，`ok` 仅在两者都为 true 时为 true。循环、过深嵌套、未知运算符 和无效子项都会失败关闭。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：匹配报告。

结构：

- `source`: Variant accepted by GFTagSourceAdapter through GFTagQuery.
- `return`: Dictionary，包含 ok、valid、matched、operator、query_report、child_reports、matched_indices、failed_indices、invalid_indices、reason 等字段。

<a id="member-gftagexpression-methods-configure_query"></a>

### `configure_query`

- API：`public`

```gdscript
func configure_query(tag_query: GFTagQuery) -> GFTagExpression:
```

配置为叶子查询表达式。

参数：

| 名称 | 说明 |
|---|---|
| `tag_query` | 标签查询资源。 |

返回：当前表达式。

<a id="member-gftagexpression-methods-configure_all"></a>

### `configure_all`

- API：`public`

```gdscript
func configure_all(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
```

配置为全部子表达式都满足。

参数：

| 名称 | 说明 |
|---|---|
| `child_expressions` | 子表达式列表。 |

返回：当前表达式。

结构：

- `child_expressions`: Array[GFTagExpression]，null 项会在匹配时按失败处理。

<a id="member-gftagexpression-methods-configure_any"></a>

### `configure_any`

- API：`public`

```gdscript
func configure_any(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
```

配置为任意子表达式满足。

参数：

| 名称 | 说明 |
|---|---|
| `child_expressions` | 子表达式列表。 |

返回：当前表达式。

结构：

- `child_expressions`: Array[GFTagExpression]，null 项会在匹配时按失败处理。

<a id="member-gftagexpression-methods-configure_none"></a>

### `configure_none`

- API：`public`

```gdscript
func configure_none(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
```

配置为没有子表达式满足。

参数：

| 名称 | 说明 |
|---|---|
| `child_expressions` | 子表达式列表。 |

返回：当前表达式。

结构：

- `child_expressions`: Array[GFTagExpression]，null 项会在匹配时按失败处理。

<a id="member-gftagexpression-methods-duplicate_expression"></a>

### `duplicate_expression`

- API：`public`

```gdscript
func duplicate_expression() -> GFTagExpression:
```

创建同内容拷贝。

返回：新表达式。

<a id="member-gftagexpression-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

导出为字典。

返回：表达式字典。

结构：

- `return`: Dictionary serialized tag expression.

<a id="member-gftagexpression-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`

```gdscript
static func from_dictionary(data: Dictionary) -> GFTagExpression:
```

从字典创建表达式。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 表达式字典。 |

返回：新表达式。

结构：

- `data`: Dictionary serialized tag expression.

<a id="member-gftagexpression-methods-from_query"></a>

### `from_query`

- API：`public`

```gdscript
static func from_query(tag_query: GFTagQuery) -> GFTagExpression:
```

以查询资源创建叶子表达式。

参数：

| 名称 | 说明 |
|---|---|
| `tag_query` | 标签查询资源。 |

返回：新表达式。
