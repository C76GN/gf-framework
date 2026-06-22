# GFInputContextDiagnostics

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_context_diagnostics.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.2.0`

输入上下文资源诊断工具。 只读取 GFInputContext / GFInputMapping / GFInputBinding 资源和可选重映射配置， 不参与运行时输入派发。适合编辑器页面、CI、项目设置界面或自定义工具复用同一套 结构校验与绑定冲突报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`build_context_report`](#member-gfinputcontextdiagnostics-methods-build_context_report) | `static func build_context_report( context: GFInputContext, remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_contexts_report`](#member-gfinputcontextdiagnostics-methods-build_contexts_report) | `static func build_contexts_report( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`collect_structure_issues`](#member-gfinputcontextdiagnostics-methods-collect_structure_issues) | `static func collect_structure_issues(context: GFInputContext, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`get_next_actions`](#member-gfinputcontextdiagnostics-methods-get_next_actions) | `static func get_next_actions() -> Dictionary:` |

## 方法

<a id="member-gfinputcontextdiagnostics-methods-build_context_report"></a>

### `build_context_report`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func build_context_report( context: GFInputContext, remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true, options: Dictionary = {} ) -> Dictionary:
```

构建单个输入上下文诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文。 |
| `remap_config` | 可选重映射配置。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |
| `options` | 可选诊断设置，支持 include_project_input_map_checks。 |

返回：标准诊断报告字典。

结构：

- `options`: Dictionary with optional `include_project_input_map_checks: bool`.
- `return`: Dictionary report payload with context, mapping, binding, conflict, item, and issue fields.

<a id="member-gfinputcontextdiagnostics-methods-build_contexts_report"></a>

### `build_contexts_report`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func build_contexts_report( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true, options: Dictionary = {} ) -> Dictionary:
```

构建多个输入上下文诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 输入上下文列表。 |
| `remap_config` | 可选重映射配置。 |
| `include_cross_context` | 是否报告跨上下文绑定冲突。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |
| `options` | 可选诊断设置，支持 include_project_input_map_checks。 |

返回：标准诊断报告字典。

结构：

- `contexts`: Array[GFInputContext] of contexts to inspect.
- `options`: Dictionary with optional `include_project_input_map_checks: bool`.
- `return`: Dictionary report payload with context, mapping, binding, conflict, item, and issue fields.

<a id="member-gfinputcontextdiagnostics-methods-collect_structure_issues"></a>

### `collect_structure_issues`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func collect_structure_issues(context: GFInputContext, options: Dictionary = {}) -> Array[Dictionary]:
```

收集单个输入上下文的结构问题。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文。 |
| `options` | 可选诊断设置，支持 include_project_input_map_checks。 |

返回：结构问题列表。

结构：

- `options`: Dictionary with optional `include_project_input_map_checks: bool`.
- `return`: Array[Dictionary] of standardized validation issue payloads.

<a id="member-gfinputcontextdiagnostics-methods-get_next_actions"></a>

### `get_next_actions`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func get_next_actions() -> Dictionary:
```

获取输入诊断问题的默认下一步建议。

返回：按问题 kind 索引的建议文本。

结构：

- `return`: Dictionary keyed by issue kind with action text.
