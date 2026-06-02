# GFBinder

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_binder.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

面向 Installer 的声明式装配入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`bind_model`](#member-gfbinder-methods-bind_model) | `func bind_model(script_cls: Script) -> GFBindBuilder:` |
| 方法 | [`bind_system`](#member-gfbinder-methods-bind_system) | `func bind_system(script_cls: Script) -> GFBindBuilder:` |
| 方法 | [`bind_utility`](#member-gfbinder-methods-bind_utility) | `func bind_utility(script_cls: Script) -> GFBindBuilder:` |
| 方法 | [`bind_factory`](#member-gfbinder-methods-bind_factory) | `func bind_factory(script_cls: Script) -> GFBindBuilder:` |

## 方法

<a id="member-gfbinder-methods-bind_model"></a>

### `bind_model`

- API：`public`

```gdscript
func bind_model(script_cls: Script) -> GFBindBuilder:
```

声明一个 Model 绑定。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | Model 脚本类型。 |

返回：绑定构建器。

<a id="member-gfbinder-methods-bind_system"></a>

### `bind_system`

- API：`public`

```gdscript
func bind_system(script_cls: Script) -> GFBindBuilder:
```

声明一个 System 绑定。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | System 脚本类型。 |

返回：绑定构建器。

<a id="member-gfbinder-methods-bind_utility"></a>

### `bind_utility`

- API：`public`

```gdscript
func bind_utility(script_cls: Script) -> GFBindBuilder:
```

声明一个 Utility 绑定。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | Utility 脚本类型。 |

返回：绑定构建器。

<a id="member-gfbinder-methods-bind_factory"></a>

### `bind_factory`

- API：`public`

```gdscript
func bind_factory(script_cls: Script) -> GFBindBuilder:
```

声明一个短生命周期对象工厂绑定。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |

返回：绑定构建器。
