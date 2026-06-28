# GFDependencyGraphTools

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_dependency_graph_tools.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

字符串 ID 依赖图排序与循环诊断。 面向扩展 manifest、内容包、资源包等“稳定 ID -> 依赖 ID 列表”的轻量依赖图。 它只负责依赖优先排序、缺失依赖记录和循环检测，不解释节点业务类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`sort_dependency_first`](#member-gfdependencygraphtools-methods-sort_dependency_first) | `static func sort_dependency_first(node_ids: PackedStringArray, dependency_map: Dictionary) -> Dictionary:` |

## 方法

<a id="member-gfdependencygraphtools-methods-sort_dependency_first"></a>

### `sort_dependency_first`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func sort_dependency_first(node_ids: PackedStringArray, dependency_map: Dictionary) -> Dictionary:
```

按依赖优先顺序排序节点。

参数：

| 名称 | 说明 |
|---|---|
| `node_ids` | 需要排序的根节点 ID。 |
| `dependency_map` | 依赖表，key 为节点 ID，value 为该节点依赖的 ID 列表。 |

返回：诊断字典，包含 ok、ordered_ids、missing_dependencies、dependency_cycles 和计数字段。

结构：

- `dependency_map`: Dictionary keyed by String or StringName node id, with Array or PackedStringArray dependency id values.
- `return`: Dictionary with ok, ordered_ids, missing_root_ids, missing_dependencies, dependency_cycles, node_count, missing_root_count, missing_dependency_count, and cycle_count.
