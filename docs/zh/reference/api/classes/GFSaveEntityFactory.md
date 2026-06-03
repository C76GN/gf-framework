# GFSaveEntityFactory

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_save_entity_factory.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存档恢复实体工厂基类。 由 GFSaveGraphUtility 在缺失 Source 且 Scope 允许工厂恢复时调用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`type_key`](#member-gfsaveentityfactory-properties-type_key) | `var type_key: StringName = &""` |
| 属性 | [`packed_scene`](#member-gfsaveentityfactory-properties-packed_scene) | `var packed_scene: PackedScene` |
| 方法 | [`get_type_key`](#member-gfsaveentityfactory-methods-get_type_key) | `func get_type_key() -> StringName:` |
| 方法 | [`_create_entity`](#member-gfsaveentityfactory-methods-_create_entity) | `func _create_entity(_descriptor: Dictionary, _context: Dictionary = {}) -> Node:` |
| 方法 | [`_after_entity_created`](#member-gfsaveentityfactory-methods-_after_entity_created) | `func _after_entity_created(_entity: Node, _descriptor: Dictionary, _context: Dictionary = {}) -> void:` |

## 属性

<a id="member-gfsaveentityfactory-properties-type_key"></a>

### `type_key`

- API：`public`

```gdscript
var type_key: StringName = &""
```

工厂可创建的实体类型键。

<a id="member-gfsaveentityfactory-properties-packed_scene"></a>

### `packed_scene`

- API：`public`

```gdscript
var packed_scene: PackedScene
```

可选场景模板。项目也可继承 _create_entity 实现自定义创建。

## 方法

<a id="member-gfsaveentityfactory-methods-get_type_key"></a>

### `get_type_key`

- API：`public`

```gdscript
func get_type_key() -> StringName:
```

获取实体类型键。

返回：类型键。

<a id="member-gfsaveentityfactory-methods-_create_entity"></a>

### `_create_entity`

- API：`protected`

```gdscript
func _create_entity(_descriptor: Dictionary, _context: Dictionary = {}) -> Node:
```

创建实体节点。

参数：

| 名称 | 说明 |
|---|---|
| `_descriptor` | 存档中的实体描述。 |
| `_context` | 调用上下文字典。 |

返回：创建出的节点；失败时返回 null。

结构：

- `_descriptor`: Dictionary，通常包含 persistent_id、type_key、phase 与 Source 描述字段。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。

<a id="member-gfsaveentityfactory-methods-_after_entity_created"></a>

### `_after_entity_created`

- API：`protected`

```gdscript
func _after_entity_created(_entity: Node, _descriptor: Dictionary, _context: Dictionary = {}) -> void:
```

实体加入场景树后调用。

参数：

| 名称 | 说明 |
|---|---|
| `_entity` | 创建出的实体。 |
| `_descriptor` | 存档中的实体描述。 |
| `_context` | 调用上下文字典。 |

结构：

- `_descriptor`: Dictionary，通常包含 persistent_id、type_key、phase 与 Source 描述字段。
- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
