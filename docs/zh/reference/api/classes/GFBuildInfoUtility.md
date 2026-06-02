# GFBuildInfoUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_build_info_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

构建信息访问工具。 在运行时提供稳定的构建信息副本，供诊断、日志、存档元数据或项目 UI 查询。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`build_info`](#member-gfbuildinfoutility-properties-build_info) | `var build_info: GFBuildInfo = null` |
| 方法 | [`init`](#member-gfbuildinfoutility-methods-init) | `func init() -> void:` |
| 方法 | [`refresh`](#member-gfbuildinfoutility-methods-refresh) | `func refresh() -> GFBuildInfo:` |
| 方法 | [`set_build_info`](#member-gfbuildinfoutility-methods-set_build_info) | `func set_build_info(info: GFBuildInfo) -> void:` |
| 方法 | [`get_build_info`](#member-gfbuildinfoutility-methods-get_build_info) | `func get_build_info(copy: bool = true) -> GFBuildInfo:` |
| 方法 | [`get_build_info_dict`](#member-gfbuildinfoutility-methods-get_build_info_dict) | `func get_build_info_dict() -> Dictionary:` |
| 方法 | [`get_summary`](#member-gfbuildinfoutility-methods-get_summary) | `func get_summary() -> String:` |
| 方法 | [`get_debug_snapshot`](#member-gfbuildinfoutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfbuildinfoutility-properties-build_info"></a>

### `build_info`

- API：`public`

```gdscript
var build_info: GFBuildInfo = null
```

当前构建信息。

## 方法

<a id="member-gfbuildinfoutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

采集当前运行环境的构建信息。

<a id="member-gfbuildinfoutility-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh() -> GFBuildInfo:
```

重新采集当前运行环境的构建信息。

返回：更新后的构建信息副本。

<a id="member-gfbuildinfoutility-methods-set_build_info"></a>

### `set_build_info`

- API：`public`

```gdscript
func set_build_info(info: GFBuildInfo) -> void:
```

手动设置构建信息。

参数：

| 名称 | 说明 |
|---|---|
| `info` | 构建信息；为空时会清空当前值。 |

<a id="member-gfbuildinfoutility-methods-get_build_info"></a>

### `get_build_info`

- API：`public`

```gdscript
func get_build_info(copy: bool = true) -> GFBuildInfo:
```

获取构建信息。

参数：

| 名称 | 说明 |
|---|---|
| `copy` | 为 true 时返回深拷贝，避免调用方修改内部状态。 |

返回：构建信息。

<a id="member-gfbuildinfoutility-methods-get_build_info_dict"></a>

### `get_build_info_dict`

- API：`public`

```gdscript
func get_build_info_dict() -> Dictionary:
```

获取构建信息字典。

返回：构建信息字典。

结构：

- `return`: Dictionary，包含 GFBuildInfo.to_dict() 输出的字段；无构建信息时为空 Dictionary。

<a id="member-gfbuildinfoutility-methods-get_summary"></a>

### `get_summary`

- API：`public`

```gdscript
func get_summary() -> String:
```

获取简短版本摘要。

返回：构建信息摘要。

<a id="member-gfbuildinfoutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 available、summary 和 info 字段。
