# GFTileMetadataPaintTool

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/editor/gf_tile_metadata_paint_tool.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`7.0.0`

Tile 元数据绘制工具辅助。 为 `GFTileMetadataLayer` 提供编辑器友好的 patch、UndoRedo 和 overlay 数据。 它只处理通用格子元数据差异，不绑定 TileSet、TileMapLayer、寻路、地形或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_OVERLAY_COLOR`](#member-gftilemetadatapainttool-constants-default_overlay_color) | `const DEFAULT_OVERLAY_COLOR: Color = Color(0.2, 0.65, 1.0, 0.45)` |
| 方法 | [`make_paint_patch`](#member-gftilemetadatapainttool-methods-make_paint_patch) | `static func make_paint_patch( layer: GFTileMetadataLayer, target_cells: Array[Vector2i], key: StringName, value: Variant, erase: bool = false ) -> Dictionary:` |
| 方法 | [`apply_paint_patch`](#member-gftilemetadatapainttool-methods-apply_paint_patch) | `static func apply_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:` |
| 方法 | [`revert_paint_patch`](#member-gftilemetadatapainttool-methods-revert_paint_patch) | `static func revert_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:` |
| 方法 | [`commit_paint_patch`](#member-gftilemetadatapainttool-methods-commit_paint_patch) | `static func commit_paint_patch( layer: GFTileMetadataLayer, patch: Dictionary, undo_manager: Object, action_name: String = "Paint Tile Metadata", execute_immediately: bool = true ) -> Error:` |
| 方法 | [`get_schema_field_options`](#member-gftilemetadatapainttool-methods-get_schema_field_options) | `static func get_schema_field_options(layer: GFTileMetadataLayer) -> Array[Dictionary]:` |
| 方法 | [`get_cell_overlay_segments`](#member-gftilemetadatapainttool-methods-get_cell_overlay_segments) | `static func get_cell_overlay_segments( layer: GFTileMetadataLayer, cell: Vector2i, options: Dictionary = {} ) -> Array[Dictionary]:` |

## 常量

<a id="member-gftilemetadatapainttool-constants-default_overlay_color"></a>

### `DEFAULT_OVERLAY_COLOR`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_OVERLAY_COLOR: Color = Color(0.2, 0.65, 1.0, 0.45)
```

默认 overlay 颜色。

## 方法

<a id="member-gftilemetadatapainttool-methods-make_paint_patch"></a>

### `make_paint_patch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func make_paint_patch( layer: GFTileMetadataLayer, target_cells: Array[Vector2i], key: StringName, value: Variant, erase: bool = false ) -> Dictionary:
```

创建一个绘制或擦除 patch，不修改 layer。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标元数据层。 |
| `target_cells` | 目标格子。 |
| `key` | 元数据字段名。 |
| `value` | 绘制值；erase 为 true 时忽略。 |
| `erase` | 为 true 时擦除字段。 |

返回：patch 字典。

结构：

- `target_cells`: Array[Vector2i]，要绘制或擦除的格子。
- `value`: Variant metadata field value.
- `return`: Dictionary，包含 ok、key、erase、cells、before、after、changed_cells 和 changed_count。

<a id="member-gftilemetadatapainttool-methods-apply_paint_patch"></a>

### `apply_paint_patch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func apply_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:
```

应用 paint patch。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标元数据层。 |
| `patch` | make_paint_patch() 返回的 patch。 |

返回：应用报告。

结构：

- `patch`: Dictionary，包含 after 与 changed_cells。
- `return`: Dictionary，包含 ok、changed_count 和 changed_cells。

<a id="member-gftilemetadatapainttool-methods-revert_paint_patch"></a>

### `revert_paint_patch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func revert_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:
```

回滚 paint patch。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标元数据层。 |
| `patch` | make_paint_patch() 返回的 patch。 |

返回：回滚报告。

结构：

- `patch`: Dictionary，包含 before 与 changed_cells。
- `return`: Dictionary，包含 ok、changed_count 和 changed_cells。

<a id="member-gftilemetadatapainttool-methods-commit_paint_patch"></a>

### `commit_paint_patch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func commit_paint_patch( layer: GFTileMetadataLayer, patch: Dictionary, undo_manager: Object, action_name: String = "Paint Tile Metadata", execute_immediately: bool = true ) -> Error:
```

将 paint patch 写入 UndoRedo 兼容对象。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标元数据层。 |
| `patch` | make_paint_patch() 返回的 patch。 |
| `undo_manager` | EditorUndoRedoManager、UndoRedo 或兼容对象。 |
| `action_name` | UndoRedo action 名称。 |
| `execute_immediately` | 提交 action 时是否立即执行 do 方法。 |

返回：Godot 错误码。

结构：

- `patch`: Dictionary，包含 before、after 与 changed_cells。

<a id="member-gftilemetadatapainttool-methods-get_schema_field_options"></a>

### `get_schema_field_options`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func get_schema_field_options(layer: GFTileMetadataLayer) -> Array[Dictionary]:
```

读取 schema 字段选项。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 元数据层。 |

返回：字段选项数组。

结构：

- `return`: Array[Dictionary]，每项包含 key、metadata、color 和 value。

<a id="member-gftilemetadatapainttool-methods-get_cell_overlay_segments"></a>

### `get_cell_overlay_segments`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func get_cell_overlay_segments( layer: GFTileMetadataLayer, cell: Vector2i, options: Dictionary = {} ) -> Array[Dictionary]:
```

获取单个格子的 overlay 分段数据。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 元数据层。 |
| `cell` | 格坐标。 |
| `options` | 可选项。支持 field_order、default_color、alpha 和 include_unconfigured。 |

返回：overlay 分段数组。

结构：

- `options`: Dictionary，field_order 为字段顺序数组，default_color 为 Color，alpha 为透明度乘数，include_unconfigured 默认为 true。
- `return`: Array[Dictionary]，每项包含 key、value、color、index、count、start_ratio 和 end_ratio。
