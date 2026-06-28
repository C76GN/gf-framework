# GFBuildInfoExportPlugin

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd`
- 模块：`Standard`
- 继承：`EditorExportPlugin`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

导出时写入构建元数据的可选编辑器插件。 只负责把外部构建流水线已提供的构建字段写入 ProjectSettings，项目仍可决定是否保存、 是否恢复旧值以及如何展示这些字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ENABLED_SETTING`](#member-gfbuildinfoexportplugin-constants-enabled_setting) | `const ENABLED_SETTING: String = GFBuildInfo.EXPORT_ENABLED_SETTING` |
| 常量 | [`BUILD_METADATA_SETTING`](#member-gfbuildinfoexportplugin-constants-build_metadata_setting) | `const BUILD_METADATA_SETTING: String = GFBuildInfo.EXPORT_BUILD_METADATA_SETTING` |
| 常量 | [`RESTORE_PREVIOUS_SETTING`](#member-gfbuildinfoexportplugin-constants-restore_previous_setting) | `const RESTORE_PREVIOUS_SETTING: String = GFBuildInfo.EXPORT_RESTORE_PREVIOUS_SETTING` |
| 常量 | [`SAVE_PROJECT_SETTINGS_SETTING`](#member-gfbuildinfoexportplugin-constants-save_project_settings_setting) | `const SAVE_PROJECT_SETTINGS_SETTING: String = GFBuildInfo.EXPORT_SAVE_PROJECT_SETTINGS_SETTING` |
| 常量 | [`EXTRA_METADATA_SETTING`](#member-gfbuildinfoexportplugin-constants-extra_metadata_setting) | `const EXTRA_METADATA_SETTING: String = GFBuildInfo.EXPORT_EXTRA_METADATA_SETTING` |

## 常量

<a id="member-gfbuildinfoexportplugin-constants-enabled_setting"></a>

### `ENABLED_SETTING`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const ENABLED_SETTING: String = GFBuildInfo.EXPORT_ENABLED_SETTING
```

是否在导出开始时写入构建元数据的 ProjectSettings 键。

<a id="member-gfbuildinfoexportplugin-constants-build_metadata_setting"></a>

### `BUILD_METADATA_SETTING`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
const BUILD_METADATA_SETTING: String = GFBuildInfo.EXPORT_BUILD_METADATA_SETTING
```

导出时写入 ProjectSettings 的构建元数据字典键。

结构：

- `value`: Dictionary，可包含 GFBuildInfo.write_metadata_to_project_settings() 支持的构建字段。

<a id="member-gfbuildinfoexportplugin-constants-restore_previous_setting"></a>

### `RESTORE_PREVIOUS_SETTING`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const RESTORE_PREVIOUS_SETTING: String = GFBuildInfo.EXPORT_RESTORE_PREVIOUS_SETTING
```

导出结束后是否恢复旧构建元数据的 ProjectSettings 键。

<a id="member-gfbuildinfoexportplugin-constants-save_project_settings_setting"></a>

### `SAVE_PROJECT_SETTINGS_SETTING`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const SAVE_PROJECT_SETTINGS_SETTING: String = GFBuildInfo.EXPORT_SAVE_PROJECT_SETTINGS_SETTING
```

写入或恢复后是否立即保存 ProjectSettings 的设置键。

<a id="member-gfbuildinfoexportplugin-constants-extra_metadata_setting"></a>

### `EXTRA_METADATA_SETTING`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const EXTRA_METADATA_SETTING: String = GFBuildInfo.EXPORT_EXTRA_METADATA_SETTING
```

导出时附加到构建信息中的自定义元数据 ProjectSettings 键。
