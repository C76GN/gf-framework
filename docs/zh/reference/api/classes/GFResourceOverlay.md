# GFResourceOverlay

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_overlay.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`7.0.0`

通用资源覆盖链。 通过 base Resource 与一组 GFResourcePropertyPatch 构建资源变体。 覆盖链只关心属性差异和应用顺序，不绑定主题、材质、皮肤或项目目录策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`base_resource`](#member-gfresourceoverlay-properties-base_resource) | `var base_resource: Resource = null` |
| 属性 | [`patches`](#member-gfresourceoverlay-properties-patches) | `var patches: Array = []` |
| 属性 | [`metadata`](#member-gfresourceoverlay-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`duplicate_base_on_resolve`](#member-gfresourceoverlay-properties-duplicate_base_on_resolve) | `var duplicate_base_on_resolve: bool = true` |
| 属性 | [`require_existing_property`](#member-gfresourceoverlay-properties-require_existing_property) | `var require_existing_property: bool = true` |
| 属性 | [`copy_values`](#member-gfresourceoverlay-properties-copy_values) | `var copy_values: bool = true` |
| 属性 | [`duplicate_resources`](#member-gfresourceoverlay-properties-duplicate_resources) | `var duplicate_resources: bool = false` |
| 属性 | [`skip_unchanged`](#member-gfresourceoverlay-properties-skip_unchanged) | `var skip_unchanged: bool = false` |
| 方法 | [`configure`](#member-gfresourceoverlay-methods-configure) | `func configure( p_base_resource: Resource, p_patches: Array = [], p_metadata: Dictionary = {} ) -> GFResourceOverlay:` |
| 方法 | [`add_patch`](#member-gfresourceoverlay-methods-add_patch) | `func add_patch(patch: GFResourcePropertyPatch) -> bool:` |
| 方法 | [`clear_patches`](#member-gfresourceoverlay-methods-clear_patches) | `func clear_patches() -> void:` |
| 方法 | [`resolve`](#member-gfresourceoverlay-methods-resolve) | `func resolve(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_to`](#member-gfresourceoverlay-methods-apply_to) | `func apply_to(target: Object, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_patch_count`](#member-gfresourceoverlay-methods-get_patch_count) | `func get_patch_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourceoverlay-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfresourceoverlay-properties-base_resource"></a>

### `base_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var base_resource: Resource = null
```

覆盖链的来源资源。

<a id="member-gfresourceoverlay-properties-patches"></a>

### `patches`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var patches: Array = []
```

按顺序应用的属性补丁列表。

结构：

- `patches`: Array[GFResourcePropertyPatch]，越靠后的补丁优先级越高。

<a id="member-gfresourceoverlay-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。GF 不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，项目工具或编辑器 UI 自行读取的补充信息。

<a id="member-gfresourceoverlay-properties-duplicate_base_on_resolve"></a>

### `duplicate_base_on_resolve`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var duplicate_base_on_resolve: bool = true
```

resolve() 时是否默认复制 base Resource 后再应用覆盖链。

<a id="member-gfresourceoverlay-properties-require_existing_property"></a>

### `require_existing_property`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var require_existing_property: bool = true
```

应用覆盖链时是否默认要求目标对象已经声明对应属性。

<a id="member-gfresourceoverlay-properties-copy_values"></a>

### `copy_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var copy_values: bool = true
```

写入目标前是否默认复制 Array、Dictionary 与 Resource 值。

<a id="member-gfresourceoverlay-properties-duplicate_resources"></a>

### `duplicate_resources`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var duplicate_resources: bool = false
```

复制值时是否默认复制 Resource 实例。

<a id="member-gfresourceoverlay-properties-skip_unchanged"></a>

### `skip_unchanged`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var skip_unchanged: bool = false
```

是否默认跳过和目标当前值相同的覆盖值。

## 方法

<a id="member-gfresourceoverlay-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_base_resource: Resource, p_patches: Array = [], p_metadata: Dictionary = {} ) -> GFResourceOverlay:
```

配置覆盖链。

参数：

| 名称 | 说明 |
|---|---|
| `p_base_resource` | 来源资源。 |
| `p_patches` | 覆盖补丁列表。 |
| `p_metadata` | 调用方元数据。 |

返回：当前覆盖链实例。

结构：

- `p_patches`: Array[GFResourcePropertyPatch] copied into patches.
- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfresourceoverlay-methods-add_patch"></a>

### `add_patch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_patch(patch: GFResourcePropertyPatch) -> bool:
```

追加一个属性补丁。

参数：

| 名称 | 说明 |
|---|---|
| `patch` | 要追加的补丁。 |

返回：追加成功返回 true。

<a id="member-gfresourceoverlay-methods-clear_patches"></a>

### `clear_patches`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_patches() -> void:
```

清空覆盖补丁。

<a id="member-gfresourceoverlay-methods-resolve"></a>

### `resolve`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func resolve(options: Dictionary = {}) -> Dictionary:
```

解析覆盖链并返回资源构建报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 解析选项。 |

返回：覆盖链构建报告，成功或部分成功时 resource 字段为结果资源。

结构：

- `options`: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 与 metadata。
- `return`: Dictionary，包含 ok、resource、patch_count、计数、路径、errors、patch_reports 和 metadata。

<a id="member-gfresourceoverlay-methods-apply_to"></a>

### `apply_to`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func apply_to(target: Object, options: Dictionary = {}) -> Dictionary:
```

把覆盖链直接应用到现有对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `options` | 应用选项。 |

返回：覆盖链应用报告。

结构：

- `options`: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 与 metadata。
- `return`: Dictionary，包含 ok、patch_count、计数、路径、errors、patch_reports 和 metadata。

<a id="member-gfresourceoverlay-methods-get_patch_count"></a>

### `get_patch_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_patch_count() -> int:
```

获取补丁数量。

返回：补丁数量。

<a id="member-gfresourceoverlay-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：覆盖链调试快照。

结构：

- `return`: Dictionary，包含 base_resource、base_resource_path、patch_count、patch_metadata、options 和 metadata。
