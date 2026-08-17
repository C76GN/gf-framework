# Kernel IDE 类型提示与编辑器访问器

这一页说明为什么 GF 推荐获取对象后立即用 `as Type` 断言，并概述脚本模板、访问器生成、编辑器类型索引和相关开发期工具。

## IDE 智能语法提示机制

GF Framework 特意设计为不需要向任何基类中注入具体的类型，所有的组件获取统一通过明确的入口方法（`Gf.get_system(...)` 等）完成。

结合 Godot 4 的静态类型特性，**强烈建议**在获取任何对象后立即使用 `as` 进行类型断言，这能激活完整的 IDE 代码补全：

```gdscript
# 在 Controller 中获取数据并更新UI
var player_model := Gf.get_model(PlayerModel) as PlayerModel
health_label.text = str(player_model.current_health)

# 触发业务逻辑
var battle_system := Gf.get_system(BattleSystem) as BattleSystem
battle_system.start_encounter()
```

启用插件后，编辑器菜单还会提供 GF 脚本模板生成、访问器生成、能力 Inspector 和节点状态机 Inspector；独立 `GF Workspace` 会提供状态、输入、存储、保存、流程、信号诊断、诊断和扩展等页面，并在编辑器打开时默认弹出，必要时可用“置顶”让工作区保持在其他窗口上方。启用插件会在缺少默认 GF ProjectSettings 时写入并保存 `project.godot`，禁用插件会移除指向 GF 的 `Gf` AutoLoad；如果项目临时关闭插件但仍要运行 GF，需要手动恢复 AutoLoad。插件主脚本只负责生命周期编排，ProjectSettings、AutoLoad、工具菜单、菜单动作、工作区窗口、Inspector/导出插件装配分别由 `addons/gf/kernel/editor/gf_plugin_*.gd` 内部辅助脚本承载。扩展级编辑器路径统一由 schema v2 的 `editor/gf_tool_contribution.json` 声明，核心插件只按启用状态动态装载，不在 `kernel` 中硬编码可选扩展 ID 或扩展内类型名；运行时 `gf_extension.json` 继续持有 `installer_paths`，工作区页面排序和短标签也继续由其中的 `editor_dock_order` 与 `editor_dock_short_label` 提供。无效 tool contribution 只形成 `partial`，不会使运行时 manifest 图失效。标准库自带的编辑器增强由 `addons/gf/standard/editor/gf_editor_contributions.json` 集中索引，文件型载荷仍放在声明贡献的包内，例如节点状态机模板位于 `addons/gf/standard/state_machine/node/editor/templates/`；维护门禁要求每条文件型记录的 `owner_package_id` 与目标文件唯一的物理包所有者一致。根插件通过 kernel/editor 清单读取器收集记录后传给辅助脚本装载；`kernel` 不直接 preload 标准库脚本，也不硬编码标准库类型名。脚本模板生成遇到已有文件会拒绝覆盖；访问器生成由 `GFAccessGenerator` 负责，可输出框架访问器或项目访问器脚本，减少手写 `get_model()` / `get_system()` 包装代码，默认会覆盖生成路径，工具调用方可通过 `overwrite_existing = false` 禁止覆盖。访问器只收集声明了 `class_name` 的脚本，Command/Query 没有 factory 时会走无参 `new()` fallback；需要构造参数的类型应注册 factory。项目常量访问器只采集命名层、项目保存的 InputMap 动作和 GF ProjectSettings 键；编辑器专用动作不会进入 `GFProjectAccess.InputActions`。编辑器侧生成脚本的缩进、section、文档注释和空行格式由 `GFSourceBuilder` 统一处理，项目自定义 generator 或扩展级访问器扩展也可以复用它来降低格式漂移风险。

类型扫描工具内部会复用 `GFEditorTypeIndex` 收集 `class_name` 脚本和能力场景；默认 index 只使用短生命周期缓存，不会隐式订阅 `EditorFileSystem`。长期持有的编辑器工具需要文件系统变更自动清缓存时，应调用 `enable_live_invalidation(owner)` 绑定工具自身生命周期；任务结束或 owner 退出时会通过订阅句柄断开信号，也可以显式调用 `dispose()` 释放 live 订阅并清空缓存。大型项目也可以用 `collect_scene_roots_extending(..., root_paths)` 限定场景扫描范围，并通过 `max_scan_depth` / `max_scanned_scenes` 调整默认扫描上限。需要在项目自定义编辑器工具里生成 2D 或 3D 资源预览时，可以复用 `GFThumbnailRenderer` 渲染 `CanvasItem`、`Node3D`、`Mesh` 或 `MeshLibrary` 条目缩略图；渲染尺寸会钳制到至少 1 像素，并在排队前拒绝单边超过 1024、总像素超过 1,048,576 或非有限 Canvas margin 的请求，等待队列最多保留 256 项。批量或可取消预览应通过 `GFThumbnailRenderRequest` 提交为 `GFThumbnailRenderTask`，并用 `cancel_render_task()` 或任务自身的 `cancel()` 中断；renderer 离开场景树时，等待与运行中的任务都会立即进入取消终态。`render_canvas_item()` 同时覆盖 `Node2D` 和 `Control`，常见 Sprite、Control、Polygon、Line、AnimatedSprite 和 2D 粒子可以自动估算边界；自定义 `_draw()` 或其他无法可靠推断范围的内容应传入来源局部坐标中的显式 `content_bounds`，屏幕空间 `CanvasLayer` 等不与 2D 相机共享坐标系的内容应由调用方提供预览专用布局。`render_node3d()` 和 `render_canvas_item()` 都会复制节点并加入内部 `SubViewport`；带运行时脚本副作用的场景应提供预览专用节点。开发期还可以直接调用 `GFSceneSignalAudit.audit_directory("res://")` 扫描 `.tscn` 中保存的编辑器信号连接，报告缺失节点、缺失信号、缺失方法和参数数量不匹配；目录扫描默认限制深度与场景数量，可通过 `max_scan_depth` / `max_scene_paths` 调整。运行时或调试工具可用 `GFSceneSignalAudit.build_signal_graph(root)` 生成当前节点树的信号连接图快照，默认也会限制节点深度和节点数，截断时报告中会标记 `truncated`。`GF` 工作区中的 Storage Viewer 页面使用本地文件系统访问，适合开发机排查存档，不应暴露给玩家 UI 或读取不可信路径。它们都是编辑器辅助能力，不参与运行时 `GFArchitecture` 生命周期。
