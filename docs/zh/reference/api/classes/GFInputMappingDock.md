# GFInputMappingDock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/editor/gf_input_mapping_dock.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

GF 输入映射工作区页面。 读取 GFInputContext 资源，展示默认绑定或可选 GFInputRemapConfig 覆盖后的 有效动作、绑定与重绑定冲突诊断。页面只读，不修改 InputMap 或重映射配置。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_input_context`](#member-gfinputmappingdock-methods-set_input_context) | `func set_input_context(context: GFInputContext) -> void:` |
| 方法 | [`set_remap_config`](#member-gfinputmappingdock-methods-set_remap_config) | `func set_remap_config(config: GFInputRemapConfig) -> void:` |
| 方法 | [`get_remap_config`](#member-gfinputmappingdock-methods-get_remap_config) | `func get_remap_config() -> GFInputRemapConfig:` |
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

<a id="member-gfinputmappingdock-methods-set_remap_config"></a>

### `set_remap_config`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_remap_config(config: GFInputRemapConfig) -> void:
```

设置诊断使用的可选重映射配置。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 玩家或项目层重映射配置；null 表示只诊断默认绑定。 |

<a id="member-gfinputmappingdock-methods-get_remap_config"></a>

### `get_remap_config`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_remap_config() -> GFInputRemapConfig:
```

获取当前诊断使用的重映射配置。

返回：当前重映射配置；未配置时为 null。

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
- 首次版本：`3.17.0`

```gdscript
func get_last_report() -> Dictionary:
```

获取最近一次诊断报告。

返回：诊断报告副本。

结构：

- `return`: Dictionary，基于当前 GFInputContext 与可选 GFInputRemapConfig 构建的校验报告，包含摘要、问题计数、冲突、remap_configured 和后续动作。
