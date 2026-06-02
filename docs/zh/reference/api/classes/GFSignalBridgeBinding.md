# GFSignalBridgeBinding

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/bridge/gf_signal_bridge_binding.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

运行中的信号桥接连接。 Binding 持有桥接资源、根节点和底层 GFSignalConnection，用于在运行时断开、 检查状态，并把原生信号参数转交给桥接规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`bridge`](#member-gfsignalbridgebinding-properties-bridge) | `var bridge: GFSignalBridge = null` |
| 属性 | [`connection`](#member-gfsignalbridgebinding-properties-connection) | `var connection: GFSignalConnection = null` |
| 方法 | [`setup`](#member-gfsignalbridgebinding-methods-setup) | `func setup(new_bridge: GFSignalBridge, root: Node, new_connection: GFSignalConnection) -> void:` |
| 方法 | [`disconnect_bridge`](#member-gfsignalbridgebinding-methods-disconnect_bridge) | `func disconnect_bridge() -> void:` |
| 方法 | [`is_active`](#member-gfsignalbridgebinding-methods-is_active) | `func is_active() -> bool:` |

## 属性

<a id="member-gfsignalbridgebinding-properties-bridge"></a>

### `bridge`

- API：`public`

```gdscript
var bridge: GFSignalBridge = null
```

桥接资源。

<a id="member-gfsignalbridgebinding-properties-connection"></a>

### `connection`

- API：`public`

```gdscript
var connection: GFSignalConnection = null
```

底层信号连接。

## 方法

<a id="member-gfsignalbridgebinding-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup(new_bridge: GFSignalBridge, root: Node, new_connection: GFSignalConnection) -> void:
```

初始化绑定。

参数：

| 名称 | 说明 |
|---|---|
| `new_bridge` | 桥接资源。 |
| `root` | 路径解析根节点。 |
| `new_connection` | 底层连接。 |

<a id="member-gfsignalbridgebinding-methods-disconnect_bridge"></a>

### `disconnect_bridge`

- API：`public`

```gdscript
func disconnect_bridge() -> void:
```

断开桥接。

<a id="member-gfsignalbridgebinding-methods-is_active"></a>

### `is_active`

- API：`public`

```gdscript
func is_active() -> bool:
```

当前绑定是否仍活跃。

返回：活跃时返回 true。
