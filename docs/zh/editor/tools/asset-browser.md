# Asset Browser 资源工作台

从 **工具 > GF > 打开 GF 工作区 > 资源** 打开资源工作台。默认项目来源使用 Godot 已有导入索引，不需要编写 Provider 或建立固定素材目录。工作台提供名称、路径和标签搜索、类型与目录范围筛选、每页最多 100 项的缩略图、个人收藏、共享目录及源资源表格编辑。

## 浏览和使用

默认范围为 `res://`，排除隐藏目录和 `addons`；勾选“包含插件”可浏览插件素材。目录字段确认或点击刷新后，工具分帧读取当前 Godot 索引，不主动重导入、不批量加载资源，也不实例化源场景。超过 10,000 项时整个候选快照被拒绝，请缩小目录或类型；旧结果会标为过期。

项目索引刷新完成前，共享标签的 Undo 或目录变化不会重新启用旧资源路径。隐藏页面会停止新预览提交；宿主撤销上下文后，保存按钮与尚未完成的文件选择请求都会失效。

- 双击或“打开”把场景交给原生场景编辑器，其他资源交给 Inspector；“定位文件”进入原生 FileSystem。
- 卡片提供 Godot 原生文件拖拽载荷，可交给支持该载荷的场景树、Inspector 或场景摆放源字段。跨窗口拖拽是否可用取决于当前 Godot 与平台窗口环境。
- 缩略图优先使用原生预览；不支持的类型保留类型图标。当前页最多 100 项，在途预览最多 4 项，工具纹理缓存最多 128 项。换页、重导入、隐藏或卸载都会隔离晚到结果。
- 个人收藏、最近使用和浏览范围保存在当前项目的编辑器 metadata，不写入游戏存档或 `project.godot`。收藏优先使用已有 UID；没有 UID 时使用完整路径，移动这种资源后需要重新收藏。

“依赖 / 引用”对单个所选资源按需扫描，显示依赖图和被引用位置、证据强度及完整性。当前范围最多扫描 2,000 个文件和 8 MiB 文本，单文件最多 1 MiB；预算、忽略范围和无法静态确定的动态路径都限制结论。没有发现引用不表示可以安全删除。

## 共享目录和标签

点击“新建共享目录”显式选择新的 `.tres` 路径，或打开已有 `GFAssetCatalog`。所选素材的标签和备注通过“应用到所选”写入目录内存，支持原生 Undo；“保存共享目录”才写入该目录文件。个人收藏和导入结果不会因此被修改。已有文件不会被新建操作覆盖。

项目来源会叠加同一资产身份在共享目录中的标签和备注；切换到“共享目录”可以浏览目录提供的条目与 metadata。工具不探测某个具体扩展，也不为收集 glTF 节点元数据而实例化全部场景。

## 源资源表格

选中资源后点击“表格编辑”。只有项目内独立、非导入的 `.tres/.res` 源资源进入保存流程，其他资源交给原生 Inspector。工具按真实 Undo history 和资源类型分组，复用 [Resource 表格](../resource-table-editor.md)；每组修改独立撤销。

属性修改与磁盘保存分别显示。修改后点击“保存表格中的源资源”，逐文件显示保存结果；一次属性 Undo 不表示多文件磁盘事务。表格有未保存修改时，会要求先保存或使用 Undo 恢复后再更换选择。

## 可复用浏览模型

`GFAssetBrowserModel` 继续提供与界面无关的 Catalog 快照、稳定选择、分页查询和当前详细预览状态。模型保持下面这些不变量：

- 目录替换是原子的；输入无法完整、安全复制时保留旧目录、revision、query generation 和选择。
- 选择只保存稳定 `asset_id`，不会持有列表行或编辑器控件引用。
- 查询、目录和预览分别使用 generation / revision 隔离陈旧结果。
- 分页和摘要有硬上限，页面 metadata 通过统一报告值编码器输出 JSON-safe 投影。
- 模型只协调调用方提交的 `GFThumbnailRenderRequest`；资源物化和 renderer 配置仍由调用方负责。

工作台是模型的编辑器消费方；整页原生缩略图由独立有界队列管理，不会让卡片互相取消模型的当前详细预览。

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

节点请求默认使用静态视觉副本；需要脚本自绘时，由调用方显式构建可信动态请求，具体边界见 [静态与可信动态模式](../non-destructive-live-preview.md#静态与可信动态模式)。模型不会为补齐外观而自动切换模式。

`preview_resolved` 只接受 Kernel 缩略图协议声明的结果：`Image`、`ImageTexture`、`null`，或精确包含 `ok`、`generated_count`、`cancelled` 与 `changes` 的 MeshLibrary 预览计划。计划最多包含 `MAX_RESULT_COUNT` 项；每项必须精确包含非负 `item_id`、可空的 `old_preview` 和非空 `new_preview`，预览值必须是 `Texture2D`。模型先按这个闭合、有界 schema 重建计划，再递归冻结所有 `Dictionary` / `Array` 容器；循环、超限、额外字段或错误类型都会把本次通知降为失败，不会在校验前执行无界深复制。`Image`、`ImageTexture` 与计划中的纹理是 Godot 引擎对象句柄，不能变为只读对象；listener 必须把它们当作只读引用，不得在同一通知链中修改资源内容。

`catalog_changed`、`query_changed`、`selection_changed` 和 `preview_resolved` 共用一个非重入 FIFO 通知队列。每次状态提交都会立即冻结本次通知参数；监听器同步发起的嵌套 mutation 只把新通知排到队尾，不会在当前 signal 的 listener 链中穿插发布。当前 signal 的全部 listener 返回后，模型才继续按提交顺序派发队列，因此后注册监听器不会先观察新 revision / generation、再收到旧通知，也不会从已经变化的 live state 重读旧 payload。

监听器必须保证同步反馈 mutation 有限并最终收敛。模型不会用任意派发上限丢弃已经提交的通知，也不会把同步契约静默改成依赖 SceneTree 帧循环的延迟契约；持续生成 mutation 的监听器反馈环属于调用方错误。若 listener 在派发中调用 `dispose()`，当前已经开始的 signal 仍会完成其 listener 链，但尚未开始派发的队尾通知会被丢弃。

`dispose()` 是终态操作。它会取消当前预览，并让目录、查询、选择和预览写入口拒绝后续请求；只读 revision、selection 和 page 仍可用于释放阶段诊断。

## 包边界

工具包只包含 `addons/gf/tools/asset_browser/**`，依赖 `gf.kernel` 和 `gf.standard.assets`：

- `GFAssetCatalog`、条目、provider 和 runtime mount 继续由 Standard Assets 拥有；
- `GFThumbnailRenderer`、请求与任务继续由 Kernel 编辑器协议拥有；
- 默认项目来源和浏览界面由本工具拥有；第三方素材服务、授权策略和业务分类由项目 Adapter 或独立插件拥有；
- 场景摆放目标自行接收 Godot 原生资源载荷，两个工具互不引用。

导出游戏和只使用资产目录的运行时包不应反向依赖这个工具包。
