# GFNodeStateMachineDock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

节点状态机结构检查工作区页面。 面向编辑器展示当前场景中的 GFNodeStateMachine，复用标准校验器输出结构问题， 不推断项目自己的状态转移、输入或动画语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_state_machine_source`](#member-gfnodestatemachinedock-methods-set_state_machine_source) | `func set_state_machine_source(root: Node) -> void:` |
| 方法 | [`refresh`](#member-gfnodestatemachinedock-methods-refresh) | `func refresh(root: Node = null) -> void:` |
| 方法 | [`get_last_report`](#member-gfnodestatemachinedock-methods-get_last_report) | `func get_last_report() -> Dictionary:` |
| 方法 | [`get_machine_count`](#member-gfnodestatemachinedock-methods-get_machine_count) | `func get_machine_count() -> int:` |

## 方法

<a id="member-gfnodestatemachinedock-methods-set_state_machine_source"></a>

### `set_state_machine_source`

- API：`public`

```gdscript
func set_state_machine_source(root: Node) -> void:
```

设置要扫描的场景根节点。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 场景根节点；为空时刷新会尝试使用当前编辑场景或运行时场景。 |

<a id="member-gfnodestatemachinedock-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh(root: Node = null) -> void:
```

刷新状态机列表与当前校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 可选场景根节点；为空时使用 set_state_machine_source() 或当前场景。 |

<a id="member-gfnodestatemachinedock-methods-get_last_report"></a>

### `get_last_report`

- API：`public`

```gdscript
func get_last_report() -> Dictionary:
```

获取最近一次校验报告字典。

返回：报告字典副本。

结构：

- `return`: 校验报告 Dictionary，包含 ok、summary、next_action、issues、error_count、warning_count 等字段。

<a id="member-gfnodestatemachinedock-methods-get_machine_count"></a>

### `get_machine_count`

- API：`public`

```gdscript
func get_machine_count() -> int:
```

获取最近一次扫描到的状态机数量。

返回：状态机数量。
