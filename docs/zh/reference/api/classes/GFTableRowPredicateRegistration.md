# GFTableRowPredicateRegistration

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_row_predicate_registration.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

命名行谓词的注册定义值。 把项目谓词与稳定 ID、启用状态和显式顺序组合成一次注册定义。 GFTableDataView 会复制数组并以 order 升序、predicate_id 字典序稳定执行。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gftablerowpredicateregistration-methods-create) | `static func create( predicate_id: StringName, predicate: GFTableRowPredicate, order: int = 0, enabled: bool = true ) -> GFTableRowPredicateRegistration:` |
| 方法 | [`get_predicate_id`](#member-gftablerowpredicateregistration-methods-get_predicate_id) | `func get_predicate_id() -> StringName:` |
| 方法 | [`get_predicate`](#member-gftablerowpredicateregistration-methods-get_predicate) | `func get_predicate() -> GFTableRowPredicate:` |
| 方法 | [`get_order`](#member-gftablerowpredicateregistration-methods-get_order) | `func get_order() -> int:` |
| 方法 | [`is_enabled`](#member-gftablerowpredicateregistration-methods-is_enabled) | `func is_enabled() -> bool:` |
| 方法 | [`validate_registration`](#member-gftablerowpredicateregistration-methods-validate_registration) | `func validate_registration() -> Dictionary:` |

## 方法

<a id="member-gftablerowpredicateregistration-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( predicate_id: StringName, predicate: GFTableRowPredicate, order: int = 0, enabled: bool = true ) -> GFTableRowPredicateRegistration:
```

创建注册定义值。

参数：

| 名称 | 说明 |
|---|---|
| `predicate_id` | 非空、无首尾空白且 UTF-8 编码不超过 128 字节的稳定 ID。 |
| `predicate` | 项目提供的类型化行谓词。 |
| `order` | 执行顺序；数值越小越早执行。 |
| `enabled` | 是否参与投影。 |

返回：新的注册值；调用方仍应检查 validate_registration()。

<a id="member-gftablerowpredicateregistration-methods-get_predicate_id"></a>

### `get_predicate_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_predicate_id() -> StringName:
```

获取稳定谓词 ID。

返回：稳定谓词 ID。

<a id="member-gftablerowpredicateregistration-methods-get_predicate"></a>

### `get_predicate`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_predicate() -> GFTableRowPredicate:
```

获取类型化谓词。

返回：注册的谓词。

<a id="member-gftablerowpredicateregistration-methods-get_order"></a>

### `get_order`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_order() -> int:
```

获取显式执行顺序。

返回：order；数值越小越早执行。

<a id="member-gftablerowpredicateregistration-methods-is_enabled"></a>

### `is_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_enabled() -> bool:
```

查询注册是否启用。

返回：启用时返回 true。

<a id="member-gftablerowpredicateregistration-methods-validate_registration"></a>

### `validate_registration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_registration() -> Dictionary:
```

校验注册定义。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, issues, counts, summary, and next_actions.
