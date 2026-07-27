# GFGridOccupancy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_occupancy.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

网格占用与预约数据结构。 适合格子移动、战棋、推箱子和解谜类玩法在 System 中跟踪运行时占用。 它不负责路径查找、碰撞或胜负规则。 占用变更会先完整提交内部映射，再同步发出通知；通知回调可以查询已提交状态， 但通知期间重入调用本类型的写入方法会失败关闭，避免嵌套修改破坏容量与双向索引。 receiver 只接受 Object、非空 StringName、非空 String 或 int 稳定身份；可变复合值 和其他 Variant 类型失败关闭。公开信号只描述实际状态变化，成功恒等操作不发信号。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cell_occupied`](#member-gfgridoccupancy-signals-cell_occupied) | `signal cell_occupied(receiver: Variant, cell: Vector2i)` |
| 信号 | [`cell_released`](#member-gfgridoccupancy-signals-cell_released) | `signal cell_released(receiver: Variant, cell: Vector2i)` |
| 信号 | [`cell_reserved`](#member-gfgridoccupancy-signals-cell_reserved) | `signal cell_reserved(receiver: Variant, cell: Vector2i)` |
| 信号 | [`reservation_released`](#member-gfgridoccupancy-signals-reservation_released) | `signal reservation_released(receiver: Variant, cell: Vector2i)` |
| 属性 | [`grid_size`](#member-gfgridoccupancy-properties-grid_size) | `var grid_size: Vector2i:` |
| 属性 | [`max_occupants_per_cell`](#member-gfgridoccupancy-properties-max_occupants_per_cell) | `var max_occupants_per_cell: int:` |
| 方法 | [`configure`](#member-gfgridoccupancy-methods-configure) | `func configure(p_grid_size: Vector2i, p_max_occupants_per_cell: int = 1) -> void:` |
| 方法 | [`is_in_bounds`](#member-gfgridoccupancy-methods-is_in_bounds) | `func is_in_bounds(cell: Vector2i) -> bool:` |
| 方法 | [`can_occupy`](#member-gfgridoccupancy-methods-can_occupy) | `func can_occupy(receiver: Variant, cell: Vector2i) -> bool:` |
| 方法 | [`get_occupied_cells`](#member-gfgridoccupancy-methods-get_occupied_cells) | `func get_occupied_cells() -> Array[Vector2i]:` |
| 方法 | [`get_reserved_cells`](#member-gfgridoccupancy-methods-get_reserved_cells) | `func get_reserved_cells() -> Array[Vector2i]:` |
| 方法 | [`get_occupiable_cells`](#member-gfgridoccupancy-methods-get_occupiable_cells) | `func get_occupiable_cells(receiver: Variant) -> Array[Vector2i]:` |
| 方法 | [`occupy`](#member-gfgridoccupancy-methods-occupy) | `func occupy(receiver: Variant, cell: Vector2i) -> bool:` |
| 方法 | [`release`](#member-gfgridoccupancy-methods-release) | `func release(receiver: Variant) -> void:` |
| 方法 | [`release_cell`](#member-gfgridoccupancy-methods-release_cell) | `func release_cell(cell: Vector2i) -> void:` |
| 方法 | [`reserve_cell`](#member-gfgridoccupancy-methods-reserve_cell) | `func reserve_cell(receiver: Variant, cell: Vector2i) -> bool:` |
| 方法 | [`confirm_reservation`](#member-gfgridoccupancy-methods-confirm_reservation) | `func confirm_reservation(receiver: Variant) -> bool:` |
| 方法 | [`release_reservation`](#member-gfgridoccupancy-methods-release_reservation) | `func release_reservation(receiver: Variant) -> void:` |
| 方法 | [`is_cell_occupied`](#member-gfgridoccupancy-methods-is_cell_occupied) | `func is_cell_occupied(cell: Vector2i) -> bool:` |
| 方法 | [`is_cell_reserved`](#member-gfgridoccupancy-methods-is_cell_reserved) | `func is_cell_reserved(cell: Vector2i) -> bool:` |
| 方法 | [`get_cell_occupants`](#member-gfgridoccupancy-methods-get_cell_occupants) | `func get_cell_occupants(cell: Vector2i) -> Array[Variant]:` |
| 方法 | [`get_cell_occupant`](#member-gfgridoccupancy-methods-get_cell_occupant) | `func get_cell_occupant(cell: Vector2i) -> Variant:` |
| 方法 | [`get_receiver_cell`](#member-gfgridoccupancy-methods-get_receiver_cell) | `func get_receiver_cell(receiver: Variant) -> Vector2i:` |
| 方法 | [`prune_invalid_receivers`](#member-gfgridoccupancy-methods-prune_invalid_receivers) | `func prune_invalid_receivers() -> void:` |
| 方法 | [`clear`](#member-gfgridoccupancy-methods-clear) | `func clear() -> void:` |

## 信号

<a id="member-gfgridoccupancy-signals-cell_occupied"></a>

### `cell_occupied`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal cell_occupied(receiver: Variant, cell: Vector2i)
```

接收者实际新建占用或移动到其他格子时发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-signals-cell_released"></a>

### `cell_released`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal cell_released(receiver: Variant, cell: Vector2i)
```

接收者的既有占用实际释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, int, or null for an expired weak Object.

<a id="member-gfgridoccupancy-signals-cell_reserved"></a>

### `cell_reserved`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal cell_reserved(receiver: Variant, cell: Vector2i)
```

接收者实际新建预约或移动预约到其他格子时发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-signals-reservation_released"></a>

### `reservation_released`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal reservation_released(receiver: Variant, cell: Vector2i)
```

接收者的既有预约实际释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, int, or null for an expired weak Object.

## 属性

<a id="member-gfgridoccupancy-properties-grid_size"></a>

### `grid_size`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var grid_size: Vector2i:
```

网格尺寸，默认为 [constant Vector2i.ZERO]。小于等于 0 的维度会让所有格子视为越界。 直接赋值会像 configure() 一样清空现有占用与预约；通知期间的赋值会失败关闭。

<a id="member-gfgridoccupancy-properties-max_occupants_per_cell"></a>

### `max_occupants_per_cell`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_occupants_per_cell: int:
```

单格允许的最大占用数量，默认为 1，最小为 1。 直接赋值会像 configure() 一样清空现有占用与预约；通知期间的赋值会失败关闭。

## 方法

<a id="member-gfgridoccupancy-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(p_grid_size: Vector2i, p_max_occupants_per_cell: int = 1) -> void:
```

设置网格参数并清空占用。

参数：

| 名称 | 说明 |
|---|---|
| `p_grid_size` | 网格尺寸。 |
| `p_max_occupants_per_cell` | 单格最大占用数量。 |

<a id="member-gfgridoccupancy-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`

```gdscript
func is_in_bounds(cell: Vector2i) -> bool:
```

检查格子是否在边界内。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：在边界内返回 true。

<a id="member-gfgridoccupancy-methods-can_occupy"></a>

### `can_occupy`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func can_occupy(receiver: Variant, cell: Vector2i) -> bool:
```

检查接收者是否可以占用格子。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

返回：可占用时返回 true。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-get_occupied_cells"></a>

### `get_occupied_cells`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_occupied_cells() -> Array[Vector2i]:
```

获取当前被占用的格子快照。

返回：被至少一个接收者占用的格子数组，按 y/x 稳定顺序返回。

<a id="member-gfgridoccupancy-methods-get_reserved_cells"></a>

### `get_reserved_cells`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_reserved_cells() -> Array[Vector2i]:
```

获取当前被预约的格子快照。

返回：被接收者预约的格子数组，按 y/x 稳定顺序返回。

<a id="member-gfgridoccupancy-methods-get_occupiable_cells"></a>

### `get_occupiable_cells`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_occupiable_cells(receiver: Variant) -> Array[Vector2i]:
```

获取指定接收者当前可占用的格子。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |

返回：当前可被该接收者占用的格子数组，按 y/x 稳定顺序返回。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-occupy"></a>

### `occupy`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func occupy(receiver: Variant, cell: Vector2i) -> bool:
```

占用格子；已有其他格占用时先移动，已占用目标格时成功且不发信号。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

返回：成功时返回 true。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func release(receiver: Variant) -> void:
```

释放接收者当前占用。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-release_cell"></a>

### `release_cell`

- API：`public`

```gdscript
func release_cell(cell: Vector2i) -> void:
```

释放指定格子的所有占用。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

<a id="member-gfgridoccupancy-methods-reserve_cell"></a>

### `reserve_cell`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func reserve_cell(receiver: Variant, cell: Vector2i) -> bool:
```

预约格子；已有其他预约时先移动，已有效预约目标格时成功且不发释放或预约信号。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |
| `cell` | 格子坐标。 |

返回：成功时返回 true。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-confirm_reservation"></a>

### `confirm_reservation`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func confirm_reservation(receiver: Variant) -> bool:
```

将接收者预约确认成占用。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |

返回：成功时返回 true。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-release_reservation"></a>

### `release_reservation`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func release_reservation(receiver: Variant) -> void:
```

释放接收者预约。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-is_cell_occupied"></a>

### `is_cell_occupied`

- API：`public`

```gdscript
func is_cell_occupied(cell: Vector2i) -> bool:
```

检查格子是否有占用。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：有占用时返回 true。

<a id="member-gfgridoccupancy-methods-is_cell_reserved"></a>

### `is_cell_reserved`

- API：`public`

```gdscript
func is_cell_reserved(cell: Vector2i) -> bool:
```

检查格子是否被预约。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：被预约时返回 true。

<a id="member-gfgridoccupancy-methods-get_cell_occupants"></a>

### `get_cell_occupants`

- API：`public`

```gdscript
func get_cell_occupants(cell: Vector2i) -> Array[Variant]:
```

获取格子中的所有接收者。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：接收者数组。

结构：

- `return`: Array receiver values restored from occupancy records.

<a id="member-gfgridoccupancy-methods-get_cell_occupant"></a>

### `get_cell_occupant`

- API：`public`

```gdscript
func get_cell_occupant(cell: Vector2i) -> Variant:
```

获取格子中的第一个接收者。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：接收者；不存在时返回 null。

结构：

- `return`: Variant receiver value restored from the occupancy record.

<a id="member-gfgridoccupancy-methods-get_receiver_cell"></a>

### `get_receiver_cell`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_receiver_cell(receiver: Variant) -> Vector2i:
```

获取接收者当前占用格。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收者。 |

返回：格子坐标；未占用时返回 Vector2i(-1, -1)。

结构：

- `receiver`: Object, non-empty StringName, non-empty String, or int stable identity.

<a id="member-gfgridoccupancy-methods-prune_invalid_receivers"></a>

### `prune_invalid_receivers`

- API：`public`

```gdscript
func prune_invalid_receivers() -> void:
```

清理已释放 Object 接收者。

<a id="member-gfgridoccupancy-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空占用和预约。
