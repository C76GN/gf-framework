# GFInputDirectionTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/common/gf_input_direction_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

二维输入方向处理工具。 提供径向 deadzone、2/4/8 向离散化、方向名称和反向方向映射。 它只处理纯 Vector2 数据，不读取 InputMap，也不规定动作命名。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`SnapMode`](#member-gfinputdirectiontools-enums-snapmode) | `enum SnapMode` |
| 枚举 | [`Direction2D`](#member-gfinputdirectiontools-enums-direction2d) | `enum Direction2D` |
| 方法 | [`apply_radial_deadzone`](#member-gfinputdirectiontools-methods-apply_radial_deadzone) | `static func apply_radial_deadzone( raw_direction: Vector2, deadzone: float, rescale_after_deadzone: bool = true ) -> Vector2:` |
| 方法 | [`snap_vector`](#member-gfinputdirectiontools-methods-snap_vector) | `static func snap_vector( raw_direction: Vector2, mode: SnapMode = SnapMode.CARDINAL_4, deadzone: float = 0.0, rescale_analog_after_deadzone: bool = false ) -> Vector2:` |
| 方法 | [`get_direction_name`](#member-gfinputdirectiontools-methods-get_direction_name) | `static func get_direction_name(direction: Direction2D) -> StringName:` |
| 方法 | [`get_direction_from_name`](#member-gfinputdirectiontools-methods-get_direction_from_name) | `static func get_direction_from_name( direction_name: StringName, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:` |
| 方法 | [`get_direction_vector`](#member-gfinputdirectiontools-methods-get_direction_vector) | `static func get_direction_vector(direction: Direction2D) -> Vector2:` |
| 方法 | [`get_closest_direction`](#member-gfinputdirectiontools-methods-get_closest_direction) | `static func get_closest_direction( raw_direction: Vector2, include_diagonal: bool = true, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:` |
| 方法 | [`get_direction_from_vector`](#member-gfinputdirectiontools-methods-get_direction_from_vector) | `static func get_direction_from_vector( direction_vector: Vector2, include_diagonal: bool = true, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:` |
| 方法 | [`get_opposite_direction`](#member-gfinputdirectiontools-methods-get_opposite_direction) | `static func get_opposite_direction(direction: Direction2D) -> Direction2D:` |
| 方法 | [`get_opposite_vector`](#member-gfinputdirectiontools-methods-get_opposite_vector) | `static func get_opposite_vector(direction_vector: Vector2) -> Vector2:` |

## 枚举

<a id="member-gfinputdirectiontools-enums-snapmode"></a>

### `SnapMode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum SnapMode {
	## 保留连续模拟向量。
	ANALOG,
	## 只输出左右方向。
	HORIZONTAL_2,
	## 只输出上下方向。
	VERTICAL_2,
	## 输出上下左右四方向。
	CARDINAL_4,
	## 输出上下左右和四个对角方向。
	EIGHT_WAY,
}
```

方向吸附模式。

<a id="member-gfinputdirectiontools-enums-direction2d"></a>

### `Direction2D`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum Direction2D {
	## 无方向。
	NONE,
	## 上方向。
	UP,
	## 右方向。
	RIGHT,
	## 下方向。
	DOWN,
	## 左方向。
	LEFT,
	## 右上方向。
	UP_RIGHT,
	## 左上方向。
	UP_LEFT,
	## 右下方向。
	DOWN_RIGHT,
	## 左下方向。
	DOWN_LEFT,
}
```

二维离散方向。

## 方法

<a id="member-gfinputdirectiontools-methods-apply_radial_deadzone"></a>

### `apply_radial_deadzone`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func apply_radial_deadzone( raw_direction: Vector2, deadzone: float, rescale_after_deadzone: bool = true ) -> Vector2:
```

对二维输入应用径向 deadzone。

参数：

| 名称 | 说明 |
|---|---|
| `raw_direction` | 原始二维输入。 |
| `deadzone` | 死区阈值，自动钳制到 0.0 到 0.99。 |
| `rescale_after_deadzone` | 是否把死区外剩余行程重映射到 0.0 到 1.0。 |

返回：处理后的二维输入。

<a id="member-gfinputdirectiontools-methods-snap_vector"></a>

### `snap_vector`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func snap_vector( raw_direction: Vector2, mode: SnapMode = SnapMode.CARDINAL_4, deadzone: float = 0.0, rescale_analog_after_deadzone: bool = false ) -> Vector2:
```

按指定模式把二维输入吸附到连续或离散方向。

参数：

| 名称 | 说明 |
|---|---|
| `raw_direction` | 原始二维输入。 |
| `mode` | 吸附模式。 |
| `deadzone` | 死区阈值，自动钳制到 0.0 到 0.99。 |
| `rescale_analog_after_deadzone` | ANALOG 模式下是否把死区外剩余行程重映射到 0.0 到 1.0。 |

返回：处理后的方向；离散模式下每个轴只会是 -1.0、0.0 或 1.0。

<a id="member-gfinputdirectiontools-methods-get_direction_name"></a>

### `get_direction_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_direction_name(direction: Direction2D) -> StringName:
```

按枚举获取方向名称。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 方向枚举。 |

返回：方向名称；NONE 返回空 StringName。

<a id="member-gfinputdirectiontools-methods-get_direction_from_name"></a>

### `get_direction_from_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_direction_from_name( direction_name: StringName, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:
```

按名称获取方向枚举。

参数：

| 名称 | 说明 |
|---|---|
| `direction_name` | 方向名称。 |
| `default_direction` | 未找到名称时返回的默认方向。 |

返回：方向枚举。

<a id="member-gfinputdirectiontools-methods-get_direction_vector"></a>

### `get_direction_vector`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_direction_vector(direction: Direction2D) -> Vector2:
```

按枚举获取方向向量。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 方向枚举。 |

返回：方向向量；对角方向保留 -1/1 分量而不归一化。

<a id="member-gfinputdirectiontools-methods-get_closest_direction"></a>

### `get_closest_direction`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_closest_direction( raw_direction: Vector2, include_diagonal: bool = true, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:
```

获取最接近二维输入的离散方向。

参数：

| 名称 | 说明 |
|---|---|
| `raw_direction` | 原始二维输入。 |
| `include_diagonal` | 是否允许返回对角方向。 |
| `default_direction` | 输入为零时返回的默认方向。 |

返回：最接近的离散方向。

<a id="member-gfinputdirectiontools-methods-get_direction_from_vector"></a>

### `get_direction_from_vector`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_direction_from_vector( direction_vector: Vector2, include_diagonal: bool = true, default_direction: Direction2D = Direction2D.NONE ) -> Direction2D:
```

按离散向量获取方向枚举。

参数：

| 名称 | 说明 |
|---|---|
| `direction_vector` | 离散方向向量。 |
| `include_diagonal` | 是否允许匹配对角方向。 |
| `default_direction` | 未匹配时返回的默认方向。 |

返回：方向枚举。

<a id="member-gfinputdirectiontools-methods-get_opposite_direction"></a>

### `get_opposite_direction`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_opposite_direction(direction: Direction2D) -> Direction2D:
```

获取反向方向。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 方向枚举。 |

返回：反向方向。

<a id="member-gfinputdirectiontools-methods-get_opposite_vector"></a>

### `get_opposite_vector`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_opposite_vector(direction_vector: Vector2) -> Vector2:
```

获取反向方向向量。

参数：

| 名称 | 说明 |
|---|---|
| `direction_vector` | 方向向量。 |

返回：反向方向向量。
