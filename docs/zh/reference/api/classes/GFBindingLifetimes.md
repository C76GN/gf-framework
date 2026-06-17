# GFBindingLifetimes

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_binding_lifetimes.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

依赖绑定的生命周期枚举。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Lifetime`](#member-gfbindinglifetimes-enums-lifetime) | `enum Lifetime` |

## 枚举

<a id="member-gfbindinglifetimes-enums-lifetime"></a>

### `Lifetime`

- API：`public`

```gdscript
enum Lifetime {
	## 首次解析后缓存实例，后续解析复用。
	SINGLETON,
	## 每次解析都重新创建实例。
	TRANSIENT,
}
```

绑定实例的生命周期。
