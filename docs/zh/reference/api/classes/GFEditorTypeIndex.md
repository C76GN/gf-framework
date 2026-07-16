# GFEditorTypeIndex

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_type_index.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器侧 GF 类型查询工具。 集中扫描 class_name 脚本与能力场景，供代码生成器和 Inspector 工具复用。 默认实例只使用短生命周期缓存；需要监听 EditorFileSystem 变更时必须显式绑定 owner 启用 live 失效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_SCAN_DEPTH`](#member-gfeditortypeindex-constants-default_max_scan_depth) | `const DEFAULT_MAX_SCAN_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_SCANNED_SCENES`](#member-gfeditortypeindex-constants-default_max_scanned_scenes) | `const DEFAULT_MAX_SCANNED_SCENES: int = 10000` |
| 方法 | [`collect_scripts_extending`](#member-gfeditortypeindex-methods-collect_scripts_extending) | `func collect_scripts_extending(base_script: Script, excluded_scripts: Array[Script] = []) -> Array[Dictionary]:` |
| 方法 | [`collect_scene_roots_extending`](#member-gfeditortypeindex-methods-collect_scene_roots_extending) | `func collect_scene_roots_extending( base_script: Script, used_paths: Dictionary = {}, root_paths: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`get_scene_root_script`](#member-gfeditortypeindex-methods-get_scene_root_script) | `func get_scene_root_script(path: String) -> Script:` |
| 方法 | [`clear_cache`](#member-gfeditortypeindex-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`enable_live_invalidation`](#member-gfeditortypeindex-methods-enable_live_invalidation) | `func enable_live_invalidation(owner: Object) -> bool:` |
| 方法 | [`disable_live_invalidation`](#member-gfeditortypeindex-methods-disable_live_invalidation) | `func disable_live_invalidation() -> void:` |
| 方法 | [`is_live_invalidation_enabled`](#member-gfeditortypeindex-methods-is_live_invalidation_enabled) | `func is_live_invalidation_enabled() -> bool:` |
| 方法 | [`dispose`](#member-gfeditortypeindex-methods-dispose) | `func dispose() -> void:` |

## 常量

<a id="member-gfeditortypeindex-constants-default_max_scan_depth"></a>

### `DEFAULT_MAX_SCAN_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_SCAN_DEPTH: int = 32
```

默认最大扫描深度。

<a id="member-gfeditortypeindex-constants-default_max_scanned_scenes"></a>

### `DEFAULT_MAX_SCANNED_SCENES`

- API：`public`

```gdscript
const DEFAULT_MAX_SCANNED_SCENES: int = 10000
```

默认最大扫描场景数。

## 方法

<a id="member-gfeditortypeindex-methods-collect_scripts_extending"></a>

### `collect_scripts_extending`

- API：`public`

```gdscript
func collect_scripts_extending(base_script: Script, excluded_scripts: Array[Script] = []) -> Array[Dictionary]:
```

收集继承指定脚本基类的全局脚本类。

参数：

| 名称 | 说明 |
|---|---|
| `base_script` | 要匹配的基类脚本。 |
| `excluded_scripts` | 收集类型时需要排除的脚本列表。 |

返回：匹配脚本记录列表。

结构：

- `return`: Array of Dictionary script records with class_name, path, and script.

<a id="member-gfeditortypeindex-methods-collect_scene_roots_extending"></a>

### `collect_scene_roots_extending`

- API：`public`

```gdscript
func collect_scene_roots_extending( base_script: Script, used_paths: Dictionary = {}, root_paths: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Array[Dictionary]:
```

收集根脚本继承指定基类的场景。

参数：

| 名称 | 说明 |
|---|---|
| `base_script` | 要匹配的基类脚本。 |
| `used_paths` | 已使用的资源路径集合。 |
| `root_paths` | 可选扫描根路径；为空时扫描整个资源树。 |
| `options` | 可选参数，支持 max_scan_depth 与 max_scanned_scenes。 |

返回：匹配场景记录列表。

结构：

- `used_paths`: Dictionary keyed by already consumed resource path.
- `options`: Dictionary with optional max_scan_depth and max_scanned_scenes.
- `return`: Array of Dictionary scene root records with path, root_script, and class metadata.

<a id="member-gfeditortypeindex-methods-get_scene_root_script"></a>

### `get_scene_root_script`

- API：`public`

```gdscript
func get_scene_root_script(path: String) -> Script:
```

获取 PackedScene 根节点脚本。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或状态路径。 |

返回：根节点脚本；无法解析时返回 null。

<a id="member-gfeditortypeindex-methods-clear_cache"></a>

### `clear_cache`

- API：`public`

```gdscript
func clear_cache() -> void:
```

清空脚本和场景根脚本缓存。

<a id="member-gfeditortypeindex-methods-enable_live_invalidation"></a>

### `enable_live_invalidation`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func enable_live_invalidation(owner: Object) -> bool:
```

启用 EditorFileSystem 变更驱动的 live 缓存失效。 短生命周期扫描不需要调用该方法；长期持有的编辑器工具应传入自己的生命周期 owner。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | live 订阅生命周期 owner。 |

返回：成功进入 live 缓存失效模式时返回 true。

<a id="member-gfeditortypeindex-methods-disable_live_invalidation"></a>

### `disable_live_invalidation`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func disable_live_invalidation() -> void:
```

停止 EditorFileSystem 变更驱动的 live 缓存失效。

<a id="member-gfeditortypeindex-methods-is_live_invalidation_enabled"></a>

### `is_live_invalidation_enabled`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_live_invalidation_enabled() -> bool:
```

返回当前是否处于 live 缓存失效模式。

返回：至少存在一个活动 live 订阅时返回 true。

<a id="member-gfeditortypeindex-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

释放类型索引持有的编辑器信号订阅和缓存。
