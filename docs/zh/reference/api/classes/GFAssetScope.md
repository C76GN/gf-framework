# GFAssetScope

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_scope.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

贯穿资源请求和句柄的生命周期。关闭会取消 pending 请求并释放全部句柄。 Node owner 退出树时自动关闭；其他 owner 失效由资源服务 tick 检测。 scope 只撤销 GF 保留及交付资格，不销毁调用者已经保存的 Resource 引用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`close`](#member-gfassetscope-methods-close) | `func close() -> void:` |
| 方法 | [`is_open`](#member-gfassetscope-methods-is_open) | `func is_open() -> bool:` |

## 方法

<a id="member-gfassetscope-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func close() -> void:
```

关闭生命周期；重复关闭无副作用。

<a id="member-gfassetscope-methods-is_open"></a>

### `is_open`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_open() -> bool:
```

判断 scope 是否仍允许请求与句柄保留。

返回：未关闭且 owner 存活时为 true。
