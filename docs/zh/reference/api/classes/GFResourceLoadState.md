# GFResourceLoadState

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_load_state.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`7.0.0`

资源加载状态与引用快照。 用于把资源键、路径、加载状态、进度、错误和弱/强引用模式收敛为统一状态对象。 它不发起 ResourceLoader 请求，也不规定资源包、下载或缓存策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_UNREQUESTED`](#member-gfresourceloadstate-constants-status_unrequested) | `const STATUS_UNREQUESTED: StringName = &"unrequested"` |
| 常量 | [`STATUS_REQUESTED`](#member-gfresourceloadstate-constants-status_requested) | `const STATUS_REQUESTED: StringName = &"requested"` |
| 常量 | [`STATUS_LOADING`](#member-gfresourceloadstate-constants-status_loading) | `const STATUS_LOADING: StringName = &"loading"` |
| 常量 | [`STATUS_LOADED`](#member-gfresourceloadstate-constants-status_loaded) | `const STATUS_LOADED: StringName = &"loaded"` |
| 常量 | [`STATUS_FAILED`](#member-gfresourceloadstate-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_RELEASED`](#member-gfresourceloadstate-constants-status_released) | `const STATUS_RELEASED: StringName = &"released"` |
| 常量 | [`STATUS_STALE`](#member-gfresourceloadstate-constants-status_stale) | `const STATUS_STALE: StringName = &"stale"` |
| 常量 | [`REFERENCE_WEAK`](#member-gfresourceloadstate-constants-reference_weak) | `const REFERENCE_WEAK: StringName = &"weak"` |
| 常量 | [`REFERENCE_STRONG`](#member-gfresourceloadstate-constants-reference_strong) | `const REFERENCE_STRONG: StringName = &"strong"` |
| 属性 | [`resource_key`](#member-gfresourceloadstate-properties-resource_key) | `var resource_key: StringName = &""` |
| 属性 | [`resource_path`](#member-gfresourceloadstate-properties-resource_path) | `var resource_path: String = ""` |
| 属性 | [`status`](#member-gfresourceloadstate-properties-status) | `var status: StringName = STATUS_UNREQUESTED:` |
| 属性 | [`progress`](#member-gfresourceloadstate-properties-progress) | `var progress: float = 0.0:` |
| 属性 | [`error`](#member-gfresourceloadstate-properties-error) | `var error: String = ""` |
| 属性 | [`reference_mode`](#member-gfresourceloadstate-properties-reference_mode) | `var reference_mode: StringName = REFERENCE_WEAK:` |
| 属性 | [`metadata`](#member-gfresourceloadstate-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfresourceloadstate-methods-configure) | `func configure( p_resource_key: StringName, p_resource_path: String = "", options: Dictionary = {} ) -> GFResourceLoadState:` |
| 方法 | [`set_status`](#member-gfresourceloadstate-methods-set_status) | `func set_status(p_status: StringName, options: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`set_resource`](#member-gfresourceloadstate-methods-set_resource) | `func set_resource(resource: Resource, options: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`get_resource`](#member-gfresourceloadstate-methods-get_resource) | `func get_resource() -> Resource:` |
| 方法 | [`has_resource`](#member-gfresourceloadstate-methods-has_resource) | `func has_resource() -> bool:` |
| 方法 | [`clear_resource`](#member-gfresourceloadstate-methods-clear_resource) | `func clear_resource(options: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_requested`](#member-gfresourceloadstate-methods-mark_requested) | `func mark_requested(p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_loading`](#member-gfresourceloadstate-methods-mark_loading) | `func mark_loading(p_progress: float = 0.0, p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_loaded`](#member-gfresourceloadstate-methods-mark_loaded) | `func mark_loaded(resource: Resource, p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_failed`](#member-gfresourceloadstate-methods-mark_failed) | `func mark_failed(error_text: String, p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_released`](#member-gfresourceloadstate-methods-mark_released) | `func mark_released(p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`mark_stale`](#member-gfresourceloadstate-methods-mark_stale) | `func mark_stale(reason: String = "", p_metadata: Dictionary = {}) -> GFResourceLoadState:` |
| 方法 | [`is_success`](#member-gfresourceloadstate-methods-is_success) | `func is_success() -> bool:` |
| 方法 | [`is_terminal`](#member-gfresourceloadstate-methods-is_terminal) | `func is_terminal() -> bool:` |
| 方法 | [`to_dictionary`](#member-gfresourceloadstate-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`duplicate_state`](#member-gfresourceloadstate-methods-duplicate_state) | `func duplicate_state() -> GFResourceLoadState:` |
| 方法 | [`from_dictionary`](#member-gfresourceloadstate-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFResourceLoadState:` |

## 常量

<a id="member-gfresourceloadstate-constants-status_unrequested"></a>

### `STATUS_UNREQUESTED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_UNREQUESTED: StringName = &"unrequested"
```

尚未请求资源。

<a id="member-gfresourceloadstate-constants-status_requested"></a>

### `STATUS_REQUESTED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REQUESTED: StringName = &"requested"
```

已请求资源但尚未开始加载。

<a id="member-gfresourceloadstate-constants-status_loading"></a>

### `STATUS_LOADING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_LOADING: StringName = &"loading"
```

资源正在加载。

<a id="member-gfresourceloadstate-constants-status_loaded"></a>

### `STATUS_LOADED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_LOADED: StringName = &"loaded"
```

资源已加载。

<a id="member-gfresourceloadstate-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

资源加载失败。

<a id="member-gfresourceloadstate-constants-status_released"></a>

### `STATUS_RELEASED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_RELEASED: StringName = &"released"
```

资源引用已释放。

<a id="member-gfresourceloadstate-constants-status_stale"></a>

### `STATUS_STALE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_STALE: StringName = &"stale"
```

资源状态已过期，需要调用方重新解析或加载。

<a id="member-gfresourceloadstate-constants-reference_weak"></a>

### `REFERENCE_WEAK`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const REFERENCE_WEAK: StringName = &"weak"
```

只保存弱引用。

<a id="member-gfresourceloadstate-constants-reference_strong"></a>

### `REFERENCE_STRONG`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const REFERENCE_STRONG: StringName = &"strong"
```

保存强引用，由状态对象持有资源。

## 属性

<a id="member-gfresourceloadstate-properties-resource_key"></a>

### `resource_key`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var resource_key: StringName = &""
```

稳定资源键。

<a id="member-gfresourceloadstate-properties-resource_path"></a>

### `resource_path`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var resource_path: String = ""
```

资源路径或解析后的路径。

<a id="member-gfresourceloadstate-properties-status"></a>

### `status`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var status: StringName = STATUS_UNREQUESTED:
```

当前加载状态。

<a id="member-gfresourceloadstate-properties-progress"></a>

### `progress`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var progress: float = 0.0:
```

加载进度，范围 0 到 1。

<a id="member-gfresourceloadstate-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var error: String = ""
```

最近错误文本。

<a id="member-gfresourceloadstate-properties-reference_mode"></a>

### `reference_mode`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var reference_mode: StringName = REFERENCE_WEAK:
```

资源引用模式。

<a id="member-gfresourceloadstate-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary for caller-defined resource state metadata.

## 方法

<a id="member-gfresourceloadstate-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_resource_key: StringName, p_resource_path: String = "", options: Dictionary = {} ) -> GFResourceLoadState:
```

配置资源加载状态。

参数：

| 名称 | 说明 |
|---|---|
| `p_resource_key` | 稳定资源键。 |
| `p_resource_path` | 资源路径。 |
| `options` | 状态选项，支持 status、progress、error、reference_mode 和 metadata。 |

返回：当前状态。

结构：

- `options`: Dictionary，可包含 status: StringName、progress: float、error: String、reference_mode: StringName、metadata: Dictionary。

<a id="member-gfresourceloadstate-methods-set_status"></a>

### `set_status`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_status(p_status: StringName, options: Dictionary = {}) -> GFResourceLoadState:
```

设置状态并按需合并 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `p_status` | 新状态。 |
| `options` | 状态选项，支持 progress、error、metadata 和 clear_error。 |

返回：当前状态。

结构：

- `options`: Dictionary，可包含 progress: float、error: String、metadata: Dictionary、clear_error: bool。

<a id="member-gfresourceloadstate-methods-set_resource"></a>

### `set_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_resource(resource: Resource, options: Dictionary = {}) -> GFResourceLoadState:
```

设置当前资源引用。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 已加载资源；为空时会清除引用。 |
| `options` | 引用选项，支持 reference_mode 和 metadata。 |

返回：当前状态。

结构：

- `options`: Dictionary，可包含 reference_mode: StringName 和 metadata: Dictionary。

<a id="member-gfresourceloadstate-methods-get_resource"></a>

### `get_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_resource() -> Resource:
```

获取当前资源引用。

返回：当前资源；弱引用已释放时返回 null。

<a id="member-gfresourceloadstate-methods-has_resource"></a>

### `has_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_resource() -> bool:
```

检查当前状态是否仍能取得资源。

返回：资源引用仍有效时返回 true。

<a id="member-gfresourceloadstate-methods-clear_resource"></a>

### `clear_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_resource(options: Dictionary = {}) -> GFResourceLoadState:
```

清除当前资源引用。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 清除选项，支持 status 和 metadata。 |

返回：当前状态。

结构：

- `options`: Dictionary，可包含 status: StringName 和 metadata: Dictionary。

<a id="member-gfresourceloadstate-methods-mark_requested"></a>

### `mark_requested`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_requested(p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记资源已请求。

参数：

| 名称 | 说明 |
|---|---|
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-mark_loading"></a>

### `mark_loading`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_loading(p_progress: float = 0.0, p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记资源正在加载。

参数：

| 名称 | 说明 |
|---|---|
| `p_progress` | 加载进度。 |
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-mark_loaded"></a>

### `mark_loaded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_loaded(resource: Resource, p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记资源已加载并保存引用。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 已加载资源。 |
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-mark_failed"></a>

### `mark_failed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_failed(error_text: String, p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记加载失败。

参数：

| 名称 | 说明 |
|---|---|
| `error_text` | 错误文本。 |
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-mark_released"></a>

### `mark_released`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_released(p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记资源已释放。

参数：

| 名称 | 说明 |
|---|---|
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-mark_stale"></a>

### `mark_stale`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_stale(reason: String = "", p_metadata: Dictionary = {}) -> GFResourceLoadState:
```

标记资源状态已过期。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 过期原因。 |
| `p_metadata` | 调用方元数据。 |

返回：当前状态。

结构：

- `p_metadata`: Dictionary merged into metadata.

<a id="member-gfresourceloadstate-methods-is_success"></a>

### `is_success`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_success() -> bool:
```

检查当前状态是否为成功终态。

返回：成功加载且资源引用有效时返回 true。

<a id="member-gfresourceloadstate-methods-is_terminal"></a>

### `is_terminal`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_terminal() -> bool:
```

检查当前状态是否为终态。

返回：loaded、failed 或 released 时返回 true。

<a id="member-gfresourceloadstate-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

导出状态字典。

返回：状态字典。

结构：

- `return`: Dictionary，包含 resource_key、resource_path、status、progress、error、reference_mode、has_resource、resource_instance_id 和 metadata。

<a id="member-gfresourceloadstate-methods-duplicate_state"></a>

### `duplicate_state`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_state() -> GFResourceLoadState:
```

复制状态对象；当前资源引用会以相同引用模式传递。

返回：状态副本。

<a id="member-gfresourceloadstate-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFResourceLoadState:
```

从字典恢复状态对象。资源引用不会从字典中恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | to_dictionary() 兼容字典。 |

返回：状态对象。

结构：

- `data`: Dictionary with resource_key, resource_path, status, progress, error, reference_mode and metadata.
