# GFSaveScope

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_save_scope.gd`
- 模块：`Save`
- 继承：`Node`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存档图作用域节点。 Scope 定义一次保存/加载的边界。它可嵌套组织子 Scope，但不假设具体业务结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`RestorePolicy`](#member-gfsavescope-enums-restorepolicy) | `enum RestorePolicy` |
| 枚举 | [`Phase`](#member-gfsavescope-enums-phase) | `enum Phase` |
| 属性 | [`scope_key`](#member-gfsavescope-properties-scope_key) | `var scope_key: StringName = &""` |
| 属性 | [`key_namespace`](#member-gfsavescope-properties-key_namespace) | `var key_namespace: StringName = &""` |
| 属性 | [`enabled`](#member-gfsavescope-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`save_enabled`](#member-gfsavescope-properties-save_enabled) | `var save_enabled: bool = true` |
| 属性 | [`load_enabled`](#member-gfsavescope-properties-load_enabled) | `var load_enabled: bool = true` |
| 属性 | [`phase`](#member-gfsavescope-properties-phase) | `var phase: Phase = Phase.NORMAL` |
| 属性 | [`restore_policy`](#member-gfsavescope-properties-restore_policy) | `var restore_policy: RestorePolicy = RestorePolicy.APPLY_ONLY_EXISTING` |
| 方法 | [`get_scope_key`](#member-gfsavescope-methods-get_scope_key) | `func get_scope_key() -> StringName:` |
| 方法 | [`get_key_prefix`](#member-gfsavescope-methods-get_key_prefix) | `func get_key_prefix() -> String:` |
| 方法 | [`describe_scope`](#member-gfsavescope-methods-describe_scope) | `func describe_scope() -> Dictionary:` |
| 方法 | [`_can_save_scope`](#member-gfsavescope-methods-_can_save_scope) | `func _can_save_scope(_context: Dictionary = {}) -> bool:` |
| 方法 | [`_can_load_scope`](#member-gfsavescope-methods-_can_load_scope) | `func _can_load_scope(_context: Dictionary = {}) -> bool:` |
| 方法 | [`_before_save`](#member-gfsavescope-methods-_before_save) | `func _before_save(_context: Dictionary = {}) -> void:` |
| 方法 | [`_after_save`](#member-gfsavescope-methods-_after_save) | `func _after_save(_payload: Dictionary, _context: Dictionary = {}) -> void:` |
| 方法 | [`_before_load`](#member-gfsavescope-methods-_before_load) | `func _before_load(_payload: Dictionary, _context: Dictionary = {}) -> void:` |
| 方法 | [`_after_load`](#member-gfsavescope-methods-_after_load) | `func _after_load(_payload: Dictionary, _context: Dictionary = {}) -> void:` |

## 枚举

<a id="member-gfsavescope-enums-restorepolicy"></a>

### `RestorePolicy`

- API：`public`

```gdscript
enum RestorePolicy { ## 只把数据应用到已存在的 Source。 APPLY_ONLY_EXISTING, ## 允许 GFSaveGraphUtility 使用注册的工厂补建实体。 ALLOW_FACTORIES, }
```

恢复未知实体时的处理策略。

<a id="member-gfsavescope-enums-phase"></a>

### `Phase`

- API：`public`

```gdscript
enum Phase { ## 早期执行。 EARLY, ## 普通执行。 NORMAL, ## 后期执行。 LATE, }
```

Scope/Source 执行阶段。

## 属性

<a id="member-gfsavescope-properties-scope_key"></a>

### `scope_key`

- API：`public`

```gdscript
var scope_key: StringName = &""
```

Scope 稳定标识。留空时回退到节点名。

<a id="member-gfsavescope-properties-key_namespace"></a>

### `key_namespace`

- API：`public`

```gdscript
var key_namespace: StringName = &""
```

可选键命名空间。用于多处复用同名子结构时隔离 source key。

<a id="member-gfsavescope-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该 Scope。

<a id="member-gfsavescope-properties-save_enabled"></a>

### `save_enabled`

- API：`public`

```gdscript
var save_enabled: bool = true
```

是否参与保存。

<a id="member-gfsavescope-properties-load_enabled"></a>

### `load_enabled`

- API：`public`

```gdscript
var load_enabled: bool = true
```

是否参与加载。

<a id="member-gfsavescope-properties-phase"></a>

### `phase`

- API：`public`

```gdscript
var phase: Phase = Phase.NORMAL
```

执行阶段。

<a id="member-gfsavescope-properties-restore_policy"></a>

### `restore_policy`

- API：`public`

```gdscript
var restore_policy: RestorePolicy = RestorePolicy.APPLY_ONLY_EXISTING
```

恢复策略。

## 方法

<a id="member-gfsavescope-methods-get_scope_key"></a>

### `get_scope_key`

- API：`public`

```gdscript
func get_scope_key() -> StringName:
```

获取 Scope 稳定标识。

返回：作用域键。

<a id="member-gfsavescope-methods-get_key_prefix"></a>

### `get_key_prefix`

- API：`public`

```gdscript
func get_key_prefix() -> String:
```

获取来源键前缀。

返回：前缀字符串。

<a id="member-gfsavescope-methods-describe_scope"></a>

### `describe_scope`

- API：`public`

```gdscript
func describe_scope() -> Dictionary:
```

返回当前 Scope 的通用描述。

返回：描述字典。

结构：

- `return`: Dictionary，包含 scope_key、key_namespace、phase 与 restore_policy。

<a id="member-gfsavescope-methods-_can_save_scope"></a>

### `_can_save_scope`

- API：`protected`

```gdscript
func _can_save_scope(_context: Dictionary = {}) -> bool:
```

判断是否可保存。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 调用上下文字典。 |

返回：可保存时返回 true。

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavescope-methods-_can_load_scope"></a>

### `_can_load_scope`

- API：`protected`

```gdscript
func _can_load_scope(_context: Dictionary = {}) -> bool:
```

判断是否可加载。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 调用上下文字典。 |

返回：可加载时返回 true。

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavescope-methods-_before_save"></a>

### `_before_save`

- API：`protected`

```gdscript
func _before_save(_context: Dictionary = {}) -> void:
```

保存前 Hook。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 调用上下文字典。 |

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavescope-methods-_after_save"></a>

### `_after_save`

- API：`protected`

```gdscript
func _after_save(_payload: Dictionary, _context: Dictionary = {}) -> void:
```

保存后 Hook。

参数：

| 名称 | 说明 |
|---|---|
| `_payload` | 当前 Scope 载荷。 |
| `_context` | 调用上下文字典。 |

结构：

- `_payload`: Dictionary，当前 Scope 采集完成后的载荷。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavescope-methods-_before_load"></a>

### `_before_load`

- API：`protected`

```gdscript
func _before_load(_payload: Dictionary, _context: Dictionary = {}) -> void:
```

加载前 Hook。

参数：

| 名称 | 说明 |
|---|---|
| `_payload` | 当前 Scope 载荷。 |
| `_context` | 调用上下文字典。 |

结构：

- `_payload`: Dictionary，当前 Scope 待应用的载荷。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavescope-methods-_after_load"></a>

### `_after_load`

- API：`protected`

```gdscript
func _after_load(_payload: Dictionary, _context: Dictionary = {}) -> void:
```

加载后 Hook。

参数：

| 名称 | 说明 |
|---|---|
| `_payload` | 当前 Scope 载荷。 |
| `_context` | 调用上下文字典。 |

结构：

- `_payload`: Dictionary，当前 Scope 已应用的载荷。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
