# GFConfig

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_config.gd`
- 模块：`Kernel`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

数据驱动配置的抽象基类。 继承自 Resource，可在编辑器中配置并序列化为 .tres 文件。 用于承载关卡配置、难度配置、游戏模式定义等只读数据， 供 GFSystem 在初始化或运行期间读取，彻底分离"数据"与"逻辑"。 子类应将所有可配置数据声明为 @export 变量。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`validate`](#member-gfconfig-methods-validate) | `func validate() -> bool:` |
| 方法 | [`to_dict`](#member-gfconfig-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 方法

<a id="member-gfconfig-methods-validate"></a>

### `validate`

- API：`public`

```gdscript
func validate() -> bool:
```

校验此配置数据是否完整且合法。 子类应重写此方法以添加必要的校验逻辑（如非空检查、范围检查）。

返回：配置合法返回 true，否则返回 false。

<a id="member-gfconfig-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

将配置数据序列化为字典，便于存档或网络传输。 子类可重写此方法以控制序列化范围。 "type": "Dictionary", "additional_properties": true }

返回：包含配置数据的字典。

结构：

- `return {`:
