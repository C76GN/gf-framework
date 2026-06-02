# GFUndoableCommand

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/command/gf_undoable_command.gd`
- 模块：`Standard`
- 继承：`GFCommand`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

可撤销命令的抽象基类。 继承自 GFCommand，在标准命令的基础上新增撤销能力。 子类须在 execute() 执行前通过 set_snapshot() 保存当前状态快照， 并在 undo() 中借助 get_snapshot() 取回快照以还原数据， 从而支持编辑器操作、运行时流程回放和项目自定义撤销功能。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action_name`](#member-gfundoablecommand-properties-action_name) | `var action_name: String = ""` |
| 方法 | [`execute`](#member-gfundoablecommand-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`undo`](#member-gfundoablecommand-methods-undo) | `func undo() -> Variant:` |
| 方法 | [`should_record`](#member-gfundoablecommand-methods-should_record) | `func should_record(_execute_result: Variant) -> bool:` |
| 方法 | [`set_snapshot`](#member-gfundoablecommand-methods-set_snapshot) | `func set_snapshot(data: Variant) -> void:` |
| 方法 | [`get_snapshot`](#member-gfundoablecommand-methods-get_snapshot) | `func get_snapshot() -> Variant:` |

## 属性

<a id="member-gfundoablecommand-properties-action_name"></a>

### `action_name`

- API：`public`

```gdscript
var action_name: String = ""
```

可选命令标签，供项目历史面板、日志或调试工具显示。默认为空，框架不生成用户可见文案。

## 方法

<a id="member-gfundoablecommand-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行命令逻辑。子类必须重写此方法，并建议在此处先调用 set_snapshot()。

返回：同步命令返回 null；异步命令可返回 Signal 供外部 await。

结构：

- `return`: Variant, null or Signal.

<a id="member-gfundoablecommand-methods-undo"></a>

### `undo`

- API：`public`

```gdscript
func undo() -> Variant:
```

撤销命令。子类必须重写此方法，使用 get_snapshot() 还原状态。

返回：同步命令返回 null；异步命令可返回 Signal 供外部 await。

结构：

- `return`: Variant, null or Signal.

<a id="member-gfundoablecommand-methods-should_record"></a>

### `should_record`

- API：`public`

```gdscript
func should_record(_execute_result: Variant) -> bool:
```

判断 execute() 返回后是否应该写入命令历史。

参数：

| 名称 | 说明 |
|---|---|
| `_execute_result` | execute() 的最终返回值。 |

返回：返回 false 时，GFCommandHistoryUtility 不会记录该命令。

结构：

- `_execute_result`: Variant returned by execute().

<a id="member-gfundoablecommand-methods-set_snapshot"></a>

### `set_snapshot`

- API：`public`

```gdscript
func set_snapshot(data: Variant) -> void:
```

保存执行前的状态快照。应在 execute() 内部、修改数据之前调用。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 任意可序列化的快照数据（如字典、数值、数组）。 |

结构：

- `data`: Variant snapshot value; Array and Dictionary values are deep-copied.

<a id="member-gfundoablecommand-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`

```gdscript
func get_snapshot() -> Variant:
```

获取由 set_snapshot() 保存的状态快照。在 undo() 中调用以还原数据。

返回：之前保存的快照数据，不存在则返回 null。

结构：

- `return`: Variant snapshot value or null.
