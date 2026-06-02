# GFPersistPropertiesSource

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_persist_properties_source.gd`
- 模块：`Save`
- 继承：`GFSaveSource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.23.0`

属性白名单存档 Source。 以节点形式包装 `GFNodePropertySerializer`，让项目可以直接在场景树中声明 需要保存的目标属性。它仍然使用 SaveGraph 的 Source/Serializer 协议， 不引入独立存储格式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`properties`](#member-gfpersistpropertiessource-properties-properties) | `var properties: PackedStringArray = PackedStringArray()` |
| 属性 | [`skip_missing_properties`](#member-gfpersistpropertiessource-properties-skip_missing_properties) | `var skip_missing_properties: bool = true` |

## 属性

<a id="member-gfpersistpropertiessource-properties-properties"></a>

### `properties`

- API：`public`

```gdscript
var properties: PackedStringArray = PackedStringArray()
```

需要保存的目标节点属性名。

<a id="member-gfpersistpropertiessource-properties-skip_missing_properties"></a>

### `skip_missing_properties`

- API：`public`

```gdscript
var skip_missing_properties: bool = true
```

应用数据时遇到缺失属性是否跳过。
