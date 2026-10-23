# GFAssetLoadResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_load_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

单次资源请求的终态事实；scope 关闭后成功事实保留，但句柄不再可用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfassetloadresult-enums-status) | `enum Status` |
| 方法 | [`is_successful`](#member-gfassetloadresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfassetloadresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_handle`](#member-gfassetloadresult-methods-get_handle) | `func get_handle() -> GFAssetHandle:` |
| 方法 | [`get_error_code`](#member-gfassetloadresult-methods-get_error_code) | `func get_error_code() -> Error:` |

## 枚举

<a id="member-gfassetloadresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 资源已成功交付到请求 scope；之后释放句柄不改变此终态。
	SUCCEEDED,
	## 请求未取得可交付句柄，具体原因由错误码表达。
	FAILED,
	## 请求已取消，不代表底层共享加载已经停止。
	CANCELLED,
}
```

请求终态。

## 方法

<a id="member-gfassetloadresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

返回请求是否成功；之后关闭 scope 不改写此历史事实。

返回：成功时为 true。

<a id="member-gfassetloadresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

返回请求终态。

返回：请求终态。

<a id="member-gfassetloadresult-methods-get_handle"></a>

### `get_handle`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_handle() -> GFAssetHandle:
```

返回同一 scope 所拥有的句柄。重复调用不增加引用计数。

返回：成功句柄或 null；scope 已关闭时句柄已释放。

<a id="member-gfassetloadresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

返回错误码。

返回：成功为 OK，取消为 ERR_SKIP，其他错误为失败码。
