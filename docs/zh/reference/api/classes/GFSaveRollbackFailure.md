# GFSaveRollbackFailure

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_rollback_failure.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

单个 section 回滚失败证据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_section_id`](#member-gfsaverollbackfailure-methods-get_section_id) | `func get_section_id() -> StringName:` |
| 方法 | [`get_error_code`](#member-gfsaverollbackfailure-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`duplicate_failure`](#member-gfsaverollbackfailure-methods-duplicate_failure) | `func duplicate_failure() -> GFSaveRollbackFailure:` |
| 方法 | [`to_dict`](#member-gfsaverollbackfailure-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 方法

<a id="member-gfsaverollbackfailure-methods-get_section_id"></a>

### `get_section_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_section_id() -> StringName:
```

获取回滚失败的 section ID。

返回：section ID。

<a id="member-gfsaverollbackfailure-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_error_code() -> Error:
```

获取回滚 Error 码。

返回：非 OK Error 码。

<a id="member-gfsaverollbackfailure-methods-duplicate_failure"></a>

### `duplicate_failure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_failure() -> GFSaveRollbackFailure:
```

创建隔离副本。

返回：新失败证据对象。

<a id="member-gfsaverollbackfailure-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可报告字典。

返回：section_id 与 error_code 字段。

结构：

- `return`: Dictionary with section_id and error_code fields.
