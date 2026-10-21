# 更新日志 (Changelog)

## [未发布]

**版本概述**：重做节点对象池的借还生命周期，解决物理碰撞回调中归还节点的引擎错误，以及弹幕复用时被提前回收的问题。调用方式统一为异步借用结果与一次性 Lease；不保留旧接口兼容层。新增场景组查询工具，可在编辑器中查找已保存的 Group 声明并定位来源节点。Flow 图编辑支持撤销与重做，Resource 表格支持只应用已编辑分量的多选属性编辑。运行期新增手动输入路由、有限存储读写预算、规范序列化测量与增量哈希、历史状态通知和字段输入会话。制作期统一 Project Layout 的 GDScript 分析权威与排除范围，开放有限数值 Tween 样机，并修正 AI 前置条件诊断和验证预算。本次为下一主版本的开发变更，尚未正式发布。

### 🚀 新增特性 (Added)

- [配置类型声明](standard/utilities/io/config-remote-outbox/config-provider/provider-schema/schema-declaration.md)新增嵌套结构、结构继承、Array、Map、枚举和多态资源；定义编译、规范化和类型访问器共用声明，循环、类型冲突、未知分支及超预算明确失败。[配置流水线](editor/tools/config-pipeline.md)支持结构列组、多行记录、转置、分层表头和显式多 Sheet 合并，保留嵌套字段与原始单元格定位；工作台和 CLI 可只读查看生效 Schema、来源及生成目标能力。
- [资源工作台](editor/tools/asset-browser.md#批量引用证据) 支持所选资源的批量直接依赖与入站引用报告，区分强缺失、UID 已解析但路径陈旧、弱引用、未观察到引用及覆盖不完整；整批共享预算，取消或上下文变化后不发布旧结果，不修改或删除资源。
- 新增 [GDScript 代码检查](editor/tools/code-quality.md)：项目显式采用预设或规则后，可在 GF Workspace 中检查当前编辑缓冲或已保存源码，按规则、位置和建议查看问题；配置在检查期间改变或失效时撤销结果。检查不会创建配置、改写源码或执行被检查脚本。
- [Tween 创作](extensions/action-queue/tween-config.md#在编辑器中创作) 沿用创建时选择的样机用途，支持步骤名称、串并行分组概览、时间块悬停与点击定位、结构化错误字段导航；新增淡入、强调和脉冲配方，以及通过 `duration_scale` 调整完整总时长的原生撤销操作。来源实例或内容变化后，旧时间块仍可查看冻结姿态，但不能误定位较新的步骤。
- [Flow 图编辑](extensions/flow/editor-model.md) 支持复制、剪切、粘贴和重复节点，并可从已保存的 `GFFlowNode` 资源创建独立副本。插入先准备完整候选，再提交一笔资源历史；只复制内部连接并重映射标识，空图起点遵守显式选择，切图或改图后的旧菜单与模板选择失效。
- 新增[资源服务域](standard/utilities/io/assets-jobs-warmup/resource-service-domain.md)：初始化时统一选择默认稳定绑定、受控排空切换或最多两代的在途切换；请求、取消与资源句柄始终归属原代。原生线程加载器仅支持稳定和受控切换，在途切换由经过准入的独立快照后端提供。
- [扩展管理器](extensions/editor-manager.md) 提供“保存设置”和“保存并应用”，展示真实的待应用、已应用、部分应用与失败结果；请求绑定设置快照，页面重建保留结果与未保存草稿。
- Dialogue 的[项目恢复示例](extensions/dialogue/recovery.md)区分相同内容快照、项目检查点与显式版本迁移；框架不推断内容映射或副作用重放策略。
- [Tween 数值时间线与自定义预览](extensions/action-queue/tween-numeric-preview.md) 提供只接收显式数值属性的冻结时间线，以及带所有者、容量和释放句柄的预览适配器与资源关联注册。Inspector 共用预览用途和属性目录，打开资源即可准备可定位快照；`gf.action_queue` 的 `extension_version` 升为 `2.9.0`。
- [Project Layout](editor/tools/project-layout.md) 支持显式声明生成证据和可丢弃目录的排除范围；排除在文件预算前生效，报告标注覆盖边界，必需源码、结构和配置来源不能被排除隐藏。
- [AI Developer](editor/tools/ai-developer.md) 支持最多 256 条有限验证检查，验证描述总量限制为 256 KiB、参数总数限制为 4096，并报告实际数量和对应上限。
- 输入映射支持完整初始化后的手动事件路由，由宿主管理输入、tick 与失焦清理，避免重复接收全局事件。
- 规范 Variant 序列化支持精确预算测量，以及快速和增量两个 SHA-256 入口；增量路径分块处理 Packed 数组，保持既有规范字节与字典排序。
- 命令历史提供有界的状态快照与变化通知，UI 可观察忙碌、成功、失败与容量变化，不必读取命令栈。
- 新增 [运行期控件输入会话](standard/utilities/runtime/settings-ui-scene/settings-display/form-binding.md#输入会话与提交边界)，保留数字原文与编辑基线，支持提交、取消及过期令牌检查；业务验证与撤销由项目管理。

- [GF Workspace](editor/workspace.md#打开与布局) 支持首次、每次或手动打开的个人启动偏好，记住最近页面、窗口尺寸和置顶状态；页面身份独立于显示标题，刷新贡献后仍可恢复选择。
- [任务首页](editor/workspace.md#任务首页) 支持搜索、收藏和最近任务；工具通过工作区上下文声明任务与资源接收动作，保留页面懒加载、扩展显式启用及旧贡献版本兼容。
- [工作区](editor/workspace.md#阅读工具状态与高级详情) 改善状态、输入、信号、诊断、存储及可选 Save / Flow 页的入门提示、资源与节点定位和高级详情展开；状态文字跟随编辑器主题，收起详情保留数据，原有表格、信号追踪和撤销行为继续可用。

- [Tween 创作](extensions/action-queue/tween-config.md#在编辑器中创作) 新增资源创建入口、类型化步骤编辑、原生 Undo / Redo 与可恢复的版本化预设；独立样机新增实际步骤时间条、过期提示和受控正反向及往返预览，运行时配置默认值保持兼容。
- [资源工作台](editor/tools/asset-browser.md) 新增默认项目来源、范围与类型筛选、分页缩略图、个人收藏和最近使用、显式共享目录标签、所选源 Resource 表格及依赖/引用详情；场景摆放源字段可接收原生资源拖拽。项目索引不加载全部资源，超出 10,000 项会要求缩小范围。
- 新增 [配置工作台](editor/tools/config-pipeline.md#从第一张表开始)：版本化新建预设、可运行样例、独立 Profile 草稿、Schema/索引/跨表引用表单、后台只读预览与小表预算预检，复用原有 Runner 校验、预览导出、事务提交和 CLI。类型化表头错误补齐真实来源坐标，实际验证前支持可选累计单元格预算，结果如实呈现严格写后失败与恢复状态。
- 新增 [项目初始化工具](editor/tools/project-bootstrap.md)：为空项目创建启动脚本、启动场景、空主场景及可选的空 Installer；初始化成功后才进入主场景。已有项目使用独立接入流程，保留原主场景和 Installer 顺序，提供初始化片段；所有创建操作先展示文件与设置变更，失败时按文件所有权补偿并报告恢复需求。
- [3D 场景摆放](editor/tools/scene-placement.md#连续摆放) 新增默认关闭的“连续摆放”选项：固定开始时的源场景、父节点和参数，每次确认分别提交独立 Undo / Redo，再等待新的有效指针命中；重复 Enter 不会复用旧位置。取消预览或编辑上下文变化会结束本轮，已提交实例保留，默认仍为单次摆放。
- [配置化 Tween](extensions/action-queue/tween-config.md) 新增可选运行时秒数定位、正向/反向播放与有限往返循环；通过显式共享的 `GFTweenReplacementScope` 接管同一目标的冲突属性，保持当前姿态并结束旧动作。连同步骤创作和受控预览，`gf.action_queue` 的 `extension_version` 升为 `2.7.0`。
- [虚拟列表](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/viewport-text-node-tools/virtual-list-model.md) 支持按复用分类混排不同模板；同一条目切换模板时保留事务检查、焦点交接与测量锚点，各类节点共享原有池总量上限，现有单模板绑定保持兼容。
- 新增 [Storage 大型结果的一次性领取](standard/utilities/io/storage-snapshot/read-results.md#大型结果的一次性领取)：通过专用句柄接收纯字典异步读取，迁移后保留一次交付隔离，通知与领取不再复制载荷；提供独立的小型诊断、取消及释放语义，普通读取保持兼容。
- [2D 空间画布](standard/input-flow/spatial-canvas-2d.md#已选条目的默认轮廓) 支持独立隐藏已选条目的默认矩形轮廓，便于项目使用自定义选中装饰，同时保留点选、框选、网格与放置预览。
- [本地 Storage 已提交版本](standard/utilities/io/storage-snapshot/committed-revisions.md) 支持显式 schema 2、离线升级、opaque revision 查询及同步/异步 JSON 和 Resource 实际读取配对；提交恢复、删除重建和 family reset 保持代次一致，显式创建中断后可安全重试空布局前缀或一致完整的 pending，布局检查和 pending 恢复包含隐藏文件证据，默认 schema 1 不自动升级。
- [Storage catalog 查询](standard/utilities/io/storage-snapshot/catalog-query.md) 支持区分成功空集合、查询失败和返回数量截断；完整性绑定本次逻辑查询范围，旧文件列表接口保持兼容。
- [配置字段校验](standard/utilities/io/config-remote-outbox/config-provider/validation-importer/validation-rules.md#数组逐元素校验) 支持为一维 Array 单独声明元素规则，复用范围、正则、白名单、资源路径和本地化 key 校验；错误保留原字段、元素下标和值，并共享本次验证的工作量与资源探测预算。
- [周期输入脉冲](standard/input-flow/input-assist/input-modifiers-triggers.md#周期脉冲的首次等待) 支持独立首次等待，可在按下立即响应后等待较长时间，再按较短间隔重复；动作和玩家保持独立计时。
- [配置化 Tween](extensions/action-queue/tween-config.md#自定义缓动曲线) 支持步骤级原生 `Curve`，可制作回弹与超调效果；运行时独立捕获曲线，Inspector 预览与时间定位使用同一配置快照。
- 新增 [方格视野查询](standard/foundation/grid-spatial/grid-2d-hex/grid-math.md)，通过显式阻挡回调计算有限半径内的可见格，返回稳定顺序与失败诊断；视野不接管地图节点、探索记忆或阵营规则。
- [Tween Inspector 预览](extensions/action-queue/tween-config.md#在-inspector-中预览) 支持时间滑条与秒数定位，可反复检查同一配置快照的中间姿态和动画终点；定位仅操作工具自有样机，并保持暂停。
- [模板列表](standard/utilities/runtime/settings-ui-scene/settings-display/list-repeat-binding.md#按稳定-id-更新模板列表) 支持调用方提供稳定 ID，按条目复用、更新、移动和释放节点，保留普通 Container 布局及未被项目回调重置的局部交互状态。
- 新增 [2D 多目标取景 Rig](extensions/camera/camera-2d.md#多目标共同入镜)，根据目标锚点、实际相机输出尺寸和像素留白计算中心与缩放，复用现有 Director 的优先级与混合，并报告缩放约束是否影响共同入镜。
- 新增 [Network 请求与回复关联](extensions/network-turnbased/network-transport/request-correlation.md)：独立的有界 Tracker、一次性 Handle 和隔离响应结果，支持同步回包、指定 peer 与会话隔离、超时及本地取消；协议编码与网络生命周期由项目显式接入，`gf.network` 的 `extension_version` 升为 `7.1.0`。
- 新增 `GFObjectPoolAcquireResult` 与 `GFObjectPoolLease`。成功借用取得独立使用权，归还立即失效，`wait_settled()` 可重复等待实际离树或淘汰完成。
- 节点根脚本可实现同步 `on_gf_pool_prepare(context) -> Error`，在每次入树前准备本次数据；空闲实例完全离树。
- 新增 `GFProjectileEmissionResult`，用单次 `await` 的返回值表达整批发射结果。
- 新增 [Scene Groups 场景组查询](editor/tools/scene-groups.md)。从已保存的 `.tscn` / `.scn` 查找持久化 Group 声明，支持搜索、分页和来源节点定位；扫描取消、读取失败或预算耗尽时明确报告结果不完整。
- 新增 [3D 场景摆放](editor/tools/scene-placement.md)：显式选择 PackedScene 与父 Node3D，在原生 3D 视口中进行平面或碰撞表面拾取，支持切向网格、法线、锚点、线框代理预览与单实例 Undo / Redo。
- [Flow 图编辑器](extensions/flow/editor-model.md) 的连线、删除节点与布局编辑接入 Godot 撤销/重做，删除节点时一并恢复关联连接与布局，一次拖动对应一次编辑动作。
- [Resource 表格](editor/resource-table-editor.md) 支持多行选择、属性混合值呈现和暂存编辑；应用时只修改实际编辑的分量，取消或切换选择会丢弃暂存输入。
- [配置跨表引用](standard/utilities/io/config-remote-outbox/config-provider/relations-builds/indexes-references.md#数组元素引用) 支持逐项校验一维 Array 中的标量键；错误保留原字段名、元素位置和值，导表继续附加可用的来源与单元格位置。
- [配置化 Tween](extensions/action-queue/tween-config.md#在-inspector-中预览) 新增 Inspector 预览，支持独立 2D、UI、3D 样机、初值调整、播放、暂停、停止和复位；复用现有配置与缓动，预览不修改当前场景或源资源。

### 🔄 机制更改 (Changed)

- [配置导入](standard/utilities/io/config-remote-outbox/config-provider/validation-importer/json-csv-import.md#工作预算与批次)、[表合并](standard/utilities/io/config-remote-outbox/config-provider/relations-builds/merge-profile.md)和[配置流水线](editor/tools/config-pipeline.md#构建工作预算)采用有限工作预算，复用通用执行预算并累计输入、遍历、载荷与输出成本。非法限额、循环或超限明确失败，合并与构建失败不交付可用半成品。正式指南补齐配置激活、事务提交、页面会话与决策复现的项目接入边界。
- 配置预算覆盖 NodePath 载荷及 XLSX 裁剪、覆盖前的单元格文本，XML 根深度统一为零。构建与导出按实际消费的选项准入；失败保留来源与读取收据，自定义合并策略获得隔离的记录容器，文本 Layout 收到真实 UTF-8 大小。

- 精简资源解析、音频会话和编辑器类型索引的缓存处理；统一 Save 的证据校验与 Feedback 的波形采样实现，保留校验预算、状态推进和既有采样结果。
- [Flow 图编辑器](extensions/flow/editor-model.md) 在原生撤销或重做回调失败后暂停同一历史中的 Flow 写入，并提供“重置撤销历史…”确认入口；清除实际共享范围内的 Undo / Redo 记录，保留当前内存资源值，不自动保存。资源、上下文、可见性或历史变化使旧确认失效；未完成的属性补偿仍须先恢复。
- 统一框架源码、测试及生成模板的结构排版：两个简单项保持同行，三个及以上参数、元素、字段或布尔项按层展开；单项及复杂子表达式按内部结构决定布局，不以名称或字符串长度换行。补齐声明、索引、调用链、普通分组、回调正文和成员间隔的一致性，保留必要的优先级括号、注释、字符串内容与执行行为；简单字符串拼接、单值格式化和单层条件选择保持紧凑，嵌套条件按层展开。
- [Spring Math](standard/foundation/grid-spatial/spring-math.md) 的四个步进入口统一拒绝非有限输入和非有限最终结果，返回空字典并发出一次明确诊断；调用方应先检查结果，再写回 value 和 velocity。有限非正 delta 保留原状态，正常结果仍只有这两个字段。
- [自定义 Action](extensions/action-queue/visual-actions/custom-action.md#结束等待与自然成功) 明确结束等待与自然成功的区别，以及等待令牌取消和实际任务取消的各自所有权。
- [Tween Inspector](extensions/action-queue/tween-config.md#在-inspector-中预览) 共用预览用途、初值和 Steps 属性目录，新增轻量资源路径关联；打开资源按声明或唯一兼容候选自动准备，歧义明确选择，首次接纳的用途在本次编辑中保留。准备与播放分开，未播放的合法编辑自动更新静态计划，已播放或定位的有效旧会话可继续并提示过期，新配置无效不替换旧快照。
- Project Layout 的规则准入、九类规则与 zone 评估、来源捕获和分析统一由 GDScript 会话执行。配置升级为 schema 2；编辑器无需额外解释器，项目声明锚定实际来源根，切换扫描目录不能重新解释原有排除。
- AI Developer 的契约升级为 schema 6，分别声明包源码存在与项目采用限制；快照与工具协议升级为 v10。无效前置输入对应的源码或政策状态明确标记为未知，报告保留根因，只有证据充分的问题进入可执行计数。
- Dialogue 将结构编译与生产 Runner 构建分开；生产成功包含完整内容身份与预算准入。行为树把执行错误与普通失败分开，组合节点默认传播错误，只有显式恢复节点处理指定原因，中止与业务失败仍保持原有语义。
- Storage 的业务文件与解析前明文默认分别限制为 64 MiB；字典保存先检查完整明文和最终编码文件，再提交同一份字节，避免保存成功却超出本请求两项字节预算。项目可显式调高正数上限，预算失败不会获得损坏文件的重置授权。

- 项目初始化工具移除默认计数器模板及其全局类型声明，新项目默认目录改为 `res://app/`；README 按需生成，生成后的入口与 Installer 属于项目源码。框架升级不重写项目源码，Model、System 及可选能力继续通过已有模板和所属工具添加。
- Flow 与 Save 新增工作区公开任务，对应 `extension_version` 分别升为 `4.1.0` 与 `6.4.0`；扩展的框架发行版本仍与 GF Framework 一致。
- [资源工作台](editor/tools/asset-browser.md) 的默认文字搜索合并连续输入，以单个可取消工作线程完成评分和排序，分批准备候选、解析当前页身份及建立卡片；查询期间旧资源动作失效，隐藏实际工作区窗口、目录变化和上下文撤销均阻止旧结果发布并回收线程。同步浏览模型接口保持兼容。
- [资产目录](editor/tools/asset-browser.md#目录快照边界) 将完整条目查找表与按需字段索引分开；空白分页只构建当前页，默认文字分页只为当前页解析资源身份，保留完整验证、复制隔离、强制重建与实时 UID 语义。
- 全面补充框架私有声明及适配器模板的维护说明，明确资源所有权、事务恢复、取消与重入边界，并区分文件私有实现、内部协作入口及受保护重写点；参考文档补充行为树调试子节点重写钩子和节点序列化属性规格校验辅助方法。
- 补齐 Tween 创作、资源工作台、配置工作台和项目初始化的私有维护说明，以及发射体运动与网络指标重写点的实现契约；源码与生成模板统一检查声明文档、参数及布局，持续拦截新增漏写。Signal 订阅令牌的来源查询说明明确为诊断身份缓存，取消或来源释放后仍可保留，不代表订阅活动或来源存活。
- [GF Workspace](editor/workspace.md) 首次打开只创建当前页面，其他页面首次访问时创建并缓存；切页和重新打开保留已访问页面状态。扩展引用审计改为点击“扫描引用”后执行，选择或文件变化会明确标记旧报告失效，导出阶段保留独立审计。

- [开发者控制台](standard/utilities/runtime/debug-observability/developer-console/window-builtins.md) 的内置命令显示完整用法，并在参数数量、整数范围或节点路径无效时报告原因并停止操作；修正方括号转义，保持项目命令的原始参数与回调派发语义。
- [开发者诊断](standard/utilities/runtime/debug-observability/runtime-telemetry/log-utility/index.md#开发者诊断与语言) 统一使用固定英文模板与稳定诊断码，保留原生错误与警告的严重级别、输出次数和调用栈；项目日志及运行时 Unicode 上下文继续保留原语言，编辑器显示文字独立管理。
- [命令历史](kernel/messaging/command-history/index.md) 补充拖拽编辑示例：预览只修改草稿，确认执行一次命令，取消或净变化为零不产生历史；明确 `record()` 与 `execute_command()` 的使用边界。
- [Storage 读取结果](standard/utilities/io/storage-snapshot/storage-utility.md) 减少隔离副本的中转深复制，迟到结算诊断只读取失败分类；保留结果归一化、来源授权及公开 getter 与信号的副本行为。
- [3D 场景摆放](editor/tools/scene-placement.md) 确认失败时显示具体原因与排查建议，并保留原始原因标识和错误码，便于区分父节点失效、实例创建失败及撤销记录被拒绝等情况。
- [调试指标序列](standard/utilities/runtime/debug-observability/debug-visual-inspection/debug-overlay.md) 的 sparkline 只归一化实际显示的最新采样，减少长窗口的绘图开销；统计与归一化范围仍使用全部保留采样。
- 补充 [2D 噪声场](standard/foundation/grid-spatial/noise-field-tools.md#分块采样与共享边缘) 的世界坐标分块与共享归一化范围示例，说明如何保持公共边缘一致，以及逐块归一化为何可能产生接缝。
- [缩略图渲染](editor/non-destructive-live-preview.md) 默认使用静态预览副本，避免复制项目脚本、持久化信号连接和场景组；需要脚本自绘的工具须显式选择可信动态预览，并负责预览脚本的副作用。
- 对象池统一在主线程安全点挂载、离树和清理。节点自己的 `_enter_tree()` / `_exit_tree()` 负责进入与退出生命周期，池不再递归改写节点处理、物理、可见性或 Controller 事件开关。
- 预热统一为 `await prewarm(scene, count, batch_size, cancellation_token)`，只分批实例化离树缓存，不触发入树生命周期，也不执行 prepare。
- 弹幕以整批借用完成后再绑定本次生命周期，使用 Lease 归还；`gf.combat` 的 `extension_version` 升为 `4.0.0`。
- 普通音效使用音频服务自己的播放器缓存，保留同步播放和现有音频 Handle 接口，不依赖异步节点对象池。
- Workspace 向需要编辑的贡献页面注入通用编辑器上下文，并在页面移除时撤销。独立创建的 Flow 面板须显式提供上下文后才能修改图资源。

### 🐛 Bug 修复 (Fixed)

- 配置类型编译与复制按每条引用路径检查共享子树深度；无效结构声明不会被允许空值掩盖，结构规则定义错误只报告一次。诊断复用统一上下文编码并保留调用方字段前缀；工作台拒绝无法复制的显式 Schema 时保留原草稿，不会退回自动推导。
- [GDScript 代码检查](editor/tools/code-quality.md) 的成员间距判断与文档绑定统一识别文件和 Inspector 分组元数据，修正分组下方已有字段文档时的间距误报；分组内的间距和字段注解规则保持不变。
- Tween 错误定位在表单布局后显露目标输入，避免字段获得焦点却仍处于 Inspector 可视区之外；失效请求不滚动新表单或夺回用户焦点。
- [Tween 创作](extensions/action-queue/tween-config.md#在编辑器中创作) 在新预览计划可用后同步“完整总时长”初值，避免首开资源时误显示为 0.001 秒；同一计划的刷新与定位保留尚未应用的输入。
- 维护命令在处理日志前校验参数，避免历史日志积累拖慢参数错误反馈。
- [Tween Inspector](extensions/action-queue/tween-config.md#在-inspector-中预览) 只缓存作者明确编辑的初值覆盖；同一用途的关联或适配器重新注册后，未编辑属性采用新的声明与默认值。样机创建或初始化失败后可直接点击“重新准备”重试，后台刷新不反复执行失败的创建钩子。
- [Flow 图编辑](extensions/flow/editor-model.md#编辑上下文与资源生命周期) 在过期插入动作的撤销被拒绝时保留外部编辑，并明确显示失败及原生历史位置失配；本次操作错误与底层属性事务报告分别呈现，零写入结构拒绝不冒充补偿恢复任务。
- [Flow 图编辑](extensions/flow/editor-model.md) 通过路径栏刷新重载时撤销已有菜单和模板选择的提交资格，防止旧对话框把节点插入后来加载的图。
- 资源快照后端接受尚未登记到 Godot UID 表的逻辑 `uid://` 键；在途切换期间，Asset 的路径引用计数查询与释放通知汇总全部存活代次，保留各代独立的释放授权。
- 扩展模板缺少或留空类型时，编辑器应用报告明确记录问题并显示部分应用；同实例 Utility 替换保持幂等，真正取得新生命周期所有权时仍执行准入检查。
- Dialogue 恢复精确快照时，在修改上下文前拒绝缺失字段、错误类型及运行状态与当前行不一致的数据；真实 JSON 往返的合法快照继续可恢复。行为树缺失必需子节点不会再被总是成功装饰器吞掉。
- 扩展管理器的组合文件路径先保存为页面草稿；撤销上下文后拒绝已打开文件选择器的迟到回调，防止页面失去权限后仍修改全局设置。
- 修正优先队列在显式负顺序值下的队首插入，嵌套 Schema 校验失败后停止执行附加规则；CSV 未指定列顺序时按 Schema 声明顺序导出。
- Resource Broker 在架构正常关闭期间继续有界处理已接收请求并拒绝新请求；音频句柄释放时解除所有者退出订阅。Storage 在递归规范化前完成结构预算检查，超限输入明确失败。
- Inventory Transfer 与普通堆叠使用相同的回调准入规则；VisualAction 的有限非正 Signal 超时关闭计时。Capability Recipe 失败回滚会恢复复用实例原有的激活及顶层归属状态，且不会覆写回调中新建的替代实例。
- Input 编辑器使用独立磁盘快照，避免诊断加载覆写其他位置持有的未保存资源；嵌套输入资源变化和撤销会刷新诊断与树。扩展管理器明确区分配置已保存与编辑器贡献已刷新。
- 场景摆放保留以独立旋转、缩放属性保存的根变换及场景继承覆盖，预览与实际摆放一致；XLSX 空共享字符串保持原始索引，网络契约生成的有限浮点默认值保持双精度数值不变。

- 修复非工具脚本 Resource 在 Inspector 占位模式下，把省略的 Tween 时长缩放与步骤时长读成零的问题；显式导出默认值与运行时一致，资源中显式保存的零仍表示瞬时完成。
- 修复 AI Developer 在契约或能力目录不可用时，衍生出大量缺能力建议的问题；一次上下文构建复用同一份已捕获的前置输入。
- 修复 Project Layout 将声明的子目录捕获范围错误绑定到项目根的问题；省略实际捕获根时由已编译声明推导，显式不一致的根仍拒绝。
- 控件输入会话取消时核验实际值与原文是否恢复到基线，原生范围或选项变化导致恢复失败时如实返回失败；SpinBox 的延期文本校正不会覆盖宿主后来修改的数值。

- 修复资源工作台按路径扩大所选资产身份的问题，以及编辑标签和备注时丢失已有共享条目的自定义字段；目录和条目 Resource 支持从磁盘重新打开后的编辑器操作，选择、Undo / Redo 和显式保存保留各条目的独立数据。
- 修复配置工作台无法删除空来源的问题；Profile 保存清理恢复成功后正确完成该次保存记录，同时保留恢复期间的新修改与外部文件冲突检查。
- 项目初始化工具校验 `Gf` AutoLoad 的真实路径或 UID 与单例状态；相关设置、模板内容或磁盘配置变化使旧预览失效，创建时不接管同名冲突。
- 修复刷新 GF 编辑器贡献时遗漏任务及资源动作记录的问题；有效接收结果保留工具的状态、原因及完整结果副本，嵌套路由和回调中刷新不会混用旧报告。
- 修复工作区贡献发现与资源动作筛选的边界：单文件超限贡献不会挤占后续扩展预算，重复页面路径保留首条记录的所属模块，自定义资源类按声明的继承链匹配原生资源类型。
- 修复贡献刷新丢失源资源表格保存基线的问题：资源与配置工作台的未保存页面保留原实例，撤销贡献后保留只读草稿，恢复同一来源及脚本路径后重新绑定上下文；容量拒绝不丢弃既有修改，保存仍须显式执行。
- 补齐扩展贡献 schema 3 返回记录及默认值文档，明确 schema 2 的既有返回形状与失败数据不可消费的约束。
- 修复资产目录零匹配页错误展开全部摘要的问题：文字无匹配或过滤 ID 全部缺失时，候选、ID、摘要和浏览模型条目均保持为空。
- 修复配置化 Tween 在中途 `finish()` 时重复叠加相对偏移的问题；串并行与有限循环推进到本次执行的真实终点，不补发跳过的标记，setter 重入后旧动作不再写入新会话。
- 修复 typed JSON 编解码的原子类型预算不对称，并恢复 Dialogue 自定义上下文的反序列化覆盖契约；恢复先完成会话校验，再提交上下文与位置。
- 修复并行任务组错误推进已独立重新调度的子任务、输入批量清理回调后的旧完成事件，以及动作队列重入清空后的重复排空通知。
- 生成文档事务回滚只清理本次成功安装且身份仍匹配的目录；并发替换的目标和无法安全恢复的旧备份会被保留。

- 修复 NodeContext 将正常跨帧关闭误判为失效的问题；强制销毁会终止旧关闭遍历，扩展设置保存失败会保留明确的失败提示。
- 修复状态机、任务组、输入序列、触控、拖放、平台初始化、UI、音频、行为树、Buff 与网络接管在同步回调重入后继续使用旧状态的问题；旧注册 token、句柄和绑定不能影响新一轮实例。
- 修复 Asset、HTTP、Job 和 Storage 通知中的取消与结果归属，以及日志批次确认、活跃日志保留、诊断 provider 和调试观察器的生命周期处理。
- Save 与 Dialogue 的可恢复数据使用明确的编解码完整性结果，预算耗尽、循环或不支持的值不会作为成功快照提交；Save 属性恢复先检查完整白名单，回滚保留采集时的引用根。
- Flow 的节点与 Context 在同步执行中共享当前运行态，交替写入、清空和恢复不会被旧快照覆盖；有向图连接拒绝方向反转的端口。Inventory 的全量添加失败保持原槽位，Feedback 的容量淘汰不会追逐回调中新建的播放。
- 修复循环单字段 schema、超大 Deque 请求、字幕空结束时间、标签恢复与层级计数、投影键和默认值，以及大额定点加减和显示精度边界。
- 修复四叉树无进展分裂、空间查询预算回退与闭边界候选、RegionMap 删除标记、单 tile WFC 邻接验证，以及浮力法线在剪切变换下的计算。
- 修复配置合并覆盖原键、验证预算丢失错误、Config Pipeline 跳过 warning、嵌套目录约束、LSP 编辑的读取预算和精确路径大小写、生成脚本符号冲突，以及工具报告来源和取消提示。
- 修复生成文档事务在中断时的回滚、无语言围栏解析、显式缺失样例目录和 schema 注释校验；验证输入检测捕获期间的文件漂移，库存枚举在收集时执行预算检查，文件门禁拒绝阻塞式特殊文件替换。AI Developer 的快照输出、计划读取及反馈提交重新核验对应边界。

- [Modal 聚焦回调](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/modal-protocol.md) 转交焦点后保留面板内的有效目标；同一面板关闭后重开会终止旧聚焦与打开通知。[焦点顺序](standard/utilities/runtime/settings-ui-scene/settings-display/control-focus-order.md) 的零步查询在当前控件失去资格时返回空，不再意外选中其他控件。
- [Modal 自动聚焦](standard/utilities/runtime/settings-ui-scene/ui-stack-routing/ui-stack-modal/modal-protocol.md) 跳过隐藏祖先、递归焦点禁用、禁用按钮和待释放目标；打开聚焦在面板显示后执行，返回值与实际焦点修正一致，并在聚焦回调关闭或替换面板时停止原目标遍历。
- 静态缩略图保留九宫格边距、3D 绘制标志、灯光参数及 Mesh 表面材质覆盖，读取节点名称时也不触发来源脚本；MeshLibrary 任一待生成条目失败时整项计划失败并保留条目原因，避免应用部分预览。
- 配置数组在类型转换前的元素准入也受共享预算约束，非法记录消耗已预留额度，超限时不扫描数组或批量生成逐元素诊断。
- 修复独占 Storage 读取误拒绝未使用的默认值与有限 `Projection`；回执准确区分尚未获取的版本/revision 和实际读取的诊断，保留普通读取结果的兼容行为。强类型默认值的预检共享预算，并在赋值前拒绝不兼容类型和非法颜色文本。
- 缩略图视口在 Compatibility 渲染器下不再请求引擎尚不支持的 2D MSAA，避免每次预览产生警告；其他渲染器保留现有抗锯齿设置。
- 开启类型转换后，声明了元素规则的数组会在记录深复制前拒绝嵌套或自引用元素并报告原始下标，避免提前触发脚本栈上限；自定义字段与元素规则的公开上下文集合保持相互隔离。
- 修复通用数值输入在未声明范围时截断负数和大值的问题；多行 String 使用保留换行的文本框。Resource 表格重新绑定资源后，旧撤销/重做动作产生的自动保存失败仍会通知调用方，同时保留当前草稿。
- 修复深复制丢失 Array/Dictionary 类型约束，导致属性事务无法写入类型化节点或连接集合的问题；副本保留集合类型、循环结构和默认 Resource 引用身份。
- 场景组查询在扫描期间拒绝重复启动，保留已有进度和结果；翻页取消节点定位时同步清除等待提示。
- 修复在 `Area2D` / `Area3D` 碰撞回调中归还对象时同步改变场景树或物理节点状态的问题。
- 修复弹幕第二次使用池中实例时，旧绑定把正常重新挂载误判为实例丢失的问题。
- 修复批量弹幕中前一枚的通知回调破坏后一枚候选后，仍对失效候选发布启动通知的问题；每个用户回调边界重新检查整个批次。
- 陈旧 Lease、重复归还和归还完成回调不能撤销同一节点的新借用；父节点丢失、prepare 失败和池销毁会回收未交付候选。
- 修复架构关停或替换对象池时未等待安全点清理和全部终态通知的问题，包括通知回调重入关停的情况。
- 借用必须绑定接收方，修复临时调用方在等待期间销毁、但常驻父节点仍存在时留下无人接收节点的问题；交付后的 Lease 仍由业务明确归还或转交。
- 批量挂载前检查候选是否已被前一候选的生命周期回调重新挂载，避免重复 `add_child()`；调试快照不再把排队删除或已被挂载的空闲记录计入可用库存。
- 修复大量分批预热时后续批次反复插队，使已接纳的借用或归还长期等待的问题。
- 修复节点在意外离树回调中先归还 Lease 后被误判为正常归还并重新缓存的问题；补全借用结果的 `invalid_owner` 原因说明。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除源码仓库的 `examples/` 独立示例及其专属测试、检查和文档入口，保留框架自身的回归测试、按需装配说明与[多目标错峰动画用法](extensions/action-queue/visual-actions/staggered-targets.md)。
- 退役已停止建设的外部 Reference 工程同步流程及其专属配置与验证。外部工程、备份与业务资源不受操作，共用事务、预算和回滚能力继续保留。
- 删除 Project Layout 的 Python 规则解释器及 legacy、shadow 迁移模式；维护命令只负责把输入交给同一个 GDScript 会话。
- 移除同步节点借用、按裸节点归还、`before_add` 回调及池专用节点启停钩子。
- 移除 `GFObjectPoolPrewarmOperation` 及其 `progressed` / `completed` 信号和多套预热入口。独立公开的弹幕发射策略 Task 改为内部实现。

### 🔧 API 变动说明 (API Changes)

- 配置列新增 `type_definition`，非空时作为复杂字段的类型权威；`GFConfigTypeDefinition` 提供有界定义编译、规范化和隔离复制。Schema 的校验结果新增成功规范化 `data`，失败时为 null；复制声明失败返回 null，不再把失败声明当作未指定 Schema。新增 `inspect_profile_path()`、CLI `inspect` 和访问器目标能力描述。
- Project Layout 只接受 profile、snapshot 和 analysis 的 schema 2；旧 profile schema 1 和 `--profile-mode` 选项已移除。声明范围、来源根与保护集合进入分析身份，不能把旧报告拼接成新报告。
- 新增 `GFTweenNumericTimeline` 数值捕获与采样接口，以及 `GFTweenPreviewAdapter`、注册目录和一次性注册句柄；内部播放计划继续作为实现细节。
- AI Developer 只接受项目契约 schema 6，使用 `framework.package_presence` 与 `framework.package_usage` 两组闭合规则；输出 snapshot v10，工具协议为 `10.0.0`，保留未知来源和未分类政策的统计。
- `GFDialogueTextCompiler.compile_text()` / `compile_source()` 移除，改为明确的 `compile_structure_text()` / `compile_structure_source()` 与 `build_runner_text()` / `build_runner_source()`。`GFBehaviorTree` 新增执行错误状态与显式 `RecoverError` 节点，不能依赖 Selector、Inverter 等把执行错误改写为业务结果。
- 新增 `GFResourceServiceDomain` 与 `GFResourceSnapshotBroker`；Asset 可绑定稳定服务域，直接 Broker 引用只享有固定绑定。活动域与 Broker 拒绝架构内替换或注销；需要更换时使用域协议或关闭重建，不能通过修改配置切换模式。
- `GFStorageUtility` 新增 `max_read_bytes`；`GFStorageCodec.max_decompressed_bytes` 及同名选项改为统一的 `max_decode_bytes`，同时约束压缩与普通文件的解析前明文及编码时完整文档明文。两项预算均默认 64 MiB 且须为正数；异步读写使用入队配置快照。新增 `GFStorageCodec.encode_result()` 闭合的 `{ok, error, bytes}`；`GFStorageReadResult.FailureKind` 和 `GFStorageAsyncResult.WriteFailureKind` 新增 `LIMIT_EXCEEDED`，压缩解码无法区分损坏与限额时保守拒绝重置授权。明文字节预算不等同于 Variant 堆内存上限。
- `GFInputMappingUtility` 新增 `automatic_input_routing`，关闭时仍正常执行初始化与依赖生命周期。
- `GFDeterministicVariantSerializer` 新增 `measure_canonical()` 与 `sha256_incremental()`。`sha256()` 在预算预检后构建规范树并使用原生快速哈希；增量入口分块编码与哈希，避免构建整棵规范树及完整 JSON。两者保持相同规范摘要与预算合同；增量路径的字典键排序仍保留规范键文本。
- `GFCommandHistoryUtility` 新增 `history_changed`、`get_history_state()` 与 `is_processing_operation`；通知期间只允许生命周期失效，拒绝历史修改，防止同步回调重入。
- 新增 `GFControlEditSession`，提供控件弱引用、会话令牌、原文快照、提交和取消边界，不接管焦点、输入事件或模型。

- `GFVirtualListBinder.bind_with_reuse_keys()` 新增分类回调与接收 `StringName` 的 factory，同步时分类无效的结果状态为 `GFVirtualListSyncResult.STATUS_INVALID_REUSE_KEY`；原 `bind()` 继续使用无参 factory，无需迁移。
- `GFVariantJsonCodec` 新增 `variant_to_json_compatible_result()` 与 `json_compatible_to_variant_result()`，返回 `{ok, value, error}`；诊断投影入口继续表达不同的输出用途。`GFDialogueContext.deserialize_values()` 返回 `bool`，失败保持原值。
- `GFSpatialHash3D.can_query_aabb()` 提供不生成候选列表的查询准入检查，空间查询 facade 在哈希预算不足时使用线性查询。
- `GFPlatformAdapter` 首次注册后冻结身份和契约配置；自定义输入序列 runtime 必须提供单调的 action edge revision。`GFNetworkBackend` 新增 protected `_reset_transport_connection()` 供传输层先提交断开状态。
- Config Pipeline 的生成 manifest 升为格式 2，并绑定验证摘要；有 warning 的输出重新验证。Content 自动导出合并同一物理文件的资源引用，在 `metadata.references` 保留逻辑引用列表。

- `GFSpatialCanvas2D` 新增 `set_selected_item_outlines_visible()` 与 `are_selected_item_outlines_visible()`；默认开启，支持入树前配置，切换不改变选择状态或选择信号。
- 新增 `GFStorageUtility.query_catalog()` 与不可变 `GFStorageCatalogResult`，提供 Error、失败阶段、排序文件副本及范围内完整性；查询保留同步 drain 和全 root 恢复，不改变存储格式，也不提供 payload revision。
- `GFConfigTableColumn` 新增 `element_validation_rules`，仅用于 `ValueType.ARRAY`；原有 `validation_rules` 继续接收整个字段。`GFConfigTableSchema` 新增每次验证共享的元素数与元素规则调用预算，定义自检、复制、构建过滤及编辑器描述同步支持元素规则。
- `GFThumbnailRenderRequest` 新增 `PreviewMode`，Node3D / CanvasItem 请求和渲染便捷方法增加末尾可选模式参数，默认 `STATIC`；`TRUSTED_DYNAMIC` 用于工具自有的受控脚本预览。
- `GFInputPulseTrigger` 新增 `initial_delay_seconds`，默认 `-1` 沿用 `interval_seconds`，`0` 表示激活当次触发一次。激活时已发出脉冲才忽略当次 delta；每次更新最多返回一个脉冲，不补发跨过的多个周期，也不改变动作开始事件的状态转换语义。
- 新增 `GFGridVisibilityMath2D.compute_fov()`，显式接收网格范围、观察格、半径和遮挡规则；输入或查询失败时返回空的可见集合，保留既有两点视线查询合同。
- `GFRepeaterBinder` 的模板同步支持 `identity_callable`，新增 `sync_container()` 提供结构化同步结果；自动刷新失败通过 `synchronization_failed` 通知。稳定 ID 更新验证重复键、克隆所有权和同步重入，不把项目回调副作用作为可回滚事务。
- 新增 `GFCameraFramingRig2D`。2D Rig 的 `get_camera_pose()` 和 `get_camera_pose_data()` 增加可选 `Camera2D` 参数，Director 显式提供目标相机；自定义覆盖需要同步签名，`gf.camera` 的 `extension_version` 升为 `3.0.0`。
- `GFObjectPoolUtility.acquire(scene, parent, lifetime_owner, context = {})` 现在需要 `await`，返回 `GFObjectPoolAcquireResult`；必填的 `lifetime_owner` 通常传 `self`，与挂载父节点分离。成功后用 `get_lease()` 获取 Lease，再以 `get_node()` 访问节点。
- `pool.release(node, scene)` 改为 `lease.release()`。首次归还返回 `true`，此时 `get_node()` 已返回 `null`；等待离树请使用 `await lease.wait_settled()`。
- `prewarm()` 不再接收父节点，返回 `GFObjectPoolPrewarmResult`；结果包含最终状态、原因、请求数与实际创建数，取消不会回滚已缓存实例。
- 同名 `GFObjectPoolPrewarmResult` 的状态、原因与计数接口也有破坏性调整；`COMPLETED` 改为 `SUCCEEDED`，容量拒绝合并为 `PARTIAL`，池销毁合并为 `CANCELLED`。旧原因常量和细分计数不再保留，详见对象池指南的迁移表。
- 删除弹幕旧同步单发/多发入口与直接节点返回值，统一使用 `await emit_pattern()` 返回 `GFProjectileEmissionResult`。移除 `use_object_pool` 开关和 Emitter 预热包装；需要复用时设置 `object_pool_utility`，预热直接调用池。
- `dispose()` 立即拒绝新借用并撤销所有 Lease，清理在安全点执行；需要等待时调用 `await pool.wait_disposed()`。该等待包含已接纳请求与 Lease 的终态通知，不保证引擎已完成 `queue_free()`。注册到架构的池参与正常异步关停与替换的静默期等待。
- 保留已有接口的首次发布 `@since` 版本，不因本次签名或语义重做而改为 `unreleased`。
- Flow 面板与 Resource 表格新增 `set_editor_context()`。新增 `GFEditorMultiPropertyField`，通过暂存值生成属性批处理请求，提交仍复用既有命令与资源历史；不改变 Flow 图的持久化格式或运行时执行协议。
- `GFConfigTableReference` 新增 `SourceMode` 与 `source_mode`，默认 `FIELDS` 保持原有字段引用行为；`ARRAY_ELEMENTS` 校验单个数组字段到目标单字段键的引用。元素问题增加零基 `element_index`；`resolve_record_references()` 仍只解析 `FIELDS` 引用。
- `GFTweenActionStep` 新增可选 `easing_curve: Curve`；为空时保留既有预设缓动，设置后使用经校验的独立曲线覆盖 transition/ease。`duplicate_step()` / `duplicate_config()` 深复制有效曲线，无效曲线使复制返回 `null` 并警告。`gf.action_queue` 的 `extension_version` 升为 `2.5.0`，包含编辑器预览、指定时间定位与自定义曲线。

### 📘 升级指南 (Migration Guide)

- 复杂配置请将重复的内部字段声明移入 `GFConfigTypeDefinition`，通过列的 `type_definition` 复用；结构布局在来源 `parse_options.layout` 中显式声明，普通平表沿用现有配置。调用 Schema 复制后须检查 null，读取规范化数据前须检查报告 `ok`；覆写增加了 `options` 参数的复制或转换方法时，同步签名并透传选项。自定义工具不能用描述报告替代真实的复杂类型资源。
- 配置入口默认有限；大批次应按实际数据规模显式设置 `work_limits`，不能用零或负数关闭额度。多个直接导入/合并调用需要共享预算时传 `work_budget`，不要同时声明两者；Pipeline 每次构建自行创建批次句柄，只在顶层或 Profile 构建选项中声明 `work_limits`。`GFConfigTableMergePolicy.merge_record()` 现在返回结果报告，检查 `ok` 后读取 `data`；记录键分量改用稳定标量。合并或数据库构建失败时不得继续读取部分结果，修正后重新执行完整操作。

- Project Layout 配置将 `schema_version` 改为 `2` 后，按当前规则闭合字段重新校验；需要排除生成目录时显式填写 `capture_scope`，并保留必需源码、结构和 profile 来源。重新捕获 snapshot 和 analysis，不能只修改旧报告的版本号。
- AI Developer 通过现有迁移计划与确认流程把 v5 契约升级为 v6：原 required 进入源码必需与采用允许，optional 进入采用允许，forbidden 同时保留源码禁止与采用禁止。重新生成 v10 快照，不手动改旧报告版本号；需要“允许源码存在但禁止项目采用”时再显式调整两组规则。
- Dialogue 调用方按用途选择结构编译或生产构建，交给内置 Runner 的内容使用 `build_runner_*` 并检查 `success`。行为树仅在项目明确允许恢复的错误原因外包 `RecoverError`；旧工作不会自动重试。对话内容变动后不能强行复用精确快照，应由项目检查点或显式版本映射恢复。
- 资源消费者在初始化前完成绑定；需要切换时共享同一个服务域入口，旧资源通过原句柄释放。受控切换暂停时拒绝新请求；在途热切换的旧代未退出时拒绝再次切换，超时不会强制销毁仍在使用的后端。
- 自定义 Tween 预览先显式注册有限数值 descriptor 和工具自有样机适配器，并持有注册句柄；退出时释放。运行时使用数值时间线时显式传入初值和范围，避免把项目 Node、资源加载或业务逻辑带入纯数值捕获。
1. 给节点借用与弹幕发射调用增加 `await`；节点借用的第三个参数必须传接收方 `lifetime_owner`（通常是 `self`），初始化数据移到第四个参数。检查结果成功后再使用节点或 Session。不要保留旧 Task 或监听已移除的预热 Operation 信号。
2. 每次借用保存对应 Lease，用 Lease 归还，不再用节点引用作为回收凭证。归还后立即停止访问此前保存的裸节点引用。
3. 将 `before_add` 和旧池启停钩子的每次初始化迁到根节点的 `on_gf_pool_prepare(context)`；进入/退出时的注册与清理由 Godot 生命周期负责。`_ready()` 默认只执行首次，不能当成每次借用的初始化。
4. 把旧预热调用改成 `await pool.prewarm(scene, count)`；预热阶段不再要求业务父节点。池需要保留到使用结束，独立使用时显式调用 `dispose()`，注册到架构后由正常异步关停流程清理。
5. 若节点有 Timer、Tween、异步任务或外部信号，项目脚本必须在退出时取消本轮任务或检查本轮 Lease，防止旧回调影响下一轮。离树不是任意外部工作的自动取消器。
6. 独立创建 Flow 面板的编辑器插件须调用 `set_editor_context(GFEditorToolContext.from_plugin(self))`；通过 Workspace 挂载的面板由工作区自动注入。没有有效撤销管理器时面板仅查看，不再直接修改资源。Resource 表格的新多选编辑入口同样需要上下文，原有显式 `commit_*` 调用方式保留。
7. 自定义 2D Rig 的 `get_camera_pose` / `get_camera_pose_data` 覆盖增加 `camera: Camera2D = null`，调用父类时转交该参数。多目标取景的独立调用也必须提供实际相机；不要用 Rig 所在视口尺寸代替相机输出尺寸。
8. 模板列表选项改为闭合字段及类型校验；移除传入 `options` 的业务附加字段。每次同步最多 4096 项；稳定 ID 模式要求 `clear_existing=true`。未提供 ID 时继续重建副本，大量长列表使用既有虚拟列表机制。
9. 检查已有缩略图调用：依赖 `_draw()` 或脚本初始化的预览专用节点须显式选择 `GFThumbnailRenderRequest.PreviewMode.TRUSTED_DYNAMIC`，并确保脚本只操作工具自有节点与资源。普通资源缩略图沿用默认静态模式，具体支持范围见[预览指南](editor/non-destructive-live-preview.md)。
10. 存档与会话恢复检查 codec 结果的 `ok`，不要用 `value == null` 判断失败；自定义 `GFDialogueContext.deserialize_values()` 覆盖同步返回 `bool`。Save 中已经移除的属性须由项目迁移清理，属性恢复不再忽略白名单之外的字段。
11. 自定义行为树节点覆盖 `reset()` 时调用 `super.reset()`，使旧 tick 失效。平台 adapter 改配置时创建新实例；自定义输入序列 runtime 按[序列协议](standard/input-flow/input-assist/input-modifiers-triggers.md)提供边沿 revision，不再用帧内布尔值模拟独立边沿。
12. Config Pipeline 的 v1 manifest 不走兼容读取。按[导出说明](editor/tools/config-pipeline.md)核对 profile、输出与 manifest 路径，仅移除对应生成 manifest 后重新导出。Content 导出中被合并的物理条目从 `metadata.references` 读取全部逻辑资源引用；未合并条目仍直接使用原有元数据字段。
13. `MultiplayerPeer` 替换若被断开回调中的另一次接管打断，返回 `ERR_BUSY`；调用方仍负责未被接管的 peer。可选 Network 字段的显式 null 也必须满足 `allow_null`，不能以 `required=false` 绕过。
14. 检查大文件读写：物理文件（含 Base64 开销）和还原后的明文分别受 `max_read_bytes`、`max_decode_bytes` 约束，默认 64 MiB；将 Codec 的 `max_decompressed_bytes` 属性与选项改名为 `max_decode_bytes`，旧选项会被拒绝。按项目存档规模显式设置更大正数，不用零关闭上限。成功保存的字典文件须符合本请求捕获的两级预算；同步保存超限返回 `ERR_OUT_OF_MEMORY`，异步保存通过物理完成结果报告 `WriteFailureKind.LIMIT_EXCEEDED`，入队 `OK` 不代表已经保存。`LIMIT_EXCEEDED` 应提示调整预算或拒绝操作，不能当作损坏文件自动覆盖或重置。
15. 手动输入宿主在初始化前设置 `automatic_input_routing=false`，正常注册/初始化工具，转发选中的事件并负责失焦清理；注册实例由架构推进 `tick()`，独立实例由宿主推进，避免重复更新。历史通知回调只更新展示，新的历史操作在通知返回后发起。字段延期提交保存会话令牌，解绑或文档切换调用 `clear()`。

详细示例见[对象池](standard/utilities/runtime/time-signal-pool/object-pool.md)与[弹幕](extensions/combat/projectiles.md)。已发布历史仍可从对应版本 tag 和 Release 查看。
