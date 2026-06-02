# GFTextAutoFit

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_text_auto_fit.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

文本控件自动字体适配节点。 挂在文本控件旁边或子节点中，在控件尺寸、场景就绪或语言变化时调用 GFTextFitter。 它只负责字体尺寸计算和主题覆盖，不接管文本来源、布局策略或项目本地化规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_path`](#member-gftextautofit-properties-target_path) | `var target_path: NodePath` |
| 属性 | [`min_font_size`](#member-gftextautofit-properties-min_font_size) | `var min_font_size: int = GFTextFitter.DEFAULT_MIN_FONT_SIZE:` |
| 属性 | [`max_font_size`](#member-gftextautofit-properties-max_font_size) | `var max_font_size: int = GFTextFitter.DEFAULT_MAX_FONT_SIZE:` |
| 属性 | [`fit_width`](#member-gftextautofit-properties-fit_width) | `var fit_width: bool = true:` |
| 属性 | [`fit_height`](#member-gftextautofit-properties-fit_height) | `var fit_height: bool = true:` |
| 属性 | [`fit_on_ready`](#member-gftextautofit-properties-fit_on_ready) | `var fit_on_ready: bool = true` |
| 属性 | [`refresh_on_resize`](#member-gftextautofit-properties-refresh_on_resize) | `var refresh_on_resize: bool = true` |
| 属性 | [`refresh_on_translation_changed`](#member-gftextautofit-properties-refresh_on_translation_changed) | `var refresh_on_translation_changed: bool = true` |
| 属性 | [`deferred_refresh`](#member-gftextautofit-properties-deferred_refresh) | `var deferred_refresh: bool = true` |
| 属性 | [`options`](#member-gftextautofit-properties-options) | `var options: Dictionary = {}` |
| 方法 | [`rebind_target`](#member-gftextautofit-methods-rebind_target) | `func rebind_target() -> void:` |
| 方法 | [`request_refresh`](#member-gftextautofit-methods-request_refresh) | `func request_refresh() -> void:` |
| 方法 | [`refresh`](#member-gftextautofit-methods-refresh) | `func refresh() -> int:` |
| 方法 | [`get_target`](#member-gftextautofit-methods-get_target) | `func get_target() -> Control:` |

## 属性

<a id="member-gftextautofit-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath
```

目标 Control 路径。为空时使用父节点。

<a id="member-gftextautofit-properties-min_font_size"></a>

### `min_font_size`

- API：`public`

```gdscript
var min_font_size: int = GFTextFitter.DEFAULT_MIN_FONT_SIZE:
```

最小字体尺寸。

<a id="member-gftextautofit-properties-max_font_size"></a>

### `max_font_size`

- API：`public`

```gdscript
var max_font_size: int = GFTextFitter.DEFAULT_MAX_FONT_SIZE:
```

最大字体尺寸。小于等于 0 时使用控件当前主题字体尺寸。

<a id="member-gftextautofit-properties-fit_width"></a>

### `fit_width`

- API：`public`

```gdscript
var fit_width: bool = true:
```

是否约束宽度。

<a id="member-gftextautofit-properties-fit_height"></a>

### `fit_height`

- API：`public`

```gdscript
var fit_height: bool = true:
```

是否约束高度。

<a id="member-gftextautofit-properties-fit_on_ready"></a>

### `fit_on_ready`

- API：`public`

```gdscript
var fit_on_ready: bool = true
```

是否在进入树并解析目标后立即适配。

<a id="member-gftextautofit-properties-refresh_on_resize"></a>

### `refresh_on_resize`

- API：`public`

```gdscript
var refresh_on_resize: bool = true
```

是否监听目标控件 resized 信号。

<a id="member-gftextautofit-properties-refresh_on_translation_changed"></a>

### `refresh_on_translation_changed`

- API：`public`

```gdscript
var refresh_on_translation_changed: bool = true
```

是否在收到翻译变更通知时刷新。

<a id="member-gftextautofit-properties-deferred_refresh"></a>

### `deferred_refresh`

- API：`public`

```gdscript
var deferred_refresh: bool = true
```

是否把刷新合并到 deferred 调用，避免同帧多次尺寸变化造成重复计算。

<a id="member-gftextautofit-properties-options"></a>

### `options`

- API：`public`

```gdscript
var options: Dictionary = {}
```

可选额外配置，会合并到 GFTextFitter.fit_control() 的 options。

结构：

- `options`: Dictionary，字段同 GFTextFitter.fit_control() 的 options；节点会覆盖 min_font_size、max_font_size、fit_width、fit_height 和 apply。

## 方法

<a id="member-gftextautofit-methods-rebind_target"></a>

### `rebind_target`

- API：`public`

```gdscript
func rebind_target() -> void:
```

重新解析并绑定目标控件。

<a id="member-gftextautofit-methods-request_refresh"></a>

### `request_refresh`

- API：`public`

```gdscript
func request_refresh() -> void:
```

请求刷新文本适配。

<a id="member-gftextautofit-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh() -> int:
```

立即执行一次文本适配。

返回：计算出的字体尺寸；目标无效时返回 0。

<a id="member-gftextautofit-methods-get_target"></a>

### `get_target`

- API：`public`

```gdscript
func get_target() -> Control:
```

获取当前目标控件。

返回：已绑定的 Control；未绑定时返回 null。
