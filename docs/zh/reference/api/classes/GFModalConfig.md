# GFModalConfig

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_modal_config.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用 modal 配置。 用 Resource 描述标题、正文、动作和交互策略，使项目自定义 modal 面板 可以共享同一套打开与结果协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`title`](#member-gfmodalconfig-properties-title) | `var title: String = ""` |
| 属性 | [`message`](#member-gfmodalconfig-properties-message) | `var message: String = ""` |
| 属性 | [`actions`](#member-gfmodalconfig-properties-actions) | `var actions: Array[GFModalAction] = []` |
| 属性 | [`dismiss_on_backdrop`](#member-gfmodalconfig-properties-dismiss_on_backdrop) | `var dismiss_on_backdrop: bool = false` |
| 属性 | [`dismiss_on_cancel`](#member-gfmodalconfig-properties-dismiss_on_cancel) | `var dismiss_on_cancel: bool = true` |
| 属性 | [`auto_focus`](#member-gfmodalconfig-properties-auto_focus) | `var auto_focus: bool = true` |
| 属性 | [`restore_focus_on_close`](#member-gfmodalconfig-properties-restore_focus_on_close) | `var restore_focus_on_close: bool = true` |
| 属性 | [`metadata`](#member-gfmodalconfig-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_actions`](#member-gfmodalconfig-methods-get_actions) | `func get_actions() -> Array[GFModalAction]:` |
| 方法 | [`get_action`](#member-gfmodalconfig-methods-get_action) | `func get_action(action_id: StringName) -> GFModalAction:` |
| 方法 | [`duplicate_config`](#member-gfmodalconfig-methods-duplicate_config) | `func duplicate_config() -> GFModalConfig:` |

## 属性

<a id="member-gfmodalconfig-properties-title"></a>

### `title`

- API：`public`

```gdscript
var title: String = ""
```

标题文本。

<a id="member-gfmodalconfig-properties-message"></a>

### `message`

- API：`public`

```gdscript
var message: String = ""
```

正文文本。

<a id="member-gfmodalconfig-properties-actions"></a>

### `actions`

- API：`public`

```gdscript
var actions: Array[GFModalAction] = []
```

动作列表。为空时不生成默认动作；项目应显式声明可渲染动作。

结构：

- `actions`: Array[GFModalAction]，modal 可渲染的动作声明列表。

<a id="member-gfmodalconfig-properties-dismiss_on_backdrop"></a>

### `dismiss_on_backdrop`

- API：`public`

```gdscript
var dismiss_on_backdrop: bool = false
```

点击背景是否按取消处理。

<a id="member-gfmodalconfig-properties-dismiss_on_cancel"></a>

### `dismiss_on_cancel`

- API：`public`

```gdscript
var dismiss_on_cancel: bool = true
```

取消请求是否关闭 modal。

<a id="member-gfmodalconfig-properties-auto_focus"></a>

### `auto_focus`

- API：`public`

```gdscript
var auto_focus: bool = true
```

打开时是否自动聚焦动作按钮。

<a id="member-gfmodalconfig-properties-restore_focus_on_close"></a>

### `restore_focus_on_close`

- API：`public`

```gdscript
var restore_focus_on_close: bool = true
```

关闭后是否恢复打开前焦点。

<a id="member-gfmodalconfig-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目层或自定义面板解释。

结构：

- `metadata`: Dictionary，项目层或自定义 modal 面板解释的配置元数据。

## 方法

<a id="member-gfmodalconfig-methods-get_actions"></a>

### `get_actions`

- API：`public`

```gdscript
func get_actions() -> Array[GFModalAction]:
```

获取可用动作列表。

返回：动作列表副本。

<a id="member-gfmodalconfig-methods-get_action"></a>

### `get_action`

- API：`public`

```gdscript
func get_action(action_id: StringName) -> GFModalAction:
```

查找指定动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作 ID。 |

返回：找到时返回动作副本，否则返回 null。

<a id="member-gfmodalconfig-methods-duplicate_config"></a>

### `duplicate_config`

- API：`public`

```gdscript
func duplicate_config() -> GFModalConfig:
```

创建同内容拷贝。

返回：新配置。
