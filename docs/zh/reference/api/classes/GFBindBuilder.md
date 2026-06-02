# GFBindBuilder

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_bind_builder.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

声明式装配链，用于把脚本绑定为模块或短生命周期工厂。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`from_factory`](#member-gfbindbuilder-methods-from_factory) | `func from_factory(factory: Callable) -> GFBindBuilder:` |
| 方法 | [`from_instance`](#member-gfbindbuilder-methods-from_instance) | `func from_instance(instance: Object) -> GFBindBuilder:` |
| 方法 | [`with_alias`](#member-gfbindbuilder-methods-with_alias) | `func with_alias(alias_cls: Script) -> GFBindBuilder:` |
| 方法 | [`as_singleton`](#member-gfbindbuilder-methods-as_singleton) | `func as_singleton() -> void:` |
| 方法 | [`as_transient`](#member-gfbindbuilder-methods-as_transient) | `func as_transient() -> void:` |

## 方法

<a id="member-gfbindbuilder-methods-from_factory"></a>

### `from_factory`

- API：`public`

```gdscript
func from_factory(factory: Callable) -> GFBindBuilder:
```

使用 Callable 作为绑定来源。

参数：

| 名称 | 说明 |
|---|---|
| `factory` | 返回 Object 实例的工厂。 |

返回：当前 Builder，便于继续声明生命周期。

<a id="member-gfbindbuilder-methods-from_instance"></a>

### `from_instance`

- API：`public`

```gdscript
func from_instance(instance: Object) -> GFBindBuilder:
```

使用已有实例作为绑定来源。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册或暴露的实例。 |

返回：当前 Builder，便于继续声明生命周期。

<a id="member-gfbindbuilder-methods-with_alias"></a>

### `with_alias`

- API：`public`

```gdscript
func with_alias(alias_cls: Script) -> GFBindBuilder:
```

额外登记一个查询别名。仅对 Model/System/Utility 有效。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 调用 get_* 时使用的抽象脚本类型。 |

返回：当前 Builder，便于继续声明生命周期。

<a id="member-gfbindbuilder-methods-as_singleton"></a>

### `as_singleton`

- API：`public`

```gdscript
func as_singleton() -> void:
```

以单例语义完成绑定。

<a id="member-gfbindbuilder-methods-as_transient"></a>

### `as_transient`

- API：`public`

```gdscript
func as_transient() -> void:
```

以瞬态语义完成绑定。仅短生命周期工厂支持 transient。
