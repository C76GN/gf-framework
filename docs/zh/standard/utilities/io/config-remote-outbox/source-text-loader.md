# 源码文本加载器

`GFSourceTextLoader` 用于把逻辑 key 解析为受控文本来源，再读取 UTF-8 内容。它适合生成器、导入器、校验器和编辑器工具读取片段文件或内存文本，不负责解释文本语义。

## 典型流程

```gdscript
var loader := GFSourceTextLoader.new("res://data/templates", {
	"max_bytes": 64 * 1024,
})

var resolved := loader.resolve_key("item_card.txt")
if resolved["ok"]:
	var loaded := loader.load_text("item_card.txt")
	print(loaded["content_hash"])
```

## 能力边界

- 文件访问需要设置 `root_path`，相对 key 会被限制在该根目录下。
- `resolve_key()` 只解析路径和缓存 key，`load_text()` 才读取文本。
- `register_text()` 可注册内存文本，适合测试、编辑器草稿或项目侧生成片段。
- 结果包含 `content_hash`、`byte_size`、`resolved_path`、`from_cache` 和 `report`。
- `max_bytes` 在每次返回时生效；配置降低后，旧缓存中的超限文本会被逐出并返回 `text_too_large`，不会绕过新预算。
- 文件和自定义 loader 返回的 `PackedByteArray` 必须是严格 UTF-8；非法、过长或 surrogate 编码以 `invalid_utf8` 失败，不会用替换字符静默改写内容。
- 失败结果会写入 `GFValidationReport`，可继续交给诊断面板或 CI 输出。

## 注意事项

- 不要把 `root_path` 指向项目不信任的宽泛目录。
- `root_path` 当前是词法路径边界：它会拒绝 `..` 和前缀逃逸，但不会解析操作系统 junction / symlink 的物理目标。不要把攻击者可创建链接的目录当作文件系统安全沙箱；需要物理路径能力边界时，应由项目侧使用受控目录、预先拒绝链接，或等待框架采用明确的物理路径策略。
- 该加载器只读 UTF-8 文本，不加载 Resource，也不执行 include 内容。
- 需要远程文本缓存时使用 `GFRemoteCacheUtility`；需要配置表语义时使用配置表 Provider 和 schema。
