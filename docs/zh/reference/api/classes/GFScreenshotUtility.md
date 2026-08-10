# GFScreenshotUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_screenshot_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

通用 Viewport 截图捕获与保存工具。 提供无 UI 的截图捕获、文件保存和批量尺寸/语言截图流程。它不绑定调试面板、 上传服务、文件浏览器或项目业务命名规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`screenshot_saved`](#member-gfscreenshotutility-signals-screenshot_saved) | `signal screenshot_saved(record: Dictionary)` |
| 信号 | [`burst_started`](#member-gfscreenshotutility-signals-burst_started) | `signal burst_started(options: Dictionary)` |
| 信号 | [`burst_finished`](#member-gfscreenshotutility-signals-burst_finished) | `signal burst_finished(report: Dictionary)` |
| 常量 | [`FORMAT_PNG`](#member-gfscreenshotutility-constants-format_png) | `const FORMAT_PNG: String = "png"` |
| 常量 | [`FORMAT_JPG`](#member-gfscreenshotutility-constants-format_jpg) | `const FORMAT_JPG: String = "jpg"` |
| 常量 | [`FORMAT_WEBP`](#member-gfscreenshotutility-constants-format_webp) | `const FORMAT_WEBP: String = "webp"` |
| 常量 | [`DEFAULT_SAVE_DIR`](#member-gfscreenshotutility-constants-default_save_dir) | `const DEFAULT_SAVE_DIR: String = "user://screenshots"` |
| 常量 | [`DEFAULT_PREFIX`](#member-gfscreenshotutility-constants-default_prefix) | `const DEFAULT_PREFIX: String = "screenshot"` |
| 常量 | [`DEFAULT_MAX_BURST_CAPTURES`](#member-gfscreenshotutility-constants-default_max_burst_captures) | `const DEFAULT_MAX_BURST_CAPTURES: int = 128` |
| 属性 | [`default_save_dir`](#member-gfscreenshotutility-properties-default_save_dir) | `var default_save_dir: String = DEFAULT_SAVE_DIR` |
| 属性 | [`default_prefix`](#member-gfscreenshotutility-properties-default_prefix) | `var default_prefix: String = DEFAULT_PREFIX` |
| 属性 | [`default_format`](#member-gfscreenshotutility-properties-default_format) | `var default_format: String = FORMAT_PNG:` |
| 属性 | [`default_unique_paths`](#member-gfscreenshotutility-properties-default_unique_paths) | `var default_unique_paths: bool = true` |
| 属性 | [`default_quality`](#member-gfscreenshotutility-properties-default_quality) | `var default_quality: float = 0.9:` |
| 方法 | [`dispose`](#member-gfscreenshotutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`cancel_burst`](#member-gfscreenshotutility-methods-cancel_burst) | `func cancel_burst(reason: String = "cancelled") -> bool:` |
| 方法 | [`capture_viewport_image`](#member-gfscreenshotutility-methods-capture_viewport_image) | `func capture_viewport_image(viewport: Viewport = null) -> Image:` |
| 方法 | [`capture_viewport_png_buffer`](#member-gfscreenshotutility-methods-capture_viewport_png_buffer) | `func capture_viewport_png_buffer(viewport: Viewport = null) -> PackedByteArray:` |
| 方法 | [`save_viewport_screenshot`](#member-gfscreenshotutility-methods-save_viewport_screenshot) | `func save_viewport_screenshot(file_path: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`save_image`](#member-gfscreenshotutility-methods-save_image) | `func save_image(image: Image, file_path: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_screenshot_path`](#member-gfscreenshotutility-methods-build_screenshot_path) | `func build_screenshot_path(options: Dictionary = {}) -> String:` |
| 方法 | [`capture_burst`](#member-gfscreenshotutility-methods-capture_burst) | `func capture_burst(options: Dictionary = {}) -> Dictionary:` |

## 信号

<a id="member-gfscreenshotutility-signals-screenshot_saved"></a>

### `screenshot_saved`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
signal screenshot_saved(record: Dictionary)
```

截图文件保存成功后发出。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 保存结果记录。 |

结构：

- `record`: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。

<a id="member-gfscreenshotutility-signals-burst_started"></a>

### `burst_started`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
signal burst_started(options: Dictionary)
```

批量截图开始前发出。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 批量截图选项副本。 |

结构：

- `options`: Dictionary，capture_burst() 接收的选项副本。

<a id="member-gfscreenshotutility-signals-burst_finished"></a>

### `burst_finished`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
signal burst_finished(report: Dictionary)
```

批量截图完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 批量截图报告。 |

结构：

- `report`: Dictionary，包含 ok、records、saved_count、error_count、locale_count、resolution_count 与 format_count 字段。

## 常量

<a id="member-gfscreenshotutility-constants-format_png"></a>

### `FORMAT_PNG`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const FORMAT_PNG: String = "png"
```

PNG 截图格式。

<a id="member-gfscreenshotutility-constants-format_jpg"></a>

### `FORMAT_JPG`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const FORMAT_JPG: String = "jpg"
```

JPEG 截图格式。

<a id="member-gfscreenshotutility-constants-format_webp"></a>

### `FORMAT_WEBP`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const FORMAT_WEBP: String = "webp"
```

WebP 截图格式。

<a id="member-gfscreenshotutility-constants-default_save_dir"></a>

### `DEFAULT_SAVE_DIR`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_SAVE_DIR: String = "user://screenshots"
```

默认截图目录。

<a id="member-gfscreenshotutility-constants-default_prefix"></a>

### `DEFAULT_PREFIX`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_PREFIX: String = "screenshot"
```

默认截图文件名前缀。

<a id="member-gfscreenshotutility-constants-default_max_burst_captures"></a>

### `DEFAULT_MAX_BURST_CAPTURES`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_BURST_CAPTURES: int = 128
```

默认批量截图数量上限。传入 0 表示不限制。

## 属性

<a id="member-gfscreenshotutility-properties-default_save_dir"></a>

### `default_save_dir`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var default_save_dir: String = DEFAULT_SAVE_DIR
```

默认截图保存目录。

<a id="member-gfscreenshotutility-properties-default_prefix"></a>

### `default_prefix`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var default_prefix: String = DEFAULT_PREFIX
```

默认截图文件名前缀。

<a id="member-gfscreenshotutility-properties-default_format"></a>

### `default_format`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var default_format: String = FORMAT_PNG:
```

默认截图格式。

<a id="member-gfscreenshotutility-properties-default_unique_paths"></a>

### `default_unique_paths`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var default_unique_paths: bool = true
```

默认是否为已存在文件追加数字后缀。

<a id="member-gfscreenshotutility-properties-default_quality"></a>

### `default_quality`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var default_quality: float = 0.9:
```

JPEG/WebP 有损保存质量，范围 0.0 到 1.0。

## 方法

<a id="member-gfscreenshotutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

取消仍在执行的批量截图并恢复环境。

<a id="member-gfscreenshotutility-methods-cancel_burst"></a>

### `cancel_burst`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel_burst(reason: String = "cancelled") -> bool:
```

取消当前批量截图并立即执行环境恢复。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：当前存在活动批次且首次取消时返回 true。

<a id="member-gfscreenshotutility-methods-capture_viewport_image"></a>

### `capture_viewport_image`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func capture_viewport_image(viewport: Viewport = null) -> Image:
```

捕获 Viewport 图像。

参数：

| 名称 | 说明 |
|---|---|
| `viewport` | 目标 Viewport；为 null 时使用当前 SceneTree root。 |

返回：捕获的 Image；无可用 Viewport 时返回 null。

<a id="member-gfscreenshotutility-methods-capture_viewport_png_buffer"></a>

### `capture_viewport_png_buffer`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func capture_viewport_png_buffer(viewport: Viewport = null) -> PackedByteArray:
```

捕获 Viewport PNG 字节。

参数：

| 名称 | 说明 |
|---|---|
| `viewport` | 目标 Viewport；为 null 时使用当前 SceneTree root。 |

返回：PNG 编码字节；捕获失败时为空数组。

<a id="member-gfscreenshotutility-methods-save_viewport_screenshot"></a>

### `save_viewport_screenshot`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func save_viewport_screenshot(file_path: String = "", options: Dictionary = {}) -> Dictionary:
```

捕获并保存 Viewport 截图。

参数：

| 名称 | 说明 |
|---|---|
| `file_path` | 目标路径；为空时使用 build_screenshot_path(options)。 |
| `options` | 保存选项，支持 viewport、directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。 |

返回：保存结果记录。

结构：

- `options`: Dictionary，支持 viewport、directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
- `return`: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。

<a id="member-gfscreenshotutility-methods-save_image"></a>

### `save_image`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func save_image(image: Image, file_path: String = "", options: Dictionary = {}) -> Dictionary:
```

保存已有 Image 为截图文件。

参数：

| 名称 | 说明 |
|---|---|
| `image` | 要保存的图像。 |
| `file_path` | 目标路径；为空时使用 build_screenshot_path(options)。 |
| `options` | 保存选项，支持 directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。 |

返回：保存结果记录。

结构：

- `options`: Dictionary，支持 directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
- `return`: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。

<a id="member-gfscreenshotutility-methods-build_screenshot_path"></a>

### `build_screenshot_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func build_screenshot_path(options: Dictionary = {}) -> String:
```

构建截图保存路径。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 路径选项，支持 directory、prefix、format、timestamp、locale、resolution 与 use_subdirectories。 |

返回：截图路径。

结构：

- `options`: Dictionary，支持 directory、prefix、format、timestamp、locale、resolution 与 use_subdirectories。

<a id="member-gfscreenshotutility-methods-capture_burst"></a>

### `capture_burst`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func capture_burst(options: Dictionary = {}) -> Dictionary:
```

按尺寸、语言和格式批量保存 Viewport 截图。 该方法只负责临时切换窗口尺寸和 TranslationServer 语言，然后恢复原值；项目层仍应决定 何时调用、是否隐藏 UI、是否上传或纳入发布流程。 frame_delay_seconds 必须是有限值；max_captures=0 仍表示由受信调用方显式选择不限制。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 批量截图选项，支持 viewport、locales、resolutions、formats、max_captures、pause_tree、frame_delay_seconds、cancellation_token、directory、prefix、quality、unique 与 use_subdirectories。 |

返回：批量截图报告。

结构：

- `options`: Dictionary，支持 viewport、locales、resolutions、formats、max_captures、pause_tree、frame_delay_seconds、cancellation_token、directory、prefix、quality、unique 与 use_subdirectories。
- `return`: Dictionary，包含 ok、records、saved_count、error_count、locale_count、resolution_count、format_count、planned_count、max_captures 与 error 字段。
