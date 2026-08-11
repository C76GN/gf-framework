# Asset Browser 素材浏览模型

`gf.tool.asset_browser` 是可选制作期工具包。当前阶段只提供 `GFAssetBrowserModel`，用于把既有 `GFAssetCatalog` 快照、稳定选择、分页查询和缩略图任务组织成可测试的无界面状态模型。它不注册 Dock，不扫描项目目录，也不拥有 provider、资源缓存、下载、导入或业务分类。

## 为什么先提供模型

素材来源、窗口布局、筛选控件、资源打开方式和拖放目标都属于消费方策略。GF 先稳定下面这些跨界面不变量：

- 目录替换是原子的；输入无法完整、安全复制时保留旧目录、revision、query generation 和选择。
- 选择只保存稳定 `asset_id`，不会持有列表行或编辑器控件引用。
- 查询、目录和预览分别使用 generation / revision 隔离陈旧结果。
- 分页和摘要有硬上限，页面 metadata 通过统一报告值编码器输出 JSON-safe 投影。
- 模型只协调调用方提交的 `GFThumbnailRenderRequest`；资源物化和 renderer 配置仍由调用方负责。

只有出现明确的编辑器贡献 owner、可复用交互契约和独立生命周期测试后，才应在项目插件或后续工具包中组合 Dock。当前模型不会为了展示一个面板而建立第二套 catalog、thumbnail 或 provider 注册表。

## 最小用法

```gdscript
var model := GFAssetBrowserModel.new()
var replace_report := model.replace_catalog(project_catalog)
if not replace_report.ok:
	push_error(replace_report.error)
	return

model.set_query("character", PackedStringArray(["hero.idle", "hero.run"]))
var first_page := model.get_page(1, 50)
model.select_asset(&"hero.idle")
```

`set_query()` 的资产 ID 闭集必须使用非空、无首尾空白的 canonical ID。无效过滤不会被归一成空过滤，因为空过滤代表查询整个目录，静默归一会意外扩大查询范围。

## 目录快照边界

`replace_catalog()` 在任何深复制和索引重建之前，直接检查输入 catalog 的原始 entries。预检同时限制：

- entry 数量和稳定 ID 长度；
- metadata 的递归深度、集合项目数和累计 Variant 节点数；
- 单段文本长度与整份 catalog 的累计 UTF-8 文本字节；
- Array / Dictionary 循环引用；
- 无法安全隔离的 Object、Callable、Signal 和 RID metadata。

预检不会调用 `catalog.to_dict()`、`get_all_ids()` 或其他会提前深复制、完整物化索引的方法。全部条目通过后，模型才复制候选目录、重建有界索引并一次性提交。超过预算、循环、重复 ID 或不支持的 live 值都会 fail closed；不会截断 `provenance`、`license`、`hash` 等来源字段后发布半份目录。成功目录中的 metadata 保持精确副本，失败目录则完全不改变旧状态。

## 查询、选择与预览代际

成功替换目录会推进 catalog revision 和 query generation，并清除新目录中不存在的选择。查询实际变化时只推进 query generation；被拒绝的查询不会让已经发布的页面失效。`get_page()` 始终限制页大小和最大匹配数，调用方不能通过超大 page size 绕过模型预算。

预览入口只接受当前目录中的稳定 ID、有效 `GFThumbnailRenderer` 和有效 `GFThumbnailRenderRequest`。新预览会取消上一代等待任务；目录或查询变化会使旧任务失效，旧代际完成后不能发布为当前结果。模型不从路径隐式加载资源，也不替调用方决定 Mesh、Texture、Scene 或自定义 renderer 的物化策略。

`catalog_changed`、`query_changed`、`selection_changed` 和 `preview_resolved` 共用一个非重入 FIFO 通知队列。每次状态提交都会立即冻结本次通知参数；监听器同步发起的嵌套 mutation 只把新通知排到队尾，不会在当前 signal 的 listener 链中穿插发布。当前 signal 的全部 listener 返回后，模型才继续按提交顺序派发队列，因此后注册监听器不会先观察新 revision / generation、再收到旧通知，也不会从已经变化的 live state 重读旧 payload。

监听器必须保证同步反馈 mutation 有限并最终收敛。模型不会用任意派发上限丢弃已经提交的通知，也不会把同步契约静默改成依赖 SceneTree 帧循环的延迟契约；持续生成 mutation 的监听器反馈环属于调用方错误。若 listener 在派发中调用 `dispose()`，当前已经开始的 signal 仍会完成其 listener 链，但尚未开始派发的队尾通知会被丢弃。

`dispose()` 是终态操作。它会取消当前预览，并让目录、查询、选择和预览写入口拒绝后续请求；只读 revision、selection 和 page 仍可用于释放阶段诊断。

## 包边界

工具包只包含 `addons/gf/tools/asset_browser/**`，依赖 `gf.kernel` 和 `gf.standard.assets`：

- `GFAssetCatalog`、条目、provider 和 runtime mount 继续由 Standard Assets 拥有；
- `GFThumbnailRenderer`、请求与任务继续由 Kernel 编辑器协议拥有；
- 项目目录扫描、第三方素材服务、授权策略、业务标签、拖放落点和 Dock 布局由项目 Adapter 或独立插件拥有。

导出游戏和只使用资产目录的运行时包不应反向依赖这个工具包。
