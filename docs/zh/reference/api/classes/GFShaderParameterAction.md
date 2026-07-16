# GFShaderParameterAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_shader_parameter_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`4.2.0`

通用 ShaderMaterial 参数动作。 将 ShaderMaterial 的某个 uniform 参数写入或缓动到目标值。 它只处理参数写入、Tween 宿主和可选材质实例化，不绑定具体 shader、特效或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfshaderparameteraction-properties-target) | `var target: Object` |
| 属性 | [`parameter_name`](#member-gfshaderparameteraction-properties-parameter_name) | `var parameter_name: StringName = &""` |
| 属性 | [`target_value`](#member-gfshaderparameteraction-properties-target_value) | `var target_value: Variant = null` |
| 属性 | [`duration`](#member-gfshaderparameteraction-properties-duration) | `var duration: float:` |
| 属性 | [`material_property`](#member-gfshaderparameteraction-properties-material_property) | `var material_property: NodePath = ^"material"` |
| 属性 | [`host_node`](#member-gfshaderparameteraction-properties-host_node) | `var host_node: Node` |
| 属性 | [`transition_type`](#member-gfshaderparameteraction-properties-transition_type) | `var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC` |
| 属性 | [`ease_type`](#member-gfshaderparameteraction-properties-ease_type) | `var ease_type: Tween.EaseType = Tween.EASE_OUT` |
| 属性 | [`duplicate_material_on_execute`](#member-gfshaderparameteraction-properties-duplicate_material_on_execute) | `var duplicate_material_on_execute: bool = false` |
| 属性 | [`restore_initial_value_on_cancel`](#member-gfshaderparameteraction-properties-restore_initial_value_on_cancel) | `var restore_initial_value_on_cancel: bool = false` |
| 属性 | [`restore_initial_value_on_finish`](#member-gfshaderparameteraction-properties-restore_initial_value_on_finish) | `var restore_initial_value_on_finish: bool = false` |
| 方法 | [`execute`](#member-gfshaderparameteraction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfshaderparameteraction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfshaderparameteraction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfshaderparameteraction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfshaderparameteraction-methods-finish) | `func finish() -> void:` |
| 方法 | [`get_wait_guard_node`](#member-gfshaderparameteraction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |

## 属性

<a id="member-gfshaderparameteraction-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Object
```

目标对象。可以直接是 ShaderMaterial，也可以是持有材质属性的对象。

<a id="member-gfshaderparameteraction-properties-parameter_name"></a>

### `parameter_name`

- API：`public`

```gdscript
var parameter_name: StringName = &""
```

Shader uniform 参数名。

<a id="member-gfshaderparameteraction-properties-target_value"></a>

### `target_value`

- API：`public`

```gdscript
var target_value: Variant = null
```

要写入的目标参数值。

结构：

- `target_value`: Variant，可被 Tween 插值并写入 parameter_name 的目标值。

<a id="member-gfshaderparameteraction-properties-duration"></a>

### `duration`

- API：`public`
- 首次版本：`4.2.0`

```gdscript
var duration: float:
```

Tween 持续时间。小于等于 0 时立即写入。

<a id="member-gfshaderparameteraction-properties-material_property"></a>

### `material_property`

- API：`public`

```gdscript
var material_property: NodePath = ^"material"
```

当 target 不是 ShaderMaterial 时，用于读取材质的属性路径。

<a id="member-gfshaderparameteraction-properties-host_node"></a>

### `host_node`

- API：`public`

```gdscript
var host_node: Node
```

可选 Tween 宿主节点。target 不是 Node 时，带时长动作必须提供。

<a id="member-gfshaderparameteraction-properties-transition_type"></a>

### `transition_type`

- API：`public`

```gdscript
var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
```

Tween 过渡类型。

<a id="member-gfshaderparameteraction-properties-ease_type"></a>

### `ease_type`

- API：`public`

```gdscript
var ease_type: Tween.EaseType = Tween.EASE_OUT
```

Tween 缓动类型。

<a id="member-gfshaderparameteraction-properties-duplicate_material_on_execute"></a>

### `duplicate_material_on_execute`

- API：`public`

```gdscript
var duplicate_material_on_execute: bool = false
```

执行前是否复制材质并写回 material_property，避免修改共享材质资源。

<a id="member-gfshaderparameteraction-properties-restore_initial_value_on_cancel"></a>

### `restore_initial_value_on_cancel`

- API：`public`

```gdscript
var restore_initial_value_on_cancel: bool = false
```

取消动作时是否恢复执行前捕获的参数值。

<a id="member-gfshaderparameteraction-properties-restore_initial_value_on_finish"></a>

### `restore_initial_value_on_finish`

- API：`public`

```gdscript
var restore_initial_value_on_finish: bool = false
```

动作自然结束或 finish() 时是否恢复执行前捕获的参数值。

## 方法

<a id="member-gfshaderparameteraction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行 Shader 参数写入或 Tween。

返回：需要等待时返回内部完成 Signal；目标、材质或参数无效时返回 null。

结构：

- `return`: Variant，返回内部完成 Signal 或 null。

<a id="member-gfshaderparameteraction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消当前 Tween，并按配置恢复参数值。

<a id="member-gfshaderparameteraction-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停当前 Tween。

<a id="member-gfshaderparameteraction-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复当前 Tween。

<a id="member-gfshaderparameteraction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即完成当前 Tween，并按配置恢复参数值。

<a id="member-gfshaderparameteraction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`

```gdscript
func get_wait_guard_node() -> Node:
```

获取用于保护等待生命周期的 Tween 宿主节点。

返回：有效宿主节点；无效时返回 null。
