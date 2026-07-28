# GFDiagnosticSnapshotProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_diagnostic_snapshot_provider.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`10.0.0`

按请求求值的诊断快照 Provider 协议。 Provider 不会被轮询或随普通快照隐式执行。项目必须显式请求稳定 Provider ID， 输出才会由 `GFDiagnosticsUtility` 在重入保护、结构预算和脱敏边界内采集。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_DURATION_USEC`](#member-gfdiagnosticsnapshotprovider-constants-default_max_duration_usec) | `const DEFAULT_MAX_DURATION_USEC: int = 50_000` |
| 属性 | [`provider_id`](#member-gfdiagnosticsnapshotprovider-properties-provider_id) | `var provider_id: StringName = &"":` |
| 属性 | [`max_duration_usec`](#member-gfdiagnosticsnapshotprovider-properties-max_duration_usec) | `var max_duration_usec: int = DEFAULT_MAX_DURATION_USEC:` |
| 属性 | [`metadata`](#member-gfdiagnosticsnapshotprovider-properties-metadata) | `var metadata: Dictionary:` |
| 方法 | [`configure`](#member-gfdiagnosticsnapshotprovider-methods-configure) | `func configure( p_provider_id: StringName, options: Dictionary = {} ) -> GFDiagnosticSnapshotProvider:` |
| 方法 | [`validate_provider`](#member-gfdiagnosticsnapshotprovider-methods-validate_provider) | `func validate_provider() -> Dictionary:` |
| 方法 | [`collect_snapshot`](#member-gfdiagnosticsnapshotprovider-methods-collect_snapshot) | `func collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:` |
| 方法 | [`_collect_snapshot`](#member-gfdiagnosticsnapshotprovider-methods-_collect_snapshot) | `func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:` |

## 常量

<a id="member-gfdiagnosticsnapshotprovider-constants-default_max_duration_usec"></a>

### `DEFAULT_MAX_DURATION_USEC`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_MAX_DURATION_USEC: int = 50_000
```

默认 Provider 返回后验收时长预算，单位微秒。 同步 GDScript 无法被安全抢占；该预算用于拒绝和诊断已经返回的慢采集结果， 不能替代 Provider 自身的有界实现。

## 属性

<a id="member-gfdiagnosticsnapshotprovider-properties-provider_id"></a>

### `provider_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var provider_id: StringName = &"":
```

Provider 稳定 ID。

<a id="member-gfdiagnosticsnapshotprovider-properties-max_duration_usec"></a>

### `max_duration_usec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_duration_usec: int = DEFAULT_MAX_DURATION_USEC:
```

Provider 返回后的最大验收时长，单位微秒；0 表示不做时长拒绝。

<a id="member-gfdiagnosticsnapshotprovider-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary:
```

Provider 目录元数据。注册后不可修改，读取时返回副本，输出前由聚合器执行预算和脱敏。

结构：

- `metadata`: Dictionary with provider-defined catalog metadata.

## 方法

<a id="member-gfdiagnosticsnapshotprovider-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_provider_id: StringName, options: Dictionary = {} ) -> GFDiagnosticSnapshotProvider:
```

配置 Provider 定义并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_provider_id` | 稳定 Provider ID。 |
| `options` | 可选目录元数据。 |

返回：当前 Provider。

结构：

- `options`: Dictionary with optional max_duration_usec: int and metadata: Dictionary.

<a id="member-gfdiagnosticsnapshotprovider-methods-validate_provider"></a>

### `validate_provider`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_provider() -> Dictionary:
```

校验 Provider 定义。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, issues, counts, summary, and next_actions.

<a id="member-gfdiagnosticsnapshotprovider-methods-collect_snapshot"></a>

### `collect_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:
```

采集一次诊断结果。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 调用方提供的临时只读上下文。 |

返回：类型化 Provider 结果；实现返回 null 时由聚合器按无效结果处理。

结构：

- `request`: Dictionary with caller-defined ephemeral fields.

<a id="member-gfdiagnosticsnapshotprovider-methods-_collect_snapshot"></a>

### `_collect_snapshot`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
```

实现一次同步、只读且有界的诊断采集。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 调用方提供的临时上下文副本。 |

返回：类型化采集结果。

结构：

- `_request`: Dictionary with caller-defined ephemeral fields.
