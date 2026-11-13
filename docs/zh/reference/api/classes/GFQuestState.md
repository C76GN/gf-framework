# GFQuestState

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/quest/gf_quest_state.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

可验证、可持久化且不持有回调的任务状态快照。 冻结接取时的定义、接取信息和生命周期。查询型指标的缓存不能在恢复时充当新样本； GFQuestUtility 恢复后将其标记为不可用，直到项目显式刷新。已完成状态保持完成。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`from_record`](#member-gfqueststate-methods-from_record) | `static func from_record(record: Dictionary) -> GFQuestState:` |
| 方法 | [`to_record`](#member-gfqueststate-methods-to_record) | `func to_record() -> Dictionary:` |
| 方法 | [`get_definition`](#member-gfqueststate-methods-get_definition) | `func get_definition() -> GFQuestDefinition:` |
| 方法 | [`get_status`](#member-gfqueststate-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_current_count`](#member-gfqueststate-methods-get_current_count) | `func get_current_count() -> int:` |
| 方法 | [`is_metric_available`](#member-gfqueststate-methods-is_metric_available) | `func is_metric_available() -> bool:` |

## 方法

<a id="member-gfqueststate-methods-from_record"></a>

### `from_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_record(record: Dictionary) -> GFQuestState:
```

验证状态记录，不触发项目查询、任务事件或奖励。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 完整状态记录。 |

返回：冻结状态；不合法时为 null。

结构：

- `record`: 封闭九字段 Dictionary：definition:GFQuestDefinition记录、status:String（available/active/completed/cancelled/failed）、current_count:int、metric_available:bool、accepted:bool、acceptance_data:Dictionary、parent_id:String、failure_reason:String、format_version:int=1。acceptance_data为原生纯数据，深度16、2048节点、64KiB；记录总预算深度20、8192节点、256KiB。available必须未接取；active/completed必须已接取；非external的completed必须保存达标样本。父级存在性和环由Utility在整批恢复时验证。

<a id="member-gfqueststate-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

返回状态记录的隔离副本。

返回：验证后的状态；未通过工厂创建的实例返回空字典。

结构：

- `return`: 与 from_record.record 相同的封闭九字段 Dictionary。

<a id="member-gfqueststate-methods-get_definition"></a>

### `get_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_definition() -> GFQuestDefinition:
```

获取该状态绑定的冻结定义。

返回：冻结定义；未验证的实例为 null。

<a id="member-gfqueststate-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取生命周期。

返回：available、active、completed、cancelled 或 failed。

<a id="member-gfqueststate-methods-get_current_count"></a>

### `get_current_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_current_count() -> int:
```

获取已记录的指标值；查询型指标可能只是缓存。

返回：整数指标值。

<a id="member-gfqueststate-methods-is_metric_available"></a>

### `is_metric_available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_metric_available() -> bool:
```

区分可用于当前判断的样本与尚未刷新的缓存。

返回：导出状态时指标可用则为 true。
