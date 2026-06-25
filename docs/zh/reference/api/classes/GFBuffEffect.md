# GFBuffEffect

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_buff_effect.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`6.0.0`

Buff 可组合效果基类。 作为数据化 Buff 的通用效果扩展点，响应 apply、remove、refresh 和 tick 生命周期。 基类不规定伤害、治疗、控制等业务语义；项目可通过子类实现具体效果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`effect_id`](#member-gfbuffeffect-properties-effect_id) | `var effect_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfbuffeffect-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`apply`](#member-gfbuffeffect-methods-apply) | `func apply(context: Dictionary) -> Dictionary:` |
| 方法 | [`remove`](#member-gfbuffeffect-methods-remove) | `func remove(context: Dictionary) -> Dictionary:` |
| 方法 | [`refresh`](#member-gfbuffeffect-methods-refresh) | `func refresh(context: Dictionary) -> Dictionary:` |
| 方法 | [`tick`](#member-gfbuffeffect-methods-tick) | `func tick(context: Dictionary) -> Dictionary:` |
| 方法 | [`get_state_snapshot`](#member-gfbuffeffect-methods-get_state_snapshot) | `func get_state_snapshot() -> Dictionary:` |
| 方法 | [`restore_state_snapshot`](#member-gfbuffeffect-methods-restore_state_snapshot) | `func restore_state_snapshot(snapshot: Dictionary) -> void:` |
| 方法 | [`_apply`](#member-gfbuffeffect-methods-_apply) | `func _apply(_context: Dictionary) -> Dictionary:` |
| 方法 | [`_remove`](#member-gfbuffeffect-methods-_remove) | `func _remove(_context: Dictionary) -> Dictionary:` |
| 方法 | [`_refresh`](#member-gfbuffeffect-methods-_refresh) | `func _refresh(_context: Dictionary) -> Dictionary:` |
| 方法 | [`_tick`](#member-gfbuffeffect-methods-_tick) | `func _tick(_context: Dictionary) -> Dictionary:` |
| 方法 | [`_get_state_snapshot`](#member-gfbuffeffect-methods-_get_state_snapshot) | `func _get_state_snapshot() -> Dictionary:` |
| 方法 | [`_restore_state_snapshot`](#member-gfbuffeffect-methods-_restore_state_snapshot) | `func _restore_state_snapshot(_snapshot: Dictionary) -> void:` |

## 属性

<a id="member-gfbuffeffect-properties-effect_id"></a>

### `effect_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var effect_id: StringName = &""
```

效果标识，用于诊断、状态快照或项目侧过滤。

<a id="member-gfbuffeffect-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释其中字段。

结构：

- `metadata`: Dictionary project-defined effect metadata.

## 方法

<a id="member-gfbuffeffect-methods-apply"></a>

### `apply`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func apply(context: Dictionary) -> Dictionary:
```

响应 Buff 应用。

参数：

| 名称 | 说明 |
|---|---|
| `context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `context`: Dictionary with buff, owner, event, and metadata.
- `return`: Dictionary with ok, reason, effect_id, and metadata.

<a id="member-gfbuffeffect-methods-remove"></a>

### `remove`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func remove(context: Dictionary) -> Dictionary:
```

响应 Buff 移除。

参数：

| 名称 | 说明 |
|---|---|
| `context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `context`: Dictionary with buff, owner, event, reason, and metadata.
- `return`: Dictionary with ok, reason, effect_id, and metadata.

<a id="member-gfbuffeffect-methods-refresh"></a>

### `refresh`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func refresh(context: Dictionary) -> Dictionary:
```

响应 Buff 刷新。

参数：

| 名称 | 说明 |
|---|---|
| `context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `context`: Dictionary with buff, owner, event, refresh_duration, and metadata.
- `return`: Dictionary with ok, reason, effect_id, and metadata.

<a id="member-gfbuffeffect-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func tick(context: Dictionary) -> Dictionary:
```

响应 Buff tick。

参数：

| 名称 | 说明 |
|---|---|
| `context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `context`: Dictionary with buff, owner, event, delta, and metadata.
- `return`: Dictionary with ok, reason, effect_id, and metadata.

<a id="member-gfbuffeffect-methods-get_state_snapshot"></a>

### `get_state_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_state_snapshot() -> Dictionary:
```

获取效果运行时状态快照。

返回：状态快照。

结构：

- `return`: Dictionary project-defined effect state payload.

<a id="member-gfbuffeffect-methods-restore_state_snapshot"></a>

### `restore_state_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func restore_state_snapshot(snapshot: Dictionary) -> void:
```

恢复效果运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 状态快照。 |

结构：

- `snapshot`: Dictionary project-defined effect state payload.

<a id="member-gfbuffeffect-methods-_apply"></a>

### `_apply`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _apply(_context: Dictionary) -> Dictionary:
```

Buff 应用钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `_context`: Dictionary with buff, owner, event, and metadata.
- `return`: Dictionary with optional ok, reason, and metadata.

<a id="member-gfbuffeffect-methods-_remove"></a>

### `_remove`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _remove(_context: Dictionary) -> Dictionary:
```

Buff 移除钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `_context`: Dictionary with buff, owner, event, reason, and metadata.
- `return`: Dictionary with optional ok, reason, and metadata.

<a id="member-gfbuffeffect-methods-_refresh"></a>

### `_refresh`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _refresh(_context: Dictionary) -> Dictionary:
```

Buff 刷新钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `_context`: Dictionary with buff, owner, event, refresh_duration, and metadata.
- `return`: Dictionary with optional ok, reason, and metadata.

<a id="member-gfbuffeffect-methods-_tick"></a>

### `_tick`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _tick(_context: Dictionary) -> Dictionary:
```

Buff tick 钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | Buff 生命周期上下文。 |

返回：效果报告。

结构：

- `_context`: Dictionary with buff, owner, event, delta, and metadata.
- `return`: Dictionary with optional ok, reason, and metadata.

<a id="member-gfbuffeffect-methods-_get_state_snapshot"></a>

### `_get_state_snapshot`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _get_state_snapshot() -> Dictionary:
```

状态快照钩子。

返回：状态快照。

结构：

- `return`: Dictionary project-defined effect state payload.

<a id="member-gfbuffeffect-methods-_restore_state_snapshot"></a>

### `_restore_state_snapshot`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _restore_state_snapshot(_snapshot: Dictionary) -> void:
```

状态恢复钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_snapshot` | 状态快照。 |

结构：

- `_snapshot`: Dictionary project-defined effect state payload.
