# 非破坏式实时调参预览

材质、主题、粒子参数或项目自定义 Resource 的编辑器工具经常需要在拖动控件时立即更新预览。如果预览直接修改已加载资源或立即保存文件，取消操作、共享资源引用和失败恢复都会变得不可靠。

GF 已有的属性补丁、显式资产槽位、缩略图渲染和编辑器命令协议可以组合出非破坏式流程，不需要再建立绑定某种素材类型的预览系统。

## 所有权模型

一次预览会话应明确持有以下对象：

- 不可修改的基准 Resource 引用。
- 一份 `GFResourcePropertyPatch`，只声明本工具允许调整的属性。
- 一个短生命周期 `GFAssetSlot`，只发布当前预览副本及其 generation。
- 当前 `GFThumbnailRenderTask` 或项目自己的可取消渲染请求。
- 一个 `GFEditorCommandSession`，用于把预览命令与最终提交分开。

`GFAssetSlot` 不监听文件，也不替换 `GFAssetUtility` 缓存。它只让预览面板、Viewport 和检查器围绕稳定身份观察“当前是哪一份临时资源”。

## 每次调整都重建副本

不要连续改写上一帧的临时资源。每次参数变化都从稳定基准重新构建副本，这样撤回某个字段、重排补丁或丢弃过期请求不会累积隐式状态。

```gdscript
var build_report: Dictionary = patch.build(base_resource, {
	"duplicate_base": true,
	"require_existing_property": true,
	"copy_values": true,
})
if not GFVariantData.get_option_bool(build_report, "ok"):
	return

var candidate_value: Variant = GFVariantData.get_option_value(
	build_report,
	"resource"
)
if not candidate_value is Resource:
	return
var candidate: Resource = candidate_value

if not preview_slot.is_configured():
	var identity: GFResourceIdentity = GFResourceIdentity.new().configure(
		&"project_tool/live_preview",
		"",
		base_resource.get_class(),
		{"check_exists": false}
	)
	var _configured: bool = preview_slot.configure(identity, candidate, self)
else:
	var _replaced: bool = preview_slot.replace(candidate)
```

调用方应先检查补丁报告，再发布副本。补丁定义、属性类型和是否允许 `null` 都由工具显式声明；GF 不推断哪些属性适合实时调整。

## 合并渲染请求

发布新 generation 后，应取消上一项尚未完成的 `GFThumbnailRenderTask`，再用 `GFThumbnailRenderer` 渲染由当前副本构建的 `CanvasItem`、`Node3D` 或 `Mesh`。异步结果返回时再次比较槽位 generation；过期结果即使成功也不能覆盖新预览。

高频滑杆可以在项目工具中增加一帧或固定毫秒的合并窗口，但窗口结束时仍只提交一份完整补丁。自定义 `_draw()`、粒子或依赖运行时脚本的内容应使用预览专用节点，并显式提供渲染边界；预览节点和任务都由当前工具会话释放。

## 确认与取消

预览命令只面向临时副本。用户确认后，再创建新的 `GFEditorPropertyBatchCommand`，把已批准的字段事务式写入权威 Resource，并通过 `GFEditorCommandSession.commit_command()` 或 `GFEditorToolContext.commit_command()` 接入 UndoRedo。自动保存、资源导入和外部产物写出仍应位于确认后的独立步骤。

取消时执行以下清理：

1. 取消并释放当前渲染任务和预览节点。
2. 释放 `GFAssetSlot`，使旧观察者进入明确终态。
3. 丢弃 `GFResourcePropertyPatch` 和未提交的命令。
4. 不调用 `ResourceSaver.save()`，也不改写基准 Resource。

如果确认后的批量属性命令失败，它会按属性事务边界尝试恢复内存值；setter 的外部副作用和磁盘保存不属于该事务。项目工具应先处理命令报告，再开始保存或生成产物，避免把未确认或回滚失败的状态写出。

## 何时不使用

- 只需显示静态资源且没有交互调整时，直接渲染基准资源即可。
- 预览必须运行完整游戏逻辑、网络会话或第三方编辑器时，应由专用 Adapter 管理其生命周期，不要把这些副作用塞进 Resource 补丁。
- 参数量巨大或重建成本高时，项目可以实现增量预览 Adapter，但仍要保留“临时状态、确认命令、持久化”三段边界，并提供取消与过期结果防护。

这套组合只定义所有权和提交顺序，不规定面板布局、素材类型、shader 算法、粒子格式或项目业务字段。
