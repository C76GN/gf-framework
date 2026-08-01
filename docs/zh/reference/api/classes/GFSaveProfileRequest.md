# GFSaveProfileRequest

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_request.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

Save Profile 保存请求的一次性所有权句柄。 `take_ownership()` 不会深复制输入。成功创建后，调用方必须立即且永久放弃 document metadata、Provider context、result metadata 及其全部嵌套集合 alias。 Utility 只允许 claim 一次，且不会公开任何 payload getter。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`take_ownership`](#member-gfsaveprofilerequest-methods-take_ownership) | `static func take_ownership( document_metadata: Dictionary, context: Dictionary, result_metadata: Dictionary ) -> GFSaveProfileRequest:` |
| 方法 | [`is_claimed`](#member-gfsaveprofilerequest-methods-is_claimed) | `func is_claimed() -> bool:` |

## 方法

<a id="member-gfsaveprofilerequest-methods-take_ownership"></a>

### `take_ownership`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func take_ownership( document_metadata: Dictionary, context: Dictionary, result_metadata: Dictionary ) -> GFSaveProfileRequest:
```

创建请求并接收三个 Dictionary 的逻辑唯一所有权。 此方法不会深复制。返回请求后，调用方必须立即且永久放弃三个源 Dictionary 以及所有嵌套 `Dictionary` / `Array` alias；继续访问或修改会破坏请求快照。

参数：

| 名称 | 说明 |
|---|---|
| `document_metadata` | 写入文档的持久化元数据。 |
| `context` | Provider 保存准备使用的临时上下文。 |
| `result_metadata` | 只写入当前操作终态的调用方元数据。 |

返回：持有三个请求载荷的新 opaque 句柄。

结构：

- `document_metadata`: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
- `context`: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
- `result_metadata`: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.

<a id="member-gfsaveprofilerequest-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_claimed() -> bool:
```

检查请求是否已经被 Save Profile Utility 接管。

返回：已成功 claim 时返回 true。
