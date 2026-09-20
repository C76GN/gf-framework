# GFStorageOwnedReadTakeResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_owned_read_take_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

一次独占读取领取的结果。 SUCCESS 时持有从句柄移交的完整读取结果，不复制业务载荷。重复调用 `get_read_result()` 返回同一对象；此后的引用共享由领取方负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfstorageownedreadtakeresult-enums-status) | `enum Status` |
| 方法 | [`get_status`](#member-gfstorageownedreadtakeresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`is_ok`](#member-gfstorageownedreadtakeresult-methods-is_ok) | `func is_ok() -> bool:` |
| 方法 | [`get_read_result`](#member-gfstorageownedreadtakeresult-methods-get_read_result) | `func get_read_result() -> GFStorageReadResult:` |

## 枚举

<a id="member-gfstorageownedreadtakeresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 本次调用取得完整读取结果。
	SUCCESS,
	## caller 尚未完成，稍后可以再次领取。
	NOT_READY,
	## 结果已经被同一句柄的另一调用领取。
	ALREADY_TAKEN,
	## 句柄已经放弃领取权。
	RELEASED,
	## caller 已失败或取消，没有可领取结果。
	FAILED,
	## 句柄未绑定到合法请求。
	INVALID,
	## 领取必须在主线程执行；本次调用未改变句柄。
	WRONG_THREAD,
}
```

领取结果的闭合分类，成功的空载荷与失败明确分离。

## 方法

<a id="member-gfstorageownedreadtakeresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取本次领取的状态。

返回：领取状态；手动构造的实例返回 INVALID。

<a id="member-gfstorageownedreadtakeresult-methods-is_ok"></a>

### `is_ok`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_ok() -> bool:
```

检查本次调用是否取得读取结果。

返回：仅 SUCCESS 时返回 true，成功的空 Dictionary 同样为 true。

<a id="member-gfstorageownedreadtakeresult-methods-get_read_result"></a>

### `get_read_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_read_result() -> GFStorageReadResult:
```

获取已经移交给领取方的完整读取结果。 返回同一个可变对象，不执行复制。句柄释放、Utility dispose 或原 owner 释放均不会撤销此对象；领取方自行管理后续引用。

返回：SUCCESS 时返回完整结果，其他状态返回 null。
