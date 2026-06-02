# GFSourceBuilder

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_source_builder.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器代码生成用的轻量源码构建器。 用于集中处理生成脚本时的缩进、空行、section 与文档注释格式， 避免各个 generator 直接拼接 `PackedStringArray` 时出现格式漂移。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`line`](#member-gfsourcebuilder-methods-line) | `func line(text: String = "") -> void:` |
| 方法 | [`doc`](#member-gfsourcebuilder-methods-doc) | `func doc(text: String = "") -> void:` |
| 方法 | [`section`](#member-gfsourcebuilder-methods-section) | `func section(title: String) -> void:` |
| 方法 | [`blank`](#member-gfsourcebuilder-methods-blank) | `func blank(count: int = 1) -> void:` |
| 方法 | [`indent`](#member-gfsourcebuilder-methods-indent) | `func indent() -> void:` |
| 方法 | [`dedent`](#member-gfsourcebuilder-methods-dedent) | `func dedent(count: int = 1) -> void:` |
| 方法 | [`clear`](#member-gfsourcebuilder-methods-clear) | `func clear() -> void:` |
| 方法 | [`build`](#member-gfsourcebuilder-methods-build) | `func build() -> String:` |

## 方法

<a id="member-gfsourcebuilder-methods-line"></a>

### `line`

- API：`public`

```gdscript
func line(text: String = "") -> void:
```

添加一行源码。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 行内容；空字符串会生成空行且不添加缩进。 |

<a id="member-gfsourcebuilder-methods-doc"></a>

### `doc`

- API：`public`

```gdscript
func doc(text: String = "") -> void:
```

添加文档注释行。

参数：

| 名称 | 说明 |
|---|---|
| `text` | 注释内容；空字符串会生成 `##`。 |

<a id="member-gfsourcebuilder-methods-section"></a>

### `section`

- API：`public`

```gdscript
func section(title: String) -> void:
```

添加规范 section 标题，并在其后添加一个空行。

参数：

| 名称 | 说明 |
|---|---|
| `title` | section 标题。 |

<a id="member-gfsourcebuilder-methods-blank"></a>

### `blank`

- API：`public`

```gdscript
func blank(count: int = 1) -> void:
```

添加空行。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 空行数量，小于等于 0 时不产生输出。 |

<a id="member-gfsourcebuilder-methods-indent"></a>

### `indent`

- API：`public`

```gdscript
func indent() -> void:
```

增加后续行的缩进层级。

<a id="member-gfsourcebuilder-methods-dedent"></a>

### `dedent`

- API：`public`

```gdscript
func dedent(count: int = 1) -> void:
```

减少后续行的缩进层级。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 要减少的层级数，小于等于 0 时不改变缩进。 |

<a id="member-gfsourcebuilder-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空已构建内容并重置缩进。

<a id="member-gfsourcebuilder-methods-build"></a>

### `build`

- API：`public`

```gdscript
func build() -> String:
```

生成最终源码字符串；非空源码末尾会包含换行。

返回：完整源码文本。
