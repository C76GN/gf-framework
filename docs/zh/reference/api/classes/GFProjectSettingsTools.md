# GFProjectSettingsTools

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_project_settings_tools.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

ProjectSettings 默认值和属性信息注册工具。 用于让插件、扩展和项目工具以一致方式声明 ProjectSettings 键、默认值、 缺失键的初始值和 Inspector 元数据。工具不解释具体设置语义，也不保存 project.godot。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`ensure_setting`](#member-gfprojectsettingstools-methods-ensure_setting) | `static func ensure_setting( setting_name: String, default_value: Variant, options: Dictionary = {} ) -> bool:` |
| 方法 | [`register_property_info`](#member-gfprojectsettingstools-methods-register_property_info) | `static func register_property_info( setting_name: String, value_type: int, options: Dictionary = {} ) -> void:` |

## 方法

<a id="member-gfprojectsettingstools-methods-ensure_setting"></a>

### `ensure_setting`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func ensure_setting( setting_name: String, default_value: Variant, options: Dictionary = {} ) -> bool:
```

确保 ProjectSettings 键存在，并可选注册 Inspector 属性信息。

参数：

| 名称 | 说明 |
|---|---|
| `setting_name` | ProjectSettings 键名。 |
| `default_value` | 缺失时写入的默认值，也会作为缺失键的重置初始值。 |
| `options` | 可选参数，支持 type、hint、hint_string、usage、basic、restart_if_changed、internal、register_property_info 和 update_initial_value。 |

返回：本次是否写入了默认值。

结构：

- `default_value`: Variant ProjectSettings default value.
- `options`: Dictionary with optional type: int, hint: int, hint_string: String, usage: int, basic: bool, restart_if_changed: bool, internal: bool, register_property_info: bool, and update_initial_value: bool.

<a id="member-gfprojectsettingstools-methods-register_property_info"></a>

### `register_property_info`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func register_property_info( setting_name: String, value_type: int, options: Dictionary = {} ) -> void:
```

注册 ProjectSettings Inspector 属性信息和显示标记。

参数：

| 名称 | 说明 |
|---|---|
| `setting_name` | ProjectSettings 键名。 |
| `value_type` | Godot Variant 类型常量。 |
| `options` | 可选参数，支持 hint、hint_string、usage、basic、restart_if_changed 和 internal。 |

结构：

- `options`: Dictionary with optional hint: int, hint_string: String, usage: int, basic: bool, restart_if_changed: bool, and internal: bool.
