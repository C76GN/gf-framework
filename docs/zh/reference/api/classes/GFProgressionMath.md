# GFProgressionMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_progression_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

挂机与模拟经营项目的纯进度曲线数学工具。 负责价格曲线、收益曲线、里程碑倍率、软上限与分段式离线收益结算。 它不依赖 GFArchitecture，可直接与 JSON、CSV 或外部工具导出的配置字典配合使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CurveMode`](#member-gfprogressionmath-enums-curvemode) | `enum CurveMode` |
| 方法 | [`evaluate_curve`](#member-gfprogressionmath-methods-evaluate_curve) | `static func evaluate_curve(level: int, curve_config: Dictionary) -> GFBigNumber:` |
| 方法 | [`apply_milestone_multipliers`](#member-gfprogressionmath-methods-apply_milestone_multipliers) | `static func apply_milestone_multipliers(value: Variant, level: int, milestones: Array) -> GFBigNumber:` |
| 方法 | [`apply_soft_cap`](#member-gfprogressionmath-methods-apply_soft_cap) | `static func apply_soft_cap( value: Variant, soft_cap: Variant, power: float = _DEFAULT_SOFT_CAP_POWER ) -> GFBigNumber:` |
| 方法 | [`settle_offline_progress`](#member-gfprogressionmath-methods-settle_offline_progress) | `static func settle_offline_progress( rate_per_second: Variant, offline_seconds: float, options: Dictionary = {} ) -> Dictionary:` |

## 枚举

<a id="member-gfprogressionmath-enums-curvemode"></a>

### `CurveMode`

- API：`public`

```gdscript
enum CurveMode {
	## 常量曲线。
	CONSTANT,
	## 线性曲线。
	LINEAR,
	## 指数曲线。
	EXPONENTIAL,
}
```

支持的基础曲线类型。

## 方法

<a id="member-gfprogressionmath-methods-evaluate_curve"></a>

### `evaluate_curve`

- API：`public`

```gdscript
static func evaluate_curve(level: int, curve_config: Dictionary) -> GFBigNumber:
```

根据配置计算某一级的曲线值。

参数：

| 名称 | 说明 |
|---|---|
| `level` | 目标等级。 |
| `curve_config` | 支持 `base_value/start_level/mode/per_level/multiplier/phases/overrides`。 |

返回：对应等级的曲线值。

结构：

- `curve_config`: Dictionary with optional `base_value`, `start_level`, `mode`, `per_level`, `multiplier`, `phases`, and `overrides` entries.

<a id="member-gfprogressionmath-methods-apply_milestone_multipliers"></a>

### `apply_milestone_multipliers`

- API：`public`

```gdscript
static func apply_milestone_multipliers(value: Variant, level: int, milestones: Array) -> GFBigNumber:
```

为基础值叠加里程碑倍率。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 基础数值。 |
| `level` | 当前等级。 |
| `milestones` | 里程碑数组；每项支持 `level/multiplier`。 |

返回：叠加后的数值。

结构：

- `value`: Variant numeric value accepted by GFBigNumber.
- `milestones`: Array[Dictionary] where each entry may contain `level: int` and `multiplier: Variant numeric value`.

<a id="member-gfprogressionmath-methods-apply_soft_cap"></a>

### `apply_soft_cap`

- API：`public`

```gdscript
static func apply_soft_cap( value: Variant, soft_cap: Variant, power: float = _DEFAULT_SOFT_CAP_POWER ) -> GFBigNumber:
```

对一个值应用幂函数型软上限。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 原始值。 |
| `soft_cap` | 软上限起点。 |
| `power` | 超出部分的幂指数；0.5 表示平方根衰减。 |

返回：软上限处理后的数值。

结构：

- `value`: Variant numeric value accepted by GFBigNumber.
- `soft_cap`: Variant numeric value accepted by GFBigNumber.

<a id="member-gfprogressionmath-methods-settle_offline_progress"></a>

### `settle_offline_progress`

- API：`public`

```gdscript
static func settle_offline_progress( rate_per_second: Variant, offline_seconds: float, options: Dictionary = {} ) -> Dictionary:
```

计算一段离线时间内的收益。

参数：

| 名称 | 说明 |
|---|---|
| `rate_per_second` | 基础每秒产出。 |
| `offline_seconds` | 离线时长（秒）。 |
| `options` | 支持 `max_seconds/storage_remaining/segments`。 |

返回：包含产出与时间统计的字典。

结构：

- `rate_per_second`: Variant numeric value accepted by GFBigNumber.
- `options`: Dictionary with optional `max_seconds`, `storage_remaining`, and `segments: Array[Dictionary]`.
- `return`: Dictionary with `produced: GFBigNumber`, `requested_seconds: float`, `settled_seconds: float`, `consumed_seconds: float`, `expired_seconds: float`, `wasted_seconds: float`, and `storage_capped: bool`.
