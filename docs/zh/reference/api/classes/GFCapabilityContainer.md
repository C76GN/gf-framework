# GFCapabilityContainer

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/nodes/gf_capability_container.gd`
- 模块：`Capability`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

场景树中的能力组件容器。 将该节点作为某个 Node 的子节点后，容器内带脚本的子节点会被注册为父节点的能力。 需要在当前架构中注册 GFCapabilityUtility。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`auto_register_children`](#member-gfcapabilitycontainer-properties-auto_register_children) | `var auto_register_children: bool = true` |
| 属性 | [`watch_child_changes`](#member-gfcapabilitycontainer-properties-watch_child_changes) | `var watch_child_changes: bool = true` |
| 方法 | [`get_receiver`](#member-gfcapabilitycontainer-methods-get_receiver) | `func get_receiver() -> Node:` |
| 方法 | [`register_children_now`](#member-gfcapabilitycontainer-methods-register_children_now) | `func register_children_now() -> void:` |

## 属性

<a id="member-gfcapabilitycontainer-properties-auto_register_children"></a>

### `auto_register_children`

- API：`public`

```gdscript
var auto_register_children: bool = true
```

是否在进入场景树后自动注册已有子节点。

<a id="member-gfcapabilitycontainer-properties-watch_child_changes"></a>

### `watch_child_changes`

- API：`public`

```gdscript
var watch_child_changes: bool = true
```

是否在子节点顺序变化时自动注册新增子节点。

## 方法

<a id="member-gfcapabilitycontainer-methods-get_receiver"></a>

### `get_receiver`

- API：`public`

```gdscript
func get_receiver() -> Node:
```

获取容器服务的能力接收者。

返回：容器的父节点；容器尚未挂载时返回 null。

<a id="member-gfcapabilitycontainer-methods-register_children_now"></a>

### `register_children_now`

- API：`public`

```gdscript
func register_children_now() -> void:
```

立即扫描并注册容器中的子节点能力。
