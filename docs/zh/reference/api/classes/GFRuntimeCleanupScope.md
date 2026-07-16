# GFRuntimeCleanupScope

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_runtime_cleanup_scope.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用运行时清理回调作用域。 用于让上层系统按 scope 注册清理回调，并在重启、切换场景或释放运行态时 按优先级执行。该类型只管理清理回调的所有权与顺序，不认识具体业务系统。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_cleanup`](#member-gfruntimecleanupscope-methods-register_cleanup) | `func register_cleanup( scope_id: StringName, cleanup_id: StringName, callback: Callable, priority: int = 0, metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`unregister_cleanup`](#member-gfruntimecleanupscope-methods-unregister_cleanup) | `func unregister_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:` |
| 方法 | [`run_scope`](#member-gfruntimecleanupscope-methods-run_scope) | `func run_scope(scope_id: StringName) -> Dictionary:` |
| 方法 | [`clear_scope`](#member-gfruntimecleanupscope-methods-clear_scope) | `func clear_scope(scope_id: StringName) -> void:` |
| 方法 | [`clear_all`](#member-gfruntimecleanupscope-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`has_cleanup`](#member-gfruntimecleanupscope-methods-has_cleanup) | `func has_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:` |
| 方法 | [`get_cleanup_ids`](#member-gfruntimecleanupscope-methods-get_cleanup_ids) | `func get_cleanup_ids(scope_id: StringName) -> PackedStringArray:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimecleanupscope-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfruntimecleanupscope-methods-register_cleanup"></a>

### `register_cleanup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_cleanup( scope_id: StringName, cleanup_id: StringName, callback: Callable, priority: int = 0, metadata: Dictionary = {} ) -> bool:
```

注册清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |
| `cleanup_id` | 清理项 ID，同一 scope 内唯一。 |
| `callback` | 无参数清理回调。 |
| `priority` | 执行优先级，数值越大越先执行。 |
| `metadata` | 调用方自定义元数据。 |

返回：注册成功返回 true。

结构：

- `metadata`: Dictionary project-defined cleanup metadata copied into diagnostics.

<a id="member-gfruntimecleanupscope-methods-unregister_cleanup"></a>

### `unregister_cleanup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:
```

注销清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |
| `cleanup_id` | 清理项 ID。 |

返回：成功移除返回 true。

<a id="member-gfruntimecleanupscope-methods-run_scope"></a>

### `run_scope`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func run_scope(scope_id: StringName) -> Dictionary:
```

执行指定 scope 的清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |

返回：清理执行报告。

结构：

- `return`: Dictionary with ok, scope_id, executed_count, skipped_count, cleanup_ids, and issues.

<a id="member-gfruntimecleanupscope-methods-clear_scope"></a>

### `clear_scope`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_scope(scope_id: StringName) -> void:
```

清空指定 scope 的所有清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |

<a id="member-gfruntimecleanupscope-methods-clear_all"></a>

### `clear_all`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_all() -> void:
```

清空全部清理作用域。

<a id="member-gfruntimecleanupscope-methods-has_cleanup"></a>

### `has_cleanup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_cleanup(scope_id: StringName, cleanup_id: StringName) -> bool:
```

检查清理回调是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |
| `cleanup_id` | 清理项 ID。 |

返回：存在返回 true。

<a id="member-gfruntimecleanupscope-methods-get_cleanup_ids"></a>

### `get_cleanup_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cleanup_ids(scope_id: StringName) -> PackedStringArray:
```

获取指定 scope 的清理项 ID。

参数：

| 名称 | 说明 |
|---|---|
| `scope_id` | 清理作用域 ID。 |

返回：排序后的清理项 ID。

<a id="member-gfruntimecleanupscope-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：作用域调试快照。

结构：

- `return`: Dictionary with scope_count, cleanup_count, and scopes.
