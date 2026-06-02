# GFSignalBridge

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/bridge/gf_signal_bridge.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

声明式信号到 Callable 的桥接资源。 桥接只描述信号来源、目标方法、参数重排和常量参数。它不修改场景结构、 不解释信号业务含义，也不要求调用方使用特定 UI 或状态机。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`bridge_id`](#member-gfsignalbridge-properties-bridge_id) | `var bridge_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfsignalbridge-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`source`](#member-gfsignalbridge-properties-source) | `var source: GFSignalSourceRef = GFSignalSourceRef.new()` |
| 属性 | [`target`](#member-gfsignalbridge-properties-target) | `var target: GFCallableTargetRef = GFCallableTargetRef.new()` |
| 属性 | [`argument_indices`](#member-gfsignalbridge-properties-argument_indices) | `var argument_indices: PackedInt32Array = PackedInt32Array()` |
| 属性 | [`constant_args`](#member-gfsignalbridge-properties-constant_args) | `var constant_args: Array = []` |
| 属性 | [`append_context`](#member-gfsignalbridge-properties-append_context) | `var append_context: bool = false` |
| 属性 | [`one_shot`](#member-gfsignalbridge-properties-one_shot) | `var one_shot: bool = false` |
| 属性 | [`connect_flags`](#member-gfsignalbridge-properties-connect_flags) | `var connect_flags: int = 0` |
| 属性 | [`metadata`](#member-gfsignalbridge-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`connect_bridge`](#member-gfsignalbridge-methods-connect_bridge) | `func connect_bridge( root: Node, owner: Object = null, signal_utility: GFSignalUtility = null ) -> GFSignalBridgeBinding:` |
| 方法 | [`invoke`](#member-gfsignalbridge-methods-invoke) | `func invoke(root: Node, signal_args: Array = []) -> Dictionary:` |
| 方法 | [`build_callable_args`](#member-gfsignalbridge-methods-build_callable_args) | `func build_callable_args(signal_args: Array = []) -> Array:` |
| 方法 | [`get_validation_report`](#member-gfsignalbridge-methods-get_validation_report) | `func get_validation_report(root: Node) -> Dictionary:` |
| 方法 | [`to_dictionary`](#member-gfsignalbridge-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfsignalbridge-properties-bridge_id"></a>

### `bridge_id`

- API：`public`

```gdscript
var bridge_id: StringName = &""
```

桥接 ID，便于调试和项目侧索引。

<a id="member-gfsignalbridge-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该桥接。

<a id="member-gfsignalbridge-properties-source"></a>

### `source`

- API：`public`

```gdscript
var source: GFSignalSourceRef = GFSignalSourceRef.new()
```

信号来源引用。

<a id="member-gfsignalbridge-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: GFCallableTargetRef = GFCallableTargetRef.new()
```

调用目标引用。

<a id="member-gfsignalbridge-properties-argument_indices"></a>

### `argument_indices`

- API：`public`

```gdscript
var argument_indices: PackedInt32Array = PackedInt32Array()
```

要从原始信号参数中抽取的索引。为空时透传全部信号参数。

<a id="member-gfsignalbridge-properties-constant_args"></a>

### `constant_args`

- API：`public`

```gdscript
var constant_args: Array = []
```

追加到桥接参数末尾的常量参数。

结构：

- `constant_args`: Array，追加在选中信号参数后的固定参数。

<a id="member-gfsignalbridge-properties-append_context"></a>

### `append_context`

- API：`public`

```gdscript
var append_context: bool = false
```

是否把桥接上下文字典追加到参数末尾。

<a id="member-gfsignalbridge-properties-one_shot"></a>

### `one_shot`

- API：`public`

```gdscript
var one_shot: bool = false
```

是否只触发一次。

<a id="member-gfsignalbridge-properties-connect_flags"></a>

### `connect_flags`

- API：`public`

```gdscript
var connect_flags: int = 0
```

Godot 信号连接标记。

<a id="member-gfsignalbridge-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，关联到信号桥的项目侧元数据。

## 方法

<a id="member-gfsignalbridge-methods-connect_bridge"></a>

### `connect_bridge`

- API：`public`

```gdscript
func connect_bridge( root: Node, owner: Object = null, signal_utility: GFSignalUtility = null ) -> GFSignalBridgeBinding:
```

连接桥接。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |
| `owner` | 可选连接拥有者。 |
| `signal_utility` | 可选 GFSignalUtility；为空时创建独立连接。 |

返回：运行中的桥接绑定；失败时返回 null。

<a id="member-gfsignalbridge-methods-invoke"></a>

### `invoke`

- API：`public`

```gdscript
func invoke(root: Node, signal_args: Array = []) -> Dictionary:
```

直接执行桥接调用。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |
| `signal_args` | 原始信号参数。 |

返回：结构化调用结果。

结构：

- `signal_args`: Array，来源信号发出的原始参数。
- `return`: Dictionary，包含 ok、reason、value、bridge_id 和 args。

<a id="member-gfsignalbridge-methods-build_callable_args"></a>

### `build_callable_args`

- API：`public`

```gdscript
func build_callable_args(signal_args: Array = []) -> Array:
```

构建目标 Callable 参数。

参数：

| 名称 | 说明 |
|---|---|
| `signal_args` | 原始信号参数。 |

返回：映射后的参数。

结构：

- `signal_args`: Array，来源信号发出的原始参数。
- `return`: Array，传给目标 Callable 且位于 target.default_args 之前的参数。

<a id="member-gfsignalbridge-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`

```gdscript
func get_validation_report(root: Node) -> Dictionary:
```

获取校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 路径解析根节点。 |

返回：兼容 GFValidationReportDictionary 的报告字典。

结构：

- `return`: GFValidationReportDictionary 兼容 Dictionary，包含 subject、bridge_id、issues、counts、summary 和 next_action。

<a id="member-gfsignalbridge-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为调试字典。

返回：桥接快照。

结构：

- `return`: Dictionary，包含 bridge_id、enabled、source、target、argument_indices、constant_args、append_context、one_shot 和 metadata。
