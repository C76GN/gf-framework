# GFPlatformRuntimeContext

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_runtime_context.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台运行时上下文。 聚合平台标识、adapter 标识、能力集合、显示信息、存储根和启动参数。该资源只 记录 adapter 提供的事实，不调用 SDK、不执行登录、不创建网络连接。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`platform_id`](#member-gfplatformruntimecontext-properties-platform_id) | `var platform_id: StringName = &""` |
| 属性 | [`adapter_id`](#member-gfplatformruntimecontext-properties-adapter_id) | `var adapter_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfplatformruntimecontext-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`capabilities`](#member-gfplatformruntimecontext-properties-capabilities) | `var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new()` |
| 属性 | [`locale`](#member-gfplatformruntimecontext-properties-locale) | `var locale: String = ""` |
| 属性 | [`fallback_locale`](#member-gfplatformruntimecontext-properties-fallback_locale) | `var fallback_locale: String = ""` |
| 属性 | [`pixel_ratio`](#member-gfplatformruntimecontext-properties-pixel_ratio) | `var pixel_ratio: float = 1.0` |
| 属性 | [`window_size`](#member-gfplatformruntimecontext-properties-window_size) | `var window_size: Vector2i = Vector2i.ZERO` |
| 属性 | [`screen_size`](#member-gfplatformruntimecontext-properties-screen_size) | `var screen_size: Vector2i = Vector2i.ZERO` |
| 属性 | [`safe_area`](#member-gfplatformruntimecontext-properties-safe_area) | `var safe_area: Rect2i = Rect2i()` |
| 属性 | [`storage_roots`](#member-gfplatformruntimecontext-properties-storage_roots) | `var storage_roots: Dictionary = {}` |
| 属性 | [`launch_options`](#member-gfplatformruntimecontext-properties-launch_options) | `var launch_options: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfplatformruntimecontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformruntimecontext-methods-configure) | `func configure(p_platform_id: StringName, options: Dictionary = {}) -> GFPlatformRuntimeContext:` |
| 方法 | [`set_capabilities`](#member-gfplatformruntimecontext-methods-set_capabilities) | `func set_capabilities(p_capabilities: GFPlatformCapabilitySet) -> GFPlatformRuntimeContext:` |
| 方法 | [`add_capability`](#member-gfplatformruntimecontext-methods-add_capability) | `func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:` |
| 方法 | [`has_capability`](#member-gfplatformruntimecontext-methods-has_capability) | `func has_capability(capability_id: StringName) -> bool:` |
| 方法 | [`set_window_info`](#member-gfplatformruntimecontext-methods-set_window_info) | `func set_window_info( p_window_size: Vector2i, p_screen_size: Vector2i = Vector2i.ZERO, p_pixel_ratio: float = 1.0, p_safe_area: Rect2i = Rect2i() ) -> GFPlatformRuntimeContext:` |
| 方法 | [`set_storage_root`](#member-gfplatformruntimecontext-methods-set_storage_root) | `func set_storage_root(root_id: StringName, root_path: String) -> bool:` |
| 方法 | [`get_storage_root`](#member-gfplatformruntimecontext-methods-get_storage_root) | `func get_storage_root(root_id: StringName, default_value: String = "") -> String:` |
| 方法 | [`erase_storage_root`](#member-gfplatformruntimecontext-methods-erase_storage_root) | `func erase_storage_root(root_id: StringName) -> bool:` |
| 方法 | [`make_compatibility_profile`](#member-gfplatformruntimecontext-methods-make_compatibility_profile) | `func make_compatibility_profile(profile_id: StringName = &"") -> GFCompatibilityProfile:` |
| 方法 | [`to_dict`](#member-gfplatformruntimecontext-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformruntimecontext-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_context`](#member-gfplatformruntimecontext-methods-duplicate_context) | `func duplicate_context() -> GFPlatformRuntimeContext:` |
| 方法 | [`from_dict`](#member-gfplatformruntimecontext-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformRuntimeContext:` |

## 属性

<a id="member-gfplatformruntimecontext-properties-platform_id"></a>

### `platform_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var platform_id: StringName = &""
```

平台标识。

<a id="member-gfplatformruntimecontext-properties-adapter_id"></a>

### `adapter_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var adapter_id: StringName = &""
```

Adapter 标识。

<a id="member-gfplatformruntimecontext-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var display_name: String = ""
```

平台展示名。

<a id="member-gfplatformruntimecontext-properties-capabilities"></a>

### `capabilities`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new()
```

能力集合。

<a id="member-gfplatformruntimecontext-properties-locale"></a>

### `locale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var locale: String = ""
```

Godot locale。

<a id="member-gfplatformruntimecontext-properties-fallback_locale"></a>

### `fallback_locale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var fallback_locale: String = ""
```

fallback Godot locale。

<a id="member-gfplatformruntimecontext-properties-pixel_ratio"></a>

### `pixel_ratio`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var pixel_ratio: float = 1.0
```

平台像素比。

<a id="member-gfplatformruntimecontext-properties-window_size"></a>

### `window_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var window_size: Vector2i = Vector2i.ZERO
```

逻辑窗口尺寸。

<a id="member-gfplatformruntimecontext-properties-screen_size"></a>

### `screen_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var screen_size: Vector2i = Vector2i.ZERO
```

物理屏幕尺寸。

<a id="member-gfplatformruntimecontext-properties-safe_area"></a>

### `safe_area`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var safe_area: Rect2i = Rect2i()
```

平台安全区域。

<a id="member-gfplatformruntimecontext-properties-storage_roots"></a>

### `storage_roots`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var storage_roots: Dictionary = {}
```

逻辑存储根映射。

结构：

- `storage_roots`: Dictionary[String, String]，key 为逻辑 root_id。

<a id="member-gfplatformruntimecontext-properties-launch_options"></a>

### `launch_options`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var launch_options: Dictionary = {}
```

启动参数。

结构：

- `launch_options`: Dictionary adapter-defined launch options.

<a id="member-gfplatformruntimecontext-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined runtime metadata.

## 方法

<a id="member-gfplatformruntimecontext-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure(p_platform_id: StringName, options: Dictionary = {}) -> GFPlatformRuntimeContext:
```

配置运行时上下文。

参数：

| 名称 | 说明 |
|---|---|
| `p_platform_id` | 平台标识。 |
| `options` | 上下文选项。 |

返回：当前上下文。

结构：

- `options`: Dictionary，可包含 adapter_id、display_name、locale、fallback_locale、capabilities、capability_ids、window_size、screen_size、safe_area、pixel_ratio、storage_roots、launch_options 和 metadata。

<a id="member-gfplatformruntimecontext-methods-set_capabilities"></a>

### `set_capabilities`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_capabilities(p_capabilities: GFPlatformCapabilitySet) -> GFPlatformRuntimeContext:
```

设置能力集合。

参数：

| 名称 | 说明 |
|---|---|
| `p_capabilities` | 能力集合。 |

返回：当前上下文。

<a id="member-gfplatformruntimecontext-methods-add_capability"></a>

### `add_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:
```

添加能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |
| `capability_limits` | 能力限制字段。 |

返回：成功添加或已存在时返回 true。

结构：

- `capability_limits`: Dictionary capability limits.

<a id="member-gfplatformruntimecontext-methods-has_capability"></a>

### `has_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_capability(capability_id: StringName) -> bool:
```

检查能力是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |

返回：存在返回 true。

<a id="member-gfplatformruntimecontext-methods-set_window_info"></a>

### `set_window_info`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_window_info( p_window_size: Vector2i, p_screen_size: Vector2i = Vector2i.ZERO, p_pixel_ratio: float = 1.0, p_safe_area: Rect2i = Rect2i() ) -> GFPlatformRuntimeContext:
```

设置窗口与显示信息。

参数：

| 名称 | 说明 |
|---|---|
| `p_window_size` | 逻辑窗口尺寸。 |
| `p_screen_size` | 物理屏幕尺寸。 |
| `p_pixel_ratio` | 平台像素比。 |
| `p_safe_area` | 平台安全区域。 |

返回：当前上下文。

<a id="member-gfplatformruntimecontext-methods-set_storage_root"></a>

### `set_storage_root`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_storage_root(root_id: StringName, root_path: String) -> bool:
```

设置逻辑存储根路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_id` | 逻辑 root ID。 |
| `root_path` | 平台路径。 |

返回：写入成功返回 true。

<a id="member-gfplatformruntimecontext-methods-get_storage_root"></a>

### `get_storage_root`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_storage_root(root_id: StringName, default_value: String = "") -> String:
```

读取逻辑存储根路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_id` | 逻辑 root ID。 |
| `default_value` | 缺失时返回的默认路径。 |

返回：平台路径。

<a id="member-gfplatformruntimecontext-methods-erase_storage_root"></a>

### `erase_storage_root`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func erase_storage_root(root_id: StringName) -> bool:
```

移除逻辑存储根路径。

参数：

| 名称 | 说明 |
|---|---|
| `root_id` | 逻辑 root ID。 |

返回：找到并移除时返回 true。

<a id="member-gfplatformruntimecontext-methods-make_compatibility_profile"></a>

### `make_compatibility_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_compatibility_profile(profile_id: StringName = &"") -> GFCompatibilityProfile:
```

创建兼容性 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | Profile ID；为空时使用 platform_id。 |

返回：兼容性 Profile。

<a id="member-gfplatformruntimecontext-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：平台上下文字典。

结构：

- `return`: Dictionary platform runtime context.

<a id="member-gfplatformruntimecontext-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用平台上下文字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 平台上下文字典。 |

结构：

- `data`: Dictionary platform runtime context.

<a id="member-gfplatformruntimecontext-methods-duplicate_context"></a>

### `duplicate_context`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_context() -> GFPlatformRuntimeContext:
```

创建运行时上下文深拷贝。

返回：新运行时上下文。

<a id="member-gfplatformruntimecontext-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformRuntimeContext:
```

从字典创建运行时上下文。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 平台上下文字典。 |

返回：新运行时上下文。

结构：

- `data`: Dictionary platform runtime context.
