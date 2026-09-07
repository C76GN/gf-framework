# GFProjectileEmissionResult

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_emission_result.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

一次原子发射请求的不可变终态。 单发和批量发射共享同一结果类型。成功结果持有按稳定生成顺序排列的已激活 Session；失败结果不持有任何部分成功 Session。结果描述已经完成的发射， 不延长 Session 的生命；通知回调可以立即结束 Session。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfprojectileemissionresult-enums-status) | `enum Status` |
| 方法 | [`is_successful`](#member-gfprojectileemissionresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfprojectileemissionresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_stage`](#member-gfprojectileemissionresult-methods-get_stage) | `func get_stage() -> StringName:` |
| 方法 | [`get_reason`](#member-gfprojectileemissionresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_requested_count`](#member-gfprojectileemissionresult-methods-get_requested_count) | `func get_requested_count() -> int:` |
| 方法 | [`get_sessions`](#member-gfprojectileemissionresult-methods-get_sessions) | `func get_sessions() -> Array[GFProjectileSession]:` |
| 方法 | [`get_emitted_count`](#member-gfprojectileemissionresult-methods-get_emitted_count) | `func get_emitted_count() -> int:` |

## 枚举

<a id="member-gfprojectileemissionresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 全批 Session 曾进入 ACTIVE 并完成公开通知。
	SUCCEEDED,
	## 请求在返回任何 Session 前失败或被生命周期取消。
	FAILED,
}
```

发射请求的唯一终态。

## 方法

<a id="member-gfprojectileemissionresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查全批发射是否成功。

返回：全批 Session 曾进入 ACTIVE 并完成公开通知时返回 true。

<a id="member-gfprojectileemissionresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取请求终态。

返回：`Status` 闭合枚举值。

<a id="member-gfprojectileemissionresult-methods-get_stage"></a>

### `get_stage`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stage() -> StringName:
```

获取终止请求的事务阶段。

返回：稳定阶段名；成功时为 `completed`。

<a id="member-gfprojectileemissionresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reason() -> StringName:
```

获取终态原因。

返回：稳定原因；成功时为空 StringName。

<a id="member-gfprojectileemissionresult-methods-get_requested_count"></a>

### `get_requested_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_requested_count() -> int:
```

获取 spawn pattern 解析后的请求数量。

返回：非负请求数量；在数量解析前失败时为 0。

<a id="member-gfprojectileemissionresult-methods-get_sessions"></a>

### `get_sessions`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_sessions() -> Array[GFProjectileSession]:
```

获取成功发射的 Session 快照。

返回：按 spawn transform 稳定顺序排列的 Session；失败时为空数组。

结构：

- `return`: Array[GFProjectileSession]，返回新的数组容器，Session 本身保持同一身份。

<a id="member-gfprojectileemissionresult-methods-get_emitted_count"></a>

### `get_emitted_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_emitted_count() -> int:
```

获取成功发射数量。

返回：`get_sessions()` 的当前快照数量。
