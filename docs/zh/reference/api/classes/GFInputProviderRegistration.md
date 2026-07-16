# GFInputProviderRegistration

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/formatting/gf_input_provider_registration.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

输入格式化 provider 注册句柄。 由 GFInputFormatterRegistry 返回，用于显式释放一次 provider 注册。 句柄只管理注册生命周期，不拥有 provider 的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`provider_kind`](#member-gfinputproviderregistration-properties-provider_kind) | `var provider_kind: StringName = &""` |
| 属性 | [`provider`](#member-gfinputproviderregistration-properties-provider) | `var provider: Resource = null` |
| 方法 | [`is_active`](#member-gfinputproviderregistration-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`release`](#member-gfinputproviderregistration-methods-release) | `func release() -> bool:` |

## 属性

<a id="member-gfinputproviderregistration-properties-provider_kind"></a>

### `provider_kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var provider_kind: StringName = &""
```

Provider 类型。

<a id="member-gfinputproviderregistration-properties-provider"></a>

### `provider`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var provider: Resource = null
```

已注册 provider。

## 方法

<a id="member-gfinputproviderregistration-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_active() -> bool:
```

检查注册是否仍处于活动状态。

返回：活动返回 true。

<a id="member-gfinputproviderregistration-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func release() -> bool:
```

释放注册。

返回：本次调用确实释放了注册时返回 true。
