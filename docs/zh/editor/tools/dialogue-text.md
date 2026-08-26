# Dialogue Text 对话文本工具包

`gf.tool.dialogue_text` 是可选制作期工具包，用于把严格 JSON 文本编译为 `GFDialogueResource`。它适合内容人员维护文本文件、编辑器按钮导入资源或 CI 在合并前校验对话跳转；游戏运行时只需要 Dialogue 扩展生成后的资源，不应反向依赖该工具包。

## 定位

`GFDialogueTextCompiler` 只负责三件事：解析 JSON、把结构字段映射为 `GFDialogueLine` / `GFDialogueResponse`，以及复用 `GFDialogueResource.validate_resource()` 检查重复 ID、缺失跳转和无条件自动循环。它不解释“好感度”“任务阶段”“角色立绘”之类业务概念；这类数据应进入 `metadata`、`condition_payload` 或 `mutation_payload`，再由项目自己的上下文处理器解释。

这条边界适合多种项目：剧情游戏可以把 `text` 保存为本地化 key，任务对话可以用通用 condition / mutation ID 连接项目状态，内部工具也可以从表格或图编辑器生成同一 JSON。GF 不要求项目手写 JSON，更不把某种编辑器工作流固化成运行时契约。

## 文本格式

根对象必须声明 `format: "gf.dialogue"`、`schema_version: 1` 和非空 `lines`。结构字段使用与运行时资源一致的名称，行 `kind` 可为 `text`、`mutation`、`jump` 或 `end`：

```json
{
  "format": "gf.dialogue",
  "schema_version": 1,
  "start_line_id": "intro",
  "metadata": {
    "chapter": "prologue"
  },
  "lines": [
    {
      "line_id": "intro",
      "kind": "text",
      "speaker_id": "guide",
      "text": "dialogue.intro",
      "responses": [
        {
          "response_id": "continue",
          "text": "dialogue.continue",
          "next_line_id": "finish"
        }
      ]
    },
    {
      "line_id": "finish",
      "kind": "end"
    }
  ]
}
```

未知结构字段会报错，而不是静默忽略；这样 `next_line` 拼写错误不会悄悄变成一条断开的对话。项目自定义内容应放进明确的 `metadata` 或 payload 容器。编译失败时结果中的 `resource` 固定为 `null`、`line_count` 固定为 `0`，调用方不能误用或误计半成品。

### 严格解释契约

“严格 JSON”表示同一份 source bytes 只有一种可接受解释：

- 拒绝 trailing comma、字符串中的原始控制字符、非法转义和根值后的额外内容；
- 在构造 Dictionary 前拒绝重复 object member，并在报告中同时给出首次声明与冲突声明；
- `\uXXXX` 必须组成合法 Unicode scalar；合法 surrogate pair、非 BMP 字符、组合字符和 RTL 文本按原码点保留，不用替换字符修复非法输入；
- 整数只接受有符号 64 位范围；带小数或指数的非零数接受规范化十进制指数 `-307..308`，上界不超过 `1.7976931348623157e308`；下溢、溢出、`NaN` 与 Infinity 均失败关闭。数学零可使用任意语法合法的十进制指数；
- `schema_version: 1` 与数值上精确等于整数的 `1.0` 都表示 schema v1；接近整数但不相等的值不会被近似比较接受。

这个数值域是制作期格式的确定性边界，不等同于“接受某个平台浮点转换器碰巧能解析的所有十进制文本”。需要任意精度、次正规数或超出 int64 的项目数据时，应在项目 schema 中用字符串表达并由项目 Adapter 显式解释。

### 资源与诊断预算

`compile_text()` 的预算选项必须是严格正整数；调用方可在默认值与框架硬上限之间选择，但不能关闭硬上限：

| 选项 | 默认值 | 硬上限 | 计量口径 |
| --- | ---: | ---: | --- |
| `max_text_bytes` | 4 MiB | 16 MiB | 输入 UTF-8 字节数；超限时不计算内容哈希、不解析 |
| `max_depth` | 64 | 64 | JSON object / array 嵌套深度 |
| `max_nodes` | 65,536 | 262,144 | JSON 值与 object member name 的总节点数 |
| `max_string_bytes` | 1 MiB | 4 MiB | 单个解码后字符串或 member name 的 UTF-8 字节数 |
| `max_lines` | 4,096 | 16,384 | 单份文档的 line 数 |
| `max_responses` | 16,384 | 65,536 | 全部 line 的 response 总数 |
| `max_diagnostics` | 256 | 1,024 | 返回 issue 总数；最后一个槽说明诊断被截断 |

文本、结构、line 与 response 预算会在构造 `GFDialogueResource` 前拒绝；资源图校验复用一次建立的 ID 索引和全局 cycle traversal，不再从每个起点重复线性查找。任何预算失败都只返回报告，不暴露部分 Resource。

### 来源定位与报告边界

语法、schema 与资源图错误统一使用 URI fragment 形式的 RFC 6901 JSON Pointer，例如 `#/lines/0/responses/1/next_line_id`，并附带 1-based line / column / range。字段名中的 `/`、`~`、非 ASCII 与控制字符会按 JSON Pointer 和 URI fragment 规则编码；同一目标出现多次时，每条资源错误按源码顺序映射到不同 token。

返回的 `report` 会在入口处和输出处经过有深度、节点、集合与 4 MiB 总字节上限的 JSON-safe 投影；Object、循环容器、PackedArray 和非有限浮点会变成稳定 marker，不会触发递归错误或破坏 `JSON.stringify()`。这是本地制作期报告，因此显式 `source_path` 会保留，供 IDE/CI 跳转；把报告发送到外部服务前，项目应再用 `GFReportValueCodec` 的 `public` 或 `privacy` profile 执行自己的脱敏政策。

## 典型流程

直接编译内存文本：

```gdscript
var compiler: GFDialogueTextCompiler = GFDialogueTextCompiler.new()
var result: Dictionary = compiler.compile_text(source_text, {
	"source_path": "res://dialogue/prologue.gf_dialogue.json",
})

if GFVariantData.get_option_bool(result, "success"):
	var resource_value: Variant = GFVariantData.get_option_value(result, "resource")
	if resource_value is GFDialogueResource:
		var dialogue: GFDialogueResource = resource_value
		ResourceSaver.save(dialogue, "res://generated/dialogue/prologue.tres")
else:
	print(GFVariantData.get_option_dictionary(result, "report"))
```

需要从文件、内存注册文本或项目自定义来源读取时，先配置 `GFSourceTextLoader`，再调用 `compile_source()`。`loader.max_bytes` 必须为正且不大于本次有效 `max_text_bytes`，这样读取阶段不会先于编译器预算分配更大的文本。文件加载仍受 `root_path` 的词法约束，`../` 不能越过声明根目录；编译器不会自己扩大文件访问范围。

```gdscript
var loader: GFSourceTextLoader = GFSourceTextLoader.new("res://dialogue", {
	"max_bytes": 2 * 1024 * 1024,
})
var result: Dictionary = compiler.compile_source("prologue.gf_dialogue.json", loader)
```

`root_path` 不是物理文件系统沙箱：当前加载器不会证明 junction / symlink 的最终目标仍在根内。完整威胁模型与部署要求见[源码文本加载器](../../standard/utilities/io/config-remote-outbox/source-text-loader.md)。

## 使用边界

- 文本编译是制作期动作；运行时 Dialogue 包不会发现或加载 `gf.tool.dialogue_text`。
- 编译器不保存产物，调用方可以先审阅 `report`，再自行选择 `.tres`、缓存、导出包或其他产物策略。
- 文件扩展名和目录结构由项目决定；`.gf_dialogue.json` 只是易识别的示例，不是框架硬编码规则。
- 本地化表、配音、立绘、任务状态、权限和内容热更仍属于项目流水线或独立插件。

## API Reference

完整方法与格式常量见 [Tools API Reference](../../reference/api/tools.md)。
