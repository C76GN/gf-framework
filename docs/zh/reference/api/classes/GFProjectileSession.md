# GFProjectileSession

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_session.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

一次 typed projectile 发射的运行期句柄。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`finished`](#member-gfprojectilesession-signals-finished) | `signal finished(session: GFProjectileSession, reason: int)` |
| 枚举 | [`Dimension`](#member-gfprojectilesession-enums-dimension) | `enum Dimension` |
| 枚举 | [`Status`](#member-gfprojectilesession-enums-status) | `enum Status` |
| 枚举 | [`EndReason`](#member-gfprojectilesession-enums-endreason) | `enum EndReason` |
| 方法 | [`get_status`](#member-gfprojectilesession-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_dimension`](#member-gfprojectilesession-methods-get_dimension) | `func get_dimension() -> Dimension:` |
| 方法 | [`get_generation`](#member-gfprojectilesession-methods-get_generation) | `func get_generation() -> int:` |
| 方法 | [`get_instance_root`](#member-gfprojectilesession-methods-get_instance_root) | `func get_instance_root() -> Node:` |
| 方法 | [`get_runtime`](#member-gfprojectilesession-methods-get_runtime) | `func get_runtime() -> Node:` |
| 方法 | [`get_elapsed_seconds`](#member-gfprojectilesession-methods-get_elapsed_seconds) | `func get_elapsed_seconds() -> float:` |
| 方法 | [`get_travelled_distance`](#member-gfprojectilesession-methods-get_travelled_distance) | `func get_travelled_distance() -> float:` |
| 方法 | [`get_accepted_impact_count`](#member-gfprojectilesession-methods-get_accepted_impact_count) | `func get_accepted_impact_count() -> int:` |
| 方法 | [`get_end_reason`](#member-gfprojectilesession-methods-get_end_reason) | `func get_end_reason() -> EndReason:` |
| 方法 | [`get_metadata`](#member-gfprojectilesession-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`is_active`](#member-gfprojectilesession-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`is_finished`](#member-gfprojectilesession-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`finish`](#member-gfprojectilesession-methods-finish) | `func finish(reason: EndReason = EndReason.CALLER_FINISHED) -> bool:` |

## 信号

<a id="member-gfprojectilesession-signals-finished"></a>

### `finished`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal finished(session: GFProjectileSession, reason: int)
```

session 首次进入 FINISHED 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 已结算的同一 session。 |
| `reason` | \`EndReason\` 枚举值。 |

## 枚举

<a id="member-gfprojectilesession-enums-dimension"></a>

### `Dimension`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Dimension {
	## 2D runtime、adapter 与 motion。
	TWO_D = 0,
	## 3D runtime、adapter 与 motion。
	THREE_D = 1,
}
```

定义 session 的空间维度。

<a id="member-gfprojectilesession-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Status {
	## 尚未由 runtime 激活。
	UNCONFIGURED = 0,
	## 正在接受 motion、impact 与 lifetime 更新。
	ACTIVE = 1,
	## 已以 first-wins 原因结算。
	FINISHED = 2,
}
```

定义 session 的封闭生命周期状态。

<a id="member-gfprojectilesession-enums-endreason"></a>

### `EndReason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum EndReason {
	## 尚未结束。
	NONE = 0,
	## 调用方显式结束。
	CALLER_FINISHED = 1,
	## 达到最大活动时长。
	LIFETIME_SECONDS = 2,
	## 达到累计实际位移上限。
	LIFETIME_DISTANCE = 3,
	## 达到已接受 impact 上限。
	LIFETIME_IMPACTS = 4,
	## 自定义 lifetime hook 请求结束。
	LIFETIME_CUSTOM = 5,
	## Motion 正常请求结束。
	MOTION_FINISHED = 6,
	## 必需目标已丢失。
	TARGET_LOST = 7,
	## Motion 返回不可应用 intent。
	INVALID_MOTION_INTENT = 8,
	## Motion state 或计算失败。
	MOTION_FAILED = 9,
	## Body adapter 捕获或应用失败。
	BODY_APPLICATION_FAILED = 10,
	## 完整实例 root 已丢失。
	ROOT_LOST = 11,
	## Runtime 已丢失。
	RUNTIME_LOST = 12,
	## 显式 impact source topology 已丢失。
	IMPACT_SOURCE_LOST = 13,
	## Emitter 或 allocator 主动释放。
	EMITTER_RELEASED = 14,
	## 无法归类的框架内部失败。
	INTERNAL_FAILURE = 15,
}
```

定义首次结束 session 的稳定原因。

## 方法

<a id="member-gfprojectilesession-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

返回当前生命周期状态。

返回：封闭 `Status` 值。

<a id="member-gfprojectilesession-methods-get_dimension"></a>

### `get_dimension`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_dimension() -> Dimension:
```

返回空间维度。

返回：TWO_D 或 THREE_D。

<a id="member-gfprojectilesession-methods-get_generation"></a>

### `get_generation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_generation() -> int:
```

返回 runtime 分配的单调 generation。

返回：激活后为正数。

<a id="member-gfprojectilesession-methods-get_instance_root"></a>

### `get_instance_root`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_instance_root() -> Node:
```

返回完整实例 root。

返回：live root；释放后为 null。

<a id="member-gfprojectilesession-methods-get_runtime"></a>

### `get_runtime`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_runtime() -> Node:
```

返回本次 session 的 runtime。

返回：live runtime；释放后为 null。

<a id="member-gfprojectilesession-methods-get_elapsed_seconds"></a>

### `get_elapsed_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_elapsed_seconds() -> float:
```

返回累计活动时长。

返回：非负秒数。

<a id="member-gfprojectilesession-methods-get_travelled_distance"></a>

### `get_travelled_distance`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_travelled_distance() -> float:
```

返回累计实际 world displacement 长度。

返回：非负累计距离，不是起点到当前位置净距离。

<a id="member-gfprojectilesession-methods-get_accepted_impact_count"></a>

### `get_accepted_impact_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_accepted_impact_count() -> int:
```

返回被当前 generation 接受的 impact 数。

返回：非负计数。

<a id="member-gfprojectilesession-methods-get_end_reason"></a>

### `get_end_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_end_reason() -> EndReason:
```

返回首次结束原因。

返回：ACTIVE 时为 NONE，FINISHED 时为冻结原因。

<a id="member-gfprojectilesession-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

返回 launch metadata 深副本。

返回：可由调用方修改的独立 metadata。

结构：

- `return`: Dictionary，激活时冻结的项目 metadata 深副本。

<a id="member-gfprojectilesession-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_active() -> bool:
```

判断 session 是否仍 ACTIVE。

返回：当前状态为 ACTIVE 时为 true。

<a id="member-gfprojectilesession-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_finished() -> bool:
```

判断 session 是否已结算。

返回：当前状态为 FINISHED 时为 true。

<a id="member-gfprojectilesession-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func finish(reason: EndReason = EndReason.CALLER_FINISHED) -> bool:
```

以 first-wins 语义结束 session，并 best-effort 要求 adapter 停止 body。 stop 在 reason 冻结后执行，其结果不会改写本次既有终结原因。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 非 NONE 的结束原因。 |

返回：本调用是否首次完成结算。
