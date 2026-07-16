# 安全文本生成边界

GF 的文本基础件只处理显式纯数据、结构化扫描、输出预算和诊断报告，不提供通用脚本语言，也不会执行表达式、对象方法或项目业务规则。

## 核心类

- `GFDataProjection`：把 Dictionary 或显式字段 Object 投影成纯 Variant 数据。
- `GFExecutionBudget`：限制步数、深度、输出长度、耗时和取消 token。
- `GFTextGenerationContext`：管理数据 scope、简单 token 替换、有限循环/空态/注释模板、输出缓冲和诊断报告。
- `GFDelimitedTextTools`：按顶层分隔符拆分文本，忽略引号和括号内的分隔符，并返回结构化扫描错误。
- `GFSourceTextPatchTools`：按零基 line/character 范围校验和应用纯文本 edit，返回变更报告。
- `GFSourceTextLoader`：按逻辑 key 读取注册文本、自定义 loader 文本或 root 内 UTF-8 文件，并返回缓存、哈希和诊断字段。

## 典型流程

```gdscript
var data := GFDataProjection.project_dictionary({
	"name": "Ada",
	"node": some_node,
}, {
	"allowed_fields": PackedStringArray(["name"]),
})

var budget := GFExecutionBudget.new({
	"max_steps": 100,
	"max_output_length": 4096,
})

var context := GFTextGenerationContext.new(data, {
	"strict_variables": true,
	"budget": budget,
})

context.append_line(context.replace_tokens("Hello {{ name }}"))
var report := context.get_report()
```

需要根据纯数据数组重复输出文本时，使用 `render_template()` 的有限循环块；需要在值缺失、false、空文本或空集合时输出兜底内容，可以使用空态块：

```gdscript
var output := context.render_template(
	"{{ empty items }}No items\n{{ end_empty }}" +
	"{{ for item in items }}- {{ item.name }}\n{{ end }}",
	{ "max_loop_items": 100 }
)
```

循环语法只支持 `{{ for item in items }}` 与 `{{ end }}`；空态语法只支持 `{{ empty path }}` 与 `{{ end_empty }}`；模板作者备注可写成 `{{ comment note }}`，渲染时会被移除。循环体内会临时推入 `item`，并提供默认 `loop.index`、`loop.number`、`loop.count`、`loop.first` 和 `loop.last` 元数据。普通 `Array` 和 Godot `Packed*Array` 都可作为循环源，token 路径也可用数字下标读取这些数组。空态块只做纯数据空值判断，不支持表达式或比较；数字 `0` 仍视为存在值，空数组、空字典、空 `Packed*Array`、空文本、`false` 和 `null` 视为空。注释内容不会读取数据、调用 formatter 或屏蔽语法错误。

如果项目需要统一处理 token 输出，例如数字缩写、富文本转义或本地化前置格式化，可以给 `replace_tokens()` 或 `render_template()` 传入 `value_formatter`。formatter 只接收当前 token 的纯数据上下文并返回最终值；它不改变 token 解析规则，也不执行模板表达式。

```gdscript
var output: String = context.replace_tokens("Score: {{ score }}", {
	"value_formatter": func(format_context: Dictionary) -> Variant:
		var data_path: String = GFVariantData.get_option_string(format_context, "path")
		var token_value: Variant = GFVariantData.get_option_value(format_context, "value")
		if data_path == "score":
			return GFNumberFormatter.format_compact(token_value)
		return token_value
})
```

## 顶层分隔符扫描

`GFDelimitedTextTools.split_top_level()` 适合处理函数参数、命令参数或配置片段。它只返回文本片段、分隔符位置和错误报告，不解释字段语义。

```gdscript
var split := GFDelimitedTextTools.split_top_level(
	"a, call(1, 2), 'x,y'",
	",",
	{ "trim_parts": true }
)

var parts := split["parts"]
```

## 文本范围补丁

`GFSourceTextPatchTools.apply_text_edits()` 适合代码生成、迁移工具或编辑器命令在写文件前先对单个文本做确定性补丁。它接受 LSP-shaped 的 `range.start.line/character` 与扁平 `start_line/start_character` 两类范围结构，但 `character` 使用 Godot `String` 字符索引，不是 LSP UTF-16 code unit 坐标。工具会先拒绝越界、反向和重叠 edit，再按原始 offset 倒序应用。

```gdscript
var patched := GFSourceTextPatchTools.apply_text_edits(source_text, [
	GFSourceTextPatchTools.make_replacement_edit(0, 5, 0, 8, "new_name"),
])

if patched["ok"]:
	var next_text := patched["text"]
```

该工具只返回字符串结果和报告；需要读取或保存文件时，分别组合 `GFSourceTextLoader` 与 `GFGeneratedArtifactReport`，或由项目自己的编辑器命令决定写入策略。

## 源码文本加载

`GFSourceTextLoader` 默认优先读取 `register_text()` 注册的内存文本，再尝试自定义 loader 链，最后按 `root_path` 读取文件。自定义 loader 只负责把逻辑 key 转换为文本或 UTF-8 字节，不执行脚本，也不改变 root 文件访问边界；返回 `null` 或 `{ "handled": false }` 时会继续尝试后续来源。

```gdscript
var loader := GFSourceTextLoader.new("res://templates")
var _custom_loader_added := loader.add_custom_loader(func(source_key: String, context: Dictionary) -> Dictionary:
	if source_key == "generated/header":
		return {
			"text": "# Header\n",
			"metadata": GFVariantData.get_option_dictionary(context, "loader_metadata"),
		}
	return { "handled": false }
)

var loaded := loader.load_text("generated/header")
```

## 使用边界

- token 只支持 `{{ path.to.value }}` 形式的数据路径；循环只支持读取数组路径；空态块只支持读取一个数据路径；注释只会被移除，不支持函数调用、条件表达式或动态脚本。
- `value_formatter` 只能处理单个 token 的输出值；排序、过滤、条件分支和业务排版应在调用前准备好数据。
- 顶层分隔符扫描只识别引号、括号和分隔符层级，不验证表达式、SQL、函数名或字段存在性。
- 文本范围补丁只按调用方提供的 Godot 字符坐标修改字符串，不解析 GDScript、不定位符号，也不替项目决定是否覆盖用户文件；如果外部 LSP 返回 UTF-16 character，调用方需要先转换坐标。
- Object / Resource 不会被默认展开；需要通过 `GFDataProjection.project_object()` 显式列出字段。
- 缺失值、未闭合 token、输出超限和预算耗尽都会进入 `GFValidationReport`。
- 如果需要读取文件片段，使用 IO 侧的 `GFSourceTextLoader` 先做 root 限制和诊断，再把文本交给上下文。
- 自定义 source loader 只能返回文本内容；网络、权限、签名、解密或缓存失效策略仍由项目侧在回调内自行决定。

## 不适合

- 不适合承载项目 DSL、剧情脚本、热更新业务逻辑或用户可执行表达式。
- 不适合替代配置表、场景序列化、国际化系统或完整模板引擎；复杂条件、过滤、排序和业务布局规则应在调用前准备好纯数据。
- 不适合替代 SQL、公式引擎、脚本解释器或完整解析器；项目需要自行解释拆分后的片段。
- 不应把业务对象直接塞进上下文；先投影成明确字段的 Dictionary。
