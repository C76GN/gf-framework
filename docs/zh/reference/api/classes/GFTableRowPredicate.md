# GFTableRowPredicate

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_row_predicate.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

表格结构化行过滤协议。 项目通过子类实现同步、只读、有界且无副作用的行判断。 GFTableDataView 按注册顺序契约组合多个谓词，并把显式失败视为整次投影失败。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`evaluate`](#member-gftablerowpredicate-methods-evaluate) | `func evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:` |
| 方法 | [`_evaluate`](#member-gftablerowpredicate-methods-_evaluate) | `func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:` |

## 方法

<a id="member-gftablerowpredicate-methods-evaluate"></a>

### `evaluate`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
```

求值一个隔离行视图。

参数：

| 名称 | 说明 |
|---|---|
| `row_view` | 不暴露源 row 的隔离只读视图。 |

返回：类型化包含、排除或失败结果。

<a id="member-gftablerowpredicate-methods-_evaluate"></a>

### `_evaluate`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
```

实现一次同步、只读且有界的行判断。

参数：

| 名称 | 说明 |
|---|---|
| `_row_view` | 当前行的隔离只读视图。 |

返回：类型化包含、排除或失败结果。
