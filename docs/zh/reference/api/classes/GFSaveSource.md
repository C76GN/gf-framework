# GFSaveSource

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/core/gf_save_source.gd`
- 模块：`Save`
- 继承：`Node`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存档图数据源节点。 Source 是存档图的最小数据入口。项目可继承并重写 gather/apply， 也可配置节点序列化器保存通用节点属性。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source_key`](#member-gfsavesource-properties-source_key) | `var source_key: StringName = &""` |
| 属性 | [`target_node_path`](#member-gfsavesource-properties-target_node_path) | `var target_node_path: NodePath` |
| 属性 | [`enabled`](#member-gfsavesource-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`save_enabled`](#member-gfsavesource-properties-save_enabled) | `var save_enabled: bool = true` |
| 属性 | [`load_enabled`](#member-gfsavesource-properties-load_enabled) | `var load_enabled: bool = true` |
| 属性 | [`phase`](#member-gfsavesource-properties-phase) | `var phase: int = GFSaveScope.Phase.NORMAL` |
| 属性 | [`serializers`](#member-gfsavesource-properties-serializers) | `var serializers: Array[GFNodeSerializer] = []` |
| 属性 | [`use_registry_serializers`](#member-gfsavesource-properties-use_registry_serializers) | `var use_registry_serializers: bool = false` |
| 属性 | [`descriptor_extra`](#member-gfsavesource-properties-descriptor_extra) | `var descriptor_extra: Dictionary = {}` |
| 方法 | [`get_source_key`](#member-gfsavesource-methods-get_source_key) | `func get_source_key() -> StringName:` |
| 方法 | [`get_target_node`](#member-gfsavesource-methods-get_target_node) | `func get_target_node() -> Node:` |
| 方法 | [`describe_source`](#member-gfsavesource-methods-describe_source) | `func describe_source(scope: Node = null) -> Dictionary:` |
| 方法 | [`make_result`](#member-gfsavesource-methods-make_result) | `func make_result(ok: bool, error: String = "") -> Dictionary:` |

## 属性

<a id="member-gfsavesource-properties-source_key"></a>

### `source_key`

- API：`public`

```gdscript
var source_key: StringName = &""
```

Source 稳定标识。留空时回退到节点名。

<a id="member-gfsavesource-properties-target_node_path"></a>

### `target_node_path`

- API：`public`

```gdscript
var target_node_path: NodePath
```

目标节点路径。留空时默认序列化父节点。

<a id="member-gfsavesource-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该 Source。

<a id="member-gfsavesource-properties-save_enabled"></a>

### `save_enabled`

- API：`public`

```gdscript
var save_enabled: bool = true
```

是否参与保存。

<a id="member-gfsavesource-properties-load_enabled"></a>

### `load_enabled`

- API：`public`

```gdscript
var load_enabled: bool = true
```

是否参与加载。

<a id="member-gfsavesource-properties-phase"></a>

### `phase`

- API：`public`

```gdscript
var phase: int = GFSaveScope.Phase.NORMAL
```

执行阶段。数值越小越早执行。

<a id="member-gfsavesource-properties-serializers"></a>

### `serializers`

- API：`public`

```gdscript
var serializers: Array[GFNodeSerializer] = []
```

Source 局部序列化器。为空时可使用注册表中的默认序列化器。

<a id="member-gfsavesource-properties-use_registry_serializers"></a>

### `use_registry_serializers`

- API：`public`

```gdscript
var use_registry_serializers: bool = false
```

是否在未配置局部序列化器时使用注册表默认序列化器。

<a id="member-gfsavesource-properties-descriptor_extra"></a>

### `descriptor_extra`

- API：`public`

```gdscript
var descriptor_extra: Dictionary = {}
```

附加描述字段。

结构：

- `descriptor_extra`: Dictionary，会合并进 describe_source() 返回值的项目自定义描述字段。

## 方法

<a id="member-gfsavesource-methods-get_source_key"></a>

### `get_source_key`

- API：`public`

```gdscript
func get_source_key() -> StringName:
```

获取 Source 稳定标识。

返回：来源键。

<a id="member-gfsavesource-methods-get_target_node"></a>

### `get_target_node`

- API：`public`

```gdscript
func get_target_node() -> Node:
```

获取目标节点。

返回：目标节点；不存在时返回 null。

<a id="member-gfsavesource-methods-describe_source"></a>

### `describe_source`

- API：`public`

```gdscript
func describe_source(scope: Node = null) -> Dictionary:
```

构造 Source 描述。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前 Scope。 |

返回：描述字典。

结构：

- `return`: Dictionary，包含 descriptor_extra、source_key、phase，并在可用时包含 node_path。

<a id="member-gfsavesource-methods-make_result"></a>

### `make_result`

- API：`public`

```gdscript
func make_result(ok: bool, error: String = "") -> Dictionary:
```

构造统一结果。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 是否成功。 |
| `error` | 错误描述。 |

返回：结果字典。

结构：

- `return`: Dictionary，包含 ok: bool 与 error: String。
