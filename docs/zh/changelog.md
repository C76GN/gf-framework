# 更新日志 (Changelog)

## [未发布]

**版本概述**：GF Framework 13.0.0 正在开发。新增可选并发通知，并降低了稳定画布和战术地图反复进行空间查询的固定开销。

### 🚀 新增特性 (Added)

- GF Native 新增多平台原生补充包，覆盖 Linux x86_64、Android arm64-v8a/x86_64 和 iOS arm64。业务沿用现有高度图、WFC 与 Data Batch 接口。
- 二维 WFC 的熵选格在安装 GF Native 的主线程上支持 Rust 加速，适用于最多 4096 格、128 种瓦片的地图。相同种子保留候选域顺序、步数和矛盾位置。
- 3D 场景摆放新增笔刷模式，按住左键预览多个位置，松手后可一次撤销或重做整笔。
- 二维曲线支持按给定参数保形切分三次 Bézier 段，并在指定距离误差和计算预算下求最近参数。
- 通知队列可配置多个活动名额。每条通知独立计时，结束后按等待优先级补位。项目负责通知的布局和动画。
- 2D 空间画布可从指定视图计算滚轮缩放目标，供项目累积滚轮输入并驱动缩放动画。

### 🐛 Bug 修复 (Fixed)

- 修复关闭编辑器时插件误删 `Gf` AutoLoad、导致下次直接启动游戏缺少单例的问题。显式禁用插件时才清理插件拥有的登记。
- 高度场在配置阶段校验样本，单点高度、法线和地表散布查询可直接访问相邻格点。RGB8 和 RGBA8 支持批量读取，安装对应平台的原生扩展后主线程自动使用 Rust 解码。
- 四方向等成本流场使用多目标广度优先搜索。噪声网格复用采样源和归一化所需的极值，Delaunay 插点会跳过后续点无法触及的外接圆，Voronoi 多边形按三角形邻接关系构建。
- 修复 Windows 桌面导出时禁用扩展的 GDScript 字节码仍可能进入 PCK 的问题。严格引用检查会在导出报告中给出错误，发布验收会核对同一策略结果并实际运行启用、禁用两种导出物。

- AI Developer Kit 现在能通过 `background work`、`job` 或 `thread` 找到后台计算服务，以及纯数据输入、协作取消和主线程写回的用法。
- 2D 空间索引在记录和配置稳定时复用四叉树及建树失败后的线性回退，只检查可能失效的弱对象身份。使用值 ID 的项目在连续点查、半径查询和框选时省去预处理阶段的全表扫描。
- 对象池支持同一节点同时作为挂载父节点和借用接收方，修复了重复连接 `tree_exiting` 的引擎报错。该节点在交付前离树时，请求以 `parent_lost` 取消。

### 🔧 API 变动说明 (API Changes)

- `GFCurve2DMath` 新增 `split_cubic_bezier()` 和 `project_point_to_cubic_bezier()`。输入采用同一坐标系中的绝对控制点，投影结果包含原始曲线参数和距离误差界。
- `GFNotificationUtility` 新增 `max_active_notifications`、`get_active_notifications()`、`dismiss_notification()` 和 `invoke_notification_action()`。
- `GFSpatialCanvas2D` 新增 `resolve_wheel_zoom_target()`，返回输入路由结果和受画布约束的缩放目标。

### 📘 升级指南 (Migration Guide)

通知队列默认继续串行展示，现有调用方式可直接使用。需要堆叠多条通知时，按[通知队列指南](standard/utilities/runtime/debug-observability/support-notifications/notifications.md#并发通知)设置活动上限，并用通知 ID 管理展示实例。

已安装 GF Framework 12.0.x 的项目可以继续使用当前版本。下一正式版发布后，请按对应的升级说明迁移。

需要从更早版本迁移到 12.0.0 时，请查阅该版本的[更新日志与升级指南](https://github.com/C76GN/gf-framework/blob/12.0.0/docs/zh/changelog.md)。

通用包、Windows x64 完整包和同版本原生补充包可从 [12.0.1 发布页](https://github.com/C76GN/gf-framework/releases/tag/12.0.1)下载。
