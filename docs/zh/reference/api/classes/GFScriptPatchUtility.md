# GFScriptPatchUtility

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_script_patch_utility.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`8.0.0`

通用 GDScript 头部补丁工具。 用于编辑器工具安全插入或替换脚本头部注解，保持 @tool、其他注解、文档注释、 class_name 与 extends 的顺序。它不绑定任何具体注解语义或项目目录约定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_annotation_insert_index`](#member-gfscriptpatchutility-methods-get_annotation_insert_index) | `static func get_annotation_insert_index(source_code: String, options: Dictionary = {}) -> int:` |
| 方法 | [`make_annotation_patch`](#member-gfscriptpatchutility-methods-make_annotation_patch) | `static func make_annotation_patch( source_code: String, annotation_line: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`patch_script_path_annotation`](#member-gfscriptpatchutility-methods-patch_script_path_annotation) | `static func patch_script_path_annotation( script_path: String, annotation_line: String, options: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfscriptpatchutility-methods-get_annotation_insert_index"></a>

### `get_annotation_insert_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_annotation_insert_index(source_code: String, options: Dictionary = {}) -> int:
```

计算注解插入位置。

参数：

| 名称 | 说明 |
|---|---|
| `source_code` | GDScript 源码。 |
| `options` | 位置选项，支持 after_existing_annotations。 |

返回：以行为单位的插入位置。

结构：

- `options`: Dictionary，包含 after_existing_annotations。

<a id="member-gfscriptpatchutility-methods-make_annotation_patch"></a>

### `make_annotation_patch`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_annotation_patch( source_code: String, annotation_line: String, options: Dictionary = {} ) -> Dictionary:
```

生成注解补丁结果。

参数：

| 名称 | 说明 |
|---|---|
| `source_code` | GDScript 源码。 |
| `annotation_line` | 要插入的完整注解行。 |
| `options` | 补丁选项，支持 replacement_prefix、allow_duplicate、after_existing_annotations。 |

返回：补丁结果。

结构：

- `options`: Dictionary，包含 replacement_prefix、allow_duplicate、after_existing_annotations。
- `return`: Dictionary，包含 ok、changed、source_code、insert_index、removed_count、status 和 error。

<a id="member-gfscriptpatchutility-methods-patch_script_path_annotation"></a>

### `patch_script_path_annotation`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func patch_script_path_annotation( script_path: String, annotation_line: String, options: Dictionary = {} ) -> Dictionary:
```

读取脚本文件、生成注解补丁并写回。

参数：

| 名称 | 说明 |
|---|---|
| `script_path` | res:// 或 user:// 脚本路径。 |
| `annotation_line` | 要插入的完整注解行。 |
| `options` | 补丁和保存选项，支持 make_annotation_patch() 与 GFGeneratedArtifactReport.save_text() 的选项。 |

返回：补丁与产物报告。

结构：

- `options`: Dictionary，包含补丁选项和保存选项。
- `return`: Dictionary，包含 ok、changed、patch、artifact_report 和 error。
