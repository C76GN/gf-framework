# GF 源码文档注释规范

本规范适用于 GF 手写的 GDScript（含脚本模板）、Rust 和 Python。调用者在 Godot 编辑器、rustdoc 或 Python 的 `help()` 中查看一个符号时，应当能读到它的使用契约。把这份说明写在声明处，修改行为时同步更新。三种语言的源文件均使用 UTF-8，文档注释和实现注释都可以写中文。[仓库编码设置](../../.editorconfig)

## 先写调用者需要知道的事

- **首句概括行为。** 让读者仅看悬停提示的第一行，就知道这个函数返回什么或改变什么。类和模块的首句说明它负责什么。
- **再写会影响调用方式的条件。** 例如，时间用毫秒还是微秒、索引从哪里开始、空输入返回什么、失败前是否已写入、结果由谁持有、允许在哪个线程调用。只记录接口实际提供的保证。简单接口在满足该语言必需标签后，一句话就足够。
- **示例展示容易用错的地方。** 选择一个短小、确定的调用，让预期结果直接可见。测试里的普通注释可解释数据为何这样排列，例如同样六个慢帧，连续出现和分散出现应有不同的窗口统计。
- **实现原因留给维护者。** 把生命周期、取舍和变通原因写在依赖它的代码旁。需要长期保留的变通先说明触发条件和移除条件，按需附上游问题。修改历史留给 Git。

## 正文用什么语言

| 谁会读到 | GF 的默认做法 |
| --- | --- |
| 使用 GF 的 Godot 开发者 | GDScript 声明文档优先用中文，与中文手册一致。字段名、类型名和枚举值保留代码原文。 |
| 使用 Rust 或 Python 工具的国际读者 | 面向这类读者的 rustdoc、Python 公共 API 文档字符串和命令行帮助默认用英文。已有本地化入口沿用该入口的语言。 |
| 维护实现或测试的开发者 | 内部接口文档、实现原因和测试说明优先用中文。提到代码标识符、协议字段或上游错误文本时保留原文，便于检索。 |

一段说明选一种主语言。参数名、`SAFETY:`、`Args:` 等可搜索或可解析的标记保留原拼写，标记后可写中文。PEP 8 建议有国际读者的代码使用英文注释。GF 运行时开发者错误与警告另有稳定 ID 和 ASCII 英文模板约定。[PEP 8 注释约定](https://peps.python.org/pep-0008/#comments) · [GF 编码规范 § 5.8 开发者诊断与显示语言](../../CODING_STYLE.md)

## GDScript 用 Godot 文档注释

用 `##` 紧贴成员声明或其注解，首行写给使用者。GF 的 API 工具读取 `@api`、`@since`、`@param`、`@return` 等项目标签。正文与标签之间、相邻标签之间各用一行 `## [br]`，让 Godot 悬停文档保留换行。[Godot 文档注释](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_documentation_comments.html) · [GF API 契约](../../API_SURFACE.md)

以 `GFGridCoordinateMath2D.cell_to_index()` 为例。调用者需要知道坐标按行展开，以及由谁校验它是否越界。公开函数按签名顺序写全参数，为非 `void` 返回值说明其含义。遇到公开的裸 `Dictionary`、`Array`、`Variant` 等结构，再按 API 契约用 `@schema` 说明字段。[对应源码](../../addons/gf/standard/foundation/math/gf_grid_coordinate_math_2d.gd)

```gdscript
## 按行将二维格坐标转换为从 0 开始的一维索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cell: 从 0 开始的格坐标。调用者负责确认它位于网格内。
## [br]
## @param width: 每行的格子数。
## [br]
## @return: 宽度大于 0 时返回 cell.y * width + cell.x，宽度无效时返回 -1。
static func cell_to_index(cell: Vector2i, width: int) -> int:
	if width <= 0:
		return -1

	return cell.y * width + cell.x
```

`addons/gf` 下 `.gd` 和 `.gd.txt` 的私有成员也用 `##`，至少写明职责和 `@api private`。私有参数只在需要补充语义时写。函数内部的局部原因用 `# `。[私有声明编写指南](private-doc-comments.md)

## Rust 用 rustdoc

用 `//!` 介绍所在模块或 crate，用 `///` 记录函数、类型等条目。第一段概括行为，空一行后按需展开。参数用反引号按名称引用。返回 `Result` 的公开函数在 `# Errors` 中写明触发 `Err` 的条件，存在调用者可触发的 panic 时写 `# Panics`。调用方式值得示范时写 `# Examples`，优先给出可以通过 `cargo test --doc` 运行的例子。[Rustdoc 编写指南](https://doc.rust-lang.org/rustdoc/how-to-write-documentation.html) · [Rust API 文档指南](https://rust-lang.github.io/api-guidelines/documentation.html#c-failure) · [Rustdoc 文档测试](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html)

下面用独立示例 crate `packed_example` 演示怎样同时记录字节序、错误条件和两种输入的结果。

```rust
/// Decodes a signed 32-bit integer from four little-endian bytes.
///
/// # Errors
///
/// Returns an error if `bytes` contains fewer or more than four bytes.
///
/// # Examples
///
/// ```
/// use packed_example::read_i32_le;
///
/// assert!(matches!(read_i32_le(&[1, 2, 0, 0]), Ok(513)));
/// assert!(read_i32_le(&[1, 2]).is_err());
/// ```
pub fn read_i32_le(bytes: &[u8]) -> Result<i32, std::array::TryFromSliceError> {
    Ok(i32::from_le_bytes(bytes.try_into()?))
}
```

公开的 `unsafe fn` 在 `/// # Safety` 下列出**调用者必须满足的前提**。在 `unsafe` 块或 `unsafe impl` 前用 `// SAFETY:` 解释**此处凭什么满足前提**。例如，GF Native 在场景初始化回调中取得 Godot 接口表，可以指出该回调运行在哪个线程、此时哪项初始化已完成。普通实现原因用 `//`。[Rust 标准库安全注释规范](https://std-dev-guide.rust-lang.org/policy/safety-comments.html)

## Python 用 Google 风格 docstring

公开模块、类和函数的第一条语句使用三重双引号文档字符串，供 IDE 和 `help()` 读取。按 PEP 257 写一句独立摘要，多行说明在摘要后空一行。GF 选用 Google 风格组织详细内容，保留英文章节名，章节条目相对标题缩进四个空格。已有类型标注时，正文写语义、单位和约束，省去重复的类型名。[PEP 257](https://peps.python.org/pep-0257/) · [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html#383-functions-and-methods)

- `Args:` 按签名顺序说明参数。涉及路径时交代相对谁解析，涉及可变对象时交代调用后是否改变。
- `Returns:` 说明返回值及特殊值的含义。生成器用 `Yields:` 描述每次产生的值。只返回 `None` 且语义已清楚时省去返回小节。
- `Raises:` 列出调用者需要处理的具体异常及触发条件。类需要说明公开属性时用 `Attributes:`。只保留有内容的小节。

下面以首次导入检查为例。文档字符串写明调用者能取得什么路径、会遇到哪些失败，函数内的中文注释解释保留缓存检查的原因。

```python
from pathlib import Path


def fresh_project_root(project: Path) -> Path:
    """Resolve a Godot project directory for a first-import check.

    Args:
        project: Project directory, relative to the working directory or absolute.

    Returns:
        The absolute, resolved path to the project directory.

    Raises:
        FileNotFoundError: The directory contains no project.godot file.
        ValueError: The directory already contains a .godot import cache.
    """
    root = project.resolve()
    if not (root / "project.godot").is_file():
        raise FileNotFoundError(root / "project.godot")
    # Godot 会复用缓存中的扩展注册信息，已有缓存会掩盖首次导入的问题。
    if (root / ".godot").exists():
        raise ValueError("Fresh import requires a project without a .godot cache.")
    return root
```

普通块注释用 `# `，与它说明的代码对齐。用行尾注释说明特殊情况时，在代码与 `#` 之间至少留两个空格。GF 有工具把模块文档字符串传给 `argparse.ArgumentParser(description=__doc__)`。修改这类摘要后，一并查看实际的 `--help` 输出。[PEP 8 注释排版](https://peps.python.org/pep-0008/#block-comments) · [GF Native 验收工具](../../tools/gf_native_acceptance.py)
