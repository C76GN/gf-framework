# GFModalAction

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_modal_action.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用 modal 动作声明。 描述一个可由 UI 渲染的操作，不绑定具体按钮样式、业务命令或页面类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action_id`](#member-gfmodalaction-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`label`](#member-gfmodalaction-properties-label) | `var label: String = ""` |
| 属性 | [`result_status`](#member-gfmodalaction-properties-result_status) | `var result_status: StringName = GFModalResult.STATUS_DISMISSED` |
| 属性 | [`payload`](#member-gfmodalaction-properties-payload) | `var payload: Variant = null` |
| 属性 | [`grab_focus`](#member-gfmodalaction-properties-grab_focus) | `var grab_focus: bool = false` |
| 属性 | [`close_on_pressed`](#member-gfmodalaction-properties-close_on_pressed) | `var close_on_pressed: bool = true` |
| 属性 | [`metadata`](#member-gfmodalaction-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`make_result`](#member-gfmodalaction-methods-make_result) | `func make_result(context: Dictionary = {}) -> GFModalResult:` |
| 方法 | [`duplicate_action`](#member-gfmodalaction-methods-duplicate_action) | `func duplicate_action() -> GFModalAction:` |

## 属性

<a id="member-gfmodalaction-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

动作 ID。为空表示项目尚未声明具体动作。

<a id="member-gfmodalaction-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

项目可选显示文本。

<a id="member-gfmodalaction-properties-result_status"></a>

### `result_status`

- API：`public`

```gdscript
var result_status: StringName = GFModalResult.STATUS_DISMISSED
```

触发动作后产生的结果状态。

<a id="member-gfmodalaction-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

动作携带的通用载荷。

结构：

- `payload`: Variant，项目自定义动作载荷，会复制到 GFModalResult。

<a id="member-gfmodalaction-properties-grab_focus"></a>

### `grab_focus`

- API：`public`

```gdscript
var grab_focus: bool = false
```

是否作为默认聚焦动作。

<a id="member-gfmodalaction-properties-close_on_pressed"></a>

### `close_on_pressed`

- API：`public`

```gdscript
var close_on_pressed: bool = true
```

触发后是否关闭 modal。

<a id="member-gfmodalaction-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目层或自定义 modal 面板解释。

结构：

- `metadata`: Dictionary，项目层或自定义 modal 面板解释的动作元数据。

## 方法

<a id="member-gfmodalaction-methods-make_result"></a>

### `make_result`

- API：`public`

```gdscript
func make_result(context: Dictionary = {}) -> GFModalResult:
```

创建该动作对应的结果。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 打开 modal 时传入的调用上下文。 |

返回：结果实例。

结构：

- `context`: Dictionary，打开 modal 时传入并复制到结果中的调用上下文。

<a id="member-gfmodalaction-methods-duplicate_action"></a>

### `duplicate_action`

- API：`public`

```gdscript
func duplicate_action() -> GFModalAction:
```

创建同内容拷贝。

返回：新动作声明。
