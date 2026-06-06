# GFPathTools

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_path_tools.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

GF 内部和项目工具可复用的路径规范化辅助。 只处理字符串层面的路径斜杠、简化、根目录裁剪、相对路径和排除匹配； 不访问文件系统、不加载资源，也不解释资源业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`normalize_path`](#member-gfpathtools-methods-normalize_path) | `static func normalize_path(path: String, fallback: String = "", simplify: bool = true) -> String:` |
| 方法 | [`normalize_resource_path`](#member-gfpathtools-methods-normalize_resource_path) | `static func normalize_resource_path(path: String, fallback: String = "", simplify: bool = true) -> String:` |
| 方法 | [`normalize_root_path`](#member-gfpathtools-methods-normalize_root_path) | `static func normalize_root_path(path: String, fallback: String = "", simplify: bool = true) -> String:` |
| 方法 | [`normalize_root_paths`](#member-gfpathtools-methods-normalize_root_paths) | `static func normalize_root_paths(paths: PackedStringArray, simplify: bool = true) -> PackedStringArray:` |
| 方法 | [`make_relative_path`](#member-gfpathtools-methods-make_relative_path) | `static func make_relative_path(path: String, base_path: String) -> String:` |
| 方法 | [`is_path_under_root`](#member-gfpathtools-methods-is_path_under_root) | `static func is_path_under_root( path: String, root_path: String, allow_equal: bool = true, empty_root_matches: bool = false ) -> bool:` |
| 方法 | [`is_path_excluded`](#member-gfpathtools-methods-is_path_excluded) | `static func is_path_excluded(path: String, excluded_paths: PackedStringArray) -> bool:` |

## 方法

<a id="member-gfpathtools-methods-normalize_path"></a>

### `normalize_path`

- API：`public`

```gdscript
static func normalize_path(path: String, fallback: String = "", simplify: bool = true) -> String:
```

规范化普通路径文本。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径。 |
| `fallback` | 输入为空时返回的兜底路径。 |
| `simplify` | 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。 |

返回：规范化后的路径。

<a id="member-gfpathtools-methods-normalize_resource_path"></a>

### `normalize_resource_path`

- API：`public`

```gdscript
static func normalize_resource_path(path: String, fallback: String = "", simplify: bool = true) -> String:
```

规范化 Godot 资源路径文本。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径，通常是 `res://`、`user://`、`uid://` 或相对路径。 |
| `fallback` | 输入为空时返回的兜底路径。 |
| `simplify` | 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。 |

返回：规范化后的资源路径文本。

<a id="member-gfpathtools-methods-normalize_root_path"></a>

### `normalize_root_path`

- API：`public`

```gdscript
static func normalize_root_path(path: String, fallback: String = "", simplify: bool = true) -> String:
```

规范化根目录路径，并移除多余尾随斜杠。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入根目录。 |
| `fallback` | 输入为空时返回的兜底路径。 |
| `simplify` | 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。 |

返回：规范化后的根目录路径。

<a id="member-gfpathtools-methods-normalize_root_paths"></a>

### `normalize_root_paths`

- API：`public`

```gdscript
static func normalize_root_paths(paths: PackedStringArray, simplify: bool = true) -> PackedStringArray:
```

规范化根目录路径集合，并按首次出现顺序去除空路径和重复项。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 输入根目录路径集合。 |
| `simplify` | 是否调用 Godot simplify_path() 折叠 `.` 和 `..`。 |

返回：规范化并去重后的根目录路径集合。

<a id="member-gfpathtools-methods-make_relative_path"></a>

### `make_relative_path`

- API：`public`

```gdscript
static func make_relative_path(path: String, base_path: String) -> String:
```

从 base_path 推导 path 的相对路径。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径。 |
| `base_path` | 基准目录。 |

返回：path 位于 base_path 下时返回相对路径，否则返回规范化后的 path。

<a id="member-gfpathtools-methods-is_path_under_root"></a>

### `is_path_under_root`

- API：`public`

```gdscript
static func is_path_under_root( path: String, root_path: String, allow_equal: bool = true, empty_root_matches: bool = false ) -> bool:
```

判断 path 是否位于 root_path 内。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径。 |
| `root_path` | 允许的根目录。 |
| `allow_equal` | 为 true 时 path 等于 root_path 也视为命中。 |
| `empty_root_matches` | 为 true 时空 root_path 视为允许所有路径。 |

返回：位于根目录内时返回 true。

<a id="member-gfpathtools-methods-is_path_excluded"></a>

### `is_path_excluded`

- API：`public`

```gdscript
static func is_path_excluded(path: String, excluded_paths: PackedStringArray) -> bool:
```

判断 path 是否被排除路径集合命中。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径。 |
| `excluded_paths` | 排除路径集合；命中目录自身或其子路径都返回 true。 |

返回：被排除时返回 true。
