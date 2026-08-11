# GFInventoryItemDefinition

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_item_definition.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用库存物品定义。 只描述库存系统需要理解的堆叠、分类和实例数据匹配规则， 不规定品质、装备、货币、掉落等项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`item_id`](#member-gfinventoryitemdefinition-properties-item_id) | `var item_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfinventoryitemdefinition-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`description`](#member-gfinventoryitemdefinition-properties-description) | `var description: String = ""` |
| 属性 | [`icon`](#member-gfinventoryitemdefinition-properties-icon) | `var icon: Texture2D = null` |
| 属性 | [`max_stack_amount`](#member-gfinventoryitemdefinition-properties-max_stack_amount) | `var max_stack_amount: int:` |
| 属性 | [`max_stack_count`](#member-gfinventoryitemdefinition-properties-max_stack_count) | `var max_stack_count: int:` |
| 属性 | [`categories`](#member-gfinventoryitemdefinition-properties-categories) | `var categories: Array[StringName] = []` |
| 属性 | [`default_instance_data`](#member-gfinventoryitemdefinition-properties-default_instance_data) | `var default_instance_data: Dictionary = {}` |
| 属性 | [`stack_key_fields`](#member-gfinventoryitemdefinition-properties-stack_key_fields) | `var stack_key_fields: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfinventoryitemdefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`compatibility_checker`](#member-gfinventoryitemdefinition-properties-compatibility_checker) | `var compatibility_checker: Callable = Callable()` |
| 方法 | [`get_item_id`](#member-gfinventoryitemdefinition-methods-get_item_id) | `func get_item_id() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfinventoryitemdefinition-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`has_category`](#member-gfinventoryitemdefinition-methods-has_category) | `func has_category(category: StringName) -> bool:` |
| 方法 | [`matches_categories`](#member-gfinventoryitemdefinition-methods-matches_categories) | `func matches_categories(required_categories: Array[StringName]) -> bool:` |
| 方法 | [`normalize_instance_data`](#member-gfinventoryitemdefinition-methods-normalize_instance_data) | `func normalize_instance_data(instance_data: Dictionary = {}) -> Dictionary:` |
| 方法 | [`are_instance_data_compatible`](#member-gfinventoryitemdefinition-methods-are_instance_data_compatible) | `func are_instance_data_compatible(left: Dictionary = {}, right: Dictionary = {}) -> bool:` |
| 方法 | [`to_dict`](#member-gfinventoryitemdefinition-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinventoryitemdefinition-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfinventoryitemdefinition-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFInventoryItemDefinition:` |

## 属性

<a id="member-gfinventoryitemdefinition-properties-item_id"></a>

### `item_id`

- API：`public`

```gdscript
var item_id: StringName = &""
```

物品稳定标识。

<a id="member-gfinventoryitemdefinition-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

显示名称，供项目 UI 或编辑器工具使用。

<a id="member-gfinventoryitemdefinition-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

描述文本，供项目 UI 或编辑器工具使用。

<a id="member-gfinventoryitemdefinition-properties-icon"></a>

### `icon`

- API：`public`

```gdscript
var icon: Texture2D = null
```

可选图标资源。

<a id="member-gfinventoryitemdefinition-properties-max_stack_amount"></a>

### `max_stack_amount`

- API：`public`

```gdscript
var max_stack_amount: int:
```

单个堆叠最多容纳的数量。

<a id="member-gfinventoryitemdefinition-properties-max_stack_count"></a>

### `max_stack_count`

- API：`public`

```gdscript
var max_stack_count: int:
```

同一物品最多占用的堆叠数量。小于等于 0 表示不限制。

<a id="member-gfinventoryitemdefinition-properties-categories"></a>

### `categories`

- API：`public`

```gdscript
var categories: Array[StringName] = []
```

分类标签。框架只保存和匹配，不解释具体含义。

结构：

- `categories`: Array[StringName]，用于项目自定义筛选的分类标签列表。

<a id="member-gfinventoryitemdefinition-properties-default_instance_data"></a>

### `default_instance_data`

- API：`public`

```gdscript
var default_instance_data: Dictionary = {}
```

默认实例数据。空堆叠或空输入会按这些默认值参与兼容性比较。

结构：

- `default_instance_data`: Dictionary，物品实例数据默认值；用于堆叠兼容性比较和序列化。

<a id="member-gfinventoryitemdefinition-properties-stack_key_fields"></a>

### `stack_key_fields`

- API：`public`

```gdscript
var stack_key_fields: PackedStringArray = PackedStringArray()
```

用于判断堆叠兼容性的实例数据字段。为空时比较完整实例数据。

<a id="member-gfinventoryitemdefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义物品定义元数据；GF 不读取或改写其中字段。

<a id="member-gfinventoryitemdefinition-properties-compatibility_checker"></a>

### `compatibility_checker`

- API：`public`
- 首次版本：`3.3.0`

```gdscript
var compatibility_checker: Callable = Callable()
```

可选堆叠兼容性回调。签名为 `Callable(left: Dictionary, right: Dictionary, definition: GFInventoryItemDefinition) -> bool`。 回调必须同步、确定、只读且有界，不得执行 I/O、产生外部副作用或依赖调用次数； 一次 mutation 或事务的 prepare/commit 重规划可能调用零次或多次。回调必须指向 可反射参数元数据的具名 Object 方法；匿名 lambda 和其他不透明 Callable 会在 调用前失败关闭。

## 方法

<a id="member-gfinventoryitemdefinition-methods-get_item_id"></a>

### `get_item_id`

- API：`public`

```gdscript
func get_item_id() -> StringName:
```

获取稳定物品标识。

返回：物品标识。

<a id="member-gfinventoryitemdefinition-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取可显示名称。

返回：显示名称；为空时回退到 item_id 或资源文件名。

<a id="member-gfinventoryitemdefinition-methods-has_category"></a>

### `has_category`

- API：`public`

```gdscript
func has_category(category: StringName) -> bool:
```

检查是否包含分类标签。

参数：

| 名称 | 说明 |
|---|---|
| `category` | 分类标签。 |

返回：包含时返回 true。

<a id="member-gfinventoryitemdefinition-methods-matches_categories"></a>

### `matches_categories`

- API：`public`

```gdscript
func matches_categories(required_categories: Array[StringName]) -> bool:
```

检查是否满足全部分类标签。

参数：

| 名称 | 说明 |
|---|---|
| `required_categories` | 需要匹配的分类标签。 |

返回：全部满足时返回 true。

结构：

- `required_categories`: Array[StringName]，必须全部存在于 categories 中的分类标签列表。

<a id="member-gfinventoryitemdefinition-methods-normalize_instance_data"></a>

### `normalize_instance_data`

- API：`public`

```gdscript
func normalize_instance_data(instance_data: Dictionary = {}) -> Dictionary:
```

规范化实例数据。与默认实例数据等价时返回空字典。

参数：

| 名称 | 说明 |
|---|---|
| `instance_data` | 实例数据。 |

返回：规范化后的实例数据副本。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。
- `return`: Dictionary，规范化后的物品实例数据副本；等价于默认实例数据时为空字典。

<a id="member-gfinventoryitemdefinition-methods-are_instance_data_compatible"></a>

### `are_instance_data_compatible`

- API：`public`

```gdscript
func are_instance_data_compatible(left: Dictionary = {}, right: Dictionary = {}) -> bool:
```

判断两份实例数据是否可以合并到同一堆叠。

参数：

| 名称 | 说明 |
|---|---|
| `left` | 左侧实例数据。 |
| `right` | 右侧实例数据。 |

返回：可合并返回 true。

结构：

- `left`: Dictionary，左侧物品实例数据。
- `right`: Dictionary，右侧物品实例数据。

<a id="member-gfinventoryitemdefinition-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。

<a id="member-gfinventoryitemdefinition-methods-apply_dict"></a>

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

- `data`: Dictionary，可包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。

<a id="member-gfinventoryitemdefinition-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFInventoryItemDefinition:
```

从字典创建物品定义。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

返回：物品定义。

结构：

- `data`: Dictionary，可包含 item_id、display_name、description、max_stack_amount、max_stack_count、categories、default_instance_data、stack_key_fields 与 metadata。
