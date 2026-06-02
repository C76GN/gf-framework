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
