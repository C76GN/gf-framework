# GFWeakMethodInvocation

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_weak_method_invocation.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`10.0.0`

不强持有目标对象的方法调用记录。 记录只保留目标的 WeakRef、创建时实例 ID 与方法名，并在调用时接收参数。 它不会保存 Callable，因此目标为 RefCounted 时不会被绑定回调意外延长生命周期。 `invoked` 只表示方法通过定义与参数数量预检且 Object.callv() 已返回；GDScript 无法捕获 callv 期间的类型错误或被调方法内部错误，因此这类错误不会转换为 `failed`。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_INVOKED`](#member-gfweakmethodinvocation-constants-status_invoked) | `const STATUS_INVOKED: StringName = &"invoked"` |
| 常量 | [`STATUS_OWNER_RELEASED`](#member-gfweakmethodinvocation-constants-status_owner_released) | `const STATUS_OWNER_RELEASED: StringName = &"owner_released"` |
| 常量 | [`STATUS_METHOD_MISSING`](#member-gfweakmethodinvocation-constants-status_method_missing) | `const STATUS_METHOD_MISSING: StringName = &"method_missing"` |
| 常量 | [`STATUS_FAILED`](#member-gfweakmethodinvocation-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 方法 | [`_init`](#member-gfweakmethodinvocation-methods-_init) | `func _init(owner: Object = null, method_name: StringName = &"") -> void:` |
| 方法 | [`invoke`](#member-gfweakmethodinvocation-methods-invoke) | `func invoke(arguments: Array = []) -> Dictionary:` |

## 常量

<a id="member-gfweakmethodinvocation-constants-status_invoked"></a>

### `STATUS_INVOKED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVOKED: StringName = &"invoked"
```

方法已被调用并返回。

<a id="member-gfweakmethodinvocation-constants-status_owner_released"></a>

### `STATUS_OWNER_RELEASED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_OWNER_RELEASED: StringName = &"owner_released"
```

目标对象已释放。

<a id="member-gfweakmethodinvocation-constants-status_method_missing"></a>

### `STATUS_METHOD_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_METHOD_MISSING: StringName = &"method_missing"
```

目标对象不再提供记录的方法。

<a id="member-gfweakmethodinvocation-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

调用记录或参数未通过显式预检。

## 方法

<a id="member-gfweakmethodinvocation-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func _init(owner: Object = null, method_name: StringName = &"") -> void:
```

创建弱方法调用记录。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 调用目标；无效目标会构造一个始终返回 failed 的记录。 |
| `method_name` | 调用时解析的方法名；空名称会构造一个始终返回 failed 的记录。 |

<a id="member-gfweakmethodinvocation-methods-invoke"></a>

### `invoke`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func invoke(arguments: Array = []) -> Dictionary:
```

调用仍存活目标上的记录方法。 参数只在本次调用期间使用，不会保存到调用记录。返回 `invoked` 只代表定义与参数 数量预检通过且 callv 已返回，不代表 callv 期间没有类型错误或被调方法内部错误。

参数：

| 名称 | 说明 |
|---|---|
| `arguments` | 传给 Object.callv() 的调用时参数数组。 |

返回：调用状态、返回值与稳定目标身份。

结构：

- `arguments`: Array of invocation-time arguments; values are never retained by this record.
- `return`: Dictionary with status, invoked, value, error_code, initial_owner_instance_id, and method_name.
