# GFQuestDefinition

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/quest/gf_quest_definition.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

独立于运行状态的冻结任务定义。 指标由项目查询或输入提供；完成策略与指标模式独立。接取条件和完成阻塞器是 GFQuestUtility 中的运行时回调，不进入可持久化定义。自动完成不发放业务奖励。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`HISTORY`](#member-gfquestdefinition-constants-history) | `const HISTORY: StringName = &"history"` |
| 常量 | [`SINCE_ACCEPTANCE`](#member-gfquestdefinition-constants-since_acceptance) | `const SINCE_ACCEPTANCE: StringName = &"since_acceptance"` |
| 常量 | [`CURRENT`](#member-gfquestdefinition-constants-current) | `const CURRENT: StringName = &"current"` |
| 常量 | [`AUTOMATIC`](#member-gfquestdefinition-constants-automatic) | `const AUTOMATIC: StringName = &"automatic"` |
| 常量 | [`MANUAL`](#member-gfquestdefinition-constants-manual) | `const MANUAL: StringName = &"manual"` |
| 常量 | [`EXTERNAL`](#member-gfquestdefinition-constants-external) | `const EXTERNAL: StringName = &"external"` |
| 方法 | [`create`](#member-gfquestdefinition-methods-create) | `static func create( quest_id: StringName, metric_id: StringName, options: Dictionary = {} ) -> GFQuestDefinition:` |
| 方法 | [`validate_create`](#member-gfquestdefinition-methods-validate_create) | `static func validate_create( quest_id: StringName, metric_id: StringName, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`from_record`](#member-gfquestdefinition-methods-from_record) | `static func from_record(record: Dictionary) -> GFQuestDefinition:` |
| 方法 | [`to_record`](#member-gfquestdefinition-methods-to_record) | `func to_record() -> Dictionary:` |
| 方法 | [`get_quest_id`](#member-gfquestdefinition-methods-get_quest_id) | `func get_quest_id() -> StringName:` |
| 方法 | [`get_metric_id`](#member-gfquestdefinition-methods-get_metric_id) | `func get_metric_id() -> StringName:` |
| 方法 | [`get_version`](#member-gfquestdefinition-methods-get_version) | `func get_version() -> int:` |
| 方法 | [`get_mode`](#member-gfquestdefinition-methods-get_mode) | `func get_mode() -> StringName:` |
| 方法 | [`get_target`](#member-gfquestdefinition-methods-get_target) | `func get_target() -> int:` |
| 方法 | [`get_completion`](#member-gfquestdefinition-methods-get_completion) | `func get_completion() -> StringName:` |
| 方法 | [`allows_negative`](#member-gfquestdefinition-methods-allows_negative) | `func allows_negative() -> bool:` |

## 常量

<a id="member-gfquestdefinition-constants-history"></a>

### `HISTORY`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const HISTORY: StringName = &"history"
```

查询项目已经积累的历史事实。

<a id="member-gfquestdefinition-constants-since_acceptance"></a>

### `SINCE_ACCEPTANCE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const SINCE_ACCEPTANCE: StringName = &"since_acceptance"
```

只累计接取后收到的明确整数增量。

<a id="member-gfquestdefinition-constants-current"></a>

### `CURRENT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const CURRENT: StringName = &"current"
```

查询会升降的当前值；默认需要显式确认完成。

<a id="member-gfquestdefinition-constants-automatic"></a>

### `AUTOMATIC`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const AUTOMATIC: StringName = &"automatic"
```

首次达标且完成阻塞器通过时完成。

<a id="member-gfquestdefinition-constants-manual"></a>

### `MANUAL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MANUAL: StringName = &"manual"
```

达标后由 complete_quest 显式确认。

<a id="member-gfquestdefinition-constants-external"></a>

### `EXTERNAL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const EXTERNAL: StringName = &"external"
```

项目显式判定完成，只检查完成阻塞器，不要求计数达标。

## 方法

<a id="member-gfquestdefinition-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( quest_id: StringName, metric_id: StringName, options: Dictionary = {} ) -> GFQuestDefinition:
```

创建定义；相同 ID 的已接取任务不受随后发布的新版本影响。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 非空任务身份，最多 256 字符且不得带首尾空白。 |
| `metric_id` | 指标或增量事件身份；external 策略可为空。 |
| `options` | 定义政策。 |

返回：冻结定义；非法输入返回 null。

结构：

- `options`: 封闭 Dictionary，可选 version:int>=1（默认1）、mode:String（history/since_acceptance/current，默认since_acceptance）、target:int>=0（默认1）、completion:String（automatic/manual/external）、allow_negative:bool（默认false）、metadata:Dictionary。current 默认manual，其他默认automatic。metadata 为有界原生纯数据，深度16、2048节点、64KiB。

<a id="member-gfquestdefinition-methods-validate_create"></a>

### `validate_create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func validate_create( quest_id: StringName, metric_id: StringName, options: Dictionary = {} ) -> Dictionary:
```

只读检查 create 的输入，返回首个拒绝原因；不创建任务定义或保留输入引用。 create 每次独立重新校验，旧报告不能授权后来修改的输入。

参数：

| 名称 | 说明 |
|---|---|
| `quest_id` | 与 create 相同的任务身份。 |
| `metric_id` | 与 create 相同的指标身份。 |
| `options` | 与 create 相同的定义政策。 |

返回：当前输入的独立校验报告；不输出错误日志。

结构：

- `options`: 与 create.options 相同的封闭 Dictionary。
- `return`: 封闭基础字段 ok:bool、error_kind:String、path:String；成功时后两项为空。容量错误可含 limit:int、observed:int；纯数据错误另含 measurement:Dictionary、limits:Dictionary，并可含 limit_kind:String、observed_is_lower_bound:bool。path 为从输入参数名开始的 / 分段路径，~ 和 / 分别转义为 ~0 和 ~1；空路径指当前服务。observed_is_lower_bound=true 时 observed 只是确定下界，measurement 失败计数只描述已遍历前缀。报告不含对象或可复用准入令牌。

<a id="member-gfquestdefinition-methods-from_record"></a>

### `from_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_record(record: Dictionary) -> GFQuestDefinition:
```

从持久化记录恢复并完整验证定义。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 完整定义记录。 |

返回：验证后的定义；失败返回 null。

结构：

- `record`: 必须且只能包含 quest_id:String、metric_id:String 和 create.options 的六个字段；不进行宽容转换。

<a id="member-gfquestdefinition-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

返回可持久化定义的隔离副本。

返回：定义记录；未经工厂验证的实例为空。

结构：

- `return`: 与 from_record.record 相同的八字段 Dictionary。

<a id="member-gfquestdefinition-methods-get_quest_id"></a>

### `get_quest_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_quest_id() -> StringName:
```

获取任务身份。

返回：任务 ID；未验证实例为空。

<a id="member-gfquestdefinition-methods-get_metric_id"></a>

### `get_metric_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metric_id() -> StringName:
```

获取指标身份。

返回：指标 ID。

<a id="member-gfquestdefinition-methods-get_version"></a>

### `get_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_version() -> int:
```

获取定义版本。

返回：正整数版本；未验证实例为0。

<a id="member-gfquestdefinition-methods-get_mode"></a>

### `get_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_mode() -> StringName:
```

获取指标模式。

返回：HISTORY、SINCE_ACCEPTANCE 或 CURRENT。

<a id="member-gfquestdefinition-methods-get_target"></a>

### `get_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target() -> int:
```

获取目标计数。

返回：非负目标。

<a id="member-gfquestdefinition-methods-get_completion"></a>

### `get_completion`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_completion() -> StringName:
```

获取完成策略。

返回：AUTOMATIC、MANUAL 或 EXTERNAL。

<a id="member-gfquestdefinition-methods-allows_negative"></a>

### `allows_negative`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func allows_negative() -> bool:
```

查询是否显式允许负向输入。

返回：允许负数指标或增量时为 true。
