# GFSavePipelineStep

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/pipeline/gf_save_pipeline_step.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存档图流程步骤基类。 用于在 GFSaveGraphUtility 的 Scope 采集/应用流程前后插入通用处理。 步骤只接收 scope、payload、context 和 result，不绑定任何业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfsavepipelinestep-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfsavepipelinestep-properties-enabled) | `var enabled: bool = true` |
| 方法 | [`_before_gather_scope`](#member-gfsavepipelinestep-methods-_before_gather_scope) | `func _before_gather_scope(_scope: GFSaveScope, _context: Dictionary = {}) -> void:` |
| 方法 | [`_after_gather_scope`](#member-gfsavepipelinestep-methods-_after_gather_scope) | `func _after_gather_scope(_scope: GFSaveScope, payload: Dictionary, _context: Dictionary = {}) -> Variant:` |
| 方法 | [`_before_apply_scope`](#member-gfsavepipelinestep-methods-_before_apply_scope) | `func _before_apply_scope(_scope: GFSaveScope, payload: Dictionary, _context: Dictionary = {}) -> Variant:` |
| 方法 | [`_after_apply_scope`](#member-gfsavepipelinestep-methods-_after_apply_scope) | `func _after_apply_scope( _scope: GFSaveScope, _payload: Dictionary, result: Dictionary, _context: Dictionary = {} ) -> Variant:` |

## 属性

<a id="member-gfsavepipelinestep-properties-step_id"></a>

### `step_id`

- API：`public`

```gdscript
var step_id: StringName = &""
```

步骤标识，便于调试与项目层开关。

<a id="member-gfsavepipelinestep-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该步骤。

## 方法

<a id="member-gfsavepipelinestep-methods-_before_gather_scope"></a>

### `_before_gather_scope`

- API：`protected`

```gdscript
func _before_gather_scope(_scope: GFSaveScope, _context: Dictionary = {}) -> void:
```

采集 Scope 前调用。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Scope。 |
| `_context` | 调用上下文字典。 |

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsavepipelinestep-methods-_after_gather_scope"></a>

### `_after_gather_scope`

- API：`protected`

```gdscript
func _after_gather_scope(_scope: GFSaveScope, payload: Dictionary, _context: Dictionary = {}) -> Variant:
```

采集 Scope 后调用。返回 Dictionary 时会替换当前 payload。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Scope。 |
| `payload` | 当前 Scope 载荷。 |
| `_context` | 调用上下文字典。 |

返回：可返回 null 或替换后的 Dictionary。

结构：

- `payload`: Dictionary，当前 Scope 采集结果载荷。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Variant，返回 Dictionary 会替换当前 payload；返回 null 或非 Dictionary 表示保持不变。

<a id="member-gfsavepipelinestep-methods-_before_apply_scope"></a>

### `_before_apply_scope`

- API：`protected`

```gdscript
func _before_apply_scope(_scope: GFSaveScope, payload: Dictionary, _context: Dictionary = {}) -> Variant:
```

应用 Scope 前调用。返回 Dictionary 时会替换当前 payload。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Scope。 |
| `payload` | 当前 Scope 载荷。 |
| `_context` | 调用上下文字典。 |

返回：可返回 null 或替换后的 Dictionary。

结构：

- `payload`: Dictionary，当前 Scope 待应用载荷。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Variant，返回 Dictionary 会替换当前 payload；返回 null 或非 Dictionary 表示保持不变。

<a id="member-gfsavepipelinestep-methods-_after_apply_scope"></a>

### `_after_apply_scope`

- API：`protected`

```gdscript
func _after_apply_scope( _scope: GFSaveScope, _payload: Dictionary, result: Dictionary, _context: Dictionary = {} ) -> Variant:
```

应用 Scope 后调用。返回 Dictionary 时会替换当前 result。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前 Scope。 |
| `_payload` | 当前 Scope 载荷。 |
| `result` | 当前应用结果。 |
| `_context` | 调用上下文字典。 |

返回：可返回 null 或替换后的 Dictionary。

结构：

- `_payload`: Dictionary，当前 Scope 已应用载荷。
- `result`: Dictionary，当前应用结果，通常包含 ok、errors 与 applied_sources 等字段。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
- `return`: Variant，返回 Dictionary 会替换当前 result；返回 null 或非 Dictionary 表示保持不变。
