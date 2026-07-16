# GFDisplaySettingsUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_display_settings_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用显示、语言与音频总线设置应用器。 该工具把抽象设置值应用到 Godot 引擎层。设置值本身由 GFSettingsUtility 管理； 未注册 GFSettingsUtility 时，也可以直接作为运行时应用器使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`display_setting_applied`](#member-gfdisplaysettingsutility-signals-display_setting_applied) | `signal display_setting_applied(key: StringName, value: Variant)` |
| 常量 | [`WINDOW_MODE_KEY`](#member-gfdisplaysettingsutility-constants-window_mode_key) | `const WINDOW_MODE_KEY: StringName = &"display/window_mode"` |
| 常量 | [`WINDOW_SIZE_KEY`](#member-gfdisplaysettingsutility-constants-window_size_key) | `const WINDOW_SIZE_KEY: StringName = &"display/window_size"` |
| 常量 | [`VSYNC_MODE_KEY`](#member-gfdisplaysettingsutility-constants-vsync_mode_key) | `const VSYNC_MODE_KEY: StringName = &"display/vsync_mode"` |
| 常量 | [`LOCALE_KEY`](#member-gfdisplaysettingsutility-constants-locale_key) | `const LOCALE_KEY: StringName = &"display/locale"` |
| 属性 | [`register_defaults_on_ready`](#member-gfdisplaysettingsutility-properties-register_defaults_on_ready) | `var register_defaults_on_ready: bool = true` |
| 属性 | [`apply_on_ready`](#member-gfdisplaysettingsutility-properties-apply_on_ready) | `var apply_on_ready: bool = true` |
| 属性 | [`auto_apply_setting_changes`](#member-gfdisplaysettingsutility-properties-auto_apply_setting_changes) | `var auto_apply_setting_changes: bool = true` |
| 属性 | [`persist_changes`](#member-gfdisplaysettingsutility-properties-persist_changes) | `var persist_changes: bool = true` |
| 属性 | [`default_windowed_size`](#member-gfdisplaysettingsutility-properties-default_windowed_size) | `var default_windowed_size: Vector2i = Vector2i.ZERO` |
| 属性 | [`audio_setting_prefix`](#member-gfdisplaysettingsutility-properties-audio_setting_prefix) | `var audio_setting_prefix: StringName = &"audio"` |
| 方法 | [`init`](#member-gfdisplaysettingsutility-methods-init) | `func init() -> void:` |
| 方法 | [`ready`](#member-gfdisplaysettingsutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfdisplaysettingsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_default_settings`](#member-gfdisplaysettingsutility-methods-register_default_settings) | `func register_default_settings() -> void:` |
| 方法 | [`apply_all`](#member-gfdisplaysettingsutility-methods-apply_all) | `func apply_all() -> void:` |
| 方法 | [`set_window_mode`](#member-gfdisplaysettingsutility-methods-set_window_mode) | `func set_window_mode(mode: DisplayServer.WindowMode) -> void:` |
| 方法 | [`get_window_mode`](#member-gfdisplaysettingsutility-methods-get_window_mode) | `func get_window_mode() -> DisplayServer.WindowMode:` |
| 方法 | [`set_fullscreen`](#member-gfdisplaysettingsutility-methods-set_fullscreen) | `func set_fullscreen(enabled: bool) -> void:` |
| 方法 | [`toggle_fullscreen`](#member-gfdisplaysettingsutility-methods-toggle_fullscreen) | `func toggle_fullscreen() -> void:` |
| 方法 | [`apply_window_mode`](#member-gfdisplaysettingsutility-methods-apply_window_mode) | `func apply_window_mode() -> void:` |
| 方法 | [`set_window_size`](#member-gfdisplaysettingsutility-methods-set_window_size) | `func set_window_size(size: Vector2i) -> void:` |
| 方法 | [`get_window_size`](#member-gfdisplaysettingsutility-methods-get_window_size) | `func get_window_size() -> Vector2i:` |
| 方法 | [`apply_window_size`](#member-gfdisplaysettingsutility-methods-apply_window_size) | `func apply_window_size() -> void:` |
| 方法 | [`set_vsync_mode`](#member-gfdisplaysettingsutility-methods-set_vsync_mode) | `func set_vsync_mode(mode: DisplayServer.VSyncMode) -> void:` |
| 方法 | [`get_vsync_mode`](#member-gfdisplaysettingsutility-methods-get_vsync_mode) | `func get_vsync_mode() -> DisplayServer.VSyncMode:` |
| 方法 | [`apply_vsync_mode`](#member-gfdisplaysettingsutility-methods-apply_vsync_mode) | `func apply_vsync_mode() -> void:` |
| 方法 | [`set_locale`](#member-gfdisplaysettingsutility-methods-set_locale) | `func set_locale(locale: String) -> void:` |
| 方法 | [`get_locale`](#member-gfdisplaysettingsutility-methods-get_locale) | `func get_locale() -> String:` |
| 方法 | [`apply_locale`](#member-gfdisplaysettingsutility-methods-apply_locale) | `func apply_locale() -> void:` |
| 方法 | [`register_audio_bus_volume`](#member-gfdisplaysettingsutility-methods-register_audio_bus_volume) | `func register_audio_bus_volume(bus_name: String, default_linear: float = 1.0) -> void:` |
| 方法 | [`set_audio_bus_volume`](#member-gfdisplaysettingsutility-methods-set_audio_bus_volume) | `func set_audio_bus_volume(bus_name: String, volume_linear: float) -> void:` |
| 方法 | [`get_audio_bus_volume`](#member-gfdisplaysettingsutility-methods-get_audio_bus_volume) | `func get_audio_bus_volume(bus_name: String, fallback: float = 1.0) -> float:` |
| 方法 | [`apply_audio_bus_volume`](#member-gfdisplaysettingsutility-methods-apply_audio_bus_volume) | `func apply_audio_bus_volume(bus_name: String) -> void:` |
| 方法 | [`apply_registered_audio_bus_volumes`](#member-gfdisplaysettingsutility-methods-apply_registered_audio_bus_volumes) | `func apply_registered_audio_bus_volumes() -> void:` |

## 信号

<a id="member-gfdisplaysettingsutility-signals-display_setting_applied"></a>

### `display_setting_applied`

- API：`public`

```gdscript
signal display_setting_applied(key: StringName, value: Variant)
```

某个引擎设置应用完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 设置键。 |
| `value` | 已应用的值。 |

结构：

- `value`: Variant，与设置键匹配的值，例如 int、Vector2i、String 或 float。

## 常量

<a id="member-gfdisplaysettingsutility-constants-window_mode_key"></a>

### `WINDOW_MODE_KEY`

- API：`public`

```gdscript
const WINDOW_MODE_KEY: StringName = &"display/window_mode"
```

窗口模式设置键。

<a id="member-gfdisplaysettingsutility-constants-window_size_key"></a>

### `WINDOW_SIZE_KEY`

- API：`public`

```gdscript
const WINDOW_SIZE_KEY: StringName = &"display/window_size"
```

窗口尺寸设置键。

<a id="member-gfdisplaysettingsutility-constants-vsync_mode_key"></a>

### `VSYNC_MODE_KEY`

- API：`public`

```gdscript
const VSYNC_MODE_KEY: StringName = &"display/vsync_mode"
```

垂直同步模式设置键。

<a id="member-gfdisplaysettingsutility-constants-locale_key"></a>

### `LOCALE_KEY`

- API：`public`

```gdscript
const LOCALE_KEY: StringName = &"display/locale"
```

语言设置键。

## 属性

<a id="member-gfdisplaysettingsutility-properties-register_defaults_on_ready"></a>

### `register_defaults_on_ready`

- API：`public`

```gdscript
var register_defaults_on_ready: bool = true
```

ready() 时是否注册默认设置定义。

<a id="member-gfdisplaysettingsutility-properties-apply_on_ready"></a>

### `apply_on_ready`

- API：`public`

```gdscript
var apply_on_ready: bool = true
```

ready() 时是否立刻应用当前设置。

<a id="member-gfdisplaysettingsutility-properties-auto_apply_setting_changes"></a>

### `auto_apply_setting_changes`

- API：`public`

```gdscript
var auto_apply_setting_changes: bool = true
```

GFSettingsUtility 中相关设置变化时是否自动应用。

<a id="member-gfdisplaysettingsutility-properties-persist_changes"></a>

### `persist_changes`

- API：`public`

```gdscript
var persist_changes: bool = true
```

设置变化时是否写入 GFSettingsUtility。

<a id="member-gfdisplaysettingsutility-properties-default_windowed_size"></a>

### `default_windowed_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var default_windowed_size: Vector2i = Vector2i.ZERO
```

非窗口模式启动且尚无持久化尺寸时使用的窗口尺寸。 任一分量小于等于 0 时，从项目窗口 override 或 viewport 尺寸推导。

<a id="member-gfdisplaysettingsutility-properties-audio_setting_prefix"></a>

### `audio_setting_prefix`

- API：`public`

```gdscript
var audio_setting_prefix: StringName = &"audio"
```

音频设置键前缀。

## 方法

<a id="member-gfdisplaysettingsutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化显示设置应用器的时间与暂停策略。

<a id="member-gfdisplaysettingsutility-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

注册默认设置、连接设置变化并按配置应用当前值。

<a id="member-gfdisplaysettingsutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放设置连接并清空运行时缓存。

<a id="member-gfdisplaysettingsutility-methods-register_default_settings"></a>

### `register_default_settings`

- API：`public`

```gdscript
func register_default_settings() -> void:
```

注册显示相关默认设置定义。

<a id="member-gfdisplaysettingsutility-methods-apply_all"></a>

### `apply_all`

- API：`public`

```gdscript
func apply_all() -> void:
```

应用所有当前已知显示设置。

<a id="member-gfdisplaysettingsutility-methods-set_window_mode"></a>

### `set_window_mode`

- API：`public`

```gdscript
func set_window_mode(mode: DisplayServer.WindowMode) -> void:
```

设置窗口模式并应用。

参数：

| 名称 | 说明 |
|---|---|
| `mode` | 目标窗口模式。 |

<a id="member-gfdisplaysettingsutility-methods-get_window_mode"></a>

### `get_window_mode`

- API：`public`

```gdscript
func get_window_mode() -> DisplayServer.WindowMode:
```

获取窗口模式设置。

返回：窗口模式。

<a id="member-gfdisplaysettingsutility-methods-set_fullscreen"></a>

### `set_fullscreen`

- API：`public`

```gdscript
func set_fullscreen(enabled: bool) -> void:
```

设置是否全屏。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | true 时切换到全屏，false 时切回窗口模式。 |

<a id="member-gfdisplaysettingsutility-methods-toggle_fullscreen"></a>

### `toggle_fullscreen`

- API：`public`

```gdscript
func toggle_fullscreen() -> void:
```

切换全屏状态。

<a id="member-gfdisplaysettingsutility-methods-apply_window_mode"></a>

### `apply_window_mode`

- API：`public`

```gdscript
func apply_window_mode() -> void:
```

应用窗口模式设置。

<a id="member-gfdisplaysettingsutility-methods-set_window_size"></a>

### `set_window_size`

- API：`public`

```gdscript
func set_window_size(size: Vector2i) -> void:
```

设置窗口尺寸并应用。

参数：

| 名称 | 说明 |
|---|---|
| `size` | 窗口尺寸。 |

<a id="member-gfdisplaysettingsutility-methods-get_window_size"></a>

### `get_window_size`

- API：`public`

```gdscript
func get_window_size() -> Vector2i:
```

获取窗口尺寸设置。

返回：窗口尺寸。

<a id="member-gfdisplaysettingsutility-methods-apply_window_size"></a>

### `apply_window_size`

- API：`public`

```gdscript
func apply_window_size() -> void:
```

应用窗口尺寸设置。

<a id="member-gfdisplaysettingsutility-methods-set_vsync_mode"></a>

### `set_vsync_mode`

- API：`public`

```gdscript
func set_vsync_mode(mode: DisplayServer.VSyncMode) -> void:
```

设置垂直同步模式并应用。

参数：

| 名称 | 说明 |
|---|---|
| `mode` | VSync 模式。 |

<a id="member-gfdisplaysettingsutility-methods-get_vsync_mode"></a>

### `get_vsync_mode`

- API：`public`

```gdscript
func get_vsync_mode() -> DisplayServer.VSyncMode:
```

获取垂直同步模式设置。

返回：VSync 模式。

<a id="member-gfdisplaysettingsutility-methods-apply_vsync_mode"></a>

### `apply_vsync_mode`

- API：`public`

```gdscript
func apply_vsync_mode() -> void:
```

应用垂直同步设置。

<a id="member-gfdisplaysettingsutility-methods-set_locale"></a>

### `set_locale`

- API：`public`

```gdscript
func set_locale(locale: String) -> void:
```

设置语言并应用。

参数：

| 名称 | 说明 |
|---|---|
| `locale` | 语言代码，例如 "en" 或 "zh_CN"。 |

<a id="member-gfdisplaysettingsutility-methods-get_locale"></a>

### `get_locale`

- API：`public`

```gdscript
func get_locale() -> String:
```

获取当前语言设置。

返回：语言代码。

<a id="member-gfdisplaysettingsutility-methods-apply_locale"></a>

### `apply_locale`

- API：`public`

```gdscript
func apply_locale() -> void:
```

应用语言设置。

<a id="member-gfdisplaysettingsutility-methods-register_audio_bus_volume"></a>

### `register_audio_bus_volume`

- API：`public`

```gdscript
func register_audio_bus_volume(bus_name: String, default_linear: float = 1.0) -> void:
```

注册一个音频总线音量设置。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 音频总线名。 |
| `default_linear` | 默认线性音量，范围 0 到 1。 |

<a id="member-gfdisplaysettingsutility-methods-set_audio_bus_volume"></a>

### `set_audio_bus_volume`

- API：`public`

```gdscript
func set_audio_bus_volume(bus_name: String, volume_linear: float) -> void:
```

设置音频总线音量并应用。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 音频总线名。 |
| `volume_linear` | 线性音量，范围 0 到 1。 |

<a id="member-gfdisplaysettingsutility-methods-get_audio_bus_volume"></a>

### `get_audio_bus_volume`

- API：`public`

```gdscript
func get_audio_bus_volume(bus_name: String, fallback: float = 1.0) -> float:
```

获取音频总线音量。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 音频总线名。 |
| `fallback` | 设置缺失时的回退值。 |

返回：线性音量。

<a id="member-gfdisplaysettingsutility-methods-apply_audio_bus_volume"></a>

### `apply_audio_bus_volume`

- API：`public`

```gdscript
func apply_audio_bus_volume(bus_name: String) -> void:
```

应用指定音频总线音量。

参数：

| 名称 | 说明 |
|---|---|
| `bus_name` | 音频总线名。 |

<a id="member-gfdisplaysettingsutility-methods-apply_registered_audio_bus_volumes"></a>

### `apply_registered_audio_bus_volumes`

- API：`public`

```gdscript
func apply_registered_audio_bus_volumes() -> void:
```

应用所有已注册音频总线音量设置。
