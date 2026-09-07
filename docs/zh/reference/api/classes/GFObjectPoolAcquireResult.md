# GFObjectPoolAcquireResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_acquire_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次节点借用的结果。 结果记录完成时的事实；成功结果中的 Lease 仍有自己的后续生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfobjectpoolacquireresult-enums-status) | `enum Status` |
| 方法 | [`is_successful`](#member-gfobjectpoolacquireresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfobjectpoolacquireresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_stage`](#member-gfobjectpoolacquireresult-methods-get_stage) | `func get_stage() -> StringName:` |
| 方法 | [`get_reason`](#member-gfobjectpoolacquireresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_lease`](#member-gfobjectpoolacquireresult-methods-get_lease) | `func get_lease() -> GFObjectPoolLease:` |

## 枚举

<a id="member-gfobjectpoolacquireresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 已完成挂载并交付借用。
	SUCCEEDED,
	## 输入或调用线程不符合要求。
	INVALID,
	## 父节点或对象池生命周期已经结束。
	CANCELLED,
	## 实例化、准备或挂载失败。
	FAILED,
}
```

借用请求的最终结果。

## 方法

<a id="member-gfobjectpoolacquireresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功交付过借用。

返回：status 为 SUCCEEDED 时为 true。

<a id="member-gfobjectpoolacquireresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取最终状态。

返回：本次请求的 Status。

<a id="member-gfobjectpoolacquireresult-methods-get_stage"></a>

### `get_stage`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stage() -> StringName:
```

获取完成或失败的业务阶段。

返回：validation、allocation、prepare、attach 或 complete。

<a id="member-gfobjectpoolacquireresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reason() -> StringName:
```

获取稳定的结果原因。

返回：acquired、invalid_scene、invalid_parent、main_thread_required、pool_disposed、parent_lost、owner_lost、scene_instantiation_failed、prepare_failed、invalid_prepare_result 或 candidate_invalidated；未配置结果为 unconfigured。

<a id="member-gfobjectpoolacquireresult-methods-get_lease"></a>

### `get_lease`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_lease() -> GFObjectPoolLease:
```

获取成功交付的借用。

返回：仅成功时非 null；是否仍可使用节点应查询 Lease。
