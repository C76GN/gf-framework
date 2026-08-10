# GFRuntimeInspectorUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_runtime_inspector_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

显式 schema 驱动的运行时调参注册表。 项目主动注册可调对象和属性后，工具提供快照、读取和受控写入能力。 它不自动暴露业务对象，也不内置具体 UI 或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`target_registered`](#member-gfruntimeinspectorutility-signals-target_registered) | `signal target_registered(target_id: StringName)` |
| 信号 | [`target_unregistered`](#member-gfruntimeinspectorutility-signals-target_unregistered) | `signal target_unregistered(target_id: StringName)` |
| 信号 | [`property_changed`](#member-gfruntimeinspectorutility-signals-property_changed) | `signal property_changed(target_id: StringName, property_id: StringName, old_value: Variant, new_value: Variant)` |
| 属性 | [`allow_writes`](#member-gfruntimeinspectorutility-properties-allow_writes) | `var allow_writes: bool = true` |
| 属性 | [`debug_build_writes_only`](#member-gfruntimeinspectorutility-properties-debug_build_writes_only) | `var debug_build_writes_only: bool = true` |
| 方法 | [`dispose`](#member-gfruntimeinspectorutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_target`](#member-gfruntimeinspectorutility-methods-register_target) | `func register_target( target_id: StringName, target: Object, properties: Array[GFRuntimeTunableProperty] = [], options: Dictionary = {} ) -> bool:` |
| 方法 | [`unregister_target`](#member-gfruntimeinspectorutility-methods-unregister_target) | `func unregister_target(target_id: StringName) -> bool:` |
| 方法 | [`has_target`](#member-gfruntimeinspectorutility-methods-has_target) | `func has_target(target_id: StringName) -> bool:` |
| 方法 | [`register_property`](#member-gfruntimeinspectorutility-methods-register_property) | `func register_property(target_id: StringName, property: GFRuntimeTunableProperty) -> bool:` |
| 方法 | [`remove_property`](#member-gfruntimeinspectorutility-methods-remove_property) | `func remove_property(target_id: StringName, property_id: StringName) -> bool:` |
| 方法 | [`get_target_ids`](#member-gfruntimeinspectorutility-methods-get_target_ids) | `func get_target_ids(include_hidden: bool = false) -> PackedStringArray:` |
| 方法 | [`get_property_value`](#member-gfruntimeinspectorutility-methods-get_property_value) | `func get_property_value(target_id: StringName, property_id: StringName) -> Variant:` |
| 方法 | [`set_property_value`](#member-gfruntimeinspectorutility-methods-set_property_value) | `func set_property_value(target_id: StringName, property_id: StringName, value: Variant) -> bool:` |
| 方法 | [`get_target_snapshot`](#member-gfruntimeinspectorutility-methods-get_target_snapshot) | `func get_target_snapshot(include_hidden: bool = false) -> Array[Dictionary]:` |
| 方法 | [`clear_targets`](#member-gfruntimeinspectorutility-methods-clear_targets) | `func clear_targets() -> void:` |
| 方法 | [`attach_to_debug_overlay`](#member-gfruntimeinspectorutility-methods-attach_to_debug_overlay) | `func attach_to_debug_overlay(panel_id: StringName = &"gf.runtime_inspector") -> bool:` |
| 方法 | [`refresh_debug_overlay_panel`](#member-gfruntimeinspectorutility-methods-refresh_debug_overlay_panel) | `func refresh_debug_overlay_panel() -> bool:` |
| 方法 | [`detach_from_debug_overlay`](#member-gfruntimeinspectorutility-methods-detach_from_debug_overlay) | `func detach_from_debug_overlay(panel_id: StringName = &"") -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimeinspectorutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfruntimeinspectorutility-signals-target_registered"></a>

### `target_registered`

- API：`public`

```gdscript
signal target_registered(target_id: StringName)
```

目标注册后发出。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |

<a id="member-gfruntimeinspectorutility-signals-target_unregistered"></a>

### `target_unregistered`

- API：`public`

```gdscript
signal target_unregistered(target_id: StringName)
```

目标注销后发出。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |

<a id="member-gfruntimeinspectorutility-signals-property_changed"></a>

### `property_changed`

- API：`public`

```gdscript
signal property_changed(target_id: StringName, property_id: StringName, old_value: Variant, new_value: Variant)
```

属性成功写入后发出。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `property_id` | 属性 ID。 |
| `old_value` | 写入前的值。 |
| `new_value` | 写入后的值。 |

结构：

- `old_value`: Variant，写入前的属性值。
- `new_value`: Variant，写入后的属性值。

## 属性

<a id="member-gfruntimeinspectorutility-properties-allow_writes"></a>

### `allow_writes`

- API：`public`

```gdscript
var allow_writes: bool = true
```

是否允许通过本工具写入值。

<a id="member-gfruntimeinspectorutility-properties-debug_build_writes_only"></a>

### `debug_build_writes_only`

- API：`public`

```gdscript
var debug_build_writes_only: bool = true
```

为 true 时，非 debug 构建禁止写入。

## 方法

<a id="member-gfruntimeinspectorutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放 Inspector 注册状态并解除 Overlay 面板。

<a id="member-gfruntimeinspectorutility-methods-register_target"></a>

### `register_target`

- API：`public`

```gdscript
func register_target( target_id: StringName, target: Object, properties: Array[GFRuntimeTunableProperty] = [], options: Dictionary = {} ) -> bool:
```

注册一个运行时可检查目标。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `target` | 目标对象。 |
| `properties` | 可调属性列表。 |
| `options` | 可选显示参数，支持 label、group、visible。 |

返回：注册成功返回 true。

结构：

- `properties`: Array[GFRuntimeTunableProperty]，目标允许检查或写入的属性声明列表。
- `options`: Dictionary，支持 label、group 和 visible。

<a id="member-gfruntimeinspectorutility-methods-unregister_target"></a>

### `unregister_target`

- API：`public`

```gdscript
func unregister_target(target_id: StringName) -> bool:
```

注销运行时目标。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfruntimeinspectorutility-methods-has_target"></a>

### `has_target`

- API：`public`

```gdscript
func has_target(target_id: StringName) -> bool:
```

检查目标是否存在且仍有效。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |

返回：目标存在且对象有效时返回 true。

<a id="member-gfruntimeinspectorutility-methods-register_property"></a>

### `register_property`

- API：`public`

```gdscript
func register_property(target_id: StringName, property: GFRuntimeTunableProperty) -> bool:
```

为目标注册或替换一个可调属性。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `property` | 可调属性声明。 |

返回：注册成功返回 true。

<a id="member-gfruntimeinspectorutility-methods-remove_property"></a>

### `remove_property`

- API：`public`

```gdscript
func remove_property(target_id: StringName, property_id: StringName) -> bool:
```

移除目标上的可调属性。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `property_id` | 属性 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfruntimeinspectorutility-methods-get_target_ids"></a>

### `get_target_ids`

- API：`public`

```gdscript
func get_target_ids(include_hidden: bool = false) -> PackedStringArray:
```

获取目标 ID 列表。

参数：

| 名称 | 说明 |
|---|---|
| `include_hidden` | 为 true 时包含隐藏目标。 |

返回：排序后的目标 ID。

<a id="member-gfruntimeinspectorutility-methods-get_property_value"></a>

### `get_property_value`

- API：`public`

```gdscript
func get_property_value(target_id: StringName, property_id: StringName) -> Variant:
```

读取目标属性当前值。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `property_id` | 属性 ID。 |

返回：当前值；找不到时返回 null。

结构：

- `return`: Variant，当前属性值，类型由对应 GFRuntimeTunableProperty 决定。

<a id="member-gfruntimeinspectorutility-methods-set_property_value"></a>

### `set_property_value`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_property_value(target_id: StringName, property_id: StringName, value: Variant) -> bool:
```

写入目标属性。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标 ID。 |
| `property_id` | 属性 ID。 |
| `value` | 请求写入的值。 |

返回：当前注册代际仍有效且写入入口完成时返回 true；回调内重入同一属性或更改目标/属性注册会返回 false，且不发 property_changed。

结构：

- `value`: Variant，请求写入的原始值，会由属性 schema 归一化。

<a id="member-gfruntimeinspectorutility-methods-get_target_snapshot"></a>

### `get_target_snapshot`

- API：`public`

```gdscript
func get_target_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
```

读取运行时 Inspector 快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_hidden` | 为 true 时包含隐藏目标和属性。 |

返回：目标快照数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 id、label、group、visible、valid 和 properties。

<a id="member-gfruntimeinspectorutility-methods-clear_targets"></a>

### `clear_targets`

- API：`public`

```gdscript
func clear_targets() -> void:
```

清空所有目标。

<a id="member-gfruntimeinspectorutility-methods-attach_to_debug_overlay"></a>

### `attach_to_debug_overlay`

- API：`public`

```gdscript
func attach_to_debug_overlay(panel_id: StringName = &"gf.runtime_inspector") -> bool:
```

将 Inspector 快照作为文本面板注册到 GFDebugOverlayUtility。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | Overlay 面板 ID。 |

返回：注册成功返回 true。

<a id="member-gfruntimeinspectorutility-methods-refresh_debug_overlay_panel"></a>

### `refresh_debug_overlay_panel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func refresh_debug_overlay_panel() -> bool:
```

把 Inspector 当前状态重新发布到已附加的 Overlay 面板。

返回：已附加且发布成功时返回 true。

<a id="member-gfruntimeinspectorutility-methods-detach_from_debug_overlay"></a>

### `detach_from_debug_overlay`

- API：`public`

```gdscript
func detach_from_debug_overlay(panel_id: StringName = &"") -> void:
```

从 GFDebugOverlayUtility 移除 Inspector 面板。

参数：

| 名称 | 说明 |
|---|---|
| `panel_id` | Overlay 面板 ID；为空时使用当前附加的面板 ID。 |

<a id="member-gfruntimeinspectorutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取诊断快照。

返回：当前注册状态。

结构：

- `return`: Dictionary，包含 target_count、target_ids 和 writes_allowed。
