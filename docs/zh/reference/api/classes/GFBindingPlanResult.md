# GFBindingPlanResult

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_binding_plan_result.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

required binding plan 的不可变终态结果。 结果精确标识首个失败 entry、绑定类别、阶段与稳定原因；不保留 Builder、 Architecture、Scope、实例或 Callable 引用，可安全用于诊断与持久化日志。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfbindingplanresult-enums-status) | `enum Status` |
| 枚举 | [`BindingKind`](#member-gfbindingplanresult-enums-bindingkind) | `enum BindingKind` |
| 枚举 | [`Phase`](#member-gfbindingplanresult-enums-phase) | `enum Phase` |
| 枚举 | [`Reason`](#member-gfbindingplanresult-enums-reason) | `enum Reason` |
| 方法 | [`is_successful`](#member-gfbindingplanresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfbindingplanresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_binding_kind`](#member-gfbindingplanresult-methods-get_binding_kind) | `func get_binding_kind() -> BindingKind:` |
| 方法 | [`get_failed_phase`](#member-gfbindingplanresult-methods-get_failed_phase) | `func get_failed_phase() -> Phase:` |
| 方法 | [`get_reason`](#member-gfbindingplanresult-methods-get_reason) | `func get_reason() -> Reason:` |
| 方法 | [`get_entry_index`](#member-gfbindingplanresult-methods-get_entry_index) | `func get_entry_index() -> int:` |
| 方法 | [`get_binding_id`](#member-gfbindingplanresult-methods-get_binding_id) | `func get_binding_id() -> StringName:` |
| 方法 | [`get_target_path`](#member-gfbindingplanresult-methods-get_target_path) | `func get_target_path() -> String:` |
| 方法 | [`get_lifetime`](#member-gfbindingplanresult-methods-get_lifetime) | `func get_lifetime() -> int:` |
| 方法 | [`get_executed_count`](#member-gfbindingplanresult-methods-get_executed_count) | `func get_executed_count() -> int:` |
| 方法 | [`get_detail`](#member-gfbindingplanresult-methods-get_detail) | `func get_detail() -> String:` |
| 方法 | [`duplicate_result`](#member-gfbindingplanresult-methods-duplicate_result) | `func duplicate_result() -> GFBindingPlanResult:` |
| 方法 | [`to_dict`](#member-gfbindingplanresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfbindingplanresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Status {
	## 全部 required entry 已按顺序成功执行。
	SUCCESS = 0,
	## 某个 required entry 执行失败。
	FAILED = 1,
	## Scope 在执行前或执行期间取消。
	CANCELLED = 2,
	## Plan、Builder ownership 或 Scope 请求无效。
	INVALID_REQUEST = 3,
}
```

Plan 终态。

<a id="member-gfbindingplanresult-enums-bindingkind"></a>

### `BindingKind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum BindingKind {
	## 没有具体 entry。
	NONE = 0,
	## Model 生命周期模块。
	MODEL = 1,
	## System 生命周期模块。
	SYSTEM = 2,
	## Utility 生命周期模块。
	UTILITY = 3,
	## 短生命周期对象工厂。
	FACTORY = 4,
}
```

绑定类别。

<a id="member-gfbindingplanresult-enums-phase"></a>

### `Phase`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Phase {
	## 没有失败阶段。
	NONE = 0,
	## Plan、Scope、Architecture 或 entry 前置校验。
	VALIDATION = 1,
	## SELF、factory 或 instance 来源的 candidate 创建。
	INSTANCE_CREATION = 2,
	## 生命周期模块或对象工厂注册。
	REGISTRATION = 3,
	## 模块查询别名注册。
	ALIAS = 4,
	## Scope 取消观察。
	CANCELLATION = 5,
}
```

首个失败阶段。

<a id="member-gfbindingplanresult-enums-reason"></a>

### `Reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Reason {
	## 没有失败原因。
	NONE = 0,
	## Plan 配置无效。
	INVALID_PLAN = 1,
	## Builder 不属于 Plan 的 Architecture。
	BUILDER_OWNERSHIP_MISMATCH = 2,
	## binding_id 在同一 Plan 中重复。
	DUPLICATE_BINDING_ID = 3,
	## 正在执行的 Plan 被重入，或已结算 Plan 被再次执行。
	ALREADY_EXECUTED = 4,
	## Scope 为空或已经 complete。
	SCOPE_UNAVAILABLE = 5,
	## Scope 在执行前或执行期间取消。
	SCOPE_CANCELLED = 6,
	## Architecture 不再接纳 required binding mutation。
	ARCHITECTURE_UNAVAILABLE = 7,
	## Entry 目标或冻结配置无效。
	INVALID_ENTRY = 8,
	## Entry 生命周期与目标类别不兼容。
	INVALID_LIFETIME = 9,
	## 无法创建绑定 candidate。
	INSTANCE_CREATION_FAILED = 10,
	## Architecture 拒绝注册模块或工厂。
	REGISTRATION_REJECTED = 11,
	## Architecture 拒绝注册模块别名。
	ALIAS_REJECTED = 12,
}
```

稳定失败原因。

## 方法

<a id="member-gfbindingplanresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

返回终态是否成功。

返回：全部 required entry 成功时返回 true。

<a id="member-gfbindingplanresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

返回 Plan 终态。

返回：Status 枚举值。

<a id="member-gfbindingplanresult-methods-get_binding_kind"></a>

### `get_binding_kind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_binding_kind() -> BindingKind:
```

返回首个失败 entry 的绑定类别。

返回：BindingKind 枚举值；成功或无具体 entry 时为 NONE。

<a id="member-gfbindingplanresult-methods-get_failed_phase"></a>

### `get_failed_phase`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_failed_phase() -> Phase:
```

返回首个失败阶段。

返回：Phase 枚举值；成功时为 NONE。

<a id="member-gfbindingplanresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reason() -> Reason:
```

返回稳定失败原因。

返回：Reason 枚举值；成功时为 NONE。

<a id="member-gfbindingplanresult-methods-get_entry_index"></a>

### `get_entry_index`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_entry_index() -> int:
```

返回首个失败 entry 的零基索引。

返回：首个失败 entry 索引；成功或无具体 entry 时为 -1。

<a id="member-gfbindingplanresult-methods-get_binding_id"></a>

### `get_binding_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_binding_id() -> StringName:
```

返回首个失败 entry 的稳定调用方 ID。

返回：binding_id；成功或无具体 entry 时为空。

<a id="member-gfbindingplanresult-methods-get_target_path"></a>

### `get_target_path`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_target_path() -> String:
```

返回目标脚本的稳定 res:// 路径。

返回：目标脚本路径；没有可识别目标时为空。

<a id="member-gfbindingplanresult-methods-get_lifetime"></a>

### `get_lifetime`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_lifetime() -> int:
```

返回 entry 请求的绑定生命周期。

返回：GFBindingLifetimes.Lifetime 枚举值；无具体 entry 时为 -1。

<a id="member-gfbindingplanresult-methods-get_executed_count"></a>

### `get_executed_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_executed_count() -> int:
```

返回已尝试的 entry 数量。 只计已经进入 Builder attempt 的 entry：attempt 内失败的当前 entry 计入，声明、 Plan、Scope 或 Architecture preflight 失败不计，未尝试的后续 entry 也不计。

返回：非负 entry 尝试数量。

<a id="member-gfbindingplanresult-methods-get_detail"></a>

### `get_detail`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_detail() -> String:
```

返回有界稳定诊断文本。

返回：最多 512 个字符的诊断文本。

<a id="member-gfbindingplanresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_result() -> GFBindingPlanResult:
```

创建终态结果的隔离副本。

返回：字段相同的新 GFBindingPlanResult。

<a id="member-gfbindingplanresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为精确、纯数据 Dictionary。

返回：Plan 终态的纯数据投影。

结构：

- `return`: Dictionary，精确包含 status: int、is_successful: bool、binding_kind: int、failed_phase: int、reason: int、entry_index: int、binding_id: String、target_path: String、lifetime: int、executed_count: int 和 detail: String。
