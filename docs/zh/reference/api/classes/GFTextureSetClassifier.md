# GFTextureSetClassifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_texture_set_classifier.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

纹理集命名分类与导入计划构建工具。 根据常见后缀把贴图文件归并为材质纹理集，并可生成 GFImportPlan。 它只做路径解析和计划输出，不创建材质、不执行导入、不绑定编辑器 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ROLE_ALBEDO`](#member-gftexturesetclassifier-constants-role_albedo) | `const ROLE_ALBEDO: StringName = &"albedo"` |
| 常量 | [`ROLE_NORMAL`](#member-gftexturesetclassifier-constants-role_normal) | `const ROLE_NORMAL: StringName = &"normal"` |
| 常量 | [`ROLE_ROUGHNESS`](#member-gftexturesetclassifier-constants-role_roughness) | `const ROLE_ROUGHNESS: StringName = &"roughness"` |
| 常量 | [`ROLE_METALLIC`](#member-gftexturesetclassifier-constants-role_metallic) | `const ROLE_METALLIC: StringName = &"metallic"` |
| 常量 | [`ROLE_ORM`](#member-gftexturesetclassifier-constants-role_orm) | `const ROLE_ORM: StringName = &"orm"` |
| 常量 | [`ROLE_AO`](#member-gftexturesetclassifier-constants-role_ao) | `const ROLE_AO: StringName = &"ao"` |
| 常量 | [`ROLE_HEIGHT`](#member-gftexturesetclassifier-constants-role_height) | `const ROLE_HEIGHT: StringName = &"height"` |
| 常量 | [`ROLE_EMISSION`](#member-gftexturesetclassifier-constants-role_emission) | `const ROLE_EMISSION: StringName = &"emission"` |
| 方法 | [`classify_files`](#member-gftexturesetclassifier-methods-classify_files) | `static func classify_files(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_material_import_plan`](#member-gftexturesetclassifier-methods-build_material_import_plan) | `static func build_material_import_plan( paths: PackedStringArray, target_root: String, options: Dictionary = {} ) -> GFImportPlan:` |
| 方法 | [`get_default_suffix_rules`](#member-gftexturesetclassifier-methods-get_default_suffix_rules) | `static func get_default_suffix_rules() -> Dictionary:` |

## 常量

<a id="member-gftexturesetclassifier-constants-role_albedo"></a>

### `ROLE_ALBEDO`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_ALBEDO: StringName = &"albedo"
```

Albedo/BaseColor 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_normal"></a>

### `ROLE_NORMAL`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_NORMAL: StringName = &"normal"
```

Normal 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_roughness"></a>

### `ROLE_ROUGHNESS`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_ROUGHNESS: StringName = &"roughness"
```

Roughness 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_metallic"></a>

### `ROLE_METALLIC`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_METALLIC: StringName = &"metallic"
```

Metallic/Metalness 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_orm"></a>

### `ROLE_ORM`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ROLE_ORM: StringName = &"orm"
```

Packed Occlusion/Roughness/Metallic 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_ao"></a>

### `ROLE_AO`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_AO: StringName = &"ao"
```

Ambient Occlusion 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_height"></a>

### `ROLE_HEIGHT`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_HEIGHT: StringName = &"height"
```

Height/Displacement 贴图角色。

<a id="member-gftexturesetclassifier-constants-role_emission"></a>

### `ROLE_EMISSION`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ROLE_EMISSION: StringName = &"emission"
```

Emission 贴图角色。

## 方法

<a id="member-gftexturesetclassifier-methods-classify_files"></a>

### `classify_files`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func classify_files(paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
```

分类纹理路径。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 输入路径列表。 |
| `options` | 分类选项。 |

返回：分类报告。

结构：

- `paths`: PackedStringArray texture file paths.
- `options`: Dictionary，可包含 suffix_rules、allowed_extensions 和 normalize_directory.
- `return`: Dictionary with ok, sets, unmatched, matched_count, unmatched_count, and suffix_rules.

<a id="member-gftexturesetclassifier-methods-build_material_import_plan"></a>

### `build_material_import_plan`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func build_material_import_plan( paths: PackedStringArray, target_root: String, options: Dictionary = {} ) -> GFImportPlan:
```

从纹理路径构建材质导入计划。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 输入路径列表。 |
| `target_root` | 目标材质目录。 |
| `options` | 构建选项。 |

返回：导入计划。

结构：

- `paths`: PackedStringArray texture file paths.
- `options`: Dictionary，可包含 material_extension、type_hint、suffix_rules、allowed_extensions 和 metadata。

<a id="member-gftexturesetclassifier-methods-get_default_suffix_rules"></a>

### `get_default_suffix_rules`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func get_default_suffix_rules() -> Dictionary:
```

获取默认后缀规则。

返回：后缀规则副本。

结构：

- `return`: Dictionary mapping role StringName to Array[String] suffixes.
