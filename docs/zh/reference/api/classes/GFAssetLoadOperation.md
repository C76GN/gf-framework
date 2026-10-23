# GFAssetLoadOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_load_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

每个消费者独立的资源请求。完成通知无条件发生，取消只影响本请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfassetloadoperation-signals-completed) | `signal completed(result: GFAssetLoadResult)` |
| 方法 | [`wait_result_async`](#member-gfassetloadoperation-methods-wait_result_async) | `func wait_result_async() -> GFAssetLoadResult:` |
| 方法 | [`get_result`](#member-gfassetloadoperation-methods-get_result) | `func get_result() -> GFAssetLoadResult:` |
| 方法 | [`is_completed`](#member-gfassetloadoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`cancel`](#member-gfassetloadoperation-methods-cancel) | `func cancel() -> bool:` |

## 信号

<a id="member-gfassetloadoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFAssetLoadResult)
```

终态提交后恰好发出一次，与 owner 是否存活无关。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 稳定的终态结果。 |

## 方法

<a id="member-gfassetloadoperation-methods-wait_result_async"></a>

### `wait_result_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func wait_result_async() -> GFAssetLoadResult:
```

等待并返回类型化结果，同时覆盖缓存命中的即时完成。

返回：同一个结果对象；重复等待不创建新句柄。

<a id="member-gfassetloadoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFAssetLoadResult:
```

查看已提交结果。

返回：pending 为 null，否则为稳定终态。

<a id="member-gfassetloadoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

判断请求是否已完成。

返回：已进入终态时为 true。

<a id="member-gfassetloadoperation-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> bool:
```

撤销本消费者的 pending 请求。终态后返回 false，不释放成功句柄。

返回：本次取消生效时为 true。
