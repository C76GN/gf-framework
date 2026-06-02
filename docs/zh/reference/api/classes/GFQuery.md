# GFQuery

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_query.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

查询抽象基类。 用于从架构中查询数据。子类必须返回结果。 子类必须实现 'execute' 方法来定义查询逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`execute`](#member-gfquery-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`is_lifecycle_active`](#member-gfquery-methods-is_lifecycle_active) | `func is_lifecycle_active() -> bool:` |
| 方法 | [`get_model`](#member-gfquery-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfquery-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfquery-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |

## 方法

<a id="member-gfquery-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行查询并返回结果。子类必须重写此方法。 "type": "Variant", "description": "查询结果；具体类型由查询子类定义。" }

返回：查询结果。

结构：

- `return {`:

<a id="member-gfquery-methods-is_lifecycle_active"></a>

### `is_lifecycle_active`

- API：`public`

```gdscript
func is_lifecycle_active() -> bool:
```

检查查询所属架构生命周期是否仍可安全继续异步写回。

返回：所属架构仍处于活动生命周期时返回 true。

<a id="member-gfquery-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例。

<a id="member-gfquery-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例。

<a id="member-gfquery-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例。
