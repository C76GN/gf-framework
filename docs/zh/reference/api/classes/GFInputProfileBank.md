# GFInputProfileBank

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_profile_bank.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

命名输入重映射配置集合。 用于保存、切换和复制多个 GFInputRemapConfig。它只管理配置资源， 不规定玩家、存档槽位、UI 展示或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`profiles`](#member-gfinputprofilebank-properties-profiles) | `var profiles: Dictionary = {}` |
| 属性 | [`active_profile_id`](#member-gfinputprofilebank-properties-active_profile_id) | `var active_profile_id: StringName = &""` |
| 属性 | [`custom_data`](#member-gfinputprofilebank-properties-custom_data) | `var custom_data: Dictionary = {}` |
| 方法 | [`set_profile`](#member-gfinputprofilebank-methods-set_profile) | `func set_profile( profile_id: StringName, config: GFInputRemapConfig, duplicate_config: bool = true ) -> void:` |
| 方法 | [`ensure_profile`](#member-gfinputprofilebank-methods-ensure_profile) | `func ensure_profile(profile_id: StringName) -> GFInputRemapConfig:` |
| 方法 | [`get_profile`](#member-gfinputprofilebank-methods-get_profile) | `func get_profile(profile_id: StringName, duplicate_result: bool = false) -> GFInputRemapConfig:` |
| 方法 | [`has_profile`](#member-gfinputprofilebank-methods-has_profile) | `func has_profile(profile_id: StringName) -> bool:` |
| 方法 | [`remove_profile`](#member-gfinputprofilebank-methods-remove_profile) | `func remove_profile(profile_id: StringName) -> bool:` |
| 方法 | [`get_profile_ids`](#member-gfinputprofilebank-methods-get_profile_ids) | `func get_profile_ids() -> PackedStringArray:` |
| 方法 | [`clear_profiles`](#member-gfinputprofilebank-methods-clear_profiles) | `func clear_profiles() -> void:` |
| 方法 | [`set_active_profile`](#member-gfinputprofilebank-methods-set_active_profile) | `func set_active_profile(profile_id: StringName) -> bool:` |
| 方法 | [`get_active_profile`](#member-gfinputprofilebank-methods-get_active_profile) | `func get_active_profile(duplicate_result: bool = false) -> GFInputRemapConfig:` |
| 方法 | [`duplicate_bank`](#member-gfinputprofilebank-methods-duplicate_bank) | `func duplicate_bank() -> GFInputProfileBank:` |

## 属性

<a id="member-gfinputprofilebank-properties-profiles"></a>

### `profiles`

- API：`public`

```gdscript
var profiles: Dictionary = {}
```

命名重映射配置。结构为 profile_id -> GFInputRemapConfig。

结构：

- `profiles`: Dictionary，以 StringName 或 String profile id 为键，值为 GFInputRemapConfig。

<a id="member-gfinputprofilebank-properties-active_profile_id"></a>

### `active_profile_id`

- API：`public`

```gdscript
var active_profile_id: StringName = &""
```

当前激活的配置 ID。为空表示尚未选择。

<a id="member-gfinputprofilebank-properties-custom_data"></a>

### `custom_data`

- API：`public`

```gdscript
var custom_data: Dictionary = {}
```

项目自定义数据。框架不解释该字段。

结构：

- `custom_data`: Dictionary，项目持有的 UI、存档槽或平台元数据。

## 方法

<a id="member-gfinputprofilebank-methods-set_profile"></a>

### `set_profile`

- API：`public`

```gdscript
func set_profile( profile_id: StringName, config: GFInputRemapConfig, duplicate_config: bool = true ) -> void:
```

设置一个命名配置。默认会深拷贝传入配置，避免外部继续修改污染 bank。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |
| `config` | 输入重映射配置；为 null 时移除该配置。 |
| `duplicate_config` | 是否保存配置副本。 |

<a id="member-gfinputprofilebank-methods-ensure_profile"></a>

### `ensure_profile`

- API：`public`

```gdscript
func ensure_profile(profile_id: StringName) -> GFInputRemapConfig:
```

确保指定配置存在并返回它。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |

返回：现有或新建的重映射配置。

<a id="member-gfinputprofilebank-methods-get_profile"></a>

### `get_profile`

- API：`public`

```gdscript
func get_profile(profile_id: StringName, duplicate_result: bool = false) -> GFInputRemapConfig:
```

获取指定命名配置。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |
| `duplicate_result` | 是否返回深拷贝。 |

返回：重映射配置；不存在时返回 null。

<a id="member-gfinputprofilebank-methods-has_profile"></a>

### `has_profile`

- API：`public`

```gdscript
func has_profile(profile_id: StringName) -> bool:
```

检查指定配置是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |

返回：是否存在。

<a id="member-gfinputprofilebank-methods-remove_profile"></a>

### `remove_profile`

- API：`public`

```gdscript
func remove_profile(profile_id: StringName) -> bool:
```

移除指定配置。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |

返回：成功移除时返回 true。

<a id="member-gfinputprofilebank-methods-get_profile_ids"></a>

### `get_profile_ids`

- API：`public`

```gdscript
func get_profile_ids() -> PackedStringArray:
```

获取所有有效配置 ID。

返回：排序后的配置 ID。

<a id="member-gfinputprofilebank-methods-clear_profiles"></a>

### `clear_profiles`

- API：`public`

```gdscript
func clear_profiles() -> void:
```

清空所有配置。

<a id="member-gfinputprofilebank-methods-set_active_profile"></a>

### `set_active_profile`

- API：`public`

```gdscript
func set_active_profile(profile_id: StringName) -> bool:
```

设置当前激活配置。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 配置 ID。 |

返回：成功设置时返回 true。

<a id="member-gfinputprofilebank-methods-get_active_profile"></a>

### `get_active_profile`

- API：`public`

```gdscript
func get_active_profile(duplicate_result: bool = false) -> GFInputRemapConfig:
```

获取当前激活配置。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_result` | 是否返回深拷贝。 |

返回：当前配置；未设置或不存在时返回 null。

<a id="member-gfinputprofilebank-methods-duplicate_bank"></a>

### `duplicate_bank`

- API：`public`

```gdscript
func duplicate_bank() -> GFInputProfileBank:
```

创建 bank 的深拷贝。

返回：新的配置集合。
