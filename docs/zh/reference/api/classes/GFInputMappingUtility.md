# GFInputMappingUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_input_mapping_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

资源化输入上下文与动作映射运行时。 负责把 Godot InputEvent 转换为项目定义的抽象动作状态，并支持上下文优先级、 运行时重绑定、动作值查询和一次性触发消费。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`contexts_changed`](#member-gfinputmappingutility-signals-contexts_changed) | `signal contexts_changed(contexts: Array[GFInputContext])` |
| 信号 | [`mappings_changed`](#member-gfinputmappingutility-signals-mappings_changed) | `signal mappings_changed` |
| 信号 | [`action_value_changed`](#member-gfinputmappingutility-signals-action_value_changed) | `signal action_value_changed(action_id: StringName, value: Variant)` |
| 信号 | [`action_started`](#member-gfinputmappingutility-signals-action_started) | `signal action_started(action_id: StringName, value: Variant)` |
| 信号 | [`action_triggered`](#member-gfinputmappingutility-signals-action_triggered) | `signal action_triggered(action_id: StringName, value: Variant)` |
| 信号 | [`action_completed`](#member-gfinputmappingutility-signals-action_completed) | `signal action_completed(action_id: StringName, value: Variant)` |
| 信号 | [`player_action_value_changed`](#member-gfinputmappingutility-signals-player_action_value_changed) | `signal player_action_value_changed(player_index: int, action_id: StringName, value: Variant)` |
| 信号 | [`player_action_started`](#member-gfinputmappingutility-signals-player_action_started) | `signal player_action_started(player_index: int, action_id: StringName, value: Variant)` |
| 信号 | [`player_action_triggered`](#member-gfinputmappingutility-signals-player_action_triggered) | `signal player_action_triggered(player_index: int, action_id: StringName, value: Variant)` |
| 信号 | [`player_action_completed`](#member-gfinputmappingutility-signals-player_action_completed) | `signal player_action_completed(player_index: int, action_id: StringName, value: Variant)` |
| 方法 | [`init`](#member-gfinputmappingutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfinputmappingutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfinputmappingutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`set_remap_config`](#member-gfinputmappingutility-methods-set_remap_config) | `func set_remap_config(config: GFInputRemapConfig) -> void:` |
| 方法 | [`get_remap_config`](#member-gfinputmappingutility-methods-get_remap_config) | `func get_remap_config(create_if_missing: bool = false) -> GFInputRemapConfig:` |
| 方法 | [`enable_context`](#member-gfinputmappingutility-methods-enable_context) | `func enable_context(context: GFInputContext, priority: int = 0) -> void:` |
| 方法 | [`disable_context`](#member-gfinputmappingutility-methods-disable_context) | `func disable_context(context: GFInputContext) -> void:` |
| 方法 | [`set_enabled_contexts`](#member-gfinputmappingutility-methods-set_enabled_contexts) | `func set_enabled_contexts(contexts: Array[GFInputContext], priority: int = 0) -> void:` |
| 方法 | [`clear_contexts`](#member-gfinputmappingutility-methods-clear_contexts) | `func clear_contexts() -> void:` |
| 方法 | [`is_context_enabled`](#member-gfinputmappingutility-methods-is_context_enabled) | `func is_context_enabled(context: GFInputContext) -> bool:` |
| 方法 | [`get_enabled_contexts`](#member-gfinputmappingutility-methods-get_enabled_contexts) | `func get_enabled_contexts() -> Array[GFInputContext]:` |
| 方法 | [`handle_input_event`](#member-gfinputmappingutility-methods-handle_input_event) | `func handle_input_event(event: InputEvent) -> void:` |
| 方法 | [`create_virtual_source`](#member-gfinputmappingutility-methods-create_virtual_source) | `func create_virtual_source( source_id: StringName = &"virtual", player_index: int = -1 ) -> GFVirtualInputSource:` |
| 方法 | [`set_virtual_action_value`](#member-gfinputmappingutility-methods-set_virtual_action_value) | `func set_virtual_action_value( action_id: StringName, value: Variant, source_id: StringName = &"virtual", player_index: int = -1 ) -> bool:` |
| 方法 | [`clear_virtual_action`](#member-gfinputmappingutility-methods-clear_virtual_action) | `func clear_virtual_action( action_id: StringName, source_id: StringName = &"virtual", player_index: int = -1 ) -> bool:` |
| 方法 | [`clear_virtual_source`](#member-gfinputmappingutility-methods-clear_virtual_source) | `func clear_virtual_source(source_id: StringName = &"virtual") -> void:` |
| 方法 | [`get_virtual_source_snapshot`](#member-gfinputmappingutility-methods-get_virtual_source_snapshot) | `func get_virtual_source_snapshot(source_id: StringName = &"virtual") -> Dictionary:` |
| 方法 | [`get_action_value`](#member-gfinputmappingutility-methods-get_action_value) | `func get_action_value(action_id: StringName) -> Variant:` |
| 方法 | [`get_action_vector`](#member-gfinputmappingutility-methods-get_action_vector) | `func get_action_vector(action_id: StringName) -> Vector2:` |
| 方法 | [`get_action_vector3`](#member-gfinputmappingutility-methods-get_action_vector3) | `func get_action_vector3(action_id: StringName) -> Vector3:` |
| 方法 | [`is_action_active`](#member-gfinputmappingutility-methods-is_action_active) | `func is_action_active(action_id: StringName) -> bool:` |
| 方法 | [`was_action_just_started`](#member-gfinputmappingutility-methods-was_action_just_started) | `func was_action_just_started(action_id: StringName) -> bool:` |
| 方法 | [`was_action_just_completed`](#member-gfinputmappingutility-methods-was_action_just_completed) | `func was_action_just_completed(action_id: StringName) -> bool:` |
| 方法 | [`get_last_completed_duration`](#member-gfinputmappingutility-methods-get_last_completed_duration) | `func get_last_completed_duration(action_id: StringName) -> float:` |
| 方法 | [`consume_action`](#member-gfinputmappingutility-methods-consume_action) | `func consume_action(action_id: StringName) -> bool:` |
| 方法 | [`get_action_value_for_player`](#member-gfinputmappingutility-methods-get_action_value_for_player) | `func get_action_value_for_player(player_index: int, action_id: StringName) -> Variant:` |
| 方法 | [`get_action_vector_for_player`](#member-gfinputmappingutility-methods-get_action_vector_for_player) | `func get_action_vector_for_player(player_index: int, action_id: StringName) -> Vector2:` |
| 方法 | [`get_action_vector3_for_player`](#member-gfinputmappingutility-methods-get_action_vector3_for_player) | `func get_action_vector3_for_player(player_index: int, action_id: StringName) -> Vector3:` |
| 方法 | [`is_action_active_for_player`](#member-gfinputmappingutility-methods-is_action_active_for_player) | `func is_action_active_for_player(player_index: int, action_id: StringName) -> bool:` |
| 方法 | [`was_action_just_started_for_player`](#member-gfinputmappingutility-methods-was_action_just_started_for_player) | `func was_action_just_started_for_player(player_index: int, action_id: StringName) -> bool:` |
| 方法 | [`was_action_just_completed_for_player`](#member-gfinputmappingutility-methods-was_action_just_completed_for_player) | `func was_action_just_completed_for_player(player_index: int, action_id: StringName) -> bool:` |
| 方法 | [`get_last_completed_duration_for_player`](#member-gfinputmappingutility-methods-get_last_completed_duration_for_player) | `func get_last_completed_duration_for_player(player_index: int, action_id: StringName) -> float:` |
| 方法 | [`consume_action_for_player`](#member-gfinputmappingutility-methods-consume_action_for_player) | `func consume_action_for_player(player_index: int, action_id: StringName) -> bool:` |
| 方法 | [`set_binding_override`](#member-gfinputmappingutility-methods-set_binding_override) | `func set_binding_override( context_id: StringName, action_id: StringName, binding_index: int, input_event: InputEvent ) -> void:` |
| 方法 | [`unbind`](#member-gfinputmappingutility-methods-unbind) | `func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:` |
| 方法 | [`clear_binding_override`](#member-gfinputmappingutility-methods-clear_binding_override) | `func clear_binding_override(context_id: StringName, action_id: StringName, binding_index: int) -> void:` |
| 方法 | [`get_remappable_items`](#member-gfinputmappingutility-methods-get_remappable_items) | `func get_remappable_items( context_filter: StringName = &"", display_category_filter: String = "" ) -> Array[Dictionary]:` |
| 方法 | [`clear_input_state`](#member-gfinputmappingutility-methods-clear_input_state) | `func clear_input_state() -> void:` |
| 方法 | [`clear_player_input_state`](#member-gfinputmappingutility-methods-clear_player_input_state) | `func clear_player_input_state(player_index: int) -> void:` |

## 信号

<a id="member-gfinputmappingutility-signals-contexts_changed"></a>

### `contexts_changed`

- API：`public`

```gdscript
signal contexts_changed(contexts: Array[GFInputContext])
```

启用上下文变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 当前启用上下文，已按运行时处理顺序排序。 |

结构：

- `contexts`: Array[GFInputContext]，按有效优先级和激活时间戳排序。

<a id="member-gfinputmappingutility-signals-mappings_changed"></a>

### `mappings_changed`

- API：`public`

```gdscript
signal mappings_changed
```

有效映射变化后发出。

<a id="member-gfinputmappingutility-signals-action_value_changed"></a>

### `action_value_changed`

- API：`public`

```gdscript
signal action_value_changed(action_id: StringName, value: Variant)
```

动作值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 新动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-action_started"></a>

### `action_started`

- API：`public`

```gdscript
signal action_started(action_id: StringName, value: Variant)
```

动作从非活跃变为活跃时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 激活时的动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-action_triggered"></a>

### `action_triggered`

- API：`public`

```gdscript
signal action_triggered(action_id: StringName, value: Variant)
```

动作活跃且收到匹配输入事件时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 当前动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-action_completed"></a>

### `action_completed`

- API：`public`

```gdscript
signal action_completed(action_id: StringName, value: Variant)
```

动作从活跃变为非活跃时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 完成时的动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-player_action_value_changed"></a>

### `player_action_value_changed`

- API：`public`

```gdscript
signal player_action_value_changed(player_index: int, action_id: StringName, value: Variant)
```

玩家动作值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |
| `value` | 新动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-player_action_started"></a>

### `player_action_started`

- API：`public`

```gdscript
signal player_action_started(player_index: int, action_id: StringName, value: Variant)
```

玩家动作从非活跃变为活跃时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |
| `value` | 激活时的动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-player_action_triggered"></a>

### `player_action_triggered`

- API：`public`

```gdscript
signal player_action_triggered(player_index: int, action_id: StringName, value: Variant)
```

玩家动作活跃且收到匹配输入事件时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |
| `value` | 当前动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

<a id="member-gfinputmappingutility-signals-player_action_completed"></a>

### `player_action_completed`

- API：`public`

```gdscript
signal player_action_completed(player_index: int, action_id: StringName, value: Variant)
```

玩家动作从活跃变为非活跃时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |
| `value` | 完成时的动作值。 |

结构：

- `value`: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。

## 方法

<a id="member-gfinputmappingutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化输入映射运行时状态并挂载输入路由节点。

<a id="member-gfinputmappingutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放输入路由节点并清理全部运行时状态。

<a id="member-gfinputmappingutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfinputmappingutility-methods-set_remap_config"></a>

### `set_remap_config`

- API：`public`

```gdscript
func set_remap_config(config: GFInputRemapConfig) -> void:
```

设置重映射配置。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 输入重映射配置；传 null 表示使用默认绑定。 |

<a id="member-gfinputmappingutility-methods-get_remap_config"></a>

### `get_remap_config`

- API：`public`

```gdscript
func get_remap_config(create_if_missing: bool = false) -> GFInputRemapConfig:
```

获取当前重映射配置。若不存在且 create_if_missing 为 true，会自动创建。

参数：

| 名称 | 说明 |
|---|---|
| `create_if_missing` | 是否在缺失时创建。 |

返回：重映射配置。

<a id="member-gfinputmappingutility-methods-enable_context"></a>

### `enable_context`

- API：`public`

```gdscript
func enable_context(context: GFInputContext, priority: int = 0) -> void:
```

启用输入上下文。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文资源。 |
| `priority` | 优先级，数值越大越先处理。 |

<a id="member-gfinputmappingutility-methods-disable_context"></a>

### `disable_context`

- API：`public`

```gdscript
func disable_context(context: GFInputContext) -> void:
```

禁用输入上下文。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文资源。 |

<a id="member-gfinputmappingutility-methods-set_enabled_contexts"></a>

### `set_enabled_contexts`

- API：`public`

```gdscript
func set_enabled_contexts(contexts: Array[GFInputContext], priority: int = 0) -> void:
```

批量替换当前启用的上下文。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 输入上下文数组。 |
| `priority` | 批量上下文默认优先级；数组越靠后，同优先级下越先处理。 |

结构：

- `contexts`: Array[GFInputContext]，作为新的活跃 context 集启用。

<a id="member-gfinputmappingutility-methods-clear_contexts"></a>

### `clear_contexts`

- API：`public`

```gdscript
func clear_contexts() -> void:
```

清空所有启用上下文。

<a id="member-gfinputmappingutility-methods-is_context_enabled"></a>

### `is_context_enabled`

- API：`public`

```gdscript
func is_context_enabled(context: GFInputContext) -> bool:
```

检查上下文是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文资源。 |

返回：是否启用。

<a id="member-gfinputmappingutility-methods-get_enabled_contexts"></a>

### `get_enabled_contexts`

- API：`public`

```gdscript
func get_enabled_contexts() -> Array[GFInputContext]:
```

获取已启用上下文，按实际处理顺序返回。

返回：上下文数组。

结构：

- `return`: Array[GFInputContext]，按有效优先级和激活时间戳排序。

<a id="member-gfinputmappingutility-methods-handle_input_event"></a>

### `handle_input_event`

- API：`public`

```gdscript
func handle_input_event(event: InputEvent) -> void:
```

手动处理输入事件。通常由内部路由节点自动调用，也可用于测试或自定义输入桥接。

参数：

| 名称 | 说明 |
|---|---|
| `event` | Godot 输入事件。 |

<a id="member-gfinputmappingutility-methods-create_virtual_source"></a>

### `create_virtual_source`

- API：`public`

```gdscript
func create_virtual_source( source_id: StringName = &"virtual", player_index: int = -1 ) -> GFVirtualInputSource:
```

创建可编程虚拟输入源。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 虚拟输入源标识。 |
| `player_index` | 玩家索引；小于 0 时只写入全局动作状态。 |

返回：虚拟输入源。

<a id="member-gfinputmappingutility-methods-set_virtual_action_value"></a>

### `set_virtual_action_value`

- API：`public`

```gdscript
func set_virtual_action_value( action_id: StringName, value: Variant, source_id: StringName = &"virtual", player_index: int = -1 ) -> bool:
```

写入虚拟动作值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 动作值。 |
| `source_id` | 虚拟输入源标识。 |
| `player_index` | 玩家索引；小于 0 时只写入全局动作状态。 |

返回：写入成功返回 true。

结构：

- `value`: Variant，要转换为动作运行时向量贡献的 bool、float、Vector2 或 Vector3 值。

<a id="member-gfinputmappingutility-methods-clear_virtual_action"></a>

### `clear_virtual_action`

- API：`public`

```gdscript
func clear_virtual_action( action_id: StringName, source_id: StringName = &"virtual", player_index: int = -1 ) -> bool:
```

清除虚拟动作值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `source_id` | 虚拟输入源标识。 |
| `player_index` | 玩家索引；小于 0 时只清除全局动作状态。 |

返回：清除成功返回 true。

<a id="member-gfinputmappingutility-methods-clear_virtual_source"></a>

### `clear_virtual_source`

- API：`public`

```gdscript
func clear_virtual_source(source_id: StringName = &"virtual") -> void:
```

清除指定虚拟输入源的所有动作贡献。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 虚拟输入源标识。 |

<a id="member-gfinputmappingutility-methods-get_virtual_source_snapshot"></a>

### `get_virtual_source_snapshot`

- API：`public`

```gdscript
func get_virtual_source_snapshot(source_id: StringName = &"virtual") -> Dictionary:
```

获取虚拟输入源状态快照。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 虚拟输入源标识。 |

返回：快照字典。

结构：

- `return`: Dictionary，包含 source_id 和 actions: Array[Dictionary]，action 条目包含 action_id 与 value。

<a id="member-gfinputmappingutility-methods-get_action_value"></a>

### `get_action_value`

- API：`public`

```gdscript
func get_action_value(action_id: StringName) -> Variant:
```

获取动作当前值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：bool、float、Vector2 或 Vector3，取决于动作值类型。

结构：

- `return`: Variant，根据动作值类型返回 bool、float、Vector2、Vector3 或 null。

<a id="member-gfinputmappingutility-methods-get_action_vector"></a>

### `get_action_vector`

- API：`public`

```gdscript
func get_action_vector(action_id: StringName) -> Vector2:
```

获取动作当前二维向量值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：二维向量值；三维轴会返回 x/y 分量。

<a id="member-gfinputmappingutility-methods-get_action_vector3"></a>

### `get_action_vector3`

- API：`public`

```gdscript
func get_action_vector3(action_id: StringName) -> Vector3:
```

获取动作当前三维向量值。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：三维向量值；非三维动作的 z 分量为 0。

<a id="member-gfinputmappingutility-methods-is_action_active"></a>

### `is_action_active`

- API：`public`

```gdscript
func is_action_active(action_id: StringName) -> bool:
```

检查动作是否活跃。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：是否活跃。

<a id="member-gfinputmappingutility-methods-was_action_just_started"></a>

### `was_action_just_started`

- API：`public`

```gdscript
func was_action_just_started(action_id: StringName) -> bool:
```

检查动作是否在当前帧刚刚开始。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：是否刚开始。

<a id="member-gfinputmappingutility-methods-was_action_just_completed"></a>

### `was_action_just_completed`

- API：`public`

```gdscript
func was_action_just_completed(action_id: StringName) -> bool:
```

检查动作是否在当前帧刚刚结束。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：是否刚结束。

<a id="member-gfinputmappingutility-methods-get_last_completed_duration"></a>

### `get_last_completed_duration`

- API：`public`

```gdscript
func get_last_completed_duration(action_id: StringName) -> float:
```

获取动作最近一次结束前的持续活跃时间。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：持续秒数。

<a id="member-gfinputmappingutility-methods-consume_action"></a>

### `consume_action`

- API：`public`

```gdscript
func consume_action(action_id: StringName) -> bool:
```

消费一次刚开始的动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |

返回：成功消费返回 true。

<a id="member-gfinputmappingutility-methods-get_action_value_for_player"></a>

### `get_action_value_for_player`

- API：`public`

```gdscript
func get_action_value_for_player(player_index: int, action_id: StringName) -> Variant:
```

获取指定玩家动作当前值。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：bool、float、Vector2 或 Vector3，取决于动作值类型。

结构：

- `return`: Variant，根据动作值类型返回 bool、float、Vector2、Vector3 或 null。

<a id="member-gfinputmappingutility-methods-get_action_vector_for_player"></a>

### `get_action_vector_for_player`

- API：`public`

```gdscript
func get_action_vector_for_player(player_index: int, action_id: StringName) -> Vector2:
```

获取指定玩家动作当前二维向量值。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：二维向量值；三维轴会返回 x/y 分量。

<a id="member-gfinputmappingutility-methods-get_action_vector3_for_player"></a>

### `get_action_vector3_for_player`

- API：`public`

```gdscript
func get_action_vector3_for_player(player_index: int, action_id: StringName) -> Vector3:
```

获取指定玩家动作当前三维向量值。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：三维向量值；非三维动作的 z 分量为 0。

<a id="member-gfinputmappingutility-methods-is_action_active_for_player"></a>

### `is_action_active_for_player`

- API：`public`

```gdscript
func is_action_active_for_player(player_index: int, action_id: StringName) -> bool:
```

检查指定玩家动作是否活跃。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：是否活跃。

<a id="member-gfinputmappingutility-methods-was_action_just_started_for_player"></a>

### `was_action_just_started_for_player`

- API：`public`

```gdscript
func was_action_just_started_for_player(player_index: int, action_id: StringName) -> bool:
```

检查指定玩家动作是否在当前帧刚刚开始。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：是否刚开始。

<a id="member-gfinputmappingutility-methods-was_action_just_completed_for_player"></a>

### `was_action_just_completed_for_player`

- API：`public`

```gdscript
func was_action_just_completed_for_player(player_index: int, action_id: StringName) -> bool:
```

检查指定玩家动作是否在当前帧刚刚结束。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：是否刚结束。

<a id="member-gfinputmappingutility-methods-get_last_completed_duration_for_player"></a>

### `get_last_completed_duration_for_player`

- API：`public`

```gdscript
func get_last_completed_duration_for_player(player_index: int, action_id: StringName) -> float:
```

获取指定玩家动作最近一次结束前的持续活跃时间。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：持续秒数。

<a id="member-gfinputmappingutility-methods-consume_action_for_player"></a>

### `consume_action_for_player`

- API：`public`

```gdscript
func consume_action_for_player(player_index: int, action_id: StringName) -> bool:
```

消费指定玩家的一次刚开始动作。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `action_id` | 动作标识。 |

返回：成功消费返回 true。

<a id="member-gfinputmappingutility-methods-set_binding_override"></a>

### `set_binding_override`

- API：`public`

```gdscript
func set_binding_override( context_id: StringName, action_id: StringName, binding_index: int, input_event: InputEvent ) -> void:
```

设置某个绑定的运行时覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |
| `input_event` | 新输入事件。 |

<a id="member-gfinputmappingutility-methods-unbind"></a>

### `unbind`

- API：`public`

```gdscript
func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:
```

显式解绑某个绑定。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

<a id="member-gfinputmappingutility-methods-clear_binding_override"></a>

### `clear_binding_override`

- API：`public`

```gdscript
func clear_binding_override(context_id: StringName, action_id: StringName, binding_index: int) -> void:
```

清除某个绑定覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `context_id` | 上下文标识。 |
| `action_id` | 动作标识。 |
| `binding_index` | 绑定索引。 |

<a id="member-gfinputmappingutility-methods-get_remappable_items"></a>

### `get_remappable_items`

- API：`public`

```gdscript
func get_remappable_items( context_filter: StringName = &"", display_category_filter: String = "" ) -> Array[Dictionary]:
```

获取可重绑条目。

参数：

| 名称 | 说明 |
|---|---|
| `context_filter` | 可选上下文过滤。 |
| `display_category_filter` | 可选显示分类过滤。 |

返回：条目字典数组。

结构：

- `return`: Array[Dictionary]，包含 context、context_id、mapping、action、action_id、binding、binding_index、display_name、display_category 和 event 字段。

<a id="member-gfinputmappingutility-methods-clear_input_state"></a>

### `clear_input_state`

- API：`public`

```gdscript
func clear_input_state() -> void:
```

清空所有动作运行时状态。

<a id="member-gfinputmappingutility-methods-clear_player_input_state"></a>

### `clear_player_input_state`

- API：`public`

```gdscript
func clear_player_input_state(player_index: int) -> void:
```

清空指定玩家动作运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
