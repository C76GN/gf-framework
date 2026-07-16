# GFInputMapPresetTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/mapping/gf_input_map_preset_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

Godot InputMap 预设转换工具。 用于把当前运行时 InputMap 捕获为通用字典，或把字典预设应用回 InputMap。它不负责保存文件、写入 ProjectSettings、玩家 profile 语义或 UI 流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`PRESET_VERSION`](#member-gfinputmappresettools-constants-preset_version) | `const PRESET_VERSION: int = 1` |
| 方法 | [`capture_input_map`](#member-gfinputmappresettools-methods-capture_input_map) | `static func capture_input_map(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_input_map_preset`](#member-gfinputmappresettools-methods-apply_input_map_preset) | `static func apply_input_map_preset(preset: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`ensure_input_map_preset`](#member-gfinputmappresettools-methods-ensure_input_map_preset) | `static func ensure_input_map_preset(preset: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfinputmappresettools-constants-preset_version"></a>

### `PRESET_VERSION`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const PRESET_VERSION: int = 1
```

InputMap 预设格式版本。

## 方法

<a id="member-gfinputmappresettools-methods-capture_input_map"></a>

### `capture_input_map`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func capture_input_map(options: Dictionary = {}) -> Dictionary:
```

捕获当前 InputMap 为可序列化预设字典。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项，支持 action_ids、include_ui_actions、include_empty_actions、sort_actions、metadata。 |

返回：InputMap 预设字典。

结构：

- `options`: Dictionary with optional action_ids: Array[String] or PackedStringArray, include_ui_actions: bool, include_empty_actions: bool, sort_actions: bool, metadata: Dictionary.
- `return`: Dictionary { version: int, actions: Array[Dictionary], metadata: Dictionary }. Each action has action_id, deadzone, and events.

<a id="member-gfinputmappresettools-methods-apply_input_map_preset"></a>

### `apply_input_map_preset`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func apply_input_map_preset(preset: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将预设字典应用到当前 InputMap。

参数：

| 名称 | 说明 |
|---|---|
| `preset` | InputMap 预设字典。 |
| `options` | 可选项，支持 action_ids、include_ui_actions、clear_existing_events。 |

返回：应用报告。

结构：

- `preset`: Dictionary created by capture_input_map().
- `options`: Dictionary with optional action_ids: Array[String] or PackedStringArray, include_ui_actions: bool, clear_existing_events: bool.
- `return`: Dictionary { ok: bool, applied_count: int, event_count: int, skipped_count: int, issues: Array[Dictionary] }.

<a id="member-gfinputmappresettools-methods-ensure_input_map_preset"></a>

### `ensure_input_map_preset`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func ensure_input_map_preset(preset: Dictionary, options: Dictionary = {}) -> Dictionary:
```

确保预设中的动作存在，并只补齐缺失的事件。 该入口适合启动期或调试工具按项目声明补齐运行时 InputMap 默认动作； 它不会写入 ProjectSettings，也不会默认覆盖已有动作的 deadzone 或绑定。

参数：

| 名称 | 说明 |
|---|---|
| `preset` | InputMap 预设字典。 |
| `options` | 可选项，支持 action_ids、include_ui_actions、add_missing_events、update_existing_deadzone、dry_run。 |

返回：确保报告。

结构：

- `preset`: Dictionary created by capture_input_map().
- `options`: Dictionary with optional action_ids: Array[String] or PackedStringArray, include_ui_actions: bool, add_missing_events: bool, update_existing_deadzone: bool, dry_run: bool.
- `return`: Dictionary { ok: bool, dry_run: bool, ensured_count: int, existing_count: int, missing_action_count: int, missing_event_count: int, created_count: int, added_event_count: int, updated_deadzone_count: int, skipped_count: int, actions: Array[Dictionary], issues: Array[Dictionary] }.
