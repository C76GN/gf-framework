# GFCallableAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_callable_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

将 Callable 包装为队列动作。 适合把轻量表现指令、日志、回调或项目自定义命令插入 GFActionQueueSystem。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`callback`](#member-gfcallableaction-properties-callback) | `var callback: Callable` |
| 属性 | [`args`](#member-gfcallableaction-properties-args) | `var args: Array = []` |
| 方法 | [`execute`](#member-gfcallableaction-methods-execute) | `func execute() -> Variant:` |

## 属性

<a id="member-gfcallableaction-properties-callback"></a>

### `callback`

- API：`public`

```gdscript
var callback: Callable
```

要执行的回调。

<a id="member-gfcallableaction-properties-args"></a>

### `args`

- API：`public`

```gdscript
var args: Array = []
```

传给回调的参数。

结构：

- `args`: Array，传给 callback.callv() 的参数列表。

## 方法

<a id="member-gfcallableaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行回调并返回回调结果。

返回：callback.callv(args) 的返回值；回调无效时返回 null。

结构：

- `return`: Variant，由 callback 返回，可能是 Signal、null 或项目自定义值。
