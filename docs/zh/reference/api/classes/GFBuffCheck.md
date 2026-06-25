# GFBuffCheck

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_buff_check.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`6.0.0`

Buff 应用检查基类。 为数据化 Buff 提供通用可组合检查入口。检查只返回是否允许应用和诊断原因， 不规定具体玩法、阵营、成本或状态语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`check_id`](#member-gfbuffcheck-properties-check_id) | `var check_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfbuffcheck-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`can_apply`](#member-gfbuffcheck-methods-can_apply) | `func can_apply(context: Dictionary) -> Dictionary:` |
| 方法 | [`_can_apply`](#member-gfbuffcheck-methods-_can_apply) | `func _can_apply(_context: Dictionary) -> Dictionary:` |

## 属性

<a id="member-gfbuffcheck-properties-check_id"></a>

### `check_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var check_id: StringName = &""
```

检查标识，用于诊断或项目侧过滤。

<a id="member-gfbuffcheck-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释其中字段。

结构：

- `metadata`: Dictionary project-defined check metadata.

## 方法

<a id="member-gfbuffcheck-methods-can_apply"></a>

### `can_apply`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func can_apply(context: Dictionary) -> Dictionary:
```

检查 Buff 是否允许应用。

参数：

| 名称 | 说明 |
|---|---|
| `context` | Buff 应用上下文。 |

返回：检查报告。

结构：

- `context`: Dictionary with buff, owner, event, and metadata.
- `return`: Dictionary with ok, reason, check_id, and metadata.

<a id="member-gfbuffcheck-methods-_can_apply"></a>

### `_can_apply`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _can_apply(_context: Dictionary) -> Dictionary:
```

Buff 应用检查钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | Buff 应用上下文。 |

返回：检查报告。

结构：

- `_context`: Dictionary with buff, owner, event, and metadata.
- `return`: Dictionary with optional ok, reason, and metadata.
