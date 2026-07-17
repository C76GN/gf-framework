# GFUIRoute

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_route.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

UI 路由资源描述。 只描述路由标识、面板场景、目标层级和默认打开选项，不规定页面业务、 动画实现或面板通信方式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`route_id`](#member-gfuiroute-properties-route_id) | `var route_id: StringName = &""` |
| 属性 | [`scene_path`](#member-gfuiroute-properties-scene_path) | `var scene_path: String = ""` |
| 属性 | [`layer`](#member-gfuiroute-properties-layer) | `var layer: int = GFUIUtility.Layer.POPUP` |
| 属性 | [`default_options`](#member-gfuiroute-properties-default_options) | `var default_options: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfuiroute-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_route_id`](#member-gfuiroute-methods-get_route_id) | `func get_route_id() -> StringName:` |
| 方法 | [`is_valid_route`](#member-gfuiroute-methods-is_valid_route) | `func is_valid_route() -> bool:` |
| 方法 | [`build_options`](#member-gfuiroute-methods-build_options) | `func build_options(params: Dictionary = {}, option_overrides: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfuiroute-properties-route_id"></a>

### `route_id`

- API：`public`

```gdscript
var route_id: StringName = &""
```

路由稳定标识。

<a id="member-gfuiroute-properties-scene_path"></a>

### `scene_path`

- API：`public`

```gdscript
var scene_path: String = ""
```

面板场景路径。

<a id="member-gfuiroute-properties-layer"></a>

### `layer`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var layer: int = GFUIUtility.Layer.POPUP
```

目标 UI 逻辑层 ID。默认使用 GFUIUtility.Layer.POPUP；自定义 ID 必须先注册到 GFUIUtility。 切换目标层不会隐式清理其他逻辑层；互斥页面应放在同一导航层并使用 replace。

<a id="member-gfuiroute-properties-default_options"></a>

### `default_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_options: Dictionary = {}
```

默认面板选项，会传给 GFUIUtility。

结构：

- `default_options`: Dictionary，字段同 GFUIUtility 打开面板 options；mode 使用 GFUIUtility.PanelMode，modal 是未提供 mode 时的布尔简写，metadata 只由项目定义并由框架复制透传。

<a id="member-gfuiroute-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary = {}
```

路由元数据。框架只复制和透传，不改变绘制、清层或 Modal 行为。

结构：

- `metadata`: Dictionary，由项目定义的路由元数据；build_options() 会追加 route_id 和 route_params。

## 方法

<a id="member-gfuiroute-methods-get_route_id"></a>

### `get_route_id`

- API：`public`

```gdscript
func get_route_id() -> StringName:
```

获取稳定路由标识。

返回：路由标识；未显式设置时尝试使用资源路径。

<a id="member-gfuiroute-methods-is_valid_route"></a>

### `is_valid_route`

- API：`public`

```gdscript
func is_valid_route() -> bool:
```

检查路由是否具备可打开的基本信息。

返回：路由有效时返回 true。

<a id="member-gfuiroute-methods-build_options"></a>

### `build_options`

- API：`public`

```gdscript
func build_options(params: Dictionary = {}, option_overrides: Dictionary = {}) -> Dictionary:
```

合并默认选项、覆盖选项和路由参数。

参数：

| 名称 | 说明 |
|---|---|
| `params` | 本次打开路由携带的参数。 |
| `option_overrides` | 本次打开路由的选项覆盖。 |

返回：合并后的 GFUIUtility 选项。

结构：

- `params`: Dictionary，由项目定义的路由参数，会复制到 metadata.route_params。
- `option_overrides`: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖 default_options。
- `return`: Dictionary，合并后的面板打开 options，至少包含 metadata.route_id，可能包含 metadata.route_params。
