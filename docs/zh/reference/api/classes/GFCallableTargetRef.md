# GFCallableTargetRef

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/bridge/gf_callable_target_ref.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可资源化的 Callable 目标引用。 该资源只描述相对于某个根节点的目标节点、方法名和默认参数。 它不决定调用时机，也不解释方法的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_path`](#member-gfcallabletargetref-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`method_name`](#member-gfcallabletargetref-properties-method_name) | `var method_name: StringName = &""` |
| 属性 | [`default_args`](#member-gfcallabletargetref-properties-default_args) | `var default_args: Array = []` |
| 属性 | [`metadata`](#member-gfcallabletargetref-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`resolve_target`](#member-gfcallabletargetref-methods-resolve_target) | `func resolve_target(root: Node) -> Object:` |
| 方法 | [`get_callable`](#member-gfcallabletargetref-methods-get_callable) | `func get_callable(root: Node) -> Callable:` |
| 方法 | [`is_valid_for`](#member-gfcallabletargetref-methods-is_valid_for) | `func is_valid_for(root: Node) -> bool:` |
| 方法 | [`call_with_args`](#member-gfcallabletargetref-methods-call_with_args) | `func call_with_args(root: Node, args: Array = []) -> Dictionary:` |
| 方法 | [`to_dictionary`](#member-gfcallabletargetref-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfcallabletargetref-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = NodePath("")
```

目标节点路径。为空时使用传入的根节点。

<a id="member-gfcallabletargetref-properties-method_name"></a>

### `method_name`

- API：`public`

```gdscript
var method_name: StringName = &""
```

要调用的方法名。

<a id="member-gfcallabletargetref-properties-default_args"></a>

### `default_args`

- API：`public`

```gdscript
var default_args: Array = []
```

每次调用时追加到末尾的默认参数。

结构：

- `default_args`: Array，追加在动态信号桥接参数后的额外参数。

<a id="member-gfcallabletargetref-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，关联到 callable 目标引用的项目侧元数据。

## 方法

<a id="member-gfcallabletargetref-methods-resolve_target"></a>

### `resolve_target`

- API：`public`

```gdscript
func resolve_target(root: Node) -> Object:
```

解析调用目标。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：目标对象；无法解析时返回 null。

<a id="member-gfcallabletargetref-methods-get_callable"></a>

### `get_callable`

- API：`public`

```gdscript
func get_callable(root: Node) -> Callable:
```

创建目标 Callable。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：有效 Callable；无法解析时返回空 Callable。

<a id="member-gfcallabletargetref-methods-is_valid_for"></a>

### `is_valid_for`

- API：`public`

```gdscript
func is_valid_for(root: Node) -> bool:
```

检查调用目标是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：有效时返回 true。

<a id="member-gfcallabletargetref-methods-call_with_args"></a>

### `call_with_args`

- API：`public`

```gdscript
func call_with_args(root: Node, args: Array = []) -> Dictionary:
```

调用目标方法。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |
| `args` | 动态参数。 |

返回：结构化调用结果。

结构：

- `args`: Array，传入 default_args 之前的动态参数。
- `return`: Dictionary，包含 ok、reason 和 value。

<a id="member-gfcallabletargetref-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为调试字典。

返回：目标快照。

结构：

- `return`: Dictionary，包含 target_path、method_name、default_args 和 metadata。
