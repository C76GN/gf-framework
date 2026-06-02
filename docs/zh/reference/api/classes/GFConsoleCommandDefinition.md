# GFConsoleCommandDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_console_command_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

控制台命令资源定义。 只保存命令名称、别名、描述和元数据，执行逻辑仍由注册时传入的 Callable 提供。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`command_name`](#member-gfconsolecommanddefinition-properties-command_name) | `var command_name: String = ""` |
| 属性 | [`aliases`](#member-gfconsolecommanddefinition-properties-aliases) | `var aliases: PackedStringArray = PackedStringArray()` |
| 属性 | [`description`](#member-gfconsolecommanddefinition-properties-description) | `var description: String = ""` |
| 属性 | [`metadata`](#member-gfconsolecommanddefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_all_names`](#member-gfconsolecommanddefinition-methods-get_all_names) | `func get_all_names() -> PackedStringArray:` |

## 属性

<a id="member-gfconsolecommanddefinition-properties-command_name"></a>

### `command_name`

- API：`public`

```gdscript
var command_name: String = ""
```

主命令名。

<a id="member-gfconsolecommanddefinition-properties-aliases"></a>

### `aliases`

- API：`public`

```gdscript
var aliases: PackedStringArray = PackedStringArray()
```

命令别名。

<a id="member-gfconsolecommanddefinition-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

命令描述。

<a id="member-gfconsolecommanddefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义命令元数据。

## 方法

<a id="member-gfconsolecommanddefinition-methods-get_all_names"></a>

### `get_all_names`

- API：`public`

```gdscript
func get_all_names() -> PackedStringArray:
```

获取所有命令名。

返回：主命令和别名。
