# GFInventorySlotDefinition

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_slot_definition.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.20.0`

通用库存槽位接收规则。 只描述一个槽位允许接收哪些物品或分类，不保存槽位内容，也不绑定 UI、 拖拽、装备类型或具体项目玩法。项目可把它挂到 `GFSlotInventoryModel.slot_definitions` 上，为背包、快捷栏或容器槽位提供轻量约束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`display_name`](#member-gfinventoryslotdefinition-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`accepted_item_ids`](#member-gfinventoryslotdefinition-properties-accepted_item_ids) | `var accepted_item_ids: Array[StringName] = []` |
| 属性 | [`rejected_item_ids`](#member-gfinventoryslotdefinition-properties-rejected_item_ids) | `var rejected_item_ids: Array[StringName] = []` |
| 属性 | [`accepted_categories`](#member-gfinventoryslotdefinition-properties-accepted_categories) | `var accepted_categories: Array[StringName] = []` |
| 属性 | [`require_all_categories`](#member-gfinventoryslotdefinition-properties-require_all_categories) | `var require_all_categories: bool = false` |
| 属性 | [`metadata`](#member-gfinventoryslotdefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`acceptance_checker`](#member-gfinventoryslotdefinition-properties-acceptance_checker) | `var acceptance_checker: Callable = Callable()` |
| 方法 | [`can_accept`](#member-gfinventoryslotdefinition-methods-can_accept) | `func can_accept( item_id: StringName, definition: GFInventoryItemDefinition = null, instance_data: Dictionary = {}, slot_index: int = -1, inventory: GFInventoryReadView = null ) -> bool:` |
| 方法 | [`to_dict`](#member-gfinventoryslotdefinition-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinventoryslotdefinition-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfinventoryslotdefinition-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFInventorySlotDefinition:` |

## 属性

<a id="member-gfinventoryslotdefinition-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

显示名称，供项目 UI 或编辑器工具使用。

<a id="member-gfinventoryslotdefinition-properties-accepted_item_ids"></a>

### `accepted_item_ids`

- API：`public`

```gdscript
var accepted_item_ids: Array[StringName] = []
```

允许的物品 ID。为空表示不按物品 ID 限制。

结构：

- `accepted_item_ids`: Array[StringName]，槽位允许接收的物品 ID；为空时不限制。

<a id="member-gfinventoryslotdefinition-properties-rejected_item_ids"></a>

### `rejected_item_ids`

- API：`public`

```gdscript
var rejected_item_ids: Array[StringName] = []
```

禁止的物品 ID。优先级高于 accepted_item_ids。

结构：

- `rejected_item_ids`: Array[StringName]，槽位拒绝接收的物品 ID。

<a id="member-gfinventoryslotdefinition-properties-accepted_categories"></a>

### `accepted_categories`

- API：`public`

```gdscript
var accepted_categories: Array[StringName] = []
```

允许的物品分类。为空表示不按分类限制。

结构：

- `accepted_categories`: Array[StringName]，槽位允许接收的物品分类；为空时不限制。

<a id="member-gfinventoryslotdefinition-properties-require_all_categories"></a>

### `require_all_categories`

- API：`public`

```gdscript
var require_all_categories: bool = false
```

是否要求物品同时拥有全部 accepted_categories。false 表示拥有任一分类即可。

<a id="member-gfinventoryslotdefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义槽位元数据；GF 不读取或改写其中字段。

<a id="member-gfinventoryslotdefinition-properties-acceptance_checker"></a>

### `acceptance_checker`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
var acceptance_checker: Callable = Callable()
```

可选接收检查回调。签名为 `Callable(item_id, definition, instance_data, slot_index, inventory_view) -> bool`。 `inventory_view` 是仅在本次同步回调内有效的 [GFInventoryReadView]；回调必须 同步、确定、只读且有界，不得保存视图、执行 I/O、产生外部副作用、依赖调用次数， 或把参数声明为可变库存模型类型。回调必须指向可反射参数元数据的具名 Object 方法；匿名 lambda 和其他不透明 Callable 会在调用前失败关闭。一次 mutation 或事务 的 prepare/commit 重规划可能调用零次或多次。

## 方法

<a id="member-gfinventoryslotdefinition-methods-can_accept"></a>

### `can_accept`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
func can_accept( item_id: StringName, definition: GFInventoryItemDefinition = null, instance_data: Dictionary = {}, slot_index: int = -1, inventory: GFInventoryReadView = null ) -> bool:
```

判断槽位是否接受指定物品。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `definition` | 可选物品定义；分类规则需要该定义。 |
| `instance_data` | 物品实例数据。 |
| `slot_index` | 槽位索引。 |
| `inventory` | 当前逐步候选的短生命周期 [GFInventoryReadView]；手工调用可传 null。 |

返回：接受时返回 true。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。

<a id="member-gfinventoryslotdefinition-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。

<a id="member-gfinventoryslotdefinition-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

结构：

- `data`: Dictionary，可包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。

<a id="member-gfinventoryslotdefinition-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFInventorySlotDefinition:
```

从字典创建槽位定义。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

返回：槽位定义。

结构：

- `data`: Dictionary，可包含 display_name、accepted_item_ids、rejected_item_ids、accepted_categories、require_all_categories 与 metadata。
