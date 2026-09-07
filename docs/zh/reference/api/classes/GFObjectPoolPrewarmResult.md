# GFObjectPoolPrewarmResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_prewarm_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

离树实例预分配的最终结果。 取消只停止未创建的实例，已经缓存的实例保留。预分配不执行入树或 ready。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfobjectpoolprewarmresult-enums-status) | `enum Status` |
| 方法 | [`is_successful`](#member-gfobjectpoolprewarmresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfobjectpoolprewarmresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_reason`](#member-gfobjectpoolprewarmresult-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_requested_count`](#member-gfobjectpoolprewarmresult-methods-get_requested_count) | `func get_requested_count() -> int:` |
| 方法 | [`get_created_count`](#member-gfobjectpoolprewarmresult-methods-get_created_count) | `func get_created_count() -> int:` |

## 枚举

<a id="member-gfobjectpoolprewarmresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 已创建全部请求实例。
	SUCCEEDED,
	## 缓存容量不足，仅创建部分实例。
	PARTIAL,
	## 请求参数无效。
	INVALID,
	## 请求被令牌或池生命周期取消。
	CANCELLED,
	## 实例化失败。
	FAILED,
}
```

预分配请求的终态。

## 方法

<a id="member-gfobjectpoolprewarmresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

检查是否完成全部预分配。

返回：仅 SUCCEEDED 返回 true。

<a id="member-gfobjectpoolprewarmresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> Status:
```

获取终态。

返回：请求的最终 Status。

<a id="member-gfobjectpoolprewarmresult-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reason() -> StringName:
```

获取结果原因。

返回：prewarmed、capacity_limited、invalid_scene、invalid_count、invalid_batch_size、main_thread_required、cancelled、pool_disposed 或 scene_instantiation_failed；未配置时为 unconfigured。

<a id="member-gfobjectpoolprewarmresult-methods-get_requested_count"></a>

### `get_requested_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_requested_count() -> int:
```

获取有效的请求数量。

返回：非负请求数量；负数输入的无效结果归零。

<a id="member-gfobjectpoolprewarmresult-methods-get_created_count"></a>

### `get_created_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_created_count() -> int:
```

获取本次已成功缓存的实例数量。

返回：完成时已创建数量，不保证这些实例以后仍留在缓存中。
