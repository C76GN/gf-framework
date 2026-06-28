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
- 失败结果会写入 `GFValidationReport`，可继续交给诊断面板或 CI 输出。

## 注意事项

- 不要把 `root_path` 指向项目不信任的宽泛目录。
- 该加载器只读 UTF-8 文本，不加载 Resource，也不执行 include 内容。
- 需要远程文本缓存时使用 `GFRemoteCacheUtility`；需要配置表语义时使用配置表 Provider 和 schema。
