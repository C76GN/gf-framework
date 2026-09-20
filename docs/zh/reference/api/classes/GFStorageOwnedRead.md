# GFStorageOwnedRead

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_owned_read.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

独占异步读取的一次性领取句柄。 只能由 `GFStorageUtility.load_data_owned_request_async()` 取得有效句柄；手动 构造的实例不可领取。共享句柄即共享领取权，同一结果仅允许一次成功领取。 caller 成功后，结果由句柄持有，直到领取、显式释放或句柄的最后一个引用释放。 owner、取消令牌和超时只约束等待阶段，不撤销已经就绪或领取的结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfstorageownedread-signals-completed) | `signal completed(receipt: GFStorageOwnedReadReceipt)` |
| 枚举 | [`State`](#member-gfstorageownedread-enums-state) | `enum State` |
| 方法 | [`is_valid`](#member-gfstorageownedread-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_request_id`](#member-gfstorageownedread-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_consumer_id`](#member-gfstorageownedread-methods-get_consumer_id) | `func get_consumer_id() -> int:` |
| 方法 | [`get_file_name`](#member-gfstorageownedread-methods-get_file_name) | `func get_file_name() -> String:` |
| 方法 | [`get_state`](#member-gfstorageownedread-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_pending`](#member-gfstorageownedread-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfstorageownedread-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfstorageownedread-methods-get_result) | `func get_result() -> GFStorageOwnedReadReceipt:` |
| 方法 | [`cancel_observation`](#member-gfstorageownedread-methods-cancel_observation) | `func cancel_observation(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`take`](#member-gfstorageownedread-methods-take) | `func take() -> GFStorageOwnedReadTakeResult:` |
| 方法 | [`release`](#member-gfstorageownedread-methods-release) | `func release() -> bool:` |

## 信号

<a id="member-gfstorageownedread-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(receipt: GFStorageOwnedReadReceipt)
```

caller 首次完成时发出不包含载荷的诊断；可在回调内立即调用 `take()`。 请求可能在入口返回前完成，应先检查 `is_completed()`。owner 已释放时可以 抑制通知，但终态仍可通过 `get_result()` 查询；晚到物理结果不会再次通知。

参数：

| 名称 | 说明 |
|---|---|
| `receipt` | 不含载荷或领取权限的不可变 caller 终态。 |

## 枚举

<a id="member-gfstorageownedread-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum State {
	## 未绑定请求的手动构造实例。
	INVALID,
	## 正在等待 caller 终态。
	WAITING,
	## 成功结果已经就绪，允许领取一次。
	READY,
	## 完整结果已经移交给领取方。
	TAKEN,
	## 已放弃领取权；尚未完成的物理请求仍由 Storage 收敛。
	RELEASED,
	## caller 已失败或取消，没有可领取结果。
	FAILED,
}
```

独占读取句柄的领取权状态。

## 方法

<a id="member-gfstorageownedread-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

检查句柄是否由 Storage 绑定到合法请求。

返回：已绑定的句柄返回 true，包括失败、已领取或已释放的句柄。

<a id="member-gfstorageownedread-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一的物理请求 ID。

返回：合法请求的大于零 ID；无效句柄返回 0。

<a id="member-gfstorageownedread-methods-get_consumer_id"></a>

### `get_consumer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_consumer_id() -> int:
```

获取 Utility 内唯一的 consumer ID。

返回：合法 consumer 的大于零 ID；无效句柄返回 0。

<a id="member-gfstorageownedread-methods-get_file_name"></a>

### `get_file_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_file_name() -> String:
```

获取请求的规范逻辑文件名。

返回：已验证的逻辑文件名；文件名校验前失败时可能为空。

<a id="member-gfstorageownedread-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> State:
```

获取当前领取权状态。

返回：当前 State 枚举值。

<a id="member-gfstorageownedread-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查是否仍在等待 caller 终态。 等待中调用 `release()` 只放弃领取权，仍可能返回 true，直到请求正常收敛。

返回：合法请求尚未取得 caller 终态时返回 true。

<a id="member-gfstorageownedread-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查 caller 终态是否已经写入。

返回：已取得成功、失败或取消诊断时返回 true。

<a id="member-gfstorageownedread-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFStorageOwnedReadReceipt:
```

获取不包含载荷和领取权限的不可变终态诊断。

返回：已完成时返回同一不可变诊断，等待中或无效句柄返回 null。

<a id="member-gfstorageownedread-methods-cancel_observation"></a>

### `cancel_observation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_observation(reason: StringName = &"cancelled") -> bool:
```

在主线程显式结束对尚未完成请求的观察。 返回 true 表示取消先于成功结算，不保证底层 worker 已经停止。 已经 READY 或 TAKEN 的结果不受取消影响。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 由共享生命周期规范化的稳定取消原因。 |

返回：本次调用首次结束 caller 观察时返回 true；非主线程返回 false。

<a id="member-gfstorageownedread-methods-take"></a>

### `take`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func take() -> GFStorageOwnedReadTakeResult:
```

在主线程一次性领取完整结果，不复制载荷或调用外部回调。 可以在 `completed` 回调内调用。成功移交前先清空句柄的载荷引用，重复领取 返回 ALREADY_TAKEN；失败状态与成功的空 Dictionary 不会混淆。

返回：包含闭合状态的领取结果，只有 SUCCESS 持有完整 GFStorageReadResult。

<a id="member-gfstorageownedread-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> bool:
```

在主线程放弃领取权，立即释放已经就绪的载荷。 等待中的请求仍按原生命周期收敛，终态诊断仍可查询。重复释放没有副作用， 也不会撤销已经移交给领取方的结果。

返回：首次从 WAITING 或 READY 释放时返回 true；其他状态或非主线程返回 false。
