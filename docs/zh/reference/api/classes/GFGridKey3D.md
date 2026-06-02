# GFGridKey3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_key_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.18.0`

3D 网格坐标稳定整数键工具。 将有限范围内的 Vector3i 格坐标与方向编号打包成非负 int，并提供反解与 Vector3 位置量化。它只处理坐标编码，不绑定 TileMap、GridMap、渲染或存档格式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`COORDINATE_BITS`](#member-gfgridkey3d-constants-coordinate_bits) | `const COORDINATE_BITS: int = 19` |
| 常量 | [`ORIENTATION_BITS`](#member-gfgridkey3d-constants-orientation_bits) | `const ORIENTATION_BITS: int = 6` |
| 常量 | [`COORDINATE_MIN`](#member-gfgridkey3d-constants-coordinate_min) | `const COORDINATE_MIN: int = -262144` |
| 常量 | [`COORDINATE_MAX`](#member-gfgridkey3d-constants-coordinate_max) | `const COORDINATE_MAX: int = 262143` |
| 常量 | [`ORIENTATION_MIN`](#member-gfgridkey3d-constants-orientation_min) | `const ORIENTATION_MIN: int = 0` |
| 常量 | [`ORIENTATION_MAX`](#member-gfgridkey3d-constants-orientation_max) | `const ORIENTATION_MAX: int = 63` |
| 常量 | [`INVALID_KEY`](#member-gfgridkey3d-constants-invalid_key) | `const INVALID_KEY: int = -1` |
| 方法 | [`can_pack_cell`](#member-gfgridkey3d-methods-can_pack_cell) | `static func can_pack_cell(cell: Vector3i, orientation: int = 0) -> bool:` |
| 方法 | [`pack_cell`](#member-gfgridkey3d-methods-pack_cell) | `static func pack_cell(cell: Vector3i, orientation: int = 0) -> int:` |
| 方法 | [`is_packed_key_valid`](#member-gfgridkey3d-methods-is_packed_key_valid) | `static func is_packed_key_valid(key: int) -> bool:` |
| 方法 | [`unpack_cell`](#member-gfgridkey3d-methods-unpack_cell) | `static func unpack_cell(key: int) -> Vector3i:` |
| 方法 | [`unpack_orientation`](#member-gfgridkey3d-methods-unpack_orientation) | `static func unpack_orientation(key: int) -> int:` |
| 方法 | [`unpack_key`](#member-gfgridkey3d-methods-unpack_key) | `static func unpack_key(key: int) -> Dictionary:` |
| 方法 | [`position_to_cell`](#member-gfgridkey3d-methods-position_to_cell) | `static func position_to_cell( position: Vector3, cell_size: Vector3 = Vector3.ONE, origin: Vector3 = Vector3.ZERO ) -> Vector3i:` |
| 方法 | [`pack_position`](#member-gfgridkey3d-methods-pack_position) | `static func pack_position( position: Vector3, cell_size: Vector3 = Vector3.ONE, origin: Vector3 = Vector3.ZERO, orientation: int = 0 ) -> int:` |

## 常量

<a id="member-gfgridkey3d-constants-coordinate_bits"></a>

### `COORDINATE_BITS`

- API：`public`

```gdscript
const COORDINATE_BITS: int = 19
```

每个坐标轴使用的位数。

<a id="member-gfgridkey3d-constants-orientation_bits"></a>

### `ORIENTATION_BITS`

- API：`public`

```gdscript
const ORIENTATION_BITS: int = 6
```

方向编号使用的位数。

<a id="member-gfgridkey3d-constants-coordinate_min"></a>

### `COORDINATE_MIN`

- API：`public`

```gdscript
const COORDINATE_MIN: int = -262144
```

可打包坐标最小值。

<a id="member-gfgridkey3d-constants-coordinate_max"></a>

### `COORDINATE_MAX`

- API：`public`

```gdscript
const COORDINATE_MAX: int = 262143
```

可打包坐标最大值。

<a id="member-gfgridkey3d-constants-orientation_min"></a>

### `ORIENTATION_MIN`

- API：`public`

```gdscript
const ORIENTATION_MIN: int = 0
```

可打包方向编号最小值。

<a id="member-gfgridkey3d-constants-orientation_max"></a>

### `ORIENTATION_MAX`

- API：`public`

```gdscript
const ORIENTATION_MAX: int = 63
```

可打包方向编号最大值。

<a id="member-gfgridkey3d-constants-invalid_key"></a>

### `INVALID_KEY`

- API：`public`

```gdscript
const INVALID_KEY: int = -1
```

无效 key 哨兵值。

## 方法

<a id="member-gfgridkey3d-methods-can_pack_cell"></a>

### `can_pack_cell`

- API：`public`

```gdscript
static func can_pack_cell(cell: Vector3i, orientation: int = 0) -> bool:
```

判断格坐标和方向编号是否能被打包。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 3D 格坐标。 |
| `orientation` | 方向编号，范围为 0..63。 |

返回：可打包时返回 true。

<a id="member-gfgridkey3d-methods-pack_cell"></a>

### `pack_cell`

- API：`public`

```gdscript
static func pack_cell(cell: Vector3i, orientation: int = 0) -> int:
```

将格坐标和方向编号打包成非负整数 key。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 3D 格坐标。 |
| `orientation` | 方向编号，范围为 0..63。 |

返回：打包后的 key；输入超出范围时返回 INVALID_KEY。

<a id="member-gfgridkey3d-methods-is_packed_key_valid"></a>

### `is_packed_key_valid`

- API：`public`

```gdscript
static func is_packed_key_valid(key: int) -> bool:
```

判断整数是否可能是 GFGridKey3D 生成的 key。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 待检测 key。 |

返回：在有效整数范围内时返回 true。

<a id="member-gfgridkey3d-methods-unpack_cell"></a>

### `unpack_cell`

- API：`public`

```gdscript
static func unpack_cell(key: int) -> Vector3i:
```

从 key 反解格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 打包 key。 |

返回：反解出的格坐标；key 无效时返回 Vector3i.ZERO。

<a id="member-gfgridkey3d-methods-unpack_orientation"></a>

### `unpack_orientation`

- API：`public`

```gdscript
static func unpack_orientation(key: int) -> int:
```

从 key 反解方向编号。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 打包 key。 |

返回：方向编号；key 无效时返回 -1。

<a id="member-gfgridkey3d-methods-unpack_key"></a>

### `unpack_key`

- API：`public`

```gdscript
static func unpack_key(key: int) -> Dictionary:
```

从 key 反解完整数据字典。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 打包 key。 |

返回：Dictionary，包含 valid、cell 和 orientation。

结构：

- `return`: Dictionary with valid: bool, cell: Vector3i, and orientation: int.

<a id="member-gfgridkey3d-methods-position_to_cell"></a>

### `position_to_cell`

- API：`public`

```gdscript
static func position_to_cell( position: Vector3, cell_size: Vector3 = Vector3.ONE, origin: Vector3 = Vector3.ZERO ) -> Vector3i:
```

将世界位置量化为格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 世界或局部位置。 |
| `cell_size` | 单格尺寸，各轴会被限制为正数。 |
| `origin` | 量化原点。 |

返回：量化后的格坐标。

<a id="member-gfgridkey3d-methods-pack_position"></a>

### `pack_position`

- API：`public`

```gdscript
static func pack_position( position: Vector3, cell_size: Vector3 = Vector3.ONE, origin: Vector3 = Vector3.ZERO, orientation: int = 0 ) -> int:
```

将世界位置量化并打包成整数 key。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 世界或局部位置。 |
| `cell_size` | 单格尺寸，各轴会被限制为正数。 |
| `origin` | 量化原点。 |
| `orientation` | 方向编号，范围为 0..63。 |

返回：打包后的 key；量化坐标或方向编号超出范围时返回 INVALID_KEY。
