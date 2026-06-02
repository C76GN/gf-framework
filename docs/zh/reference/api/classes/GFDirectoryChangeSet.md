# GFDirectoryChangeSet

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_directory_change_set.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.23.0`

目录扫描差异结果。 描述一次目录轮询发现的新增、修改和删除路径。它只表达文件系统变化， 不绑定导入、热更新或业务资源刷新策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`root_paths`](#member-gfdirectorychangeset-properties-root_paths) | `var root_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`created`](#member-gfdirectorychangeset-properties-created) | `var created: PackedStringArray = PackedStringArray()` |
| 属性 | [`modified`](#member-gfdirectorychangeset-properties-modified) | `var modified: PackedStringArray = PackedStringArray()` |
| 属性 | [`deleted`](#member-gfdirectorychangeset-properties-deleted) | `var deleted: PackedStringArray = PackedStringArray()` |
| 属性 | [`scanned_count`](#member-gfdirectorychangeset-properties-scanned_count) | `var scanned_count: int = 0` |
| 属性 | [`snapshot_size`](#member-gfdirectorychangeset-properties-snapshot_size) | `var snapshot_size: int = 0` |
| 属性 | [`truncated`](#member-gfdirectorychangeset-properties-truncated) | `var truncated: bool = false` |
| 属性 | [`timestamp_msec`](#member-gfdirectorychangeset-properties-timestamp_msec) | `var timestamp_msec: int = 0` |
| 方法 | [`configure`](#member-gfdirectorychangeset-methods-configure) | `func configure( p_root_paths: PackedStringArray, p_created: PackedStringArray, p_modified: PackedStringArray, p_deleted: PackedStringArray, p_scanned_count: int, p_snapshot_size: int, p_truncated: bool ) -> GFDirectoryChangeSet:` |
| 方法 | [`is_empty`](#member-gfdirectorychangeset-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_all_changed_paths`](#member-gfdirectorychangeset-methods-get_all_changed_paths) | `func get_all_changed_paths() -> PackedStringArray:` |
| 方法 | [`to_dict`](#member-gfdirectorychangeset-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_change_set`](#member-gfdirectorychangeset-methods-duplicate_change_set) | `func duplicate_change_set() -> GFDirectoryChangeSet:` |

## 属性

<a id="member-gfdirectorychangeset-properties-root_paths"></a>

### `root_paths`

- API：`public`

```gdscript
var root_paths: PackedStringArray = PackedStringArray()
```

本次扫描覆盖的根目录。

<a id="member-gfdirectorychangeset-properties-created"></a>

### `created`

- API：`public`

```gdscript
var created: PackedStringArray = PackedStringArray()
```

新增文件路径。

<a id="member-gfdirectorychangeset-properties-modified"></a>

### `modified`

- API：`public`

```gdscript
var modified: PackedStringArray = PackedStringArray()
```

修改文件路径。

<a id="member-gfdirectorychangeset-properties-deleted"></a>

### `deleted`

- API：`public`

```gdscript
var deleted: PackedStringArray = PackedStringArray()
```

删除文件路径。

<a id="member-gfdirectorychangeset-properties-scanned_count"></a>

### `scanned_count`

- API：`public`

```gdscript
var scanned_count: int = 0
```

本次扫描访问的文件数量。

<a id="member-gfdirectorychangeset-properties-snapshot_size"></a>

### `snapshot_size`

- API：`public`

```gdscript
var snapshot_size: int = 0
```

当前快照中的文件数量。

<a id="member-gfdirectorychangeset-properties-truncated"></a>

### `truncated`

- API：`public`

```gdscript
var truncated: bool = false
```

扫描是否因深度或数量限制被截断。

<a id="member-gfdirectorychangeset-properties-timestamp_msec"></a>

### `timestamp_msec`

- API：`public`

```gdscript
var timestamp_msec: int = 0
```

生成时间，单位为毫秒。

## 方法

<a id="member-gfdirectorychangeset-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_root_paths: PackedStringArray, p_created: PackedStringArray, p_modified: PackedStringArray, p_deleted: PackedStringArray, p_scanned_count: int, p_snapshot_size: int, p_truncated: bool ) -> GFDirectoryChangeSet:
```

配置变化集并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_root_paths` | 扫描根目录。 |
| `p_created` | 新增路径。 |
| `p_modified` | 修改路径。 |
| `p_deleted` | 删除路径。 |
| `p_scanned_count` | 扫描文件数量。 |
| `p_snapshot_size` | 当前快照文件数量。 |
| `p_truncated` | 是否被截断。 |

返回：当前变化集。

<a id="member-gfdirectorychangeset-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

判断本次扫描是否没有任何文件变化。

返回：没有新增、修改和删除路径时返回 true。

<a id="member-gfdirectorychangeset-methods-get_all_changed_paths"></a>

### `get_all_changed_paths`

- API：`public`

```gdscript
func get_all_changed_paths() -> PackedStringArray:
```

获取全部变化路径。

返回：去重并排序后的变化路径。

<a id="member-gfdirectorychangeset-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：变化集字典。

结构：

- `return`: Dictionary with root_paths, created, modified, deleted, counts, truncated, and timestamp_msec.

<a id="member-gfdirectorychangeset-methods-duplicate_change_set"></a>

### `duplicate_change_set`

- API：`public`

```gdscript
func duplicate_change_set() -> GFDirectoryChangeSet:
```

创建变化集副本。

返回：新变化集。
