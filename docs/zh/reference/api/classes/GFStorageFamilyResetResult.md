# GFStorageFamilyResetResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_family_reset_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单个 Storage logical family 破坏性 reset/recreate 的不可变终态。 结果只公开 logical 层分类、阶段与有界计数，不暴露 Storage root、family path、 retirement staging 或任何私有 sidecar 名称。实例只能由 Storage 框架内部配置一次。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FailureKind`](#member-gfstoragefamilyresetresult-enums-failurekind) | `enum FailureKind` |
| 枚举 | [`SourceKind`](#member-gfstoragefamilyresetresult-enums-sourcekind) | `enum SourceKind` |
| 枚举 | [`Phase`](#member-gfstoragefamilyresetresult-enums-phase) | `enum Phase` |
| 枚举 | [`FamilyMember`](#member-gfstoragefamilyresetresult-enums-familymember) | `enum FamilyMember` |
| 方法 | [`is_successful`](#member-gfstoragefamilyresetresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_error_code`](#member-gfstoragefamilyresetresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_failure_kind`](#member-gfstoragefamilyresetresult-methods-get_failure_kind) | `func get_failure_kind() -> FailureKind:` |
| 方法 | [`get_source_kind`](#member-gfstoragefamilyresetresult-methods-get_source_kind) | `func get_source_kind() -> SourceKind:` |
| 方法 | [`get_failed_phase`](#member-gfstoragefamilyresetresult-methods-get_failed_phase) | `func get_failed_phase() -> Phase:` |
| 方法 | [`get_retired_member_count`](#member-gfstoragefamilyresetresult-methods-get_retired_member_count) | `func get_retired_member_count() -> int:` |
| 方法 | [`get_recreated_member_count`](#member-gfstoragefamilyresetresult-methods-get_recreated_member_count) | `func get_recreated_member_count() -> int:` |
| 方法 | [`get_remaining_evidence_count`](#member-gfstoragefamilyresetresult-methods-get_remaining_evidence_count) | `func get_remaining_evidence_count() -> int:` |
| 方法 | [`get_failed_member`](#member-gfstoragefamilyresetresult-methods-get_failed_member) | `func get_failed_member() -> FamilyMember:` |
| 方法 | [`duplicate_result`](#member-gfstoragefamilyresetresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageFamilyResetResult:` |
| 方法 | [`to_dict`](#member-gfstoragefamilyresetresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfstoragefamilyresetresult-enums-failurekind"></a>

### `FailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureKind {
	## reset/recreate 成功。
	NONE,
	## logical identity、参数或结果形状无效。
	INVALID_REQUEST,
	## 目标 logical family 不存在。
	NOT_FOUND,
	## 未提供匹配且可用的一次性破坏性授权。
	UNAUTHORIZED,
	## 私有 layout 版本高于当前运行时理解范围。
	UNSUPPORTED_LAYOUT,
	## 当前 layout 或 retirement evidence 无法安全归属于精确目标。
	CONFLICT,
	## reset worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility 生命周期、准入或同 family 串行边界未接纳请求。
	UNAVAILABLE,
	## retirement、recreate 或 cleanup I/O 失败。
	IO_FAILED,
}
```

reset/recreate 失败的稳定分类。

<a id="member-gfstoragefamilyresetresult-enums-sourcekind"></a>

### `SourceKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum SourceKind {
	## 尚未完成目标分类。
	UNKNOWN,
	## 精确 logical family 不存在。
	MISSING,
	## catalog/owner identity 有效；损坏只可能位于 payload 或可变事务 evidence。
	PAYLOAD_ONLY,
	## catalog、owner、事务身份或 family 结构发生冲突。
	STRUCTURAL_IDENTITY,
}
```

reset 前精确目标的稳定分类。

<a id="member-gfstoragefamilyresetresult-enums-phase"></a>

### `Phase`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Phase {
	## 没有失败阶段。
	NONE,
	## layout、authorization 或目标 evidence 预检。
	PREFLIGHT,
	## 把精确旧 family identity 移入 retirement staging。
	RETIRE,
	## 发布新的 owner 与 catalog claim。
	RECREATE,
	## 清理已退休的私有 evidence。
	CLEANUP,
}
```

失败发生的稳定 reset 阶段。

<a id="member-gfstoragefamilyresetresult-enums-familymember"></a>

### `FamilyMember`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FamilyMember {
	## 没有失败成员。
	NONE,
	## 全局私有 layout manifest 或版本目录。
	LAYOUT,
	## 精确 logical identity 的 catalog claim。
	CATALOG,
	## family owner claim。
	OWNER,
	## payload、candidate、backup、resource stage 或事务 evidence。
	MUTABLE_EVIDENCE,
	## 精确 family 容器或其 retirement staging。
	FAMILY_CONTAINER,
	## 与精确 logical identity 绑定的不可变 reset intent。
	RESET_INTENT,
}
```

reset 结果可报告的路径无关成员分类。

## 方法

<a id="member-gfstoragefamilyresetresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查 reset/recreate 是否完整成功。

返回：已配置为无剩余 evidence 的成功终态时返回 true。

<a id="member-gfstoragefamilyresetresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取 reset/recreate 的 Godot Error 码。

返回：成功时为 OK；未配置实例返回 FAILED。

<a id="member-gfstoragefamilyresetresult-methods-get_failure_kind"></a>

### `get_failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_kind() -> FailureKind:
```

获取稳定失败分类。

返回：FailureKind 枚举值。

<a id="member-gfstoragefamilyresetresult-methods-get_source_kind"></a>

### `get_source_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_kind() -> SourceKind:
```

获取 reset 前目标状态分类。

返回：SourceKind 枚举值。

<a id="member-gfstoragefamilyresetresult-methods-get_failed_phase"></a>

### `get_failed_phase`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_phase() -> Phase:
```

获取失败发生的阶段。

返回：成功时为 Phase.NONE。

<a id="member-gfstoragefamilyresetresult-methods-get_retired_member_count"></a>

### `get_retired_member_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_retired_member_count() -> int:
```

获取已移入 retirement staging 的 identity root 数量。

返回：0 到 2，分别对应 family container 与 catalog claim。

<a id="member-gfstoragefamilyresetresult-methods-get_recreated_member_count"></a>

### `get_recreated_member_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_recreated_member_count() -> int:
```

获取已重新发布的 claim 成员数量。

返回：0 到 3，分别计 family container、owner 与 catalog。

<a id="member-gfstoragefamilyresetresult-methods-get_remaining_evidence_count"></a>

### `get_remaining_evidence_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_remaining_evidence_count() -> int:
```

获取终态仍未清除的旧 family、retirement 或 reset intent evidence 数量。 有效的 recreated exact claim 不计入该值。

返回：0 到 5 的有界计数。

<a id="member-gfstoragefamilyresetresult-methods-get_failed_member"></a>

### `get_failed_member`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_member() -> FamilyMember:
```

获取阻止 reset 继续执行的成员分类。

返回：没有失败成员时为 FamilyMember.NONE。

<a id="member-gfstoragefamilyresetresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFStorageFamilyResetResult:
```

创建隔离结果副本。

返回：新结果对象；未配置实例返回新的未配置对象。

<a id="member-gfstoragefamilyresetresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不含物理路径的可报告字典。

返回：reset/recreate 终态、分类、阶段与有界 evidence 计数。

结构：

- `return`: Exact Dictionary with ok: bool, error_code: int (Error), failure_kind: int (FailureKind), source_kind: int (SourceKind), failed_phase: int (Phase), retired_member_count: int, recreated_member_count: int, remaining_evidence_count: int, and failed_member: int (FamilyMember).
