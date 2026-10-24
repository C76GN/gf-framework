# GFSaveProfileRequest

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_request.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

Save Profile 保存请求的一次性所有权句柄。 `create()` 在大小预算内隔离 document metadata、Provider context 和 result metadata。调用方可继续使用源字典；后续修改不会改变已提交请求。 Utility 只允许 claim 一次，且不会公开任何 payload getter。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfsaveprofilerequest-methods-create) | `static func create( document_metadata: Dictionary, context: Dictionary, result_metadata: Dictionary ) -> GFSaveProfileRequest:` |
| 方法 | [`is_claimed`](#member-gfsaveprofilerequest-methods-is_claimed) | `func is_claimed() -> bool:` |

## 方法

<a id="member-gfsaveprofilerequest-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( document_metadata: Dictionary, context: Dictionary, result_metadata: Dictionary ) -> GFSaveProfileRequest:
```

创建拥有独立元数据快照的请求。 输入必须是纯数据；三个字典合计最多 64 层、100000 节点、1 MiB 保守复制 预算。对象、循环、非有限数与超预算输入被拒绝；大型 section 应由 Provider 准备。

参数：

| 名称 | 说明 |
|---|---|
| `document_metadata` | 写入文档的持久化元数据。 |
| `context` | Provider 保存准备使用的临时上下文。 |
| `result_metadata` | 只写入当前操作终态的调用方元数据。 |

返回：持有隔离快照的一次性句柄；输入无效或超预算时返回 null。

结构：

- `document_metadata`: Bounded pure-data Dictionary copied into an isolated snapshot.
- `context`: Bounded pure-data Dictionary copied into an isolated snapshot.
- `result_metadata`: Bounded pure-data Dictionary copied into an isolated snapshot.

<a id="member-gfsaveprofilerequest-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_claimed() -> bool:
```

检查请求是否已经被 Save Profile Utility 接管。

返回：已成功 claim 时返回 true。
