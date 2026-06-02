# GFPayload

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_payload.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

强类型数据载体的抽象基类。 继承自 RefCounted，用作事件传递、命令参数、系统间查询返回值的 标准化强类型数据包，替代容易在大型项目中引发类型错误和 null 访问的裸 Dictionary。 使用方式：为每个具体的数据场景定义一个子类， 将相关字段声明为强类型变量，并按需实现 to_dict() / from_dict()。 典型用途： - 作为 GFCommand 的参数包（替代 Dictionary 参数） - 作为类型事件系统中的事件数据载体 - 作为 GFQuery 的查询结果返回值

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`is_consumed`](#member-gfpayload-properties-is_consumed) | `var is_consumed: bool = false` |
| 方法 | [`to_dict`](#member-gfpayload-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfpayload-methods-from_dict) | `func from_dict(_data: Dictionary) -> void:` |
| 方法 | [`validate`](#member-gfpayload-methods-validate) | `func validate() -> bool:` |

## 属性

<a id="member-gfpayload-properties-is_consumed"></a>

### `is_consumed`

- API：`public`

```gdscript
var is_consumed: bool = false
```

事件消费标记。高优先级回调可将此标记设为 true， 阻止后续低优先级回调继续接收该事件。 仅在 GFTypeEventSystem 的类型事件轨道中生效。

## 方法

<a id="member-gfpayload-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

将此载体序列化为字典，便于存档、网络传输或日志记录。 子类应重写此方法以包含所有相关字段。 "type": "Dictionary", "additional_properties": true }

返回：包含字段数据的字典。

结构：

- `return {`:

<a id="member-gfpayload-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(_data: Dictionary) -> void:
```

从字典反序列化并填充此载体的字段。 子类应重写此方法以恢复所有相关字段。 "type": "Dictionary", "additional_properties": true }

参数：

| 名称 | 说明 |
|---|---|
| `_data` | 包含字段数据的字典（通常来自 to_dict() 的结果）。 |

结构：

- `_data {`:

<a id="member-gfpayload-methods-validate"></a>

### `validate`

- API：`public`

```gdscript
func validate() -> bool:
```

校验载体中的数据是否满足业务约束。 子类可重写此方法以添加非空、范围等校验逻辑。

返回：数据合法返回 true，否则返回 false。
