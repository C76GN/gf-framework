# GFStorageSectionCache

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_section_cache.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

通用分区数据脏标记缓存。 用 scope_id + section_id 管理 Dictionary 分区，记录哪些分区被修改，并可生成只包含脏分区的 存储载荷。它不定义存档字段、业务模块或 UI，只负责分区缓存和脏状态机制。 scope_id 按每次调用时的序列化值识别；修改 Array/Dictionary 内容会表示另一个 scope， 因此长期作用域应优先使用稳定的 String、StringName 或 int。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`write_section`](#member-gfstoragesectioncache-methods-write_section) | `func write_section(scope_id: Variant, section_id: StringName, data: Dictionary, mark_dirty: bool = true) -> bool:` |
| 方法 | [`merge_section`](#member-gfstoragesectioncache-methods-merge_section) | `func merge_section( scope_id: Variant, section_id: StringName, patch: Dictionary, deep: bool = true, mark_dirty: bool = true ) -> Dictionary:` |
| 方法 | [`read_section`](#member-gfstoragesectioncache-methods-read_section) | `func read_section(scope_id: Variant, section_id: StringName, duplicate_value: bool = true) -> Dictionary:` |
| 方法 | [`has_section`](#member-gfstoragesectioncache-methods-has_section) | `func has_section(scope_id: Variant, section_id: StringName) -> bool:` |
| 方法 | [`get_sections`](#member-gfstoragesectioncache-methods-get_sections) | `func get_sections(scope_id: Variant, only_dirty: bool = false) -> Dictionary:` |
| 方法 | [`get_section_ids`](#member-gfstoragesectioncache-methods-get_section_ids) | `func get_section_ids(scope_id: Variant) -> PackedStringArray:` |
| 方法 | [`get_dirty_sections`](#member-gfstoragesectioncache-methods-get_dirty_sections) | `func get_dirty_sections(scope_id: Variant) -> PackedStringArray:` |
| 方法 | [`is_dirty`](#member-gfstoragesectioncache-methods-is_dirty) | `func is_dirty(scope_id: Variant, section_id: StringName = &"") -> bool:` |
| 方法 | [`mark_clean`](#member-gfstoragesectioncache-methods-mark_clean) | `func mark_clean(scope_id: Variant, section_ids: PackedStringArray = PackedStringArray()) -> int:` |
| 方法 | [`apply_payload`](#member-gfstoragesectioncache-methods-apply_payload) | `func apply_payload(scope_id: Variant, payload: Dictionary, mark_dirty: bool = false) -> int:` |
| 方法 | [`build_payload`](#member-gfstoragesectioncache-methods-build_payload) | `func build_payload( scope_id: Variant, include_clean: bool = false, mark_clean_after_build: bool = false ) -> Dictionary:` |
| 方法 | [`evict_scope`](#member-gfstoragesectioncache-methods-evict_scope) | `func evict_scope(scope_id: Variant) -> bool:` |
| 方法 | [`clear`](#member-gfstoragesectioncache-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragesectioncache-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfstoragesectioncache-methods-write_section"></a>

### `write_section`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func write_section(scope_id: Variant, section_id: StringName, data: Dictionary, mark_dirty: bool = true) -> bool:
```

写入一个分区。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_id` | 分区标识。 |
| `data` | 分区数据。 |
| `mark_dirty` | 为 true 时把分区标记为脏。 |

返回：写入成功返回 true。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `data`: Dictionary，调用方定义的分区载荷。

<a id="member-gfstoragesectioncache-methods-merge_section"></a>

### `merge_section`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func merge_section( scope_id: Variant, section_id: StringName, patch: Dictionary, deep: bool = true, mark_dirty: bool = true ) -> Dictionary:
```

合并一个分区的补丁数据。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_id` | 分区标识。 |
| `patch` | 要合并到分区内的数据。 |
| `deep` | 是否深合并嵌套 Dictionary。 |
| `mark_dirty` | 为 true 时把分区标记为脏。 |

返回：合并后的分区副本。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `patch`: Dictionary，调用方定义的分区补丁。
- `return`: Dictionary，合并后的分区数据副本。

<a id="member-gfstoragesectioncache-methods-read_section"></a>

### `read_section`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func read_section(scope_id: Variant, section_id: StringName, duplicate_value: bool = true) -> Dictionary:
```

读取一个分区。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_id` | 分区标识。 |
| `duplicate_value` | 为 true 时返回深拷贝。 |

返回：分区数据；不存在时返回空字典。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `return`: Dictionary，调用方定义的分区载荷。

<a id="member-gfstoragesectioncache-methods-has_section"></a>

### `has_section`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_section(scope_id: Variant, section_id: StringName) -> bool:
```

检查分区是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_id` | 分区标识。 |

返回：存在返回 true。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-get_sections"></a>

### `get_sections`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_sections(scope_id: Variant, only_dirty: bool = false) -> Dictionary:
```

获取作用域内的分区字典。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `only_dirty` | 为 true 时只返回脏分区。 |

返回：分区字典副本。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `return`: Dictionary[StringName, Dictionary]，分区 ID 到分区载荷的映射。

<a id="member-gfstoragesectioncache-methods-get_section_ids"></a>

### `get_section_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_section_ids(scope_id: Variant) -> PackedStringArray:
```

获取作用域内的分区 ID 列表。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |

返回：分区 ID 列表。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-get_dirty_sections"></a>

### `get_dirty_sections`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_dirty_sections(scope_id: Variant) -> PackedStringArray:
```

获取作用域内的脏分区 ID 列表。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |

返回：脏分区 ID 列表。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-is_dirty"></a>

### `is_dirty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_dirty(scope_id: Variant, section_id: StringName = &"") -> bool:
```

检查作用域或分区是否存在脏数据。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_id` | 分区标识；为空时检查整个作用域。 |

返回：存在脏数据返回 true。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-mark_clean"></a>

### `mark_clean`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func mark_clean(scope_id: Variant, section_ids: PackedStringArray = PackedStringArray()) -> int:
```

标记分区为干净。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `section_ids` | 要清理的分区；为空时清理整个作用域。 |

返回：被清理的脏分区数量。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-apply_payload"></a>

### `apply_payload`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_payload(scope_id: Variant, payload: Dictionary, mark_dirty: bool = false) -> int:
```

从 payload 填充作用域。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `payload` | 带 sections 字段的载荷，或直接作为分区字典使用的载荷。 |
| `mark_dirty` | 为 true 时把导入分区标记为脏。 |

返回：导入的分区数量。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `payload`: Dictionary，包含 sections 字段或直接为 Dictionary[StringName, Dictionary]。

<a id="member-gfstoragesectioncache-methods-build_payload"></a>

### `build_payload`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_payload( scope_id: Variant, include_clean: bool = false, mark_clean_after_build: bool = false ) -> Dictionary:
```

构建适合交给存储层保存的分区载荷。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |
| `include_clean` | 为 true 时包含所有分区；为 false 时只包含脏分区。 |
| `mark_clean_after_build` | 为 true 时构建后清理对应脏标记。 |

返回：分区载荷。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。
- `return`: Dictionary，包含 scope_id、sections、dirty_sections 和 include_clean。

<a id="member-gfstoragesectioncache-methods-evict_scope"></a>

### `evict_scope`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func evict_scope(scope_id: Variant) -> bool:
```

移除一个作用域。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 调用方定义的作用域标识。 |

返回：存在并移除时返回 true。

结构：

- `scope_id`: Variant，建议使用 String、StringName 或 int 等稳定值。

<a id="member-gfstoragesectioncache-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear() -> void:
```

清空全部缓存。

<a id="member-gfstoragesectioncache-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 scope_count、section_count 和 dirty_section_count。
