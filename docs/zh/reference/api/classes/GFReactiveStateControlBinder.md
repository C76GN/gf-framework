# GFReactiveStateControlBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_reactive_state_control_binder.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`5.0.0`

GFReactiveStateStore 与 Control 值的双向绑定器。 只负责把 store path 映射到 Godot Control 值，复用 `GFControlValueAdapter` 的控件读写和信号连接能力。状态归属仍由 `GFReactiveStateStore` 负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`bind_control`](#member-gfreactivestatecontrolbinder-methods-bind_control) | `func bind_control( store: RefCounted, path: Variant, control: Control, options: Dictionary = {} ) -> bool:` |
| 方法 | [`unbind_control`](#member-gfreactivestatecontrolbinder-methods-unbind_control) | `func unbind_control(control: Control) -> bool:` |
| 方法 | [`unbind_path`](#member-gfreactivestatecontrolbinder-methods-unbind_path) | `func unbind_path(store: RefCounted, path: Variant) -> int:` |
| 方法 | [`clear`](#member-gfreactivestatecontrolbinder-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_binding_count`](#member-gfreactivestatecontrolbinder-methods-get_binding_count) | `func get_binding_count() -> int:` |
| 方法 | [`dispose`](#member-gfreactivestatecontrolbinder-methods-dispose) | `func dispose() -> void:` |

## 方法

<a id="member-gfreactivestatecontrolbinder-methods-bind_control"></a>

### `bind_control`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func bind_control( store: RefCounted, path: Variant, control: Control, options: Dictionary = {} ) -> bool:
```

绑定一个 Control 到 store 路径。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径。 |
| `control` | 控件节点。 |
| `options` | 可选项。支持 default_value、sync_initial、write_initial_to_store。 |

返回：成功绑定时返回 true。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。
- `options`: Dictionary，default_value 为控件或状态缺省值；sync_initial 默认为 true；write_initial_to_store 为 true 时用控件当前值初始化 store。

<a id="member-gfreactivestatecontrolbinder-methods-unbind_control"></a>

### `unbind_control`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unbind_control(control: Control) -> bool:
```

解绑指定 Control。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 控件节点。 |

返回：找到并解绑时返回 true。

<a id="member-gfreactivestatecontrolbinder-methods-unbind_path"></a>

### `unbind_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unbind_path(store: RefCounted, path: Variant) -> int:
```

解绑指定 store 路径上的所有 Control。

参数：

| 名称 | 说明 |
|---|---|
| `store` | \`GFReactiveStateStore\` 实例。 |
| `path` | 状态路径。 |

返回：解绑数量。

结构：

- `store`: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
- `path`: Variant，路径表达。

<a id="member-gfreactivestatecontrolbinder-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func clear() -> void:
```

清理所有绑定。

<a id="member-gfreactivestatecontrolbinder-methods-get_binding_count"></a>

### `get_binding_count`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_binding_count() -> int:
```

获取当前有效绑定数量。

返回：有效绑定数量。

<a id="member-gfreactivestatecontrolbinder-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func dispose() -> void:
```

释放所有绑定。
