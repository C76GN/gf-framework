# GFEditorSceneMetadataPatch

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_scene_metadata_patch.gd`
- 模块：`Kernel`
- 继承：`GFEditorCommand`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`7.0.0`

可撤销的场景节点 metadata 修改命令。 用于把编辑器工具对场景根节点或普通节点 metadata 的读写收敛成 GFEditorCommand。 该命令只处理 Object metadata，不规定具体工具面板、场景分组或业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_node`](#member-gfeditorscenemetadatapatch-properties-target_node) | `var target_node: Node:` |
| 属性 | [`metadata_key`](#member-gfeditorscenemetadatapatch-properties-metadata_key) | `var metadata_key: StringName:` |
| 属性 | [`value`](#member-gfeditorscenemetadatapatch-properties-value) | `var value: Variant:` |
| 属性 | [`remove_on_execute`](#member-gfeditorscenemetadatapatch-properties-remove_on_execute) | `var remove_on_execute: bool:` |
| 方法 | [`configure`](#member-gfeditorscenemetadatapatch-methods-configure) | `func configure( node: Node, key: StringName, new_value: Variant = null, options: Dictionary = {} ) -> GFEditorCommand:` |
| 方法 | [`get_metadata_debug_snapshot`](#member-gfeditorscenemetadatapatch-methods-get_metadata_debug_snapshot) | `func get_metadata_debug_snapshot() -> Dictionary:` |
| 方法 | [`can_execute`](#member-gfeditorscenemetadatapatch-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`_do_it`](#member-gfeditorscenemetadatapatch-methods-_do_it) | `func _do_it() -> Error:` |
| 方法 | [`_undo_it`](#member-gfeditorscenemetadatapatch-methods-_undo_it) | `func _undo_it() -> Error:` |
| 方法 | [`_get_undo_context`](#member-gfeditorscenemetadatapatch-methods-_get_undo_context) | `func _get_undo_context() -> Object:` |

## 属性

<a id="member-gfeditorscenemetadatapatch-properties-target_node"></a>

### `target_node`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var target_node: Node:
```

要修改的节点。

<a id="member-gfeditorscenemetadatapatch-properties-metadata_key"></a>

### `metadata_key`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata_key: StringName:
```

要修改的 metadata key。

<a id="member-gfeditorscenemetadatapatch-properties-value"></a>

### `value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var value: Variant:
```

执行时写入的新值。

结构：

- `value`: Variant copied when configured and written.

<a id="member-gfeditorscenemetadatapatch-properties-remove_on_execute"></a>

### `remove_on_execute`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var remove_on_execute: bool:
```

执行时是否移除 metadata key，而不是写入 value。

## 方法

<a id="member-gfeditorscenemetadatapatch-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( node: Node, key: StringName, new_value: Variant = null, options: Dictionary = {} ) -> GFEditorCommand:
```

配置 metadata 修改命令。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 要修改的节点。 |
| `key` | metadata key。 |
| `new_value` | 写入值。 |
| `options` | 配置选项。 |

返回：当前命令实例。

结构：

- `new_value`: Variant copied into value.
- `options`: Dictionary，支持 command_name、remove_on_execute、metadata 和 duplicate_resources。

<a id="member-gfeditorscenemetadatapatch-methods-get_metadata_debug_snapshot"></a>

### `get_metadata_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_metadata_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing command fields and previous metadata snapshot state.

<a id="member-gfeditorscenemetadatapatch-methods-can_execute"></a>

### `can_execute`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func can_execute() -> bool:
```

命令当前是否允许执行。

返回：允许执行时返回 true。

<a id="member-gfeditorscenemetadatapatch-methods-_do_it"></a>

### `_do_it`

- API：`protected`
- 首次版本：`7.0.0`

```gdscript
func _do_it() -> Error:
```

执行 metadata 修改。

返回：Godot 错误码。

<a id="member-gfeditorscenemetadatapatch-methods-_undo_it"></a>

### `_undo_it`

- API：`protected`
- 首次版本：`7.0.0`

```gdscript
func _undo_it() -> Error:
```

撤销 metadata 修改。

返回：Godot 错误码。

<a id="member-gfeditorscenemetadatapatch-methods-_get_undo_context"></a>

### `_get_undo_context`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_undo_context() -> Object:
```

返回 metadata 实际修改的节点，确保 action 进入对应场景历史。

返回：metadata 目标节点。
