# GFStorageAsyncRequestOptions

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_async_request_options.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

异步 Storage caller 观察生命周期的不可变选项。 选项只弱持有 owner，并可绑定只读取消令牌与单调 timeout。必须通过 `create()` 构造；直接 `new()` 或非法参数会得到 `is_valid() == false` 的对象，避免把错误选项 静默解释成没有生命周期约束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfstorageasyncrequestoptions-methods-create) | `static func create( owner: Object, cancel_token: GFCancellationToken = null, timeout_msec: int = 0 ) -> GFStorageAsyncRequestOptions:` |
| 方法 | [`is_valid`](#member-gfstorageasyncrequestoptions-methods-is_valid) | `func is_valid() -> bool:` |

## 方法

<a id="member-gfstorageasyncrequestoptions-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( owner: Object, cancel_token: GFCancellationToken = null, timeout_msec: int = 0 ) -> GFStorageAsyncRequestOptions:
```

创建 caller 生命周期选项。 owner 不会被强持有；需要在 Node 离树时结束观察的调用方，应另行传入由 `GFCancellationSource.cancel_when_node_exits()` 驱动的 token。timeout 从公开 request 调用时刻开始使用 Utility 的单调时钟计算，`0` 表示不设截止时间。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 当前 consumer 的非空生命周期 owner。 |
| `cancel_token` | 可选只读取消令牌；已取消令牌会在 worker 接纳前参与仲裁。 |
| `timeout_msec` | 非负单调超时毫秒数；\`0\` 表示不设截止时间。 |

返回：始终返回对象；参数非法时对象的 `is_valid()` 为 false。

<a id="member-gfstorageasyncrequestoptions-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

返回选项是否由合法参数创建。

返回：仅 `create()` 接受全部参数时返回 true；owner 后续释放不会改写该配置事实。
