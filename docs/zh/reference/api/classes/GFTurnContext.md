# GFTurnContext

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/runtime/gf_turn_context.gd`
- 模块：`Turn Based`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用回合流程上下文。 只记录参与者、行动、轮次和元数据，不假设生命值、阵营、技能等业务概念。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`current_actor`](#member-gfturncontext-properties-current_actor) | `var current_actor: Object:` |
| 属性 | [`round_index`](#member-gfturncontext-properties-round_index) | `var round_index: int:` |
| 属性 | [`metadata`](#member-gfturncontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_actor`](#member-gfturncontext-methods-add_actor) | `func add_actor(actor: Object) -> void:` |
| 方法 | [`remove_actor`](#member-gfturncontext-methods-remove_actor) | `func remove_actor(actor: Object) -> void:` |
| 方法 | [`get_actors`](#member-gfturncontext-methods-get_actors) | `func get_actors() -> Array[Object]:` |
| 方法 | [`cleanup_invalid_actors`](#member-gfturncontext-methods-cleanup_invalid_actors) | `func cleanup_invalid_actors() -> int:` |
| 方法 | [`get_actor_value`](#member-gfturncontext-methods-get_actor_value) | `func get_actor_value(actor: Object, key: StringName, fallback: Variant = null) -> Variant:` |

## 属性

<a id="member-gfturncontext-properties-current_actor"></a>

### `current_actor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var current_actor: Object:
```

当前行动主体。

<a id="member-gfturncontext-properties-round_index"></a>

### `round_index`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var round_index: int:
```

当前轮次索引。

<a id="member-gfturncontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据，框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant] project-defined turn flow metadata.

## 方法

<a id="member-gfturncontext-methods-add_actor"></a>

### `add_actor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_actor(actor: Object) -> void:
```

添加参与者。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象。Context 会强持有 RefCounted，直到 remove_actor() 或 Context 自身释放。 |

<a id="member-gfturncontext-methods-remove_actor"></a>

### `remove_actor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func remove_actor(actor: Object) -> void:
```

移除参与者。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象；移除会释放 Context 对 RefCounted 的强所有权。 |

<a id="member-gfturncontext-methods-get_actors"></a>

### `get_actors`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_actors() -> Array[Object]:
```

获取参与者只读快照。

返回：当前有效性尚未重新校验的参与者数组快照。

<a id="member-gfturncontext-methods-cleanup_invalid_actors"></a>

### `cleanup_invalid_actors`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cleanup_invalid_actors() -> int:
```

清理已经失效的参与者引用。

返回：被移除的失效参与者数量。

结构：

- `return`: int removed invalid actor reference count.

<a id="member-gfturncontext-methods-get_actor_value"></a>

### `get_actor_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_actor_value(actor: Object, key: StringName, fallback: Variant = null) -> Variant:
```

从参与者读取排序或判定值。 优先调用参数兼容的 `get_turn_value(key, fallback)`，其次读取对象属性。 同名方法若不接受两个实参或参数类型不兼容，会被视为不可调用并继续属性读取。 GDScript 无法捕获方法内部脚本错误；项目实现必须自行保证回调可安全返回。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象。 |
| `key` | 值键。 |
| `fallback` | 读取失败时的兜底值。 |

返回：读取到的值。

结构：

- `fallback`: Variant returned when no actor value can be read.
- `return`: Variant read from get_turn_value(), object property access, or fallback.
