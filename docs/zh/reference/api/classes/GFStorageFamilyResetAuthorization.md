# GFStorageFamilyResetAuthorization

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_family_reset_authorization.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

单个 Storage logical family 的一次性破坏性恢复授权。 授权只能由 GFStorageUtility 为当前实例、冻结 root 与 canonical logical identity 创建。 reset 必须原样提交同一对象；跨 Utility、跨 root/file 或重复提交都会失败关闭。 授权冻结签发时的 family 观察；较新写入或修复会在签发、claim 或 worker 复核时使其 stale。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REASON_CORRUPT`](#member-gfstoragefamilyresetauthorization-constants-reason_corrupt) | `const REASON_CORRUPT: StringName = &"corrupt"` |
| 常量 | [`STATE_AVAILABLE`](#member-gfstoragefamilyresetauthorization-constants-state_available) | `const STATE_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATE_CLAIMED`](#member-gfstoragefamilyresetauthorization-constants-state_claimed) | `const STATE_CLAIMED: StringName = &"claimed"` |
| 常量 | [`STATE_STALE`](#member-gfstoragefamilyresetauthorization-constants-state_stale) | `const STATE_STALE: StringName = &"stale"` |
| 方法 | [`get_authorization_id`](#member-gfstoragefamilyresetauthorization-methods-get_authorization_id) | `func get_authorization_id() -> int:` |
| 方法 | [`get_logical_path`](#member-gfstoragefamilyresetauthorization-methods-get_logical_path) | `func get_logical_path() -> String:` |
| 方法 | [`get_reason`](#member-gfstoragefamilyresetauthorization-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_state`](#member-gfstoragefamilyresetauthorization-methods-get_state) | `func get_state() -> StringName:` |
| 方法 | [`is_available`](#member-gfstoragefamilyresetauthorization-methods-is_available) | `func is_available() -> bool:` |
| 方法 | [`is_claimed`](#member-gfstoragefamilyresetauthorization-methods-is_claimed) | `func is_claimed() -> bool:` |
| 方法 | [`is_stale`](#member-gfstoragefamilyresetauthorization-methods-is_stale) | `func is_stale() -> bool:` |

## 常量

<a id="member-gfstoragefamilyresetauthorization-constants-reason_corrupt"></a>

### `REASON_CORRUPT`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const REASON_CORRUPT: StringName = &"corrupt"
```

调用方已经确认目标读失败属于可破坏恢复的损坏状态。

<a id="member-gfstoragefamilyresetauthorization-constants-state_available"></a>

### `STATE_AVAILABLE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_AVAILABLE: StringName = &"available"
```

授权尚未被 reset 请求消费。

<a id="member-gfstoragefamilyresetauthorization-constants-state_claimed"></a>

### `STATE_CLAIMED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_CLAIMED: StringName = &"claimed"
```

授权已经被一个 reset 请求消费。

<a id="member-gfstoragefamilyresetauthorization-constants-state_stale"></a>

### `STATE_STALE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_STALE: StringName = &"stale"
```

授权无效、绑定不匹配或已经过期。

## 方法

<a id="member-gfstoragefamilyresetauthorization-methods-get_authorization_id"></a>

### `get_authorization_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_authorization_id() -> int:
```

获取当前 Utility 生命周期内唯一的授权 ID。

返回：正整数授权 ID；未配置时为 0。

<a id="member-gfstoragefamilyresetauthorization-methods-get_logical_path"></a>

### `get_logical_path`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_logical_path() -> String:
```

获取授权绑定的 canonical logical identity。

返回：portable logical file path；未配置时为空字符串。

<a id="member-gfstoragefamilyresetauthorization-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reason() -> StringName:
```

获取调用方确认的破坏性恢复原因。

返回：当前只可能为 REASON_CORRUPT；未配置时为空 StringName。

<a id="member-gfstoragefamilyresetauthorization-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_state() -> StringName:
```

获取授权当前状态。

返回：STATE_AVAILABLE、STATE_CLAIMED 或 STATE_STALE。

<a id="member-gfstoragefamilyresetauthorization-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_available() -> bool:
```

检查授权是否仍可提交一次。

返回：本地句柄已配置且尚未消费时返回 true；实际提交仍会复核冻结的 family 观察。

<a id="member-gfstoragefamilyresetauthorization-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_claimed() -> bool:
```

检查授权是否已经被 reset 请求消费。

返回：已 claim 时返回 true。

<a id="member-gfstoragefamilyresetauthorization-methods-is_stale"></a>

### `is_stale`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_stale() -> bool:
```

检查授权是否无效或已经过期。

返回：未配置或已标记 stale 时返回 true。
