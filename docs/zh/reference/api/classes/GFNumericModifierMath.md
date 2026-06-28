# GFNumericModifierMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_numeric_modifier_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用数值修饰计算工具。 按 priority 顺序把 add / multiply / divide 修饰应用到基础数值上，并返回结构化报告。 该类只处理纯数值计算，不绑定属性、装备、Buff、经济或任意项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Operation`](#member-gfnumericmodifiermath-enums-operation) | `enum Operation` |
| 方法 | [`make_modifier`](#member-gfnumericmodifiermath-methods-make_modifier) | `static func make_modifier( value: float, operation: Operation = Operation.ADD, priority: int = 0, enabled: bool = true, modifier_id: StringName = &"", metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`normalize_modifier`](#member-gfnumericmodifiermath-methods-normalize_modifier) | `static func normalize_modifier(raw_modifier: Dictionary) -> Dictionary:` |
| 方法 | [`calculate`](#member-gfnumericmodifiermath-methods-calculate) | `static func calculate(base_value: float, modifiers: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`calculate_value`](#member-gfnumericmodifiermath-methods-calculate_value) | `static func calculate_value(base_value: float, modifiers: Array, options: Dictionary = {}) -> float:` |

## 枚举

<a id="member-gfnumericmodifiermath-enums-operation"></a>

### `Operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum Operation {
	## 把修饰值加到当前值上。
	ADD,
	## 把当前值乘以修饰值。
	MULTIPLY,
	## 把当前值除以修饰值；除零会被报告并跳过。
	DIVIDE,
}
```

支持的数值修饰操作。

## 方法

<a id="member-gfnumericmodifiermath-methods-make_modifier"></a>

### `make_modifier`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func make_modifier( value: float, operation: Operation = Operation.ADD, priority: int = 0, enabled: bool = true, modifier_id: StringName = &"", metadata: Dictionary = {} ) -> Dictionary:
```

创建通用数值修饰字典。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 修饰数值。 |
| `operation` | 修饰操作。 |
| `priority` | 应用优先级；数值越小越早应用。 |
| `enabled` | 是否启用该修饰。 |
| `modifier_id` | 可选修饰标识，用于报告和项目侧去重。 |
| `metadata` | 项目层元数据，框架不解释其含义。 |

返回：通用数值修饰字典。

结构：

- `metadata`: Dictionary extension metadata copied into the modifier payload.
- `return`: Dictionary with `id: StringName`, `value: float`, `operation: Operation`, `priority: int`, `enabled: bool`, and `metadata: Dictionary`.

<a id="member-gfnumericmodifiermath-methods-normalize_modifier"></a>

### `normalize_modifier`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func normalize_modifier(raw_modifier: Dictionary) -> Dictionary:
```

规范化通用数值修饰字典。

参数：

| 名称 | 说明 |
|---|---|
| `raw_modifier` | 支持 `id/modifier_id/value/operation/priority/enabled/metadata` 的修饰字典。 |

返回：规范化后的修饰字典。

结构：

- `raw_modifier`: Dictionary numeric modifier payload.
- `return`: Dictionary with `id: StringName`, `value: float`, `operation: Operation`, `priority: int`, `enabled: bool`, and `metadata: Dictionary`.

<a id="member-gfnumericmodifiermath-methods-calculate"></a>

### `calculate`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func calculate(base_value: float, modifiers: Array, options: Dictionary = {}) -> Dictionary:
```

计算基础值叠加修饰后的结构化报告。

参数：

| 名称 | 说明 |
|---|---|
| `base_value` | 基础数值；非有限值会被 `fallback_value` 或 0 替换并记录 issue。 |
| `modifiers` | 修饰数组；每项支持 `id/modifier_id/value/operation/priority/enabled/metadata`。 |
| `options` | 支持 `fallback_value`、`clamp_enabled`、`min_value` / `clamp_min`、`max_value` / `clamp_max`。 |

返回：结构化计算报告。

结构：

- `modifiers`: Array[Dictionary] numeric modifier payloads. `operation` accepts Operation values or `add`, `multiply`, `divide` text.
- `options`: Dictionary calculation options.
- `return`: Dictionary with `ok: bool`, finite `base_value`, finite `value`, finite `unclamped_value`, `clamped: bool`, `applied_count: int`, `skipped_count: int`, `issue_count: int`, `applied_modifiers: Array[Dictionary]`, `skipped_modifiers: Array[Dictionary]`, and `issues: Array[Dictionary]`.

<a id="member-gfnumericmodifiermath-methods-calculate_value"></a>

### `calculate_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func calculate_value(base_value: float, modifiers: Array, options: Dictionary = {}) -> float:
```

计算基础值叠加修饰后的数值。

参数：

| 名称 | 说明 |
|---|---|
| `base_value` | 基础数值。 |
| `modifiers` | 修饰数组；格式同 calculate()。 |
| `options` | 计算选项；格式同 calculate()。 |

返回：计算后的有限数值。

结构：

- `modifiers`: Array[Dictionary] numeric modifier payloads.
- `options`: Dictionary calculation options.
