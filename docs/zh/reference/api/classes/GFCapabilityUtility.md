# GFCapabilityUtility

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/core/gf_capability_utility.gd`
- 模块：`Capability`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

对象能力组件管理器。 提供面向任意 Object / Node 的能力挂载、查询、移除、启停、索引查询与依赖补齐能力。 能力组合是可选扩展，不改变核心分层容器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`capability_added`](#member-gfcapabilityutility-signals-capability_added) | `signal capability_added(receiver: Object, capability_type: Script, capability: Object)` |
| 信号 | [`capability_removed`](#member-gfcapabilityutility-signals-capability_removed) | `signal capability_removed(receiver: Object, capability_type: Script, capability: Object)` |
| 信号 | [`capability_active_changed`](#member-gfcapabilityutility-signals-capability_active_changed) | `signal capability_active_changed(receiver: Object, capability_type: Script, capability: Object, active: bool)` |
| 枚举 | [`DependencyRemovalPolicy`](#member-gfcapabilityutility-enums-dependencyremovalpolicy) | `enum DependencyRemovalPolicy` |
| 常量 | [`HOOK_GET_REQUIRED_CAPABILITIES`](#member-gfcapabilityutility-constants-hook_get_required_capabilities) | `const HOOK_GET_REQUIRED_CAPABILITIES: StringName = &"get_required_capabilities"` |
| 常量 | [`HOOK_GET_DEPENDENCY_REMOVAL_POLICY`](#member-gfcapabilityutility-constants-hook_get_dependency_removal_policy) | `const HOOK_GET_DEPENDENCY_REMOVAL_POLICY: StringName = &"get_dependency_removal_policy"` |
| 常量 | [`HOOK_ON_ADDED`](#member-gfcapabilityutility-constants-hook_on_added) | `const HOOK_ON_ADDED: StringName = &"on_gf_capability_added"` |
| 常量 | [`HOOK_ON_REMOVED`](#member-gfcapabilityutility-constants-hook_on_removed) | `const HOOK_ON_REMOVED: StringName = &"on_gf_capability_removed"` |
| 常量 | [`HOOK_ON_ACTIVE_CHANGED`](#member-gfcapabilityutility-constants-hook_on_active_changed) | `const HOOK_ON_ACTIVE_CHANGED: StringName = &"on_gf_capability_active_changed"` |
| 属性 | [`prune_invalid_receivers_per_tick`](#member-gfcapabilityutility-properties-prune_invalid_receivers_per_tick) | `var prune_invalid_receivers_per_tick: int = 128:` |
| 方法 | [`init`](#member-gfcapabilityutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfcapabilityutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfcapabilityutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`has_capability`](#member-gfcapabilityutility-methods-has_capability) | `func has_capability(receiver: Object, capability_type: Script) -> bool:` |
| 方法 | [`get_capability`](#member-gfcapabilityutility-methods-get_capability) | `func get_capability(receiver: Object, capability_type: Script) -> Object:` |
| 方法 | [`get_capability_types`](#member-gfcapabilityutility-methods-get_capability_types) | `func get_capability_types(receiver: Object) -> Array[Script]:` |
| 方法 | [`get_receivers_with`](#member-gfcapabilityutility-methods-get_receivers_with) | `func get_receivers_with(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:` |
| 方法 | [`prune_invalid_receivers`](#member-gfcapabilityutility-methods-prune_invalid_receivers) | `func prune_invalid_receivers() -> void:` |
| 方法 | [`get_capabilities`](#member-gfcapabilityutility-methods-get_capabilities) | `func get_capabilities(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:` |
| 方法 | [`add_receiver_to_group`](#member-gfcapabilityutility-methods-add_receiver_to_group) | `func add_receiver_to_group(receiver: Object, group_name: StringName) -> void:` |
| 方法 | [`remove_receiver_from_group`](#member-gfcapabilityutility-methods-remove_receiver_from_group) | `func remove_receiver_from_group(receiver: Object, group_name: StringName) -> void:` |
| 方法 | [`get_receiver_groups`](#member-gfcapabilityutility-methods-get_receiver_groups) | `func get_receiver_groups(receiver: Object) -> Array[StringName]:` |
| 方法 | [`get_receivers_in_group`](#member-gfcapabilityutility-methods-get_receivers_in_group) | `func get_receivers_in_group(group_name: StringName) -> Array[Object]:` |
| 方法 | [`get_receivers_in_group_with`](#member-gfcapabilityutility-methods-get_receivers_in_group_with) | `func get_receivers_in_group_with( group_name: StringName, capability_type: Script, include_subclasses: bool = true ) -> Array[Object]:` |
| 方法 | [`add_capability`](#member-gfcapabilityutility-methods-add_capability) | `func add_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:` |
| 方法 | [`add_required_capability`](#member-gfcapabilityutility-methods-add_required_capability) | `func add_required_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:` |
| 方法 | [`add_capability_instance`](#member-gfcapabilityutility-methods-add_capability_instance) | `func add_capability_instance(receiver: Object, capability: Object, as_type: Script = null) -> Object:` |
| 方法 | [`add_scene_capability`](#member-gfcapabilityutility-methods-add_scene_capability) | `func add_scene_capability(receiver: Node, scene: PackedScene, as_type: Script = null) -> Object:` |
| 方法 | [`set_capability_active`](#member-gfcapabilityutility-methods-set_capability_active) | `func set_capability_active(receiver: Object, capability_type: Script, active: bool) -> void:` |
| 方法 | [`is_capability_active`](#member-gfcapabilityutility-methods-is_capability_active) | `func is_capability_active(receiver: Object, capability_type: Script) -> bool:` |
| 方法 | [`remove_capability`](#member-gfcapabilityutility-methods-remove_capability) | `func remove_capability(receiver: Object, capability_type: Script) -> void:` |
| 方法 | [`unregister_capability`](#member-gfcapabilityutility-methods-unregister_capability) | `func unregister_capability(receiver: Object, capability_type: Script) -> void:` |
| 方法 | [`clear_capabilities`](#member-gfcapabilityutility-methods-clear_capabilities) | `func clear_capabilities(receiver: Object) -> void:` |
| 方法 | [`clear_receiver_groups`](#member-gfcapabilityutility-methods-clear_receiver_groups) | `func clear_receiver_groups(receiver: Object) -> void:` |
| 方法 | [`apply_recipe`](#member-gfcapabilityutility-methods-apply_recipe) | `func apply_recipe(receiver: Object, recipe: GFCapabilityRecipe, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`remove_recipe`](#member-gfcapabilityutility-methods-remove_recipe) | `func remove_recipe(receiver: Object, recipe: GFCapabilityRecipe, remove_groups: bool = true) -> Dictionary:` |
| 方法 | [`validate_receiver_dependencies`](#member-gfcapabilityutility-methods-validate_receiver_dependencies) | `func validate_receiver_dependencies(receiver: Object) -> Dictionary:` |
| 方法 | [`inspect_receiver`](#member-gfcapabilityutility-methods-inspect_receiver) | `func inspect_receiver(receiver: Object) -> Dictionary:` |

## 信号

<a id="member-gfcapabilityutility-signals-capability_added"></a>

### `capability_added`

- API：`public`

```gdscript
signal capability_added(receiver: Object, capability_type: Script, capability: Object)
```

当能力成功挂载到对象后发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 实际注册的能力脚本类型。 |
| `capability` | 已挂载的能力实例。 |

<a id="member-gfcapabilityutility-signals-capability_removed"></a>

### `capability_removed`

- API：`public`

```gdscript
signal capability_removed(receiver: Object, capability_type: Script, capability: Object)
```

当能力从对象移除前发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 实际注册的能力脚本类型。 |
| `capability` | 将被移除的能力实例。 |

<a id="member-gfcapabilityutility-signals-capability_active_changed"></a>

### `capability_active_changed`

- API：`public`

```gdscript
signal capability_active_changed(receiver: Object, capability_type: Script, capability: Object, active: bool)
```

当能力启停状态变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 实际注册的能力脚本类型。 |
| `capability` | 状态变化的能力实例。 |
| `active` | 新的启用状态。 |

## 枚举

<a id="member-gfcapabilityutility-enums-dependencyremovalpolicy"></a>

### `DependencyRemovalPolicy`

- API：`public`

```gdscript
enum DependencyRemovalPolicy { ## 保留依赖能力，适合依赖能力需要在主能力移除后继续存在的场景。 KEEP_DEPENDENCIES, ## 移除仅由当前能力自动补齐且未被显式添加的依赖能力。 REMOVE_AUTO_DEPENDENCIES, }
```

移除能力时自动补齐依赖的清理策略。

## 常量

<a id="member-gfcapabilityutility-constants-hook_get_required_capabilities"></a>

### `HOOK_GET_REQUIRED_CAPABILITIES`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_CAPABILITIES: StringName = &"get_required_capabilities"
```

能力对象可选实现：返回运行时依赖的能力类型列表。

<a id="member-gfcapabilityutility-constants-hook_get_dependency_removal_policy"></a>

### `HOOK_GET_DEPENDENCY_REMOVAL_POLICY`

- API：`public`

```gdscript
const HOOK_GET_DEPENDENCY_REMOVAL_POLICY: StringName = &"get_dependency_removal_policy"
```

能力对象可选实现：返回自动依赖能力的移除策略。

<a id="member-gfcapabilityutility-constants-hook_on_added"></a>

### `HOOK_ON_ADDED`

- API：`public`

```gdscript
const HOOK_ON_ADDED: StringName = &"on_gf_capability_added"
```

能力对象可选实现：挂载到 receiver 后调用。

<a id="member-gfcapabilityutility-constants-hook_on_removed"></a>

### `HOOK_ON_REMOVED`

- API：`public`

```gdscript
const HOOK_ON_REMOVED: StringName = &"on_gf_capability_removed"
```

能力对象可选实现：从 receiver 移除前调用。

<a id="member-gfcapabilityutility-constants-hook_on_active_changed"></a>

### `HOOK_ON_ACTIVE_CHANGED`

- API：`public`

```gdscript
const HOOK_ON_ACTIVE_CHANGED: StringName = &"on_gf_capability_active_changed"
```

能力对象可选实现：启停状态变化后调用。

## 属性

<a id="member-gfcapabilityutility-properties-prune_invalid_receivers_per_tick"></a>

### `prune_invalid_receivers_per_tick`

- API：`public`

```gdscript
var prune_invalid_receivers_per_tick: int = 128:
```

tick() 自动清理失效 receiver 时每次最多检查的数量，避免大型索引在单帧产生尖峰。 主动调用 prune_invalid_receivers() 仍会执行全量清理。

## 方法

<a id="member-gfcapabilityutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化能力管理器的运行时游标。

<a id="member-gfcapabilityutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

注销已索引 receiver 上的能力并清理分组状态。 由本 Utility 创建或 PackedScene 实例化的能力会随架构销毁释放；外部传入或场景中已有的能力只注销，不抢占其节点所有权。

<a id="member-gfcapabilityutility-methods-tick"></a>

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

<a id="member-gfcapabilityutility-methods-has_capability"></a>

### `has_capability`

- API：`public`

```gdscript
func has_capability(receiver: Object, capability_type: Script) -> bool:
```

检查对象是否拥有指定能力。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

返回：拥有该能力或其唯一子类能力时返回 true。

<a id="member-gfcapabilityutility-methods-get_capability"></a>

### `get_capability`

- API：`public`

```gdscript
func get_capability(receiver: Object, capability_type: Script) -> Object:
```

获取对象上的指定能力。 未命中精确类型时，会尝试寻找唯一的子类能力。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

返回：匹配的能力实例；未命中或匹配不唯一时返回 null。

<a id="member-gfcapabilityutility-methods-get_capability_types"></a>

### `get_capability_types`

- API：`public`

```gdscript
func get_capability_types(receiver: Object) -> Array[Script]:
```

获取对象当前拥有的所有能力类型。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |

返回：当前注册的能力脚本类型列表。

结构：

- `return`: Array[Script]，元素为 receiver 上当前注册的能力脚本类型。

<a id="member-gfcapabilityutility-methods-get_receivers_with"></a>

### `get_receivers_with`

- API：`public`

```gdscript
func get_receivers_with(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:
```

获取所有拥有指定能力的 receiver。

参数：

| 名称 | 说明 |
|---|---|
| `capability_type` | 要查询的能力脚本类型。 |
| `include_subclasses` | 为 true 时同时匹配指定能力的子类能力。 |

返回：当前拥有该能力的 receiver 列表。

结构：

- `return`: Array[Object]，元素为当前仍有效的能力接收对象。

<a id="member-gfcapabilityutility-methods-prune_invalid_receivers"></a>

### `prune_invalid_receivers`

- API：`public`

```gdscript
func prune_invalid_receivers() -> void:
```

主动清理已经失效的 receiver 弱引用与反向索引。

<a id="member-gfcapabilityutility-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`

```gdscript
func get_capabilities(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:
```

获取当前已挂载的指定能力实例列表。

参数：

| 名称 | 说明 |
|---|---|
| `capability_type` | 要查询的能力脚本类型。 |
| `include_subclasses` | 为 true 时同时返回指定能力的子类能力实例。 |

返回：匹配的能力实例列表。

结构：

- `return`: Array[Object]，元素为当前仍有效的能力实例。

<a id="member-gfcapabilityutility-methods-add_receiver_to_group"></a>

### `add_receiver_to_group`

- API：`public`

```gdscript
func add_receiver_to_group(receiver: Object, group_name: StringName) -> void:
```

把 receiver 加入一个能力查询分组。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `group_name` | 能力组或状态组名称。 |

<a id="member-gfcapabilityutility-methods-remove_receiver_from_group"></a>

### `remove_receiver_from_group`

- API：`public`

```gdscript
func remove_receiver_from_group(receiver: Object, group_name: StringName) -> void:
```

从一个能力查询分组移除 receiver。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `group_name` | 能力组或状态组名称。 |

<a id="member-gfcapabilityutility-methods-get_receiver_groups"></a>

### `get_receiver_groups`

- API：`public`

```gdscript
func get_receiver_groups(receiver: Object) -> Array[StringName]:
```

获取 receiver 当前所属的能力查询分组。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |

返回：receiver 当前所属的分组名称。

结构：

- `return`: Array[StringName]，元素为能力查询分组名称。

<a id="member-gfcapabilityutility-methods-get_receivers_in_group"></a>

### `get_receivers_in_group`

- API：`public`

```gdscript
func get_receivers_in_group(group_name: StringName) -> Array[Object]:
```

获取指定分组内的 receiver。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：分组内仍有效的 receiver 列表。

结构：

- `return`: Array[Object]，元素为当前仍有效的能力接收对象。

<a id="member-gfcapabilityutility-methods-get_receivers_in_group_with"></a>

### `get_receivers_in_group_with`

- API：`public`

```gdscript
func get_receivers_in_group_with( group_name: StringName, capability_type: Script, include_subclasses: bool = true ) -> Array[Object]:
```

获取指定分组内拥有某个能力的 receiver。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |
| `include_subclasses` | 为 true 时同时匹配指定类型的子类。 |

返回：分组内拥有该能力的 receiver 列表。

结构：

- `return`: Array[Object]，元素为当前仍有效的能力接收对象。

<a id="member-gfcapabilityutility-methods-add_capability"></a>

### `add_capability`

- API：`public`

```gdscript
func add_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:
```

给对象挂载指定能力类型。 provider 可为 Callable、PackedScene、Object；为空时使用 capability_type.new()。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |
| `provider` | 用于创建能力实例的 provider。 |

返回：已挂载或复用的能力实例；失败时返回 null。

结构：

- `provider`: Variant，可为 null、Callable、PackedScene 或 Object 能力实例。

<a id="member-gfcapabilityutility-methods-add_required_capability"></a>

### `add_required_capability`

- API：`public`

```gdscript
func add_required_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:
```

给对象挂载指定能力类型，并标记为自动依赖能力。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |
| `provider` | 用于创建能力实例的 provider。 |

返回：已挂载或复用的能力实例；失败时返回 null。

结构：

- `provider`: Variant，可为 null、Callable、PackedScene 或 Object 能力实例。

<a id="member-gfcapabilityutility-methods-add_capability_instance"></a>

### `add_capability_instance`

- API：`public`

```gdscript
func add_capability_instance(receiver: Object, capability: Object, as_type: Script = null) -> Object:
```

给对象挂载一个已经存在的能力实例。 该入口不会接管传入实例的所有权；架构销毁时只注销能力记录。需要由 Utility 创建并接管节点释放时，请使用 add_capability() 或 add_scene_capability()。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability` | 要挂载的能力实例。 |
| `as_type` | 能力实例注册时使用的类型；为 null 时使用实例脚本类型。 |

返回：已挂载或复用的能力实例；失败时返回 null。

<a id="member-gfcapabilityutility-methods-add_scene_capability"></a>

### `add_scene_capability`

- API：`public`

```gdscript
func add_scene_capability(receiver: Node, scene: PackedScene, as_type: Script = null) -> Object:
```

实例化 PackedScene 并作为能力挂载。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `scene` | 要实例化的能力场景资源。 |
| `as_type` | 能力实例注册时使用的类型；为 null 时使用实例脚本类型。 |

返回：已挂载的能力节点；失败时返回 null。

<a id="member-gfcapabilityutility-methods-set_capability_active"></a>

### `set_capability_active`

- API：`public`

```gdscript
func set_capability_active(receiver: Object, capability_type: Script, active: bool) -> void:
```

设置对象上指定能力的启停状态。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |
| `active` | 要设置的激活状态。 |

<a id="member-gfcapabilityutility-methods-is_capability_active"></a>

### `is_capability_active`

- API：`public`

```gdscript
func is_capability_active(receiver: Object, capability_type: Script) -> bool:
```

查询对象上指定能力当前是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

返回：能力存在且处于启用状态时返回 true。

<a id="member-gfcapabilityutility-methods-remove_capability"></a>

### `remove_capability`

- API：`public`

```gdscript
func remove_capability(receiver: Object, capability_type: Script) -> void:
```

从对象移除指定能力。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

<a id="member-gfcapabilityutility-methods-unregister_capability"></a>

### `unregister_capability`

- API：`public`

```gdscript
func unregister_capability(receiver: Object, capability_type: Script) -> void:
```

从对象注销指定能力，但不释放能力实例。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

<a id="member-gfcapabilityutility-methods-clear_capabilities"></a>

### `clear_capabilities`

- API：`public`

```gdscript
func clear_capabilities(receiver: Object) -> void:
```

清空对象上的所有能力。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |

<a id="member-gfcapabilityutility-methods-clear_receiver_groups"></a>

### `clear_receiver_groups`

- API：`public`

```gdscript
func clear_receiver_groups(receiver: Object) -> void:
```

清空 receiver 所属的所有能力查询分组。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |

<a id="member-gfcapabilityutility-methods-apply_recipe"></a>

### `apply_recipe`

- API：`public`

```gdscript
func apply_recipe(receiver: Object, recipe: GFCapabilityRecipe, options: Dictionary = {}) -> Dictionary:
```

把能力组合 Recipe 应用到 receiver。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `recipe` | 能力组合资源。 |
| `options` | 可选参数，支持 skip_groups、validate_after_apply 与 transactional。 |

返回：应用报告。

结构：

- `options`: Dictionary，可包含 skip_groups、validate_after_apply、transactional 布尔选项。
- `return`: Dictionary，包含 ok、recipe_id、added、reused、failed、groups、dependency_validation 与 rolled_back。

<a id="member-gfcapabilityutility-methods-remove_recipe"></a>

### `remove_recipe`

- API：`public`

```gdscript
func remove_recipe(receiver: Object, recipe: GFCapabilityRecipe, remove_groups: bool = true) -> Dictionary:
```

移除 Recipe 描述的能力和可选分组。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 能力接收对象。 |
| `recipe` | 能力组合资源。 |
| `remove_groups` | 是否同步移除 Recipe groups。 |

返回：移除报告。

结构：

- `return`: Dictionary，包含 ok、recipe_id、removed、skipped 和 groups_removed。

<a id="member-gfcapabilityutility-methods-validate_receiver_dependencies"></a>

### `validate_receiver_dependencies`

- API：`public`

```gdscript
func validate_receiver_dependencies(receiver: Object) -> Dictionary:
```

检查 receiver 上能力依赖是否完整。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 目标对象。 |

返回：统一检查结果，包含 ok 与 missing_dependencies。

结构：

- `return`: Dictionary，包含 ok 与 missing_dependencies；missing_dependencies 为缺失依赖记录数组。

<a id="member-gfcapabilityutility-methods-inspect_receiver"></a>

### `inspect_receiver`

- API：`public`

```gdscript
func inspect_receiver(receiver: Object) -> Dictionary:
```

获取 receiver 能力诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 目标对象。 |

返回：能力、依赖、缺失项和分组信息。

结构：

- `return`: Dictionary，包含 ok、error、receiver_id、capability_count、capabilities、missing_dependencies 和 groups。
