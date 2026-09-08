# GFSceneGroupDock

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/scene_groups/editor/gf_scene_group_dock.gd`
- 模块：`Tools`
- 继承：`VBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`unreleased`

编辑器期已保存场景 Group 声明查询页面。 用户主动刷新后分批读取磁盘场景，按组名、场景路径或节点路径搜索并定位声明节点。 只读查询不包含未保存编辑或运行时添加的组；定位通过编辑器打开源场景。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`refresh`](#member-gfscenegroupdock-methods-refresh) | `func refresh(root_path: String = "res://") -> Error:` |
| 方法 | [`cancel_scan`](#member-gfscenegroupdock-methods-cancel_scan) | `func cancel_scan() -> void:` |
| 方法 | [`get_snapshot`](#member-gfscenegroupdock-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfscenegroupdock-methods-refresh"></a>

### `refresh`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func refresh(root_path: String = "res://") -> Error:
```

清除旧结果并开始扫描指定项目目录；页面入树后按帧推进。 返回 ERR_BUSY 时保留当前扫描和页面状态，不产生刷新副作用。

参数：

| 名称 | 说明 |
|---|---|
| `root_path` | res:// 下的已保存场景搜索根目录。 |

返回：初始化扫描的 Error；无效输入会呈现 failed 状态。

<a id="member-gfscenegroupdock-methods-cancel_scan"></a>

### `cancel_scan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_scan() -> void:
```

取消当前扫描和待完成定位；保留已收集结果，并明确标记取消状态。

<a id="member-gfscenegroupdock-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_snapshot() -> Dictionary:
```

获取扫描摘要的防御性副本；结果行通过页面分页呈现。

返回：与 GFSceneGroupIndex.get_snapshot() 相同的摘要。

结构：

- `return`: Dictionary，status 为 idle/scanning/complete/partial/cancelled/failed；root_path 为 String；entry_count、scene_count、row_count、omitted_issue_count 为 int；issues 为 Array[Dictionary]，每项含 String 字段 code、path、message。
