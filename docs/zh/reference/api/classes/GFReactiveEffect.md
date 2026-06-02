# GFReactiveEffect

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_reactive_effect.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

GFBindableProperty 的轻量响应式副作用。 监听一组 GFBindableProperty，在任意来源变化时执行回调。可绑定 Node 生命周期， 适合 Controller 层组合多个 Model 属性，不要求项目引入新的状态模型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`effect_ran`](#member-gfreactiveeffect-signals-effect_ran) | `signal effect_ran(value: Variant)` |
| 属性 | [`max_reruns_per_run`](#member-gfreactiveeffect-properties-max_reruns_per_run) | `var max_reruns_per_run: int = 8` |
| 方法 | [`configure`](#member-gfreactiveeffect-methods-configure) | `func configure( sources: Array[GFBindableProperty], callback: Callable, owner: Node = null, run_immediately: bool = true ) -> void:` |
| 方法 | [`run`](#member-gfreactiveeffect-methods-run) | `func run() -> Variant:` |
| 方法 | [`stop`](#member-gfreactiveeffect-methods-stop) | `func stop() -> void:` |
| 方法 | [`dispose`](#member-gfreactiveeffect-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`is_active`](#member-gfreactiveeffect-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_sources`](#member-gfreactiveeffect-methods-get_sources) | `func get_sources() -> Array[GFBindableProperty]:` |

## 信号

<a id="member-gfreactiveeffect-signals-effect_ran"></a>

### `effect_ran`

- API：`public`

```gdscript
signal effect_ran(value: Variant)
```

effect 执行后发出。 "type": "Variant", "description": "回调返回值。" }

参数：

| 名称 | 说明 |
|---|---|
| `value` | 回调返回值。 |

结构：

- `value {`:

## 属性

<a id="member-gfreactiveeffect-properties-max_reruns_per_run"></a>

### `max_reruns_per_run`

- API：`public`

```gdscript
var max_reruns_per_run: int = 8
```

单次 run 中最多补跑的次数，避免回调持续写入来源属性造成死循环。

## 方法

<a id="member-gfreactiveeffect-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( sources: Array[GFBindableProperty], callback: Callable, owner: Node = null, run_immediately: bool = true ) -> void:
```

配置并启动 effect。重复调用会先停止旧绑定。

参数：

| 名称 | 说明 |
|---|---|
| `sources` | 要监听的 GFBindableProperty 列表。 |
| `callback` | 变化后执行的回调。 |
| `owner` | 可选 Node 生命周期宿主。 |
| `run_immediately` | 是否立即执行一次。 |

<a id="member-gfreactiveeffect-methods-run"></a>

### `run`

- API：`public`

```gdscript
func run() -> Variant:
```

手动执行 effect。 "type": "Variant", "description": "回调返回值；回调无效时返回 null。" }

返回：回调返回值；回调无效时返回 null。

结构：

- `return {`:

<a id="member-gfreactiveeffect-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

停止 effect 并断开全部监听。

<a id="member-gfreactiveeffect-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放 effect 持有的监听。

<a id="member-gfreactiveeffect-methods-is_active"></a>

### `is_active`

- API：`public`

```gdscript
func is_active() -> bool:
```

检查 effect 是否处于激活状态。

返回：激活时返回 true。

<a id="member-gfreactiveeffect-methods-get_sources"></a>

### `get_sources`

- API：`public`

```gdscript
func get_sources() -> Array[GFBindableProperty]:
```

获取当前监听的属性列表。

返回：GFBindableProperty 数组。
