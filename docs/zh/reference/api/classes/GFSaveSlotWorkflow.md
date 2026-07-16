# GFSaveSlotWorkflow

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/slots/gf_save_slot_workflow.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用存档槽工作流配置。 负责把槽位索引、逻辑标识、元数据和槽位摘要 DTO 串起来。 不执行具体存取逻辑，也不写死任何游戏业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`active_slot_index`](#member-gfsaveslotworkflow-properties-active_slot_index) | `var active_slot_index: int = 0` |
| 属性 | [`slot_id_template`](#member-gfsaveslotworkflow-properties-slot_id_template) | `var slot_id_template: String = "slot_{index}"` |
| 属性 | [`empty_display_name_template`](#member-gfsaveslotworkflow-properties-empty_display_name_template) | `var empty_display_name_template: String = ""` |
| 属性 | [`metadata_script`](#member-gfsaveslotworkflow-properties-metadata_script) | `var metadata_script: Script = GFSaveSlotMetadata` |
| 属性 | [`card_script`](#member-gfsaveslotworkflow-properties-card_script) | `var card_script: Script = GFSaveSlotCard` |
| 属性 | [`slot_role`](#member-gfsaveslotworkflow-properties-slot_role) | `var slot_role: StringName = &""` |
| 方法 | [`select_slot_index`](#member-gfsaveslotworkflow-methods-select_slot_index) | `func select_slot_index(index: int) -> StringName:` |
| 方法 | [`set_slot_id_override`](#member-gfsaveslotworkflow-methods-set_slot_id_override) | `func set_slot_id_override(index: int, slot_id: StringName) -> void:` |
| 方法 | [`clear_slot_id_overrides`](#member-gfsaveslotworkflow-methods-clear_slot_id_overrides) | `func clear_slot_id_overrides() -> void:` |
| 方法 | [`get_active_slot_id`](#member-gfsaveslotworkflow-methods-get_active_slot_id) | `func get_active_slot_id() -> StringName:` |
| 方法 | [`get_active_storage_slot_id`](#member-gfsaveslotworkflow-methods-get_active_storage_slot_id) | `func get_active_storage_slot_id() -> int:` |
| 方法 | [`get_slot_id_for_index`](#member-gfsaveslotworkflow-methods-get_slot_id_for_index) | `func get_slot_id_for_index(index: int) -> StringName:` |
| 方法 | [`get_empty_display_name_for_index`](#member-gfsaveslotworkflow-methods-get_empty_display_name_for_index) | `func get_empty_display_name_for_index(index: int) -> String:` |
| 方法 | [`build_active_metadata`](#member-gfsaveslotworkflow-methods-build_active_metadata) | `func build_active_metadata( display_name: String = "", custom_metadata: Dictionary = {} ) -> GFSaveSlotMetadata:` |
| 方法 | [`build_slot_metadata`](#member-gfsaveslotworkflow-methods-build_slot_metadata) | `func build_slot_metadata( index: int, display_name: String = "", custom_metadata: Dictionary = {} ) -> GFSaveSlotMetadata:` |
| 方法 | [`build_empty_card`](#member-gfsaveslotworkflow-methods-build_empty_card) | `func build_empty_card(index: int) -> GFSaveSlotCard:` |
| 方法 | [`build_card_for_index`](#member-gfsaveslotworkflow-methods-build_card_for_index) | `func build_card_for_index( index: int, summary: Dictionary = {}, p_active_slot_index: int = -1 ) -> GFSaveSlotCard:` |
| 方法 | [`build_cards_for_indices`](#member-gfsaveslotworkflow-methods-build_cards_for_indices) | `func build_cards_for_indices(indices: Array, summaries: Array = []) -> Array[GFSaveSlotCard]:` |
| 方法 | [`build_cards_from_slot_store`](#member-gfsaveslotworkflow-methods-build_cards_from_slot_store) | `func build_cards_from_slot_store(slot_store: GFSaveSlotStorageAdapter, indices: Array = []) -> Array[GFSaveSlotCard]:` |

## 属性

<a id="member-gfsaveslotworkflow-properties-active_slot_index"></a>

### `active_slot_index`

- API：`public`

```gdscript
var active_slot_index: int = 0
```

当前选中槽位索引。仅用于构建摘要时标记 active。

<a id="member-gfsaveslotworkflow-properties-slot_id_template"></a>

### `slot_id_template`

- API：`public`

```gdscript
var slot_id_template: String = "slot_{index}"
```

槽位标识模板，支持 {index} 占位符。

<a id="member-gfsaveslotworkflow-properties-empty_display_name_template"></a>

### `empty_display_name_template`

- API：`public`

```gdscript
var empty_display_name_template: String = ""
```

空槽位展示名模板，支持 {index} 占位符。默认为空，由项目按 UI 与本地化需要显式设置。

<a id="member-gfsaveslotworkflow-properties-metadata_script"></a>

### `metadata_script`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata_script: Script = GFSaveSlotMetadata
```

可替换的元数据资源脚本，项目层可继承 GFSaveSlotMetadata 扩展。

<a id="member-gfsaveslotworkflow-properties-card_script"></a>

### `card_script`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var card_script: Script = GFSaveSlotCard
```

可替换的卡片资源脚本，项目层可继承 GFSaveSlotCard 扩展。

<a id="member-gfsaveslotworkflow-properties-slot_role"></a>

### `slot_role`

- API：`public`

```gdscript
var slot_role: StringName = &""
```

槽位角色。用于区分 autosave/manual/cloud 等抽象类别。

## 方法

<a id="member-gfsaveslotworkflow-methods-select_slot_index"></a>

### `select_slot_index`

- API：`public`

```gdscript
func select_slot_index(index: int) -> StringName:
```

选择当前槽位。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |

返回：当前槽位逻辑标识。

<a id="member-gfsaveslotworkflow-methods-set_slot_id_override"></a>

### `set_slot_id_override`

- API：`public`

```gdscript
func set_slot_id_override(index: int, slot_id: StringName) -> void:
```

设置指定索引的逻辑标识覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |
| `slot_id` | 逻辑标识。 |

<a id="member-gfsaveslotworkflow-methods-clear_slot_id_overrides"></a>

### `clear_slot_id_overrides`

- API：`public`

```gdscript
func clear_slot_id_overrides() -> void:
```

清空逻辑标识覆盖。

<a id="member-gfsaveslotworkflow-methods-get_active_slot_id"></a>

### `get_active_slot_id`

- API：`public`

```gdscript
func get_active_slot_id() -> StringName:
```

获取当前槽位逻辑标识。

返回：槽位标识。

<a id="member-gfsaveslotworkflow-methods-get_active_storage_slot_id"></a>

### `get_active_storage_slot_id`

- API：`public`

```gdscript
func get_active_storage_slot_id() -> int:
```

获取当前 GFStorageUtility 整数槽位。

返回：整数槽位。

<a id="member-gfsaveslotworkflow-methods-get_slot_id_for_index"></a>

### `get_slot_id_for_index`

- API：`public`

```gdscript
func get_slot_id_for_index(index: int) -> StringName:
```

获取指定索引的逻辑标识。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |

返回：槽位标识。

<a id="member-gfsaveslotworkflow-methods-get_empty_display_name_for_index"></a>

### `get_empty_display_name_for_index`

- API：`public`

```gdscript
func get_empty_display_name_for_index(index: int) -> String:
```

获取空槽位展示名。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |

返回：展示名。

<a id="member-gfsaveslotworkflow-methods-build_active_metadata"></a>

### `build_active_metadata`

- API：`public`

```gdscript
func build_active_metadata( display_name: String = "", custom_metadata: Dictionary = {} ) -> GFSaveSlotMetadata:
```

构建当前槽位元数据。

参数：

| 名称 | 说明 |
|---|---|
| `display_name` | 可选展示名。 |
| `custom_metadata` | 自定义元数据。 |

返回：元数据资源。

结构：

- `custom_metadata`: Dictionary，会写入 GFSaveSlotMetadata.custom_metadata；slot_role 非空时会额外写入 slot_role。

<a id="member-gfsaveslotworkflow-methods-build_slot_metadata"></a>

### `build_slot_metadata`

- API：`public`

```gdscript
func build_slot_metadata( index: int, display_name: String = "", custom_metadata: Dictionary = {} ) -> GFSaveSlotMetadata:
```

构建指定槽位元数据。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |
| `display_name` | 可选展示名。 |
| `custom_metadata` | 自定义元数据。 |

返回：元数据资源。

结构：

- `custom_metadata`: Dictionary，会写入 GFSaveSlotMetadata.custom_metadata；slot_role 非空时会额外写入 slot_role。

<a id="member-gfsaveslotworkflow-methods-build_empty_card"></a>

### `build_empty_card`

- API：`public`

```gdscript
func build_empty_card(index: int) -> GFSaveSlotCard:
```

构建空槽位卡片。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |

返回：卡片资源。

<a id="member-gfsaveslotworkflow-methods-build_card_for_index"></a>

### `build_card_for_index`

- API：`public`

```gdscript
func build_card_for_index( index: int, summary: Dictionary = {}, p_active_slot_index: int = -1 ) -> GFSaveSlotCard:
```

根据摘要构建槽位卡片。摘要为空时返回空卡片。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 槽位索引。 |
| `summary` | 槽位摘要。 |
| `p_active_slot_index` | 当前选中索引；小于 0 时使用 active_slot_index。 |

返回：卡片资源。

结构：

- `summary`: Dictionary，可包含 slot_index、slot_id、modified_time、is_compatible、compatibility_errors 与 metadata。

<a id="member-gfsaveslotworkflow-methods-build_cards_for_indices"></a>

### `build_cards_for_indices`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func build_cards_for_indices(indices: Array, summaries: Array = []) -> Array[GFSaveSlotCard]:
```

根据索引和摘要列表构建卡片列表。

参数：

| 名称 | 说明 |
|---|---|
| `indices` | 槽位索引列表。 |
| `summaries` | 槽位摘要列表。 |

返回：卡片列表。

结构：

- `indices`: Array，元素为可转换为 int 的槽位索引。
- `summaries`: Array，每项为槽位存储适配器产出的 Dictionary 摘要。

<a id="member-gfsaveslotworkflow-methods-build_cards_from_slot_store"></a>

### `build_cards_from_slot_store`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_cards_from_slot_store(slot_store: GFSaveSlotStorageAdapter, indices: Array = []) -> Array[GFSaveSlotCard]:
```

从 GFSaveSlotStorageAdapter 读取摘要并构建卡片。

参数：

| 名称 | 说明 |
|---|---|
| `slot_store` | 槽位存储适配器。 |
| `indices` | 需要展示的槽位索引；为空时使用已有槽位。 |

返回：卡片列表。

结构：

- `indices`: Array，元素为可转换为 int 的槽位索引。
