# GFBuffRecipe

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_buff_recipe.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

数据化 Buff 配方。 描述如何创建一个运行时 GFBuff，包括通用生命周期参数、属性修饰器、标签、检查和效果。 配方不包含具体战斗业务规则；项目可通过 GFBuffEffect / GFBuffCheck 子类扩展。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`id`](#member-gfbuffrecipe-properties-id) | `var id: StringName = &""` |
| 属性 | [`duration`](#member-gfbuffrecipe-properties-duration) | `var duration: float = 0.0` |
| 属性 | [`stacks`](#member-gfbuffrecipe-properties-stacks) | `var stacks: int = 1` |
| 属性 | [`max_stacks`](#member-gfbuffrecipe-properties-max_stacks) | `var max_stacks: int = 1` |
| 属性 | [`stack_mode`](#member-gfbuffrecipe-properties-stack_mode) | `var stack_mode: GFBuff.StackMode = GFBuff.StackMode.ADD_STACK` |
| 属性 | [`duration_refresh_policy`](#member-gfbuffrecipe-properties-duration_refresh_policy) | `var duration_refresh_policy: GFBuff.DurationRefreshPolicy = GFBuff.DurationRefreshPolicy.RESET_TO_NEW_DURATION` |
| 属性 | [`tick_interval_seconds`](#member-gfbuffrecipe-properties-tick_interval_seconds) | `var tick_interval_seconds: float = 0.0` |
| 属性 | [`max_periodic_ticks_per_update`](#member-gfbuffrecipe-properties-max_periodic_ticks_per_update) | `var max_periodic_ticks_per_update: int = 8` |
| 属性 | [`remove_on_expire`](#member-gfbuffrecipe-properties-remove_on_expire) | `var remove_on_expire: bool = true` |
| 属性 | [`buff_script`](#member-gfbuffrecipe-properties-buff_script) | `var buff_script: Script = null` |
| 属性 | [`tags`](#member-gfbuffrecipe-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`modifier_entries`](#member-gfbuffrecipe-properties-modifier_entries) | `var modifier_entries: Array[Dictionary] = []` |
| 属性 | [`checks`](#member-gfbuffrecipe-properties-checks) | `var checks: Array[GFBuffCheck] = []` |
| 属性 | [`effects`](#member-gfbuffrecipe-properties-effects) | `var effects: Array[GFBuffEffect] = []` |
| 属性 | [`metadata`](#member-gfbuffrecipe-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`create_buff`](#member-gfbuffrecipe-methods-create_buff) | `func create_buff(owner: Object = null, context: Dictionary = {}) -> GFBuff:` |
| 方法 | [`get_validation_report`](#member-gfbuffrecipe-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |
| 方法 | [`to_dictionary`](#member-gfbuffrecipe-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfbuffrecipe-properties-id"></a>

### `id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var id: StringName = &""
```

运行时 Buff ID。

<a id="member-gfbuffrecipe-properties-duration"></a>

### `duration`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var duration: float = 0.0
```

运行时 Buff 持续时间。-1 表示永久。

<a id="member-gfbuffrecipe-properties-stacks"></a>

### `stacks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var stacks: int = 1
```

初始层数。

<a id="member-gfbuffrecipe-properties-max_stacks"></a>

### `max_stacks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var max_stacks: int = 1
```

最大层数。

<a id="member-gfbuffrecipe-properties-stack_mode"></a>

### `stack_mode`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var stack_mode: GFBuff.StackMode = GFBuff.StackMode.ADD_STACK
```

重复添加时的层数策略。

<a id="member-gfbuffrecipe-properties-duration_refresh_policy"></a>

### `duration_refresh_policy`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var duration_refresh_policy: GFBuff.DurationRefreshPolicy = GFBuff.DurationRefreshPolicy.RESET_TO_NEW_DURATION
```

重复添加时的持续时间刷新策略。

<a id="member-gfbuffrecipe-properties-tick_interval_seconds"></a>

### `tick_interval_seconds`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var tick_interval_seconds: float = 0.0
```

周期 Tick 间隔。

<a id="member-gfbuffrecipe-properties-max_periodic_ticks_per_update"></a>

### `max_periodic_ticks_per_update`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var max_periodic_ticks_per_update: int = 8
```

单次 update 最多补偿 tick 次数。

<a id="member-gfbuffrecipe-properties-remove_on_expire"></a>

### `remove_on_expire`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var remove_on_expire: bool = true
```

持续时间耗尽时是否由 CombatSystem 移除。

<a id="member-gfbuffrecipe-properties-buff_script"></a>

### `buff_script`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var buff_script: Script = null
```

可选 Buff 脚本。为空时创建基础 GFBuff。

<a id="member-gfbuffrecipe-properties-tags"></a>

### `tags`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var tags: Array[StringName] = []
```

Buff 附带的标签。

<a id="member-gfbuffrecipe-properties-modifier_entries"></a>

### `modifier_entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var modifier_entries: Array[Dictionary] = []
```

Buff 附带的属性修饰器字典。

结构：

- `modifier_entries`: Array[Dictionary]，每项包含 type、value、attribute_id 和 source_id。

<a id="member-gfbuffrecipe-properties-checks"></a>

### `checks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var checks: Array[GFBuffCheck] = []
```

Buff 应用前检查。

<a id="member-gfbuffrecipe-properties-effects"></a>

### `effects`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var effects: Array[GFBuffEffect] = []
```

Buff 生命周期效果。

<a id="member-gfbuffrecipe-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释其中字段。

结构：

- `metadata`: Dictionary project-defined buff metadata.

## 方法

<a id="member-gfbuffrecipe-methods-create_buff"></a>

### `create_buff`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func create_buff(owner: Object = null, context: Dictionary = {}) -> GFBuff:
```

创建运行时 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | Buff 拥有者。 |
| `context` | 创建上下文。 |

返回：新 Buff；配方无效时仍返回基础 Buff，诊断可通过 get_validation_report() 获取。

结构：

- `context`: Dictionary，可包含 metadata 作为运行时附加元数据。

<a id="member-gfbuffrecipe-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取配方诊断报告。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, healthy, issues, summary, and next_action.

<a id="member-gfbuffrecipe-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为可序列化字典。

返回：配方字典。

结构：

- `return`: Dictionary with generic buff recipe fields.
