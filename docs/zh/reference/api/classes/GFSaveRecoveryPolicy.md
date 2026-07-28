# GFSaveRecoveryPolicy

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_recovery_policy.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

Save Profile 的显式恢复与有界重试政策。 缺失和损坏数据默认失败；项目必须显式选择保留当前内存状态。 重试只接受列出的临时错误，并受有限延迟序列约束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ACTION_FAIL`](#member-gfsaverecoverypolicy-constants-action_fail) | `const ACTION_FAIL: StringName = &"fail"` |
| 常量 | [`ACTION_USE_CURRENT_STATE`](#member-gfsaverecoverypolicy-constants-action_use_current_state) | `const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"` |
| 属性 | [`missing_file_action`](#member-gfsaverecoverypolicy-properties-missing_file_action) | `var missing_file_action: StringName = ACTION_FAIL` |
| 属性 | [`corrupt_file_action`](#member-gfsaverecoverypolicy-properties-corrupt_file_action) | `var corrupt_file_action: StringName = ACTION_FAIL` |
| 属性 | [`retry_delays_msec`](#member-gfsaverecoverypolicy-properties-retry_delays_msec) | `var retry_delays_msec: PackedInt32Array = PackedInt32Array()` |
| 属性 | [`transient_error_codes`](#member-gfsaverecoverypolicy-properties-transient_error_codes) | `var transient_error_codes: PackedInt32Array = PackedInt32Array([` |
| 属性 | [`io_timeout_msec`](#member-gfsaverecoverypolicy-properties-io_timeout_msec) | `var io_timeout_msec: int = 30_000` |
| 方法 | [`validate_policy`](#member-gfsaverecoverypolicy-methods-validate_policy) | `func validate_policy() -> Dictionary:` |
| 方法 | [`can_retry`](#member-gfsaverecoverypolicy-methods-can_retry) | `func can_retry(error_code: Error, failed_attempt_count: int) -> bool:` |
| 方法 | [`get_retry_delay_msec`](#member-gfsaverecoverypolicy-methods-get_retry_delay_msec) | `func get_retry_delay_msec(failed_attempt_count: int) -> int:` |

## 常量

<a id="member-gfsaverecoverypolicy-constants-action_fail"></a>

### `ACTION_FAIL`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ACTION_FAIL: StringName = &"fail"
```

不执行自动恢复。

<a id="member-gfsaverecoverypolicy-constants-action_use_current_state"></a>

### `ACTION_USE_CURRENT_STATE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"
```

保留当前内存状态，不写入或替换原文件。

## 属性

<a id="member-gfsaverecoverypolicy-properties-missing_file_action"></a>

### `missing_file_action`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var missing_file_action: StringName = ACTION_FAIL
```

文件缺失时的恢复动作。

<a id="member-gfsaverecoverypolicy-properties-corrupt_file_action"></a>

### `corrupt_file_action`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var corrupt_file_action: StringName = ACTION_FAIL
```

文件损坏或完整性校验失败时的恢复动作。

<a id="member-gfsaverecoverypolicy-properties-retry_delays_msec"></a>

### `retry_delays_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var retry_delays_msec: PackedInt32Array = PackedInt32Array()
```

每次临时失败后的有限重试延迟，单位毫秒。 第一个元素用于首次失败后的重试；数组耗尽后操作进入失败终态。

<a id="member-gfsaverecoverypolicy-properties-transient_error_codes"></a>

### `transient_error_codes`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var transient_error_codes: PackedInt32Array = PackedInt32Array([
```

允许重试的 Godot Error 码。

<a id="member-gfsaverecoverypolicy-properties-io_timeout_msec"></a>

### `io_timeout_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var io_timeout_msec: int = 30_000
```

单次底层 IO 的最大等待时间，单位毫秒。 超时后读取可安全失败；写入因无法取消而进入 outcome-unknown，策略仍可选择 使用同一不可变文档重试。

## 方法

<a id="member-gfsaverecoverypolicy-methods-validate_policy"></a>

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

<a id="member-gfsaverecoverypolicy-methods-can_retry"></a>

### `can_retry`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func can_retry(error_code: Error, failed_attempt_count: int) -> bool:
```

检查指定错误在当前失败次数后是否可以重试。

参数：

| 名称 | 说明 |
|---|---|
| `error_code` | 本次失败的 Godot Error 码。 |
| `failed_attempt_count` | 已失败尝试次数，从 1 开始。 |

返回：错误为临时错误且仍有延迟槽位时返回 true。

<a id="member-gfsaverecoverypolicy-methods-get_retry_delay_msec"></a>

### `get_retry_delay_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_retry_delay_msec(failed_attempt_count: int) -> int:
```

获取指定失败次数后的重试延迟。

参数：

| 名称 | 说明 |
|---|---|
| `failed_attempt_count` | 已失败尝试次数，从 1 开始。 |

返回：对应延迟；没有重试槽位时返回 -1。
