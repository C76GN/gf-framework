# GFInstaller

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_installer.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

项目启动装配脚本基类。 继承后重写 install()，并在 Project Settings 的 gf/project/installers 中登记脚本路径， Gf.init() 与 Gf.set_architecture() 会在架构初始化前自动执行这些安装器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`install`](#member-gfinstaller-methods-install) | `func install(_architecture: GFArchitecture) -> void:` |
| 方法 | [`install_bindings`](#member-gfinstaller-methods-install_bindings) | `func install_bindings(_binder: Variant) -> void:` |

## 方法

<a id="member-gfinstaller-methods-install"></a>

### `install`

- API：`public`

```gdscript
func install(_architecture: GFArchitecture) -> void:
```

将项目模块注册到架构。

参数：

| 名称 | 说明 |
|---|---|
| `_architecture` | 当前即将初始化的架构实例。 |

<a id="member-gfinstaller-methods-install_bindings"></a>

### `install_bindings`

- API：`public`

```gdscript
func install_bindings(_binder: Variant) -> void:
```

使用声明式装配器注册项目模块。 "type": "Variant", "description": "当前架构创建的装配器实例，实际类型为 GFBindBuilder。" }

参数：

| 名称 | 说明 |
|---|---|
| `_binder` | 绑定到当前架构的装配器。 |

结构：

- `_binder {`:
