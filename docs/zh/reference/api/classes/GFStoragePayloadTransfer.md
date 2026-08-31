# GFStoragePayloadTransfer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_payload_transfer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

异步 Storage 写入载荷的单所有者传递句柄。 调用方通过静态 `take_ownership()` 把 Dictionary 的逻辑唯一所有权移交给新句柄。 移交不会深拷贝；调用成功后，调用方必须永久放弃源 Dictionary 以及它的全部 嵌套 alias。失败操作只通过 `GFStorageAsyncOperation.reclaim_failed_payload()` 归还同一 opaque 句柄用于重试，任何阶段都不公开 payload getter。 首次合法 Storage 请求会把句柄绑定到一个 Storage 实例、规范文件名、冻结的 target file-family identity 和 codec options。同一绑定可取得多个只读 attempt lease，用于 timeout 后仍有旧 attempt 运行时复用同一逻辑快照。最终调用 `release()`；若仍有活动 attempt，载荷会在最后一个 attempt 结束后才清空。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`State`](#member-gfstoragepayloadtransfer-enums-state) | `enum State` |
| 方法 | [`take_ownership`](#member-gfstoragepayloadtransfer-methods-take_ownership) | `static func take_ownership(payload: Dictionary) -> GFStoragePayloadTransfer:` |
| 方法 | [`get_state`](#member-gfstoragepayloadtransfer-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_claimed`](#member-gfstoragepayloadtransfer-methods-is_claimed) | `func is_claimed() -> bool:` |
| 方法 | [`is_released`](#member-gfstoragepayloadtransfer-methods-is_released) | `func is_released() -> bool:` |
| 方法 | [`get_active_attempt_count`](#member-gfstoragepayloadtransfer-methods-get_active_attempt_count) | `func get_active_attempt_count() -> int:` |
| 方法 | [`release`](#member-gfstoragepayloadtransfer-methods-release) | `func release() -> bool:` |

## 枚举

<a id="member-gfstoragepayloadtransfer-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum State {
	## 尚未接收载荷。
	EMPTY,
	## 已接收载荷，尚未被 Storage claim。
	READY,
	## 已由 Storage claim，可由同一冻结绑定建立 attempt。
	CLAIMED,
	## 已请求释放，等待活动 attempt 收敛。
	RELEASE_PENDING,
	## 载荷已清空，句柄不可再次使用。
	RELEASED,
}
```

传递句柄的所有权状态。

## 方法

<a id="member-gfstoragepayloadtransfer-methods-take_ownership"></a>

### `take_ownership`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func take_ownership(payload: Dictionary) -> GFStoragePayloadTransfer:
```

创建句柄并接收 Dictionary 的逻辑唯一所有权。 此方法不会深拷贝。返回句柄后，调用方必须立即并永久放弃源 Dictionary 以及所有嵌套 alias；继续读取或修改这些 alias 会破坏跨线程快照不变量。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 要移交的纯 Variant Dictionary。 |

返回：持有 payload 的新 opaque transfer。

结构：

- `payload`: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.

<a id="member-gfstoragepayloadtransfer-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_state() -> State:
```

获取当前所有权状态。

返回：`State` 枚举值。

<a id="member-gfstoragepayloadtransfer-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_claimed() -> bool:
```

检查句柄是否已被 Storage claim。

返回：CLAIMED 或 RELEASE_PENDING 时返回 true。

<a id="member-gfstoragepayloadtransfer-methods-is_released"></a>

### `is_released`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_released() -> bool:
```

检查载荷是否已最终释放。

返回：已清空且不可复用时返回 true。

<a id="member-gfstoragepayloadtransfer-methods-get_active_attempt_count"></a>

### `get_active_attempt_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_active_attempt_count() -> int:
```

获取当前活动 attempt 数量。

返回：已取得且尚未完成的 attempt lease 数量。

<a id="member-gfstoragepayloadtransfer-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func release() -> bool:
```

显式释放载荷所有权。 若仍有活动 attempt，本方法只进入 RELEASE_PENDING；最后一个 attempt 完成后 才真正清空载荷。释放请求只能成功一次。

返回：首次接受释放请求时返回 true。
