# 结构化日志与日志 Sink

本组页面说明 `GFLogUtility` 的分级日志、结构化上下文、本地文件、内存缓存、日志信号和可扩展 sink。项目需要日志时，应在 Installer 中显式装配；框架不会因为脚本存在就自动注册日志工具。

## 阅读入口

- [注册与日志 API](setup-and-api/index.md)：Installer 装配、分级日志、结构化上下文、标签静音、懒构造和日志信号。
- [文件、缓存与上下文](files-memory-context.md)：本地日志文件、flush 策略、内存环形缓存、上下文清洗、trace id 和崩溃标记。
- [日志 Sink](sinks.md)：`GFLogSink`、`GFJsonLineLogSink`、`GFBatchedLogSink` 和项目自定义输出。

## 开发者诊断与语言

GF 自有的开发者错误与警告使用固定英文和稳定诊断码，例如 `[GFStorageUtility][storage_utility.resource_null] Cannot save_resource: resource is null.`。这些诊断通过原生 `push_error()` / `push_warning()` 输出，保留对应的严重级别与调用栈，不随游戏语言切换。诊断码便于检索同一类问题；结果对象的 `error_kind` 等字段仍按各自接口约定使用，项目逻辑不应解析英文说明。

英文要求只约束框架模板和框架提供的详情。运行时路径、资源名等参数可以包含中文；项目通过 `GFLogUtility` 提交的 `tag`、`message` 和 `context` 也保留项目选择的语言，并继续遵守原有等级过滤、大小限制和输出规则。框架诊断不依赖项目是否注册日志工具。

编辑器显示文字采用独立的工具语言设置。已接入工具翻译 catalog 的文字支持 `en` 和 `zh_CN`，缺失翻译或不支持的语言回退英文；当前这一保证仅适用于既有 catalog，部分面板仍有固定文案。

## 使用边界

`GFLogUtility` 提供本地与内存级别的通用观测能力。`trace_id`、`tag`、`message` 和 `context` 会先经过有界报告编码，避免单条日志无限放大输出；体量限制和 JSON 兼容只约束数据形态，不等于隐私脱敏，也不会识别项目自由文本中的账号、用户内容或业务秘密。

本地 `.log`、控制台、内存缓存、日志信号和 `GFJsonLineLogSink` 使用 debug profile，允许保留本机路径等排障信息；普通自定义 `GFLogSink` 默认使用 public profile；`GFBatchedLogSink` 固定使用 privacy profile，并在外发前再次清洗完整条目。框架不替项目决定远端上传、鉴权、用户同意、业务字段分类、采样、崩溃归因或线上采集策略；公开日志前仍应由项目层做最小化采集和人工检查。
