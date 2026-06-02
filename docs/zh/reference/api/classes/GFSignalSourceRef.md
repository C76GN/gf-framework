# GFSignalSourceRef

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/bridge/gf_signal_source_ref.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可资源化的信号来源引用。 该资源只描述相对于某个根节点的信号来源节点和信号名，不连接信号、 不解释信号含义，也不绑定任何业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source_path`](#member-gfsignalsourceref-properties-source_path) | `var source_path: NodePath = NodePath("")` |
| 属性 | [`signal_name`](#member-gfsignalsourceref-properties-signal_name) | `var signal_name: StringName = &""` |
| 属性 | [`metadata`](#member-gfsignalsourceref-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`resolve_source`](#member-gfsignalsourceref-methods-resolve_source) | `func resolve_source(root: Node) -> Object:` |
| 方法 | [`get_signal`](#member-gfsignalsourceref-methods-get_signal) | `func get_signal(root: Node) -> Signal:` |
| 方法 | [`is_valid_for`](#member-gfsignalsourceref-methods-is_valid_for) | `func is_valid_for(root: Node) -> bool:` |
| 方法 | [`get_signal_argument_count`](#member-gfsignalsourceref-methods-get_signal_argument_count) | `func get_signal_argument_count(root: Node) -> int:` |
| 方法 | [`to_dictionary`](#member-gfsignalsourceref-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfsignalsourceref-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: NodePath = NodePath("")
```

信号来源节点路径。为空时使用传入的根节点。

<a id="member-gfsignalsourceref-properties-signal_name"></a>

### `signal_name`

- API：`public`

```gdscript
var signal_name: StringName = &""
```

要读取的信号名。

<a id="member-gfsignalsourceref-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，关联到信号来源引用的项目侧元数据。

## 方法

<a id="member-gfsignalsourceref-methods-resolve_source"></a>

### `resolve_source`

- API：`public`

```gdscript
func resolve_source(root: Node) -> Object:
```

解析信号来源对象。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：来源对象；无法解析时返回 null。

<a id="member-gfsignalsourceref-methods-get_signal"></a>

### `get_signal`

- API：`public`

```gdscript
func get_signal(root: Node) -> Signal:
```

获取信号。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：有效信号；无法解析时返回空 Signal。

<a id="member-gfsignalsourceref-methods-is_valid_for"></a>

### `is_valid_for`

- API：`public`

```gdscript
func is_valid_for(root: Node) -> bool:
```

检查信号来源是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：有效时返回 true。

<a id="member-gfsignalsourceref-methods-get_signal_argument_count"></a>

### `get_signal_argument_count`

- API：`public`

```gdscript
func get_signal_argument_count(root: Node) -> int:
```

获取信号参数数量。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：参数数量；无法确定时返回 -1。

<a id="member-gfsignalsourceref-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为调试字典。

返回：来源快照。

结构：

- `return`: Dictionary，包含 source_path、signal_name 和 metadata。
