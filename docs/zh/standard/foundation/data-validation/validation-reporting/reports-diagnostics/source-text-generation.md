# 安全文本生成边界

GF 的文本生成基础件只处理显式纯数据、输出预算和诊断报告，不提供通用脚本语言，也不会执行表达式、对象方法或项目业务规则。

## 核心类

- `GFDataProjection`：把 Dictionary 或显式字段 Object 投影成纯 Variant 数据。
- `GFExecutionBudget`：限制步数、深度、输出长度、耗时和取消 token。
- `GFTextGenerationContext`：管理数据 scope、简单 token 替换、输出缓冲和诊断报告。

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

## 使用边界

- token 只支持 `{{ path.to.value }}` 形式的数据路径，不支持函数调用、条件、循环或动态脚本。
- Object / Resource 不会被默认展开；需要通过 `GFDataProjection.project_object()` 显式列出字段。
- 缺失值、未闭合 token、输出超限和预算耗尽都会进入 `GFValidationReport`。
- 如果需要读取文件片段，使用 IO 侧的 `GFSourceTextLoader` 先做 root 限制和诊断，再把文本交给上下文。

## 不适合

- 不适合承载项目 DSL、剧情脚本、热更新业务逻辑或用户可执行表达式。
- 不适合替代配置表、场景序列化、国际化系统或完整模板引擎。
- 不应把业务对象直接塞进上下文；先投影成明确字段的 Dictionary。
