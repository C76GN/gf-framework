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

未知结构字段会报错，而不是静默忽略；这样 `next_line` 拼写错误不会悄悄变成一条断开的对话。项目自定义内容应放进明确的 `metadata` 或 payload 容器。编译失败时结果中的 `resource` 固定为 `null`，调用方不能误用半成品。

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

需要从文件、内存注册文本或项目自定义来源读取时，先配置 `GFSourceTextLoader`，再调用 `compile_source()`。文件加载仍受 `root_path` 和 `max_bytes` 约束，`../` 不能越过声明根目录；编译器不会自己扩大文件访问范围。

```gdscript
var loader: GFSourceTextLoader = GFSourceTextLoader.new("res://dialogue", {
	"max_bytes": 2 * 1024 * 1024,
})
var result: Dictionary = compiler.compile_source("prologue.gf_dialogue.json", loader)
```

## 使用边界

- 文本编译是制作期动作；运行时 Dialogue 包不会发现或加载 `gf.tool.dialogue_text`。
- 编译器不保存产物，调用方可以先审阅 `report`，再自行选择 `.tres`、缓存、导出包或其他产物策略。
- 文件扩展名和目录结构由项目决定；`.gf_dialogue.json` 只是易识别的示例，不是框架硬编码规则。
- 本地化表、配音、立绘、任务状态、权限和内容热更仍属于项目流水线或独立插件。

## API Reference

完整方法与格式常量见 [Tool Packages API Reference](../../reference/api/tools.md)。
