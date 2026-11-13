# GFTimeWindow

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_time_window.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

带周期身份的冻结左闭右开时间窗口。 使用 Unix 毫秒，不隐式读取系统时钟，不代表奖励已结算。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gftimewindow-methods-create) | `static func create( start_msec: int, end_msec: int, period_id: String ) -> GFTimeWindow:` |
| 方法 | [`get_start_msec`](#member-gftimewindow-methods-get_start_msec) | `func get_start_msec() -> int:` |
| 方法 | [`get_end_msec`](#member-gftimewindow-methods-get_end_msec) | `func get_end_msec() -> int:` |
| 方法 | [`get_period_id`](#member-gftimewindow-methods-get_period_id) | `func get_period_id() -> String:` |
| 方法 | [`contains`](#member-gftimewindow-methods-contains) | `func contains(unix_msec: int) -> bool:` |
| 方法 | [`to_record`](#member-gftimewindow-methods-to_record) | `func to_record() -> Dictionary:` |

## 方法

<a id="member-gftimewindow-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( start_msec: int, end_msec: int, period_id: String ) -> GFTimeWindow:
```

创建有效窗口。

参数：

| 名称 | 说明 |
|---|---|
| `start_msec` | Unix 毫秒起点，范围 ±8×10^15。 |
| `end_msec` | Unix 毫秒终点，同范围且严格大于起点。 |
| `period_id` | 非空周期身份，最多2048字符。 |

返回：冻结窗口；无效时返回 null。

<a id="member-gftimewindow-methods-get_start_msec"></a>

### `get_start_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_start_msec() -> int:
```

获取包含的起点。

返回：Unix 毫秒起点。

<a id="member-gftimewindow-methods-get_end_msec"></a>

### `get_end_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_end_msec() -> int:
```

获取排除的终点。

返回：Unix 毫秒终点。

<a id="member-gftimewindow-methods-get_period_id"></a>

### `get_period_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_period_id() -> String:
```

获取周期身份。

返回：创建时冻结的身份；未经工厂创建时为空。

<a id="member-gftimewindow-methods-contains"></a>

### `contains`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func contains(unix_msec: int) -> bool:
```

判断一个时间戳是否位于窗口中。

参数：

| 名称 | 说明 |
|---|---|
| `unix_msec` | 待检查的 Unix 毫秒时间戳。 |

返回：start <= unix_msec < end，未经工厂创建的对象始终返回 false。

<a id="member-gftimewindow-methods-to_record"></a>

### `to_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_record() -> Dictionary:
```

获取持久化或诊断记录。

返回：窗口副本。

结构：

- `return`: 封闭 Dictionary，start_msec:int、end_msec:int、period_id:String。
