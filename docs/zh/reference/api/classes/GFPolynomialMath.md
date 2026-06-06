# GFPolynomialMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_polynomial_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

通用实数多项式数学工具。 使用高阶到低阶的系数顺序，例如 x^2 - 5x + 6 表示为 [1, -5, 6]。 工具只提供纯计算能力，不解释项目公式、曲线配置或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_EPSILON`](#member-gfpolynomialmath-constants-default_epsilon) | `const DEFAULT_EPSILON: float = 0.000001` |
| 常量 | [`DEFAULT_ROOT_MERGE_EPSILON`](#member-gfpolynomialmath-constants-default_root_merge_epsilon) | `const DEFAULT_ROOT_MERGE_EPSILON: float = 0.00001` |
| 常量 | [`DEFAULT_MAX_ITERATIONS`](#member-gfpolynomialmath-constants-default_max_iterations) | `const DEFAULT_MAX_ITERATIONS: int = 96` |
| 常量 | [`DEFAULT_MAX_DEGREE`](#member-gfpolynomialmath-constants-default_max_degree) | `const DEFAULT_MAX_DEGREE: int = 12` |
| 方法 | [`normalize_coefficients`](#member-gfpolynomialmath-methods-normalize_coefficients) | `static func normalize_coefficients( coefficients: PackedFloat64Array, epsilon: float = DEFAULT_EPSILON ) -> PackedFloat64Array:` |
| 方法 | [`evaluate`](#member-gfpolynomialmath-methods-evaluate) | `static func evaluate(coefficients: PackedFloat64Array, x: float) -> float:` |
| 方法 | [`derivative`](#member-gfpolynomialmath-methods-derivative) | `static func derivative( coefficients: PackedFloat64Array, epsilon: float = DEFAULT_EPSILON ) -> PackedFloat64Array:` |
| 方法 | [`from_roots`](#member-gfpolynomialmath-methods-from_roots) | `static func from_roots( roots: PackedFloat64Array, leading_coefficient: float = 1.0 ) -> PackedFloat64Array:` |
| 方法 | [`real_roots`](#member-gfpolynomialmath-methods-real_roots) | `static func real_roots( coefficients: PackedFloat64Array, options: Dictionary = {} ) -> PackedFloat64Array:` |

## 常量

<a id="member-gfpolynomialmath-constants-default_epsilon"></a>

### `DEFAULT_EPSILON`

- API：`public`

```gdscript
const DEFAULT_EPSILON: float = 0.000001
```

默认浮点容差。

<a id="member-gfpolynomialmath-constants-default_root_merge_epsilon"></a>

### `DEFAULT_ROOT_MERGE_EPSILON`

- API：`public`

```gdscript
const DEFAULT_ROOT_MERGE_EPSILON: float = 0.00001
```

默认根合并距离。

<a id="member-gfpolynomialmath-constants-default_max_iterations"></a>

### `DEFAULT_MAX_ITERATIONS`

- API：`public`

```gdscript
const DEFAULT_MAX_ITERATIONS: int = 96
```

默认二分迭代次数。

<a id="member-gfpolynomialmath-constants-default_max_degree"></a>

### `DEFAULT_MAX_DEGREE`

- API：`public`

```gdscript
const DEFAULT_MAX_DEGREE: int = 12
```

默认允许的最高次数。

## 方法

<a id="member-gfpolynomialmath-methods-normalize_coefficients"></a>

### `normalize_coefficients`

- API：`public`

```gdscript
static func normalize_coefficients( coefficients: PackedFloat64Array, epsilon: float = DEFAULT_EPSILON ) -> PackedFloat64Array:
```

移除前导近零系数。

参数：

| 名称 | 说明 |
|---|---|
| `coefficients` | 高阶到低阶排列的多项式系数。 |
| `epsilon` | 小于等于该绝对值的前导项会被视为 0。 |

返回：规范化后的系数；零多项式返回空数组。

结构：

- `coefficients`: PackedFloat64Array high-to-low polynomial coefficients.

<a id="member-gfpolynomialmath-methods-evaluate"></a>

### `evaluate`

- API：`public`

```gdscript
static func evaluate(coefficients: PackedFloat64Array, x: float) -> float:
```

使用 Horner 法计算多项式在 x 处的值。

参数：

| 名称 | 说明 |
|---|---|
| `coefficients` | 高阶到低阶排列的多项式系数。 |
| `x` | 采样位置。 |

返回：多项式值；非法输入返回 NAN。

结构：

- `coefficients`: PackedFloat64Array high-to-low polynomial coefficients.

<a id="member-gfpolynomialmath-methods-derivative"></a>

### `derivative`

- API：`public`

```gdscript
static func derivative( coefficients: PackedFloat64Array, epsilon: float = DEFAULT_EPSILON ) -> PackedFloat64Array:
```

计算导函数系数。

参数：

| 名称 | 说明 |
|---|---|
| `coefficients` | 高阶到低阶排列的多项式系数。 |
| `epsilon` | 前导项规范化容差。 |

返回：导函数系数；常量或零多项式返回空数组。

结构：

- `coefficients`: PackedFloat64Array high-to-low polynomial coefficients.

<a id="member-gfpolynomialmath-methods-from_roots"></a>

### `from_roots`

- API：`public`

```gdscript
static func from_roots( roots: PackedFloat64Array, leading_coefficient: float = 1.0 ) -> PackedFloat64Array:
```

根据实根生成多项式系数。

参数：

| 名称 | 说明 |
|---|---|
| `roots` | 多项式实根列表，每个根生成一个 (x - root) 因子。 |
| `leading_coefficient` | 最高阶系数。 |

返回：高阶到低阶排列的系数；leading_coefficient 为 0 时返回空数组。

<a id="member-gfpolynomialmath-methods-real_roots"></a>

### `real_roots`

- API：`public`

```gdscript
static func real_roots( coefficients: PackedFloat64Array, options: Dictionary = {} ) -> PackedFloat64Array:
```

求多项式的实根。

参数：

| 名称 | 说明 |
|---|---|
| `coefficients` | 高阶到低阶排列的多项式系数。 |
| `options` | 可选参数，支持 epsilon、root_merge_epsilon、max_iterations、max_degree、min_x 和 max_x。 |

返回：升序排列的实根列表，重复根会按 root_merge_epsilon 合并。

结构：

- `coefficients`: PackedFloat64Array high-to-low polynomial coefficients.
- `options`: Dictionary with optional epsilon: float, root_merge_epsilon: float, max_iterations: int, max_degree: int, min_x: float, and max_x: float.
