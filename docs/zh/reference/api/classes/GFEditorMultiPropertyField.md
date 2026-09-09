# GFEditorMultiPropertyField

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_multi_property_field.gd`
- 模块：`Kernel`
- 继承：`VBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`unreleased`

编辑器中多个对象的单属性暂存输入。 显示一致、混合、缺失与不兼容状态。标量整值编辑，Vector2/3/4 及其整数类型按分量编辑。 输入不写对象；调用方将 prepare_changes 的结果交给 GFEditorPropertyBatchCommand。 目标在暂存期间使用弱引用，取消、重新配置和离树均丢弃草稿。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`draft_changed`](#member-gfeditormultipropertyfield-signals-draft_changed) | `signal draft_changed()` |
| 方法 | [`configure`](#member-gfeditormultipropertyfield-methods-configure) | `func configure(targets: Array[Object], property: StringName) -> void:` |
| 方法 | [`cancel_edit`](#member-gfeditormultipropertyfield-methods-cancel_edit) | `func cancel_edit() -> void:` |
| 方法 | [`get_snapshot`](#member-gfeditormultipropertyfield-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |
| 方法 | [`prepare_changes`](#member-gfeditormultipropertyfield-methods-prepare_changes) | `func prepare_changes() -> Dictionary:` |

## 信号

<a id="member-gfeditormultipropertyfield-signals-draft_changed"></a>

### `draft_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal draft_changed()
```

草稿或选择状态变化后发出，不表示对象已写入。

## 方法

<a id="member-gfeditormultipropertyfield-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure(targets: Array[Object], property: StringName) -> void:
```

以去重后的目标重新建立选择，丢弃此前草稿；不保活目标。

参数：

| 名称 | 说明 |
|---|---|
| `targets` | 要共同编辑的对象；失效目标使整组不可编辑。 |
| `property` | 直接属性名。 |

<a id="member-gfeditormultipropertyfield-methods-cancel_edit"></a>

### `cancel_edit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_edit() -> void:
```

取消草稿并重新读取仍然有效的选中对象，不写入任何属性。

<a id="member-gfeditormultipropertyfield-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_snapshot() -> Dictionary:
```

返回选择与暂存状态的独立副本；状态在配置、取消或准备提交时重新检查。

返回：选择摘要，不包含对象引用。

结构：

- `return`: Dictionary 包含 status（empty/invalid/missing/incompatible/readonly/unsupported/uniform/mixed）、property: StringName、target_count: int、dirty: bool、components: Dictionary；各分量包含 value: Variant 标量值、mixed: bool、edited: bool。

<a id="member-gfeditormultipropertyfield-methods-prepare_changes"></a>

### `prepare_changes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_changes() -> Dictionary:
```

再次验证目标和属性声明，生成只包含已编辑分量的批量命令输入，不执行写入。 未编辑分量在执行时由命令读取当前值；任一失效、缺失或不兼容目标使整批失败。

返回：准备结果。返回 changes 的目标引用由调用方负责释放或移交给命令历史。

结构：

- `return`: Dictionary 包含 ok: bool、error: Error、status: String、changes: Array[Dictionary]；每项包含 target: Object、new_value: Variant，及 property_name: StringName 或 property_path: NodePath。
