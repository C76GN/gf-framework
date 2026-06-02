# GFNodeCapability

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/nodes/gf_node_capability.gd`
- 模块：`Capability`
- 继承：`Node`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

可直接作为场景节点使用的能力组件基类。 适合承载通用节点逻辑、输入、动画或子节点引用的局部能力。 需要 2D/3D/UI 空间继承时，优先使用 GFNode2DCapability、GFNode3DCapability 或 GFControlCapability。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`required_capabilities`](#member-gfnodecapability-properties-required_capabilities) | `var required_capabilities: Array[Script] = []` |
| 属性 | [`receiver`](#member-gfnodecapability-properties-receiver) | `var receiver: Object = null` |
| 属性 | [`active`](#member-gfnodecapability-properties-active) | `var active: bool = true` |
| 方法 | [`get_required_capabilities`](#member-gfnodecapability-methods-get_required_capabilities) | `func get_required_capabilities() -> Array[Script]:` |
| 方法 | [`get_dependency_removal_policy`](#member-gfnodecapability-methods-get_dependency_removal_policy) | `func get_dependency_removal_policy() -> int:` |
| 方法 | [`on_gf_capability_added`](#member-gfnodecapability-methods-on_gf_capability_added) | `func on_gf_capability_added(target: Object) -> void:` |
| 方法 | [`on_gf_capability_removed`](#member-gfnodecapability-methods-on_gf_capability_removed) | `func on_gf_capability_removed(_target: Object) -> void:` |
| 方法 | [`on_gf_capability_active_changed`](#member-gfnodecapability-methods-on_gf_capability_active_changed) | `func on_gf_capability_active_changed(_target: Object, _active: bool) -> void:` |
| 方法 | [`get_model`](#member-gfnodecapability-methods-get_model) | `func get_model(model_type: Script) -> Object:` |
| 方法 | [`get_system`](#member-gfnodecapability-methods-get_system) | `func get_system(system_type: Script) -> Object:` |
| 方法 | [`get_utility`](#member-gfnodecapability-methods-get_utility) | `func get_utility(utility_type: Script) -> Object:` |
| 方法 | [`get_capability`](#member-gfnodecapability-methods-get_capability) | `func get_capability(capability_type: Script) -> Object:` |

## 属性

<a id="member-gfnodecapability-properties-required_capabilities"></a>

### `required_capabilities`

- API：`public`

```gdscript
var required_capabilities: Array[Script] = []
```

当前能力依赖的其他能力类型。运行时挂载前会先确保这些能力存在。

结构：

- `required_capabilities`: 元素为 Script 的能力类型列表。

<a id="member-gfnodecapability-properties-receiver"></a>

### `receiver`

- API：`public`

```gdscript
var receiver: Object = null
```

当前能力所属对象。由 GFCapabilityUtility 挂载时写入。

<a id="member-gfnodecapability-properties-active"></a>

### `active`

- API：`public`

```gdscript
var active: bool = true
```

当前能力是否启用。请优先通过 GFCapabilityUtility.set_capability_active() 修改。

## 方法

<a id="member-gfnodecapability-methods-get_required_capabilities"></a>

### `get_required_capabilities`

- API：`public`

```gdscript
func get_required_capabilities() -> Array[Script]:
```

返回当前能力依赖的其他能力类型。 默认返回 required_capabilities；只有运行时动态依赖才建议在子类中重写。 GFCapabilityUtility 会在挂载当前能力前先确保这些能力存在。

返回：当前能力依赖的能力脚本类型列表。

结构：

- `return`: 元素为 Script 的能力类型列表。

<a id="member-gfnodecapability-methods-get_dependency_removal_policy"></a>

### `get_dependency_removal_policy`

- API：`public`

```gdscript
func get_dependency_removal_policy() -> int:
```

返回移除当前能力时对自动补齐依赖能力的处理策略。

返回：DependencyRemovalPolicy 枚举值。

<a id="member-gfnodecapability-methods-on_gf_capability_added"></a>

### `on_gf_capability_added`

- API：`public`

```gdscript
func on_gf_capability_added(target: Object) -> void:
```

能力挂载到对象后调用。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 当前能力所属对象。 |

<a id="member-gfnodecapability-methods-on_gf_capability_removed"></a>

### `on_gf_capability_removed`

- API：`public`

```gdscript
func on_gf_capability_removed(_target: Object) -> void:
```

能力从对象移除前调用。

参数：

| 名称 | 说明 |
|---|---|
| `_target` | 当前能力所属对象。 |

<a id="member-gfnodecapability-methods-on_gf_capability_active_changed"></a>

### `on_gf_capability_active_changed`

- API：`public`

```gdscript
func on_gf_capability_active_changed(_target: Object, _active: bool) -> void:
```

能力启停状态变化后调用。

参数：

| 名称 | 说明 |
|---|---|
| `_target` | 当前能力所属对象。 |
| `_active` | 当前启停状态。 |

<a id="member-gfnodecapability-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script) -> Object:
```

通过当前架构获取 Model。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 要获取的 Model 脚本类型。 |

返回：Model 实例；不可用时返回 null。

<a id="member-gfnodecapability-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script) -> Object:
```

通过当前架构获取 System。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 目标类型。 |

返回：System 实例；不可用时返回 null。

<a id="member-gfnodecapability-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script) -> Object:
```

通过当前架构获取 Utility。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 要获取的 Utility 脚本类型。 |

返回：Utility 实例；不可用时返回 null。

<a id="member-gfnodecapability-methods-get_capability"></a>

### `get_capability`

- API：`public`

```gdscript
func get_capability(capability_type: Script) -> Object:
```

获取当前 receiver 上的其他能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_type` | 要查询、添加或移除的能力脚本类型。 |

返回：能力实例；不存在时返回 null。
