# GFSaveIdentity

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_save_identity.gd`
- 模块：`Save`
- 继承：`Node`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

场景节点的持久化身份描述。 用于为可恢复实体提供稳定 id、类型键和额外描述信息。它只描述身份， 不直接负责保存或实例化。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`persistent_id`](#member-gfsaveidentity-properties-persistent_id) | `var persistent_id: StringName = &""` |
| 属性 | [`type_key`](#member-gfsaveidentity-properties-type_key) | `var type_key: StringName = &""` |
| 属性 | [`descriptor_extra`](#member-gfsaveidentity-properties-descriptor_extra) | `var descriptor_extra: Dictionary = {}` |
| 方法 | [`get_persistent_id`](#member-gfsaveidentity-methods-get_persistent_id) | `func get_persistent_id() -> StringName:` |
| 方法 | [`get_type_key`](#member-gfsaveidentity-methods-get_type_key) | `func get_type_key() -> StringName:` |
| 方法 | [`describe_identity`](#member-gfsaveidentity-methods-describe_identity) | `func describe_identity() -> Dictionary:` |

## 属性

<a id="member-gfsaveidentity-properties-persistent_id"></a>

### `persistent_id`

- API：`public`

```gdscript
var persistent_id: StringName = &""
```

稳定实体 id。留空时由调用方决定是否使用节点路径等回退方案。

<a id="member-gfsaveidentity-properties-type_key"></a>

### `type_key`

- API：`public`

```gdscript
var type_key: StringName = &""
```

可选实体类型键，通常用于恢复时选择工厂。

<a id="member-gfsaveidentity-properties-descriptor_extra"></a>

### `descriptor_extra`

- API：`public`

```gdscript
var descriptor_extra: Dictionary = {}
```

可写入存档描述的扩展字段。

结构：

- `descriptor_extra`: Dictionary，会合并进 describe_identity() 返回值的项目自定义描述字段。

## 方法

<a id="member-gfsaveidentity-methods-get_persistent_id"></a>

### `get_persistent_id`

- API：`public`

```gdscript
func get_persistent_id() -> StringName:
```

获取稳定实体 id。

返回：实体 id。

<a id="member-gfsaveidentity-methods-get_type_key"></a>

### `get_type_key`

- API：`public`

```gdscript
func get_type_key() -> StringName:
```

获取实体类型键。

返回：类型键。

<a id="member-gfsaveidentity-methods-describe_identity"></a>

### `describe_identity`

- API：`public`

```gdscript
func describe_identity() -> Dictionary:
```

构造身份描述。

返回：描述字典。

结构：

- `return`: Dictionary，包含 descriptor_extra，并在非空时包含 persistent_id 与 type_key。
