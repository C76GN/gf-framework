# GFInputMappingDock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/editor/gf_input_mapping_dock.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

GF 输入映射工作区页面。 读取 GFInputContext 资源，展示动作、绑定与重绑定冲突诊断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_input_context`](#member-gfinputmappingdock-methods-set_input_context) | `func set_input_context(context: GFInputContext) -> void:` |
| 方法 | [`load_context_path`](#member-gfinputmappingdock-methods-load_context_path) | `func load_context_path(path: String) -> Error:` |
| 方法 | [`refresh`](#member-gfinputmappingdock-methods-refresh) | `func refresh() -> void:` |
| 方法 | [`get_last_report`](#member-gfinputmappingdock-methods-get_last_report) | `func get_last_report() -> Dictionary:` |

## 方法

<a id="member-gfinputmappingdock-methods-set_input_context"></a>

### `set_input_context`

- API：`public`

```gdscript
func set_input_context(context: GFInputContext) -> void:
```

载入输入上下文资源。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文资源。 |

<a id="member-gfinputmappingdock-methods-load_context_path"></a>

### `load_context_path`

- API：`public`

```gdscript
func load_context_path(path: String) -> Error:
```

从资源路径载入输入上下文。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入上下文资源路径。 |

返回：Godot 错误码。

<a id="member-gfinputmappingdock-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh() -> void:
```

刷新当前上下文诊断。

<a id="member-gfinputmappingdock-methods-get_last_report"></a>

### `get_last_report`

- API：`public`

```gdscript
func get_last_report() -> Dictionary:
```

获取最近一次诊断报告。

返回：诊断报告副本。

结构：

- `return`: Dictionary，基于当前 GFInputContext 构建的校验报告，包含摘要、问题计数、冲突和后续动作。
