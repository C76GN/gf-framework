# GFTextFitter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_text_fitter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

文本尺寸适配器。 为常见文本控件提供通用字体大小计算，不接管控件布局、主题或项目文本规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`MeasurementMode`](#member-gftextfitter-enums-measurementmode) | `enum MeasurementMode` |
| 常量 | [`DEFAULT_MIN_FONT_SIZE`](#member-gftextfitter-constants-default_min_font_size) | `const DEFAULT_MIN_FONT_SIZE: int = 8` |
| 常量 | [`DEFAULT_MAX_FONT_SIZE`](#member-gftextfitter-constants-default_max_font_size) | `const DEFAULT_MAX_FONT_SIZE: int = 64` |
| 方法 | [`fit_control`](#member-gftextfitter-methods-fit_control) | `static func fit_control(control: Control, options: Dictionary = {}) -> int:` |
| 方法 | [`fit_label`](#member-gftextfitter-methods-fit_label) | `static func fit_label(label: Label, options: Dictionary = {}) -> int:` |
| 方法 | [`fit_rich_text_label`](#member-gftextfitter-methods-fit_rich_text_label) | `static func fit_rich_text_label(label: RichTextLabel, options: Dictionary = {}) -> int:` |
| 方法 | [`measure_control_text`](#member-gftextfitter-methods-measure_control_text) | `static func measure_control_text(control: Control, font_size: int, options: Dictionary = {}) -> Vector2:` |
| 方法 | [`measure_text`](#member-gftextfitter-methods-measure_text) | `static func measure_text(control: Control, text: String, font_size: int, options: Dictionary = {}) -> Vector2:` |

## 枚举

<a id="member-gftextfitter-enums-measurementmode"></a>

### `MeasurementMode`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
enum MeasurementMode {
	## 根据控件文本布局属性选择测量路径，保持完整换行与排版语义。
	AUTO,
	## 面向不换行短文本，只在最大字号测量一次并按可用区域推导结果。
	SINGLE_LINE,
	## 强制使用完整多行排版测量。
	MULTILINE,
}
```

文本测量模式。

## 常量

<a id="member-gftextfitter-constants-default_min_font_size"></a>

### `DEFAULT_MIN_FONT_SIZE`

- API：`public`

```gdscript
const DEFAULT_MIN_FONT_SIZE: int = 8
```

默认最小字体尺寸。

<a id="member-gftextfitter-constants-default_max_font_size"></a>

### `DEFAULT_MAX_FONT_SIZE`

- API：`public`

```gdscript
const DEFAULT_MAX_FONT_SIZE: int = 64
```

默认最大字体尺寸。

## 方法

<a id="member-gftextfitter-methods-fit_control"></a>

### `fit_control`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func fit_control(control: Control, options: Dictionary = {}) -> int:
```

计算并可选应用常见 Control 的合适字体尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标文本控件，支持 Label、RichTextLabel、Button、LineEdit 与 TextEdit，也可通过 options.text 适配自定义控件。 |
| `options` | 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、text、content_insets、use_placeholder、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。 |

返回：计算出的字体尺寸；目标无效或无法读取文本时返回 0。

结构：

- `options`: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、content_insets、use_placeholder、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，SINGLE_LINE 只测量一次最大字号并按比例选择连续或候选字号，MULTILINE 强制完整多行排版；font_size_candidates 为整数候选字号数组。

<a id="member-gftextfitter-methods-fit_label"></a>

### `fit_label`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func fit_label(label: Label, options: Dictionary = {}) -> int:
```

计算并可选应用 Label 的合适字体尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `label` | 目标 Label。 |
| `options` | 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。 |

返回：计算出的字体尺寸；目标无效时返回 0。

结构：

- `options`: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，SINGLE_LINE 适用于无换行短文本的一次测量路径，MULTILINE 强制完整多行排版；font_size_candidates 为整数候选字号数组。

<a id="member-gftextfitter-methods-fit_rich_text_label"></a>

### `fit_rich_text_label`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func fit_rich_text_label(label: RichTextLabel, options: Dictionary = {}) -> int:
```

计算并可选应用 RichTextLabel 的合适字体尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `label` | 目标 RichTextLabel。 |
| `options` | 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。 |

返回：计算出的字体尺寸；目标无效时返回 0。

结构：

- `options`: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，MULTILINE 可用于显式保留完整多行排版；font_size_candidates 为整数候选字号数组。

<a id="member-gftextfitter-methods-measure_control_text"></a>

### `measure_control_text`

- API：`public`

```gdscript
static func measure_control_text(control: Control, font_size: int, options: Dictionary = {}) -> Vector2:
```

测量常见 Control 在指定字体尺寸下的文本占用。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标文本控件。 |
| `font_size` | 字体尺寸。 |
| `options` | fit_control() 使用的设置。 |

返回：文本尺寸；目标无效或字体缺失时返回 Vector2.ZERO。

结构：

- `options`: Dictionary，字段同 fit_control() 的 options。

<a id="member-gftextfitter-methods-measure_text"></a>

### `measure_text`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func measure_text(control: Control, text: String, font_size: int, options: Dictionary = {}) -> Vector2:
```

测量 Control 在指定字体尺寸下的文本占用。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 提供主题字体的控件。 |
| `text` | 待测量文本。 |
| `font_size` | 字体尺寸。 |
| `options` | fit_label() 或 fit_rich_text_label() 使用的设置。 |

返回：文本尺寸；字体缺失时返回 Vector2.ZERO。

结构：

- `options`: Dictionary，支持 available_size、fit_width、font_name、font、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。
