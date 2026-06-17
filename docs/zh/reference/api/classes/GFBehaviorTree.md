# GFBehaviorTree

[API Reference](../index.md) / [Behavior Tree](../extensions-behavior-tree.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Object`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

轻量级、纯代码的行为树实现。 提供无需编辑器的、以代码方式构建 AI 或通用决策逻辑的轻量方案。 可以在任何 System 中通过 Runner 来驱动 tick()。核心节点包含 Sequence、Selector、Parallel、Action、Condition 以及常用装饰节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfbehaviortree-enums-status) | `enum Status` |
| 枚举 | [`ParallelPolicy`](#member-gfbehaviortree-enums-parallelpolicy) | `enum ParallelPolicy` |
| 方法 | [`status_to_string`](#member-gfbehaviortree-methods-status_to_string) | `static func status_to_string(status: int) -> StringName:` |
| 方法 | [`build_debug_snapshot`](#member-gfbehaviortree-methods-build_debug_snapshot) | `static func build_debug_snapshot(node: Variant) -> Dictionary:` |

## 枚举

<a id="member-gfbehaviortree-enums-status"></a>

### `Status`

- API：`public`

```gdscript
enum Status {
	## 节点尚未被 tick。
	FRESH = -1,
	## 节点本次执行成功。
	SUCCESS = 0,
	## 节点本次执行失败。
	FAILURE = 1,
	## 节点仍在运行，需要后续 tick 继续推进。
	RUNNING = 2,
	## 节点被外部中止。
	ABORTED = 3,
}
```

行为树节点的执行状态。

<a id="member-gfbehaviortree-enums-parallelpolicy"></a>

### `ParallelPolicy`

- API：`public`

```gdscript
enum ParallelPolicy {
	## 所有子节点成功才成功，任意子节点失败即失败。
	REQUIRE_ALL,
	## 任意子节点成功即成功，所有子节点失败才失败。
	REQUIRE_ONE,
}
```

Parallel 节点的完成策略。

## 方法

<a id="member-gfbehaviortree-methods-status_to_string"></a>

### `status_to_string`

- API：`public`

```gdscript
static func status_to_string(status: int) -> StringName:
```

将状态枚举转换为稳定文本。

参数：

| 名称 | 说明 |
|---|---|
| `status` | 行为树状态。 |

返回：状态文本。

<a id="member-gfbehaviortree-methods-build_debug_snapshot"></a>

### `build_debug_snapshot`

- API：`public`

```gdscript
static func build_debug_snapshot(node: Variant) -> Dictionary:
```

获取节点调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 行为树节点。 |

返回：调试快照字典。

结构：

- `node`: GFBehaviorTree.BTNode、null 或提供 get_debug_snapshot() 的对象。
- `return`: 包含节点调试状态的 Dictionary；null 节点返回空字典。

## 内部类概览

| 内部类 | 类别 | 继承 | 成员 |
|---|---|---|---:|
| [`GFBehaviorTree.Action`](#gfbehaviortreeaction) | 领域模型 (`domain_model`) | `BTNode` | 2 |
| [`GFBehaviorTree.AlwaysFail`](#gfbehaviortreealwaysfail) | 领域模型 (`domain_model`) | `Decorator` | 2 |
| [`GFBehaviorTree.AlwaysSucceed`](#gfbehaviortreealwayssucceed) | 领域模型 (`domain_model`) | `Decorator` | 2 |
| [`GFBehaviorTree.BTNode`](#gfbehaviortreebtnode) | 协议与扩展点 (`protocol`) | `RefCounted` | 13 |
| [`GFBehaviorTree.BlackboardScope`](#gfbehaviortreeblackboardscope) | 领域模型 (`domain_model`) | `RefCounted` | 6 |
| [`GFBehaviorTree.Condition`](#gfbehaviortreecondition) | 领域模型 (`domain_model`) | `BTNode` | 2 |
| [`GFBehaviorTree.Cooldown`](#gfbehaviortreecooldown) | 领域模型 (`domain_model`) | `Decorator` | 5 |
| [`GFBehaviorTree.Decorator`](#gfbehaviortreedecorator) | 协议与扩展点 (`protocol`) | `BTNode` | 3 |
| [`GFBehaviorTree.Inverter`](#gfbehaviortreeinverter) | 领域模型 (`domain_model`) | `Decorator` | 2 |
| [`GFBehaviorTree.Limit`](#gfbehaviortreelimit) | 领域模型 (`domain_model`) | `Decorator` | 4 |
| [`GFBehaviorTree.Parallel`](#gfbehaviortreeparallel) | 领域模型 (`domain_model`) | `BTNode` | 4 |
| [`GFBehaviorTree.Probability`](#gfbehaviortreeprobability) | 领域模型 (`domain_model`) | `Decorator` | 5 |
| [`GFBehaviorTree.RandomSelector`](#gfbehaviortreerandomselector) | 领域模型 (`domain_model`) | `BTNode` | 4 |
| [`GFBehaviorTree.RandomSequence`](#gfbehaviortreerandomsequence) | 领域模型 (`domain_model`) | `BTNode` | 4 |
| [`GFBehaviorTree.Repeat`](#gfbehaviortreerepeat) | 领域模型 (`domain_model`) | `Decorator` | 4 |
| [`GFBehaviorTree.Runner`](#gfbehaviortreerunner) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 6 |
| [`GFBehaviorTree.Selector`](#gfbehaviortreeselector) | 领域模型 (`domain_model`) | `BTNode` | 3 |
| [`GFBehaviorTree.Sequence`](#gfbehaviortreesequence) | 领域模型 (`domain_model`) | `BTNode` | 3 |
| [`GFBehaviorTree.TimeLimit`](#gfbehaviortreetimelimit) | 领域模型 (`domain_model`) | `Decorator` | 4 |
| [`GFBehaviorTree.UntilFail`](#gfbehaviortreeuntilfail) | 领域模型 (`domain_model`) | `Decorator` | 2 |
| [`GFBehaviorTree.UntilSuccess`](#gfbehaviortreeuntilsuccess) | 领域模型 (`domain_model`) | `Decorator` | 2 |

## 内部类详情

### GFBehaviorTree.Action

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

动作节点 (叶子节点)。 包装一个回调函数执行具体指令。回调需返回 Status 类型。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-action-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-action-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-action-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-action-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的动作节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.AlwaysFail

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

总是失败装饰节点。 子节点运行中时保持 RUNNING，子节点结束时统一返回 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-alwaysfail-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-alwaysfail-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-alwaysfail-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-alwaysfail-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的总是失败装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.AlwaysSucceed

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

总是成功装饰节点。 子节点运行中时保持 RUNNING，子节点结束时统一返回 SUCCESS。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-alwayssucceed-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-alwayssucceed-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-alwayssucceed-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-alwayssucceed-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的总是成功装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.BTNode

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

行为树所有节点的基类。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`name`](#member-gfbehaviortree-btnode-properties-name) | `var name: String = "BTNode"` |
| 属性 | [`node_id`](#member-gfbehaviortree-btnode-properties-node_id) | `var node_id: StringName = &""` |
| 属性 | [`last_status`](#member-gfbehaviortree-btnode-properties-last_status) | `var last_status: int = Status.FRESH` |
| 属性 | [`last_reason`](#member-gfbehaviortree-btnode-properties-last_reason) | `var last_reason: StringName = &""` |
| 属性 | [`tick_count`](#member-gfbehaviortree-btnode-properties-tick_count) | `var tick_count: int = 0` |
| 属性 | [`last_tick_usec`](#member-gfbehaviortree-btnode-properties-last_tick_usec) | `var last_tick_usec: int = 0` |
| 属性 | [`metadata`](#member-gfbehaviortree-btnode-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`tick`](#member-gfbehaviortree-btnode-methods-tick) | `func tick(_blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-btnode-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-btnode-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |
| 方法 | [`clear_debug_state`](#member-gfbehaviortree-btnode-methods-clear_debug_state) | `func clear_debug_state(recursive: bool = true) -> void:` |
| 方法 | [`record_status`](#member-gfbehaviortree-btnode-methods-record_status) | `func record_status(status: int, reason: StringName = &"", elapsed_usec: int = 0) -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfbehaviortree-btnode-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

#### 属性

<a id="member-gfbehaviortree-btnode-properties-name"></a>

##### `name`

- API：`public`

```gdscript
var name: String = "BTNode"
```

节点名称，用于调试。

<a id="member-gfbehaviortree-btnode-properties-node_id"></a>

##### `node_id`

- API：`public`

```gdscript
var node_id: StringName = &""
```

可选稳定节点标识。

<a id="member-gfbehaviortree-btnode-properties-last_status"></a>

##### `last_status`

- API：`public`

```gdscript
var last_status: int = Status.FRESH
```

最近一次 tick 状态。

<a id="member-gfbehaviortree-btnode-properties-last_reason"></a>

##### `last_reason`

- API：`public`

```gdscript
var last_reason: StringName = &""
```

最近一次状态原因。

<a id="member-gfbehaviortree-btnode-properties-tick_count"></a>

##### `tick_count`

- API：`public`

```gdscript
var tick_count: int = 0
```

累计 tick 次数。

<a id="member-gfbehaviortree-btnode-properties-last_tick_usec"></a>

##### `last_tick_usec`

- API：`public`

```gdscript
var last_tick_usec: int = 0
```

最近一次 tick 耗时，单位微秒。

<a id="member-gfbehaviortree-btnode-properties-metadata"></a>

##### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: 项目自定义元数据 Dictionary；键和值由调用方维护。

#### 方法

<a id="member-gfbehaviortree-btnode-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(_blackboard: Dictionary) -> int:
```

执行该节点的逻辑。子类应重写此方法。

参数：

| 名称 | 说明 |
|---|---|
| `_blackboard` | 运行时共享的数据字典。 |

返回：返回 Status 枚举。

结构：

- `_blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-btnode-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置节点内部运行状态。

<a id="member-gfbehaviortree-btnode-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建一份可独立运行的节点副本，不复制调试计数和正在运行的内部状态。 自定义节点若持有运行态，应重写此方法并复制自身类型；默认返回自身， 以避免未知子类被错误降级为基础 BTNode。

返回：运行时副本。

<a id="member-gfbehaviortree-btnode-methods-clear_debug_state"></a>

##### `clear_debug_state`

- API：`public`

```gdscript
func clear_debug_state(recursive: bool = true) -> void:
```

清空节点调试状态。

参数：

| 名称 | 说明 |
|---|---|
| `recursive` | 是否同时清空子节点调试状态。 |

<a id="member-gfbehaviortree-btnode-methods-record_status"></a>

##### `record_status`

- API：`public`

```gdscript
func record_status(status: int, reason: StringName = &"", elapsed_usec: int = 0) -> int:
```

记录节点状态。

参数：

| 名称 | 说明 |
|---|---|
| `status` | 新状态。 |
| `reason` | 可选状态原因。 |
| `elapsed_usec` | 可选耗时。 |

返回：原状态值，便于子类直接 return。

<a id="member-gfbehaviortree-btnode-methods-get_debug_snapshot"></a>

##### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: 包含 node_id、name、status、status_text、reason、tick_count、last_tick_usec、child_count、children 和 metadata 字段的 Dictionary；children 为子节点快照数组。

### GFBehaviorTree.BlackboardScope

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

行为树黑板作用域。 支持父级回退和局部覆盖，可在项目层按需转换为 Dictionary 传给既有节点。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`values`](#member-gfbehaviortree-blackboardscope-properties-values) | `var values: Dictionary = {}` |
| 属性 | [`parent`](#member-gfbehaviortree-blackboardscope-properties-parent) | `var parent: BlackboardScope = null` |
| 方法 | [`set_value`](#member-gfbehaviortree-blackboardscope-methods-set_value) | `func set_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_value`](#member-gfbehaviortree-blackboardscope-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_value`](#member-gfbehaviortree-blackboardscope-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`to_dictionary`](#member-gfbehaviortree-blackboardscope-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

#### 属性

<a id="member-gfbehaviortree-blackboardscope-properties-values"></a>

##### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

当前作用域值。

结构：

- `values`: 当前作用域持有的黑板值 Dictionary；键通常为 StringName，值由项目自定义。

<a id="member-gfbehaviortree-blackboardscope-properties-parent"></a>

##### `parent`

- API：`public`

```gdscript
var parent: BlackboardScope = null
```

可选父级作用域。

#### 方法

<a id="member-gfbehaviortree-blackboardscope-methods-set_value"></a>

##### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> void:
```

设置作用域值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值标识。 |
| `value` | 值。 |

结构：

- `value`: 任意可存入黑板的项目值。

<a id="member-gfbehaviortree-blackboardscope-methods-get_value"></a>

##### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

获取作用域值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值标识。 |
| `default_value` | 缺失时返回的默认值。 |

返回：作用域值。

结构：

- `default_value`: 缺失时返回的任意项目值。
- `return`: 找到的黑板值，或传入的 default_value。

<a id="member-gfbehaviortree-blackboardscope-methods-has_value"></a>

##### `has_value`

- API：`public`

```gdscript
func has_value(key: StringName) -> bool:
```

检查作用域值是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 值标识。 |

返回：存在返回 true。

<a id="member-gfbehaviortree-blackboardscope-methods-to_dictionary"></a>

##### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为合并后的字典。

返回：黑板字典。

结构：

- `return`: 父级与当前作用域合并后的 Dictionary；当前作用域同名键覆盖父级键。

### GFBehaviorTree.Condition

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

条件检查节点 (叶子节点)。 包装一个返回布尔值的回调。true 为 SUCCESS，false 为 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-condition-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-condition-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-condition-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-condition-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的条件节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Cooldown

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

冷却装饰节点。 子节点结束后进入冷却期，冷却未结束时返回 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`cooldown_seconds`](#member-gfbehaviortree-cooldown-properties-cooldown_seconds) | `var cooldown_seconds: float = 0.0` |
| 方法 | [`tick`](#member-gfbehaviortree-cooldown-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-cooldown-methods-reset) | `func reset() -> void:` |
| 方法 | [`clear_cooldown`](#member-gfbehaviortree-cooldown-methods-clear_cooldown) | `func clear_cooldown() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-cooldown-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-cooldown-properties-cooldown_seconds"></a>

##### `cooldown_seconds`

- API：`public`

```gdscript
var cooldown_seconds: float = 0.0
```

冷却秒数。

#### 方法

<a id="member-gfbehaviortree-cooldown-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；可提供 time_msec: int，其余字段由项目自定义。

<a id="member-gfbehaviortree-cooldown-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置运行状态，保留已经开始的冷却。

<a id="member-gfbehaviortree-cooldown-methods-clear_cooldown"></a>

##### `clear_cooldown`

- API：`public`

```gdscript
func clear_cooldown() -> void:
```

清空冷却状态。

<a id="member-gfbehaviortree-cooldown-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的冷却装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Decorator

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

单子节点装饰器基类。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_child`](#member-gfbehaviortree-decorator-methods-set_child) | `func set_child(child_node: BTNode) -> Decorator:` |
| 方法 | [`reset`](#member-gfbehaviortree-decorator-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-decorator-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-decorator-methods-set_child"></a>

##### `set_child`

- API：`public`

```gdscript
func set_child(child_node: BTNode) -> Decorator:
```

设置被装饰的子节点。

参数：

| 名称 | 说明 |
|---|---|
| `child_node` | 子节点。 |

返回：当前装饰器。

<a id="member-gfbehaviortree-decorator-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置子节点状态。

<a id="member-gfbehaviortree-decorator-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的装饰器副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Inverter

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

反转装饰节点。 翻转子节点的成功与失败状态。RUNNING 状态保持不变。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-inverter-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-inverter-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-inverter-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-inverter-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的反转装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Limit

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

次数限制装饰节点。 子节点最多被 tick 指定次数；超过次数后返回 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_ticks`](#member-gfbehaviortree-limit-properties-max_ticks) | `var max_ticks: int = 1` |
| 方法 | [`tick`](#member-gfbehaviortree-limit-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-limit-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-limit-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-limit-properties-max_ticks"></a>

##### `max_ticks`

- API：`public`

```gdscript
var max_ticks: int = 1
```

最大允许 tick 次数。

#### 方法

<a id="member-gfbehaviortree-limit-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-limit-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置调用计数与子节点状态。

<a id="member-gfbehaviortree-limit-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的次数限制装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Parallel

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

并行节点。 每次 tick 推进全部子节点，并根据 ParallelPolicy 汇总状态。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`policy`](#member-gfbehaviortree-parallel-properties-policy) | `var policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL` |
| 方法 | [`tick`](#member-gfbehaviortree-parallel-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-parallel-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-parallel-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-parallel-properties-policy"></a>

##### `policy`

- API：`public`

```gdscript
var policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL
```

并行节点完成策略。

#### 方法

<a id="member-gfbehaviortree-parallel-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-parallel-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置所有子节点状态。

<a id="member-gfbehaviortree-parallel-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的并行节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Probability

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

概率装饰节点。 每轮按 probability 判定是否允许子节点执行，未命中时返回 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`probability`](#member-gfbehaviortree-probability-properties-probability) | `var probability: float = 1.0` |
| 属性 | [`rng`](#member-gfbehaviortree-probability-properties-rng) | `var rng: RandomNumberGenerator = null` |
| 方法 | [`tick`](#member-gfbehaviortree-probability-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-probability-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-probability-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-probability-properties-probability"></a>

##### `probability`

- API：`public`

```gdscript
var probability: float = 1.0
```

执行概率，范围 0.0 到 1.0。

<a id="member-gfbehaviortree-probability-properties-rng"></a>

##### `rng`

- API：`public`

```gdscript
var rng: RandomNumberGenerator = null
```

可选随机源；为空时优先使用 blackboard["rng"]。

#### 方法

<a id="member-gfbehaviortree-probability-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。

<a id="member-gfbehaviortree-probability-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置当前概率轮次与子节点状态。

<a id="member-gfbehaviortree-probability-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的概率装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.RandomSelector

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

随机选择节点。 与 Selector 语义一致，但每轮从随机顺序尝试子节点。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`rng`](#member-gfbehaviortree-randomselector-properties-rng) | `var rng: RandomNumberGenerator = null` |
| 方法 | [`tick`](#member-gfbehaviortree-randomselector-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-randomselector-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-randomselector-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-randomselector-properties-rng"></a>

##### `rng`

- API：`public`

```gdscript
var rng: RandomNumberGenerator = null
```

可选随机源；为空时优先使用 blackboard["rng"]，否则退回全局随机。

#### 方法

<a id="member-gfbehaviortree-randomselector-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。

<a id="member-gfbehaviortree-randomselector-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置当前随机轮次与子节点状态。

<a id="member-gfbehaviortree-randomselector-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的随机选择节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.RandomSequence

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

随机顺序节点。 与 Sequence 语义一致，但每轮从随机顺序尝试子节点。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`rng`](#member-gfbehaviortree-randomsequence-properties-rng) | `var rng: RandomNumberGenerator = null` |
| 方法 | [`tick`](#member-gfbehaviortree-randomsequence-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-randomsequence-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-randomsequence-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-randomsequence-properties-rng"></a>

##### `rng`

- API：`public`

```gdscript
var rng: RandomNumberGenerator = null
```

可选随机源；为空时优先使用 blackboard["rng"]，否则退回全局随机。

#### 方法

<a id="member-gfbehaviortree-randomsequence-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。

<a id="member-gfbehaviortree-randomsequence-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置当前随机轮次与子节点状态。

<a id="member-gfbehaviortree-randomsequence-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的随机顺序节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Repeat

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

重复装饰节点。 子节点成功后重复执行，达到 repeat_count 后返回 SUCCESS；repeat_count 为 0 表示无限重复。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`repeat_count`](#member-gfbehaviortree-repeat-properties-repeat_count) | `var repeat_count: int = 1` |
| 方法 | [`tick`](#member-gfbehaviortree-repeat-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-repeat-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-repeat-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-repeat-properties-repeat_count"></a>

##### `repeat_count`

- API：`public`

```gdscript
var repeat_count: int = 1
```

成功重复次数；0 表示无限重复。

#### 方法

<a id="member-gfbehaviortree-repeat-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-repeat-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置重复计数与子节点状态。

<a id="member-gfbehaviortree-repeat-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的重复装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Runner

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

行为树的执行入口容器。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`blackboard`](#member-gfbehaviortree-runner-properties-blackboard) | `var blackboard: Dictionary = {}` |
| 属性 | [`duplicates_runtime_tree`](#member-gfbehaviortree-runner-properties-duplicates_runtime_tree) | `var duplicates_runtime_tree: bool = true` |
| 方法 | [`tick`](#member-gfbehaviortree-runner-methods-tick) | `func tick() -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-runner-methods-reset) | `func reset() -> void:` |
| 方法 | [`clear_debug_state`](#member-gfbehaviortree-runner-methods-clear_debug_state) | `func clear_debug_state() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfbehaviortree-runner-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

#### 属性

<a id="member-gfbehaviortree-runner-properties-blackboard"></a>

##### `blackboard`

- API：`public`

```gdscript
var blackboard: Dictionary = {}
```

运行时共享黑板。

结构：

- `blackboard`: 传给根节点 tick() 的共享 Dictionary；键和值由项目自定义。

<a id="member-gfbehaviortree-runner-properties-duplicates_runtime_tree"></a>

##### `duplicates_runtime_tree`

- API：`public`

```gdscript
var duplicates_runtime_tree: bool = true
```

是否在构造运行器时复制内置节点运行态，避免多个 Runner 共享同一棵树的进度。

#### 方法

<a id="member-gfbehaviortree-runner-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick() -> int:
```

驱动行为树运行逻辑。 通常在 GFSystem 的 tick 中被调用。

返回：返回根节点 Status 枚举。

<a id="member-gfbehaviortree-runner-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置整棵行为树的运行状态。

<a id="member-gfbehaviortree-runner-methods-clear_debug_state"></a>

##### `clear_debug_state`

- API：`public`

```gdscript
func clear_debug_state() -> void:
```

清空整棵行为树的调试状态。

<a id="member-gfbehaviortree-runner-methods-get_debug_snapshot"></a>

##### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取运行器调试快照。

返回：调试快照字典。

结构：

- `return`: 包含 root 和 blackboard_keys 字段的 Dictionary；root 为根节点调试快照，blackboard_keys 为排序后的黑板键列表。

### GFBehaviorTree.Selector

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

选择节点 (OR 逻辑)。 依次执行子节点，直到有一个子节点返回 SUCCESS 或 RUNNING，否则返回 FAILURE。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-selector-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-selector-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-selector-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-selector-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-selector-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置当前子节点索引与所有子节点状态。

<a id="member-gfbehaviortree-selector-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的选择节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.Sequence

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`BTNode`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

顺序节点 (AND 逻辑)。 依次执行子节点，只有全部成功才返回 SUCCESS。遇到 RUNNING 或 FAILURE 则中断并返回对应状态。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-sequence-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-sequence-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-sequence-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-sequence-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-sequence-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置当前子节点索引与所有子节点状态。

<a id="member-gfbehaviortree-sequence-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的顺序节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.TimeLimit

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

时间限制装饰节点。 子节点 RUNNING 持续超过限制时返回 FAILURE 并重置子节点。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`limit_seconds`](#member-gfbehaviortree-timelimit-properties-limit_seconds) | `var limit_seconds: float = 1.0` |
| 方法 | [`tick`](#member-gfbehaviortree-timelimit-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`reset`](#member-gfbehaviortree-timelimit-methods-reset) | `func reset() -> void:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-timelimit-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 属性

<a id="member-gfbehaviortree-timelimit-properties-limit_seconds"></a>

##### `limit_seconds`

- API：`public`

```gdscript
var limit_seconds: float = 1.0
```

最大运行秒数。

#### 方法

<a id="member-gfbehaviortree-timelimit-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；可提供 time_msec: int，其余字段由项目自定义。

<a id="member-gfbehaviortree-timelimit-methods-reset"></a>

##### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置计时状态。

<a id="member-gfbehaviortree-timelimit-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的时间限制装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.UntilFail

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

直到失败装饰节点。 子节点成功时继续返回 RUNNING，直到子节点失败。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-untilfail-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-untilfail-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-untilfail-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-untilfail-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的直到失败装饰节点副本。

返回：复制后的运行时节点。

### GFBehaviorTree.UntilSuccess

- 路径：`addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd`
- 模块：`Behavior Tree`
- 继承：`Decorator`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

直到成功装饰节点。 子节点失败时继续返回 RUNNING，直到子节点成功。

#### 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`tick`](#member-gfbehaviortree-untilsuccess-methods-tick) | `func tick(blackboard: Dictionary) -> int:` |
| 方法 | [`duplicate_runtime`](#member-gfbehaviortree-untilsuccess-methods-duplicate_runtime) | `func duplicate_runtime() -> BTNode:` |

#### 方法

<a id="member-gfbehaviortree-untilsuccess-methods-tick"></a>

##### `tick`

- API：`public`

```gdscript
func tick(blackboard: Dictionary) -> int:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `blackboard` | 行为树本次 tick 使用的黑板数据。 |

返回：返回 Status 枚举。

结构：

- `blackboard`: Dictionary 形式黑板；字段由项目自定义。

<a id="member-gfbehaviortree-untilsuccess-methods-duplicate_runtime"></a>

##### `duplicate_runtime`

- API：`public`

```gdscript
func duplicate_runtime() -> BTNode:
```

创建可独立运行的直到成功装饰节点副本。

返回：复制后的运行时节点。
