# GFResourceSnapshotBroker

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_snapshot_broker.gd`
- 模块：`Standard`
- 继承：`GFResourceBroker`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

GFResourceSnapshotBroker：以预加载 Resource 映射提供独立实例的异步资源服务。 映射初始化后冻结；不调用全局 ResourceLoader，不修改或销毁资源内容。 Resource 自身由引用计数持有，项目仍须按自己的资源数据契约控制修改。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`configure`](#member-gfresourcesnapshotbroker-methods-configure) | `func configure(resources: Dictionary) -> Error:` |
| 方法 | [`is_configured`](#member-gfresourcesnapshotbroker-methods-is_configured) | `func is_configured() -> bool:` |
| 方法 | [`_request_threaded_resource`](#member-gfresourcesnapshotbroker-methods-_request_threaded_resource) | `func _request_threaded_resource(path: String, type_hint: String) -> Error:` |
| 方法 | [`_poll_threaded_resource`](#member-gfresourcesnapshotbroker-methods-_poll_threaded_resource) | `func _poll_threaded_resource(path: String, _previous_progress: float) -> Dictionary:` |

## 方法

<a id="member-gfresourcesnapshotbroker-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure(resources: Dictionary) -> Error:
```

冻结资源映射并初始化 Broker；失败不提交部分映射。 路径是逻辑资源路径，可以没有对应磁盘文件；不同代可映射到不同 Resource。

参数：

| 名称 | 说明 |
|---|---|
| `resources` | 1–4096 项逻辑路径与非空 Resource。 |

返回：已配置返回 ERR_ALREADY_IN_USE，无效输入返回 ERR_INVALID_PARAMETER。

结构：

- `resources`: Dictionary[String, Resource]，键须为可规范化的 res:// 或 uid:// 路径；规范化后不能重复。

<a id="member-gfresourcesnapshotbroker-methods-is_configured"></a>

### `is_configured`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_configured() -> bool:
```

获取实例是否拥有已冻结映射；服务域仍会核对具体实现身份。

返回：配置成功时为 true。

<a id="member-gfresourcesnapshotbroker-methods-_request_threaded_resource"></a>

### `_request_threaded_resource`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _request_threaded_resource(path: String, type_hint: String) -> Error:
```

对实例私有映射执行准入，不访问全局 path keyed threaded loader。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 规范化逻辑路径。 |
| `type_hint` | 可选原生类或全局脚本类型。 |

返回：缺失路径或类型不符时失败。

<a id="member-gfresourcesnapshotbroker-methods-_poll_threaded_resource"></a>

### `_poll_threaded_resource`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _poll_threaded_resource(path: String, _previous_progress: float) -> Dictionary:
```

最早在下一次 pump 交付；请求与结果只访问本代映射。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 已准入路径。 |
| `_previous_progress` | 此后端不需要中间进度。 |

返回：completed 适配器结果。

结构：

- `return`: Dictionary with status: StringName, progress: float, resource: Resource, has_resource: bool, error: String.
