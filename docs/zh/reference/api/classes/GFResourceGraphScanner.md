# GFResourceGraphScanner

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_graph_scanner.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

通用 Object / Resource 图扫描器。 递归读取 Resource、Object、Array 和 Dictionary 的属性图，生成可用于诊断、编辑器工具和测试的结构化报告。 它只描述图形状，不修改对象、不注入编辑器 UI，也不解释资源业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_DEPTH`](#member-gfresourcegraphscanner-constants-default_max_depth) | `const DEFAULT_MAX_DEPTH: int = 32` |
| 常量 | [`DEFAULT_MAX_NODES`](#member-gfresourcegraphscanner-constants-default_max_nodes) | `const DEFAULT_MAX_NODES: int = 10000` |
| 方法 | [`scan`](#member-gfresourcegraphscanner-methods-scan) | `static func scan(root: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_paths`](#member-gfresourcegraphscanner-methods-collect_paths) | `static func collect_paths(root: Variant, options: Dictionary = {}) -> PackedStringArray:` |

## 常量

<a id="member-gfresourcegraphscanner-constants-default_max_depth"></a>

### `DEFAULT_MAX_DEPTH`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MAX_DEPTH: int = 32
```

默认递归深度上限。

<a id="member-gfresourcegraphscanner-constants-default_max_nodes"></a>

### `DEFAULT_MAX_NODES`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MAX_NODES: int = 10000
```

默认节点数量上限。

## 方法

<a id="member-gfresourcegraphscanner-methods-scan"></a>

### `scan`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func scan(root: Variant, options: Dictionary = {}) -> Dictionary:
```

扫描一个 Variant 图并返回结构化报告。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 扫描根对象，可为 Resource、Object、Array、Dictionary 或标量。 |
| `options` | 扫描选项。 |

返回：资源图报告。

结构：

- `root`: Variant graph root.
- `options`: Dictionary，可包含 max_depth、max_nodes、include_nodes、include_scalar、include_null、include_all_properties、excluded_properties。
- `return`: Dictionary with ok, nodes, node_count, cycle_count, truncated, depth_limit_reached, and root_type.

<a id="member-gfresourcegraphscanner-methods-collect_paths"></a>

### `collect_paths`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func collect_paths(root: Variant, options: Dictionary = {}) -> PackedStringArray:
```

只返回扫描到的路径列表。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 扫描根对象。 |
| `options` | 扫描选项，见 scan()。 |

返回：排序后的路径列表。

结构：

- `root`: Variant graph root.
- `options`: Dictionary，可包含 max_depth、max_nodes、include_nodes、include_scalar、include_null、include_all_properties、excluded_properties。
