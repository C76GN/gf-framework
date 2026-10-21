# Schema 声明

导表结构可以用 `GFConfigTableColumn` 和 `GFConfigTableSchema` 独立声明，再注册到 Provider 上做导入期或运行时校验。

它们描述字段类型、必填、空值、默认值、额外字段策略与校验规则，不规定项目业务字段。

```gdscript
var id_column := GFConfigTableColumn.new()
id_column.field_name = &"id"
id_column.value_type = GFConfigTableColumn.ValueType.INT
id_column.required = true
id_column.allow_null = false

var name_column := GFConfigTableColumn.new()
name_column.field_name = &"name"
name_column.value_type = GFConfigTableColumn.ValueType.STRING
name_column.required = true

var schema := GFConfigTableSchema.new()
schema.table_name = &"items"
schema.columns = [id_column, name_column]
schema.allow_extra_fields = false
schema.coerce_values = true
schema.fail_on_coerce_error = true
schema.require_unique_id = true

register_schema(schema)
var report := validate_table(&"items", get_table(&"items"))
```

字段校验、记录校验、表校验、JSON/CSV 导入报告见 [导入校验与规则](../validation-importer/index.md)。

## 结构化类型

`GFConfigTableColumn.type_definition` 可以引用 `GFConfigTypeDefinition`。非空时该定义决定字段的值形状，`value_type` 不再是第二份类型声明；字段的 `required`、`allow_null`、默认值和校验规则继续由 Column 管理。

定义资源可以保存在项目自己的 `.tres` 中，在多个字段间复用。导入规范化、校验、结构描述与 GDScript 访问器生成消费同一份定义：

| Kind | 声明 | 数据形状 |
| --- | --- | --- |
| `SCALAR` | `scalar_type` | 已有标量类型；不接受 ANY、Array 或 Dictionary |
| `STRUCT` | `fields`、可选 `base_type` | 字段明确的 Dictionary，拒绝未知字段 |
| `ARRAY` | `element_type` | 每个元素遵循同一类型的 Array |
| `MAP` | `map_key_type`、`map_value_type` | 键为 String、StringName 或 int 的 Dictionary |
| `ENUM` | `symbols` | 具名且数值唯一的整数枚举 |
| `POLYMORPHIC` | `discriminator`、`variants` | 判别字段选择一个具名 STRUCT |

例如，同一组效果可以包含不同的结构分支：

```gdscript
var amount: GFConfigTableColumn = GFConfigTableColumn.new()
amount.field_name = &"amount"
amount.value_type = GFConfigTableColumn.ValueType.INT
amount.required = true
amount.allow_null = false

var damage: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
damage.kind = GFConfigTypeDefinition.Kind.STRUCT
damage.type_name = &"Damage"
damage.fields = [amount]

var effect: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
effect.kind = GFConfigTypeDefinition.Kind.POLYMORPHIC
effect.type_name = &"Effect"
effect.discriminator = &"kind"
effect.variants = [damage]

var effects_type: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
effects_type.kind = GFConfigTypeDefinition.Kind.ARRAY
effects_type.element_type = effect

var effects: GFConfigTableColumn = GFConfigTableColumn.new()
effects.field_name = &"effects"
effects.type_definition = effects_type
effects.required = true
effects.allow_null = false
```

对应值为 `[{ "kind": "Damage", "amount": 12 }]`。增加分支时声明另一个具名 STRUCT 并加入 `variants`；不需要在表格读取器里增加分支。判别字段必须存在，且不能与结构字段重名。继承只允许 STRUCT，基类字段位于派生字段之前，不允许覆盖同名字段。

字段位置的空值由 Column 的 `allow_null` 决定；数组元素、映射值和独立类型调用使用类型自身的 `allow_null`。缺字段和显式 `null` 保持不同语义，默认值也必须通过同一类型及规则校验。枚举值必须是已声明的整数；开启转换时也接受表示这些整数的文本。枚举符号用于声明和生成常量，不作为输入值转换。映射键转换后发生碰撞会失败。

定义图允许共享子类型和有限层级嵌套，拒绝循环定义、循环数据、非法类型组合和超预算输入。所有遍历复用 `GFConfigWorkBudget`；同次表校验编译一次类型模型，再用于各行。错误同时保留逻辑 `field_path` 和 `field_segments`，布局提供物理来源时可定位到具体工作表与单元格。规范化失败不会返回部分成功值。

`compile_definition()` 和 `describe()` 返回带 `definition` 的报告；必须检查 `ok`。描述用于检查和文档，不是可重新导入的已验证凭据。结构化访问器要求真实 Schema/Column/TypeDefinition 资源，详见[访问器生成](../access-editor-tools.md)。

## Schema 副本语义

`register_schema()` 会保存 schema 副本。`get_schema()` 也返回副本，整值规则与 `element_validation_rules` 都随列复制；调用方修改返回值不会污染 Provider 内部校验规则。

这能避免编辑器工具、CI 校验或项目调试代码在读取 schema 后意外改动运行时 Provider 的正式规则。
