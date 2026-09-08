# GFSceneGroupIndex

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/scene_groups/gf_scene_group_index.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

编辑器期已保存场景 Group 声明位置索引。 只读取磁盘 .tscn / .scn 自身 SceneState 中的持久化声明，不实例化场景节点， 不把继承或嵌套来源已有的组复制到引用场景。隐藏条目与 .gdignore 子树不在扫描范围内。 主线程 advance() 在目录项、节点和组之间让出控制；单次 ResourceLoader.load() 不能被抢占。引擎资源加载器和自定义 Resource 的加载行为仍由 Godot 管理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`begin_scan`](#member-gfscenegroupindex-methods-begin_scan) | `func begin_scan(root_path: String = "res://", options: Dictionary = {}) -> Error:` |
| 方法 | [`advance`](#member-gfscenegroupindex-methods-advance) | `func advance(entry_budget: int = 64) -> bool:` |
| 方法 | [`cancel`](#member-gfscenegroupindex-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`get_snapshot`](#member-gfscenegroupindex-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |
| 方法 | [`query`](#member-gfscenegroupindex-methods-query) | `func query(text: String = "", offset: int = 0, limit: int = 100) -> Dictionary:` |

## 方法

<a id="member-gfscenegroupindex-methods-begin_scan"></a>

### `begin_scan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_scan(root_path: String = "res://", options: Dictionary = {}) -> Error:
```

丢弃旧索引并开始扫描项目内目录。未知选项、非法类型或越界值会拒绝请求。 目录打不开时返回 ERR_CANT_OPEN；路径链含链接时拒绝读取。根目录有 .gdignore 时返回 OK 并以 partial / ignored_root 结束。扫描中的重入调用返回 ERR_BUSY。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | 规范 res:// 目录；不接受相对路径、反斜杠、空片段或点路径穿越。 |
| `options` | 只允许降低内置扫描上限。 |

返回：OK 表示请求有效；ERR_INVALID_PARAMETER、ERR_CANT_OPEN 或 ERR_BUSY 表示拒绝。

结构：

- `options`: Dictionary，键为 max_depth（int，0..32）、max_entries（int，1..100000）、max_scenes（int，1..10000）、max_rows（int，1..50000）、max_scene_bytes（int，1..8388608）。省略使用上限，0 深度仅扫描根目录。

<a id="member-gfscenegroupindex-methods-advance"></a>

### `advance`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func advance(entry_budget: int = 64) -> bool:
```

在主线程推进有界工作量。每个目录项、目录打开、场景加载、节点或组占一个单位。 单次引擎资源加载不受单位预算抢占；不启动后台任务。无效预算令当前扫描 failed。

参数：

| 名称 | 说明 |
|---|---|
| `entry_budget` | 本次最多处理的工作单位，范围 1..4096。 |

返回：返回 true 表示仍为 scanning，false 表示当前无需继续调用。

<a id="member-gfscenegroupindex-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> void:
```

取消当前扫描并立即关闭目录枚举，保留已发现记录供查看。 终态调用不改变结果；新的 begin_scan() 会清空旧记录。

<a id="member-gfscenegroupindex-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_snapshot() -> Dictionary:
```

返回摘要和最多 64 条诊断的副本，不包含整个索引。 complete 仅表示已完成本次范围的声明扫描；不是运行时成员、实例展开或同时刻的文件系统快照。

返回：当前扫描摘要。

结构：

- `return`: Dictionary，包含 status（idle/scanning/complete/partial/cancelled/failed）、root_path、entry_count（已枚举文件和目录数）、scene_count（尝试读取的场景数）、row_count、issues（Array[Dictionary]，每项 code/path/message）和 omitted_issue_count。

<a id="member-gfscenegroupindex-methods-query"></a>

### `query`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func query(text: String = "", offset: int = 0, limit: int = 100) -> Dictionary:
```

搜索组名、场景路径或节点路径。搜索忽略大小写，但保留不同组名的精确身份。 结果稳定按 group、scene_path、node_path 排序；返回行均为副本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 子字符串搜索文本；空文本匹配所有记录。 |
| `offset` | 起始记录偏移，负数按 0 处理。 |
| `limit` | 页大小，限制到 0..200；0 只计算总数。 |

返回：有界分页与匹配总数。

结构：

- `return`: Dictionary，包含 rows（Array[Dictionary]，每项 group:String、scene_path:String、node_path:String）、total:int、offset:int、limit:int。node_path 相对声明场景根，根节点为 .。
