# GFSettingsRecoveryPolicy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_settings_recovery_policy.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

设置加载的显式恢复策略。 缺失与损坏设置默认严格失败。项目可以显式选择保留当前内存状态， 或把有效设置重置为已注册默认值；恢复不会创建或覆盖持久化文件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ACTION_FAIL`](#member-gfsettingsrecoverypolicy-constants-action_fail) | `const ACTION_FAIL: StringName = &"fail"` |
| 常量 | [`ACTION_USE_CURRENT_STATE`](#member-gfsettingsrecoverypolicy-constants-action_use_current_state) | `const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"` |
| 常量 | [`ACTION_RESET_TO_DEFAULTS`](#member-gfsettingsrecoverypolicy-constants-action_reset_to_defaults) | `const ACTION_RESET_TO_DEFAULTS: StringName = &"reset_to_defaults"` |
| 属性 | [`missing_file_action`](#member-gfsettingsrecoverypolicy-properties-missing_file_action) | `var missing_file_action: StringName = ACTION_FAIL` |
| 属性 | [`corrupt_file_action`](#member-gfsettingsrecoverypolicy-properties-corrupt_file_action) | `var corrupt_file_action: StringName = ACTION_FAIL` |
| 方法 | [`validate_policy`](#member-gfsettingsrecoverypolicy-methods-validate_policy) | `func validate_policy() -> Dictionary:` |

## 常量

<a id="member-gfsettingsrecoverypolicy-constants-action_fail"></a>

### `ACTION_FAIL`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ACTION_FAIL: StringName = &"fail"
```

不执行自动恢复。

<a id="member-gfsettingsrecoverypolicy-constants-action_use_current_state"></a>

### `ACTION_USE_CURRENT_STATE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"
```

保留当前有效值和暂存值。

<a id="member-gfsettingsrecoverypolicy-constants-action_reset_to_defaults"></a>

### `ACTION_RESET_TO_DEFAULTS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ACTION_RESET_TO_DEFAULTS: StringName = &"reset_to_defaults"
```

使用空 replace 语义恢复已注册默认值。

## 属性

<a id="member-gfsettingsrecoverypolicy-properties-missing_file_action"></a>

### `missing_file_action`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var missing_file_action: StringName = ACTION_FAIL
```

文件缺失时的恢复动作。

<a id="member-gfsettingsrecoverypolicy-properties-corrupt_file_action"></a>

### `corrupt_file_action`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var corrupt_file_action: StringName = ACTION_FAIL
```

文件损坏或完整性校验失败时的恢复动作。

## 方法

<a id="member-gfsettingsrecoverypolicy-methods-validate_policy"></a>

### `validate_policy`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_policy() -> Dictionary:
```

检查策略自身是否合法。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
