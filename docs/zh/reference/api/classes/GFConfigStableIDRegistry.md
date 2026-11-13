# GFConfigStableIDRegistry

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_stable_id_registry.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

项目所有的不可变稳定 ID 登记簿。 ID 由作者明确指定；本类型不自动分配、不修改来源表、不写文件。 每张表独立登记符号和正整数 ID；删除产生永久墓碑，符号及 ID 均不可复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create_empty`](#member-gfconfigstableidregistry-methods-create_empty) | `static func create_empty() -> GFConfigStableIDRegistry:` |
| 方法 | [`from_record`](#member-gfconfigstableidregistry-methods-from_record) | `static func from_record(record: Dictionary) -> GFConfigStableIDRegistry:` |
| 方法 | [`from_json`](#member-gfconfigstableidregistry-methods-from_json) | `static func from_json(text: String) -> GFConfigStableIDRegistry:` |
| 方法 | [`preview`](#member-gfconfigstableidregistry-methods-preview) | `func preview(assignments: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`with_assignments`](#member-gfconfigstableidregistry-methods-with_assignments) | `func with_assignments(assignments: Dictionary, options: Dictionary = {}) -> GFConfigStableIDRegistry:` |
| 方法 | [`get_id`](#member-gfconfigstableidregistry-methods-get_id) | `func get_id(table: String, symbol: String) -> int:` |
| 方法 | [`to_record`](#member-gfconfigstableidregistry-methods-to_record) | `func to_record() -> Dictionary:` |

## 方法

<a id="member-gfconfigstableidregistry-methods-create_empty"></a>

### `create_empty`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create_empty() -> GFConfigStableIDRegistry:
```

创建尚无登记的空簿。

返回：可用于首次显式登记的空簿。

<a id="member-gfconfigstableidregistry-methods-from_record"></a>

### `from_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_record(record: Dictionary) -> GFConfigStableIDRegistry:
```

验证完整历史记录；墓碑与活动条目共同占有 ID。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 登记簿纯数据。 |

返回：冻结登记簿；任何结构、重复 ID 或预算问题返回 null。

结构：

- `record`: 封闭 Dictionary，format:String="gf.config.stable_ids"、format_version:int=1、tables:Dictionary[String,Dictionary[String,Dictionary]]。table和symbol为1至256字符精确名称；条目仅含 id:String（1至2147483647的规范十进制文本）及 state:String（active/retired）。最多4096表、65536条目，总预算8MiB、262144节点、深度8；无循环、无原生对象。

<a id="member-gfconfigstableidregistry-methods-from_json"></a>

### `from_json`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_json(text: String) -> GFConfigStableIDRegistry:
```

从有界 JSON 文本读取登记簿；ID 使用文本避免 JSON 数值精度变化。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 最多8MiB的登记簿 JSON。 |

返回：完整验证的登记簿；失败返回 null。

<a id="member-gfconfigstableidregistry-methods-preview"></a>

### `preview`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func preview(assignments: Dictionary, options: Dictionary = {}) -> Dictionary:
```

只读比较当前作者映射；不分配 ID、不改变登记簿、不写入文件。

参数：

| 名称 | 说明 |
|---|---|
| `assignments` | 对账范围内完整的活动符号映射；范围内没有出现的历史活动符号列为待退役。 |
| `options` | 显式选择对账范围及允许恢复的原身份；省略时保留整簿对账和禁止恢复的行为。 |

返回：差异或错误；失败不交付部分变化。

结构：

- `assignments`: Dictionary[String,Dictionary[String,int]]，table到symbol到显式正整数ID；ID范围1至2147483647，每表唯一；名称与数量预算同from_record。局部范围中的整表退役必须显式提供该表的空字典。
- `options`: 封闭 Dictionary，可含 scope_tables:Array[String] 和 restorations:Dictionary[String,Dictionary[String,String]]。scope_tables为空时对账整簿；非空时最多4096个唯一精确表名，必须与assignments的表集合相同，范围外历史表保持不变。restorations以table/symbol到原ID的规范十进制String声明恢复，必须匹配历史记录及本次assignments中的int ID；已经active的同一声明幂等无变化。拒绝未知字段、其他身份、改号和非规范文本。
- `return`: 封闭 Dictionary，success:bool、changes:Array[Dictionary]、error:String。变化仅含 table:String、symbol:String、id:int、kind:String（register/retire/restore），按table和symbol排序；预览不会修改原登记簿。

<a id="member-gfconfigstableidregistry-methods-with_assignments"></a>

### `with_assignments`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func with_assignments(assignments: Dictionary, options: Dictionary = {}) -> GFConfigStableIDRegistry:
```

构造显式映射的下一代登记簿；调用者负责把它与产物放入同一文件事务。

参数：

| 名称 | 说明 |
|---|---|
| `assignments` | 对账范围内完整的活动符号映射。 |
| `options` | 对账表范围及原身份恢复声明；语义与 preview.options 相同。 |

返回：下一代冻结登记簿；范围不明确、身份不匹配、重复、改号或预算失败返回 null，原登记簿保持不变。

结构：

- `assignments`: 与 preview.assignments 相同的 Dictionary[String,Dictionary[String,int]]。
- `options`: 封闭 Dictionary，可含 scope_tables:Array[String] 和 restorations:Dictionary[String,Dictionary[String,String]]；恢复ID使用原登记簿的规范十进制文本，作者映射ID仍必须是int。省略时对账整簿且不允许恢复。

<a id="member-gfconfigstableidregistry-methods-get_id"></a>

### `get_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_id(table: String, symbol: String) -> int:
```

查询活动符号的稳定 ID。

参数：

| 名称 | 说明 |
|---|---|
| `table` | 表的登记命名空间。 |
| `symbol` | 作者符号。 |

返回：活动条目的正整数 ID；未登记、已退役或无效实例返回0。

<a id="member-gfconfigstableidregistry-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

获取完整历史的隔离副本。

返回：登记簿记录；非工厂实例返回空字典。

结构：

- `return`: 与 from_record.record 相同的封闭记录。
