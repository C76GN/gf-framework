# GFValidationRunner

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_runner.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用校验套件执行器。 执行 GFValidationSuite 中的规则，支持直接目标、资源路径和 PackedScene 实例化。 Runner 不调用项目约定方法，只把目标、路径和上下文交给显式注册的规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`validation_started`](#member-gfvalidationrunner-signals-validation_started) | `signal validation_started(suite_id: StringName)` |
| 信号 | [`target_validated`](#member-gfvalidationrunner-signals-target_validated) | `signal target_validated(target_id: String, report: GFValidationReport)` |
| 信号 | [`validation_finished`](#member-gfvalidationrunner-signals-validation_finished) | `signal validation_finished(report: GFValidationReport)` |
| 常量 | [`GFValidationSuiteBase`](#member-gfvalidationrunner-constants-gfvalidationsuitebase) | `const GFValidationSuiteBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_suite.gd")` |
| 常量 | [`GFValidationRuleBase`](#member-gfvalidationrunner-constants-gfvalidationrulebase) | `const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")` |
| 属性 | [`validate_scene_instances`](#member-gfvalidationrunner-properties-validate_scene_instances) | `var validate_scene_instances: bool = true` |
| 属性 | [`free_instantiated_scenes`](#member-gfvalidationrunner-properties-free_instantiated_scenes) | `var free_instantiated_scenes: bool = true` |
| 方法 | [`run_suite`](#member-gfvalidationrunner-methods-run_suite) | `func run_suite(suite: GFValidationSuiteBase, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`run_targets`](#member-gfvalidationrunner-methods-run_targets) | `func run_targets( targets: Array, suite: GFValidationSuiteBase = null, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`run_paths`](#member-gfvalidationrunner-methods-run_paths) | `func run_paths( paths: PackedStringArray, suite: GFValidationSuiteBase = null, options: Dictionary = {} ) -> GFValidationReport:` |

## 信号

<a id="member-gfvalidationrunner-signals-validation_started"></a>

### `validation_started`

- API：`public`

```gdscript
signal validation_started(suite_id: StringName)
```

套件开始执行后发出。

参数：

| 名称 | 说明 |
|---|---|
| `suite_id` | 套件标识。 |

<a id="member-gfvalidationrunner-signals-target_validated"></a>

### `target_validated`

- API：`public`

```gdscript
signal target_validated(target_id: String, report: GFValidationReport)
```

单个目标完成校验后发出。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标标识。 |
| `report` | 目标报告。 |

<a id="member-gfvalidationrunner-signals-validation_finished"></a>

### `validation_finished`

- API：`public`

```gdscript
signal validation_finished(report: GFValidationReport)
```

套件完成执行后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 聚合报告。 |

## 常量

<a id="member-gfvalidationrunner-constants-gfvalidationsuitebase"></a>

### `GFValidationSuiteBase`

- API：`public`

```gdscript
const GFValidationSuiteBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_suite.gd")
```

校验套件脚本基类。

<a id="member-gfvalidationrunner-constants-gfvalidationrulebase"></a>

### `GFValidationRuleBase`

- API：`public`

```gdscript
const GFValidationRuleBase = preload("res://addons/gf/standard/foundation/validation/gf_validation_rule.gd")
```

校验规则脚本基类。

## 属性

<a id="member-gfvalidationrunner-properties-validate_scene_instances"></a>

### `validate_scene_instances`

- API：`public`

```gdscript
var validate_scene_instances: bool = true
```

通过路径加载 PackedScene 时是否同时实例化根节点参与 Node 规则校验。

<a id="member-gfvalidationrunner-properties-free_instantiated_scenes"></a>

### `free_instantiated_scenes`

- API：`public`

```gdscript
var free_instantiated_scenes: bool = true
```

路径校验时是否释放由 Runner 实例化的场景根节点。

## 方法

<a id="member-gfvalidationrunner-methods-run_suite"></a>

### `run_suite`

- API：`public`

```gdscript
func run_suite(suite: GFValidationSuiteBase, options: Dictionary = {}) -> GFValidationReport:
```

执行套件。

参数：

| 名称 | 说明 |
|---|---|
| `suite` | 校验套件。 |
| `options` | 可选参数，支持 targets、paths、context、treat_warnings_as_errors。 |

返回：聚合报告。

结构：

- `options`: Dictionary runner options with targets, paths, context, and warning policy.

<a id="member-gfvalidationrunner-methods-run_targets"></a>

### `run_targets`

- API：`public`

```gdscript
func run_targets( targets: Array, suite: GFValidationSuiteBase = null, options: Dictionary = {} ) -> GFValidationReport:
```

校验一组直接目标。

参数：

| 名称 | 说明 |
|---|---|
| `targets` | 目标数组。 |
| `suite` | 可选套件；为空时使用无规则套件。 |
| `options` | 可选参数，支持 context、treat_warnings_as_errors。 |

返回：聚合报告。

结构：

- `targets`: Array of validation targets.
- `options`: Dictionary runner options with context and warning policy.

<a id="member-gfvalidationrunner-methods-run_paths"></a>

### `run_paths`

- API：`public`

```gdscript
func run_paths( paths: PackedStringArray, suite: GFValidationSuiteBase = null, options: Dictionary = {} ) -> GFValidationReport:
```

校验一组资源或场景路径。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 资源或场景路径列表。 |
| `suite` | 可选套件；为空时使用无规则套件。 |
| `options` | 可选参数，支持 context、treat_warnings_as_errors。 |

返回：聚合报告。

结构：

- `options`: Dictionary runner options with context and warning policy.
