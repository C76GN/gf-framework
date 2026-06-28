# GFAsyncGateLease

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_gate_lease.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

keyed async gate 的租约句柄。 租约表示某个 key 当前被允许执行的一个并发槽位。调用方只需要在工作完成、 取消或失败时调用 release()；释放是幂等的，不负责执行业务回滚。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`released`](#member-gfasyncgatelease-signals-released) | `signal released(lease: GFAsyncGateLease, reason: StringName)` |
| 方法 | [`release`](#member-gfasyncgatelease-methods-release) | `func release(reason: StringName = &"manual") -> bool:` |
| 方法 | [`is_active`](#member-gfasyncgatelease-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_lease_id`](#member-gfasyncgatelease-methods-get_lease_id) | `func get_lease_id() -> int:` |
| 方法 | [`get_request_id`](#member-gfasyncgatelease-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_key`](#member-gfasyncgatelease-methods-get_key) | `func get_key() -> Variant:` |
| 方法 | [`get_metadata`](#member-gfasyncgatelease-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_held_msec`](#member-gfasyncgatelease-methods-get_held_msec) | `func get_held_msec() -> int:` |
| 方法 | [`get_release_reason`](#member-gfasyncgatelease-methods-get_release_reason) | `func get_release_reason() -> StringName:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncgatelease-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncgatelease-signals-released"></a>

### `released`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal released(lease: GFAsyncGateLease, reason: StringName)
```

租约首次释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 当前租约。 |
| `reason` | 稳定释放原因。 |

## 方法

<a id="member-gfasyncgatelease-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func release(reason: StringName = &"manual") -> bool:
```

释放租约。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定释放原因。 |

返回：首次释放成功时返回 true。

<a id="member-gfasyncgatelease-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_active() -> bool:
```

当前租约是否仍占用并发槽位。

返回：活跃时返回 true。

<a id="member-gfasyncgatelease-methods-get_lease_id"></a>

### `get_lease_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_lease_id() -> int:
```

获取租约 ID。

返回：当前 gate 内唯一的租约 ID。

<a id="member-gfasyncgatelease-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_request_id() -> int:
```

获取创建该租约的请求 ID。

返回：当前 gate 内唯一的请求 ID。

<a id="member-gfasyncgatelease-methods-get_key"></a>

### `get_key`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_key() -> Variant:
```

获取租约 key 的副本。

返回：租约 key。

结构：

- `return`: Variant，调用方传入的 key 副本。

<a id="member-gfasyncgatelease-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取租约元数据副本。

返回：租约元数据。

结构：

- `return`: Dictionary，调用方传入的 metadata 副本。

<a id="member-gfasyncgatelease-methods-get_held_msec"></a>

### `get_held_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_held_msec() -> int:
```

获取租约持有时长。

返回：活跃租约返回当前持有毫秒数；已释放租约返回实际持有毫秒数。

<a id="member-gfasyncgatelease-methods-get_release_reason"></a>

### `get_release_reason`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_release_reason() -> StringName:
```

获取释放原因。

返回：释放原因；未释放时为空 StringName。

<a id="member-gfasyncgatelease-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取租约调试快照。

返回：租约状态快照。

结构：

- `return`: Dictionary，包含 lease_id、request_id、key、active、metadata、acquired_msec、released_msec、held_msec 和 release_reason。
