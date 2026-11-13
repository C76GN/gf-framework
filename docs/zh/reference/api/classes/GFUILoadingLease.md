# GFUILoadingLease

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_loading_lease.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次等待请求的幂等释放句柄。 由 GFUILoadingUtility 持有至释放；owner 与 scope 使用弱引用，不能延长业务生命周期。 进度达到 1 不自动释放，调用方仍需在业务结束时 release。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_id`](#member-gfuiloadinglease-methods-get_id) | `func get_id() -> int:` |
| 方法 | [`is_active`](#member-gfuiloadinglease-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_progress`](#member-gfuiloadinglease-methods-get_progress) | `func get_progress() -> GFAsyncProgress:` |
| 方法 | [`release`](#member-gfuiloadinglease-methods-release) | `func release() -> bool:` |

## 方法

<a id="member-gfuiloadinglease-methods-get_id"></a>

### `get_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_id() -> int:
```

获取服务内唯一请求身份。

返回：正数身份；未配置为 0。

<a id="member-gfuiloadinglease-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

检查等待请求是否仍有效。

返回：服务仍存在且尚未释放时为 true。

<a id="member-gfuiloadinglease-methods-get_progress"></a>

### `get_progress`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_progress() -> GFAsyncProgress:
```

获取关联的既有进度对象。

返回：无进度时为 null。

<a id="member-gfuiloadinglease-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> bool:
```

结束本次等待，不取消业务操作，也不等待最短显示时间。

返回：首次释放活动请求时为 true。
