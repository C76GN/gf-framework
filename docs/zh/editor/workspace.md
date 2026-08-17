# GF Workspace

`GF Workspace` 是核心插件固定提供的独立编辑器窗口。它把 GF 自带的扩展管理、输入映射、信号诊断和诊断快照等基础面板收束到一个响应式工作区，避免多个 GF 面板挤占 Godot 底部栏。存档图、Flow 等业务型工具页面只在对应可选扩展显式启用后，通过 `editor/gf_tool_contribution.json` 贡献到同一个工作区。

窗口右上角的“置顶”开关可让独立工作区保持在其他窗口上方，便于一边操作编辑器或运行窗口一边观察调试页面。

## 打开与布局

插件启用或编辑器打开项目时，GF 会默认弹出工作区窗口；关闭窗口后，可从 `工具 > GF > 打开 GF 工作区` 再次打开。

工作区顶部提供自动换行的短页面入口，完整页面名保留在 tooltip；页面默认按“状态、输入、存储、信号、诊断、扩展、保存、流程”的产品顺序展示，未启用扩展贡献的页面不会占位。标准库页面通过记录里的 `order` 和 `short_label` 声明顺序与短标签，扩展页面通过 manifest 的 `editor_dock_order` 和 `editor_dock_short_label` 声明对应信息，核心插件只按记录排序。

内容区仍只显示当前页面，避免多个工具同时挤压。每个页面都会放进无最小高度的裁剪容器，页面内容不会把窗口撑坏。右上角的“关于”按钮会打开 GF Framework 简介，并提供项目地址、正式文档地址、Issues、Releases、维护者联系方式和手动最新版本检测入口。检测到 GitHub Releases 存在更高版本时，关于弹窗会显示“打开更新页面”按钮，跳转到对应 Release；GF 不会在编辑器运行中自动覆盖 `addons/gf`，以避免丢失本地修改或替换正在加载的插件脚本。

内置页面共享 `GFEditorWorkspaceUI` 提供的页面根、工具栏、摘要、空状态和详情输出构建方式。新增页面应优先复用这些通用控件，再把真正的业务无关编辑逻辑放在页面自身脚本中，这样工作区的密度、状态颜色、空态文案和只读详情区会保持一致。

可选扩展的编辑器工具可以放在独立 tool package 中。`editor_action_paths`、`editor_dock_paths`、`editor_inspector_paths`、`import_plugin_paths`、`export_plugin_paths`、`gltf_document_extension_paths`、`access_generator_extension_paths` 和 `debugger_plugin_paths` 都只通过扩展目录下的 `editor/gf_tool_contribution.json` 贡献，不能写入运行时 `gf_extension.json`。贡献文件必须声明 `schema_version: 2` 和与所属 manifest 一致的 `extension_id`，路径字段必须是非空字符串数组；schema v1、未来 schema、未知字段、错误扩展 ID 或越过扩展根的路径都会被拒绝并进入选择快照的 `tool_contribution_errors`。

无效 tool contribution 只会使选择报告进入 `partial` 并隔离该文件的无效路径，不会使运行时 manifest 图失效，也不会阻断 manifest 中有效的 `installer_paths`。工作区页面的 `editor_dock_order` 与 `editor_dock_short_label` 仍保留在 manifest 中；项目安装对应 tool package 且扩展启用后，根编辑器插件才会在标准库 Debugger 记录之后装载 `debugger_plugin_paths` 指向的 `EditorDebuggerPlugin` 脚本，重复路径只装载一次，并在插件刷新或卸载时由同一生命周期统一移除。

## Extensions 页面

`GF Extensions` 页面用于查看 `gf_extension.json`、显式启用或禁用默认关闭的内置可选扩展、检查 manifest 状态、扫描禁用扩展引用并保存扩展相关设置。

扩展 preset 会先校验 ID、依赖 ID 和来源路径；项目工具需要审查 preset 配置时，可读取 `GFExtensionSettings.get_extension_preset_report()` 获取有效、无效、重复和跳过的 preset 记录。

面板里的三个开关含义不同：

- `自动装配启用扩展 Installer`：`Gf.init()` / `Gf.set_architecture()` 时执行启用扩展 manifest 声明的 `installer_paths`。
- `导出时排除禁用扩展`：导出阶段跳过禁用扩展根目录下的文件。
- `引用禁用扩展时阻止导出`：导出审计发现项目仍引用禁用扩展时，以错误形式报告，适合发布前或 CI 使用。

扩展启用状态不会让编辑器中的脚本或 `class_name` 立刻消失。它影响的是扩展 Installer 是否自动参与运行时装配，以及导出时是否排除禁用扩展目录。禁用或删除扩展前，应先清理项目脚本、场景、资源、preload 和已生成访问器中的直接引用。

## Package Manager 页面 { #package-manager }

`GF Package Manager` 页面用于从 GF registry、registry source 或 offline bundle 安装模块化 package。空项目可以直接安装 package 闭包完成 GF bootstrap；已经安装 GF 的项目会读取 `addons/gf/plugin.cfg` 中的框架版本，并在刷新状态、预览安装和真实安装前检查 registry 与 package 的 `minimum_framework_version` / `maximum_framework_version_exclusive` 兼容范围。版本字段必须是无 `v` 前缀的严格 SemVer；稳定排他上界表示下一条兼容线，因此同 core 的预发布版本也会被排除，例如 `9.0.0-dev.0` 不满足 `< 9.0.0` 的 8.x 兼容范围。只有上界自身显式声明为预发布版本时，才在同 core 内按完整 SemVer 先后关系判断。

默认在线源会优先指向当前 GF 版本对应的 release registry source，避免旧框架项目无意间读取最新 registry。自定义 registry source 或 offline bundle 仍可用于团队内分发，但应与目标项目的 GF 主版本线匹配；不兼容时页面会显示失败原因，安装流程不会下载 archive、写入 lockfile 或覆盖项目文件。

只安装 `gf.kernel` 的项目也可以直接使用 Godot 原生命令行入口，不需要 Python：

```powershell
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- status
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- install <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- update [<package-id>...] [--all-installed]
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- uninstall <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- verify
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- recover
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- cache-init --cache-dir <absolute-path>
```

常用参数包括 `--registry`、`--channel`、`--project-root`、`--lockfile`、`--cache-mode`、`--cache-dir`、`--dry-run`、`--all-installed`、`--all-concrete`、`--kind`、`--exclude-kind`、`--force` 和 `--json`。`status` 用来查看 registry 中有哪些 package、哪些已安装、哪些可安装或可更新；`install` 会根据依赖闭包安装新 package；`update` 只更新 lockfile 中已经安装的 package，可显式指定 package id，也可用 `--all-installed` 对齐全部已安装 package；`uninstall` 会按 lockfile、依赖关系和项目引用检查卸载风险；`verify` 用来检查 lockfile 与当前 registry 是否一致；`recover` 用来显式恢复或收尾上次被进程退出、系统中断或文件系统故障打断的事务。

Package cache 默认使用项目私有的 `.gf/package_cache`。内部的 `GFPackageCachePolicy` 统一解析目录所有权和模式，`GFPackageFilesystemCacheStore` 负责当前文件系统 artifact 实现；二者不作为项目业务 API。仅传 `--cache-dir` 不会授权外部目录；跨项目或 CI 需要共享下载物时，必须先用 `cache-init` 在一个空目录中创建版本化 `.gf-package-cache.json` marker，再显式选择 `external_read_only` 或 `external_shared_rw`。`external_read_only` 会优先读取共享 artifact，未命中内容写回当前项目私有缓存；`external_shared_rw` 才允许向共享根提交对象。已有未知内容且没有 marker 的目录不会被自动接管。

Artifact store 只保存通过完整 SHA-256 和字节数校验的不可变 registry 原文与 package archive，布局位于 `objects/sha256`。消费带 source integrity 的 registry 时，backend 不会直接解析共享对象路径：它先把命中的对象复制到当前项目私有 workspace，再对这份实际消费快照复核 SHA-256 与字节数；共享写者在 lookup 后替换路径不会让“已校验路径”变成未校验输入。下载临时文件、私有消费快照、重写后的 registry 和 offline bundle 解包结果都属于当前项目的 `.gf/package_workspace`，不会写入共享根。缓存始终只是可丢弃的派生数据，不能替代 registry source integrity、archive sha256 或 size 校验。包管理结果中的 `cache` 字段会报告实际 mode、读写根、workspace、marker 状态和只读属性。

远程 registry 中的 package archive 必须解析为 HTTP(S) URL，并带有 registry 中声明的 sha256 与 size 校验。重定向全程必须保持 HTTPS、不能携带 URL 凭据；跨 authority 只允许 GF 明确列出的 GitHub release asset host，并要求默认 443 端口。协议降级、任意 host、非标准跨 host 端口和未授权 authority 变化都会在下载前失败关闭。

本地 registry 或 offline bundle 中的 archive 必须是 registry 包内的相对路径；`res://`、`user://`、绝对文件系统路径、带盘符路径和越过 registry 包根的路径都会被拒绝。生成的本地 registry 可以把 zip 放在 registry 同级的 `packages/` 目录内，但不能让普通 registry 条目任意读取项目或磁盘上的其他文件。archive 条目、offline bundle 条目、lockfile 与事务目标使用字面路径协议：逐段拒绝 `..`、符号链接、Windows junction/reparse point、`< > : " / \ | ? *`、大小写或尾点/尾空格别名，以及 `CON`、`NUL.txt`、`COM1`、`LPT9.ext`、`COM¹`、`LPT³.gd` 等 Windows 设备名或上标别名。manifest `paths` 是唯一允许 glob 的入口：`*` 与 `?` 只匹配当前 segment，递归 `**` 只能作为最后一个完整 segment，并匹配前缀自身与其任意深度后代；`**` 前面的 segment 仍可使用单段 `*` 或 `?`。通配符不会跨 `/`，`[` 与 `]` 只按普通文件名字符处理。安装前会审计 archive 的条目数量、解压大小、压缩比、ZIP64、路径长度和路径深度，并按实际读取字节累计 staging 硬预算；offline bundle 的 central-directory 大小只用于预检，解包时还会按实际 bytes 跨 entry 累计，任一实际预算或条目校验失败都会删除整棵 partial extraction；非 preset runtime archive 必须至少包含一个合法 payload。在 Godot 原生验签实现完成前，registry package entry 或 registry source channel 中的签名、公钥和同类信任字段会被拒绝，而不是被当作已验证元数据。

registry v2 是闭合协议，而不是可随意扩展的配置袋。根对象和每个 package 都必须只包含当前 schema 允许的字段；版本与兼容范围必须是字符串，依赖和路径必须是唯一字符串数组。具体 package 还必须提供非空 archive、完整 SHA-256 与正整数 size；preset 必须提供非空 package 集合，同时让 `dependencies` 和 `paths` 为空，且不能夹带 archive/checksum 字段。缺字段、类型错误、未知字段或非法 package ID 会在计划计算前失败关闭，Python 维护规划器与 Godot 原生 backend 遵循同一契约。

安装、更新和卸载预览会返回 `plan_entries` 与 `plan_summary`。每个条目说明 package 的动作是 `install`、`update`、`keep`、`remove`、`prune_dependency` 还是 `blocked`，并保留 `requested`、`dependency`、`already_satisfied`、`lockfile_changed` 等计划原因，方便编辑器页面或项目工具在执行前解释 dry-run 结果。lockfile 的 `reasons` 必须非空且只含已知原因，`verify` 会检查全部已安装 dependency closure；畸形或缺失依赖不会被静默剪枝。更新判定的 payload identity 同时包含版本、kind、paths、archive、sha256、扩展 ID 和 preset package 集合，任一载荷字段变化都会进入真实更新计划。

批量卸载按整批请求的投影最终状态检查 `required_by`。如果 depender 和一个被手动 pin 的 dependency 都在同一请求中，二者之间的依赖边不会自我阻断该批原子移除；如果 depender 未包含在请求里，或同批中的 depender 因保护原因、项目引用等条件不能移除，它仍会作为集合外 blocker 阻止 dependency。`--force` 仍是显式绕过保护的高风险入口，不应用来替代完整批量计划。

编辑器页面关闭或插件卸载时，后台 Package Manager 任务会发出协作取消请求。原生 backend 会在扫描、下载、解包、复制、删除和 lockfile 写入前后的关键边界检查取消状态，并在结果中标记 `cancelled`，避免退出树后继续长时间写项目文件。

真实安装、更新、卸载和只改 metadata 的 lockfile 写入都通过内核内部的 `GFPackageTransactionEngine`。引擎会在开启事务前完成跨 package staged target 冲突、既有文件 ownership、portable path 和 payload 完整性预检；lockfile 不得与任一 payload target 使用同一跨平台路径身份，也不得位于事务声明的 cleanup tree 内。这些零写入失败会明确返回 `rolled_back = false`。通过预检后，引擎先在 `.gf/package_transactions/active` 写入版本化 journal：payload 原状态以稳定 SHA-256 与字节数记录，不再为每个文件复制第二份备份；需要替换的原 lockfile 仍保留事务内快照。每个磁盘 target 真正变更前还必须继续匹配 preparation 快照。已有 target 会原子移动到带 transaction id 的 `.owner` sidecar，再由事务写入或删除；原先不存在的 write target 不创建逐文件 ownership claim，回滚只会删除仍精确匹配本事务 planned identity 的字节。未被本事务取得 ownership 的并发变化会保留并进入 warning，而不会被旧快照覆盖。

完成 payload 后才替换 lockfile；新 payload、删除结果与 lockfile 全部复验通过后才写入 `committed`，事务专属 temp/owner sidecar 和声明的 staging cleanup 也会在 active journal 最终移出前完成。这样，进程停在“旧 target 已移动、新 target 尚未 rename”的窗口时，恢复器仍能以 sidecar 证明所有权并还原原字节。`prepared`、`payload_applied` 或 lockfile 已替换但尚未记录 `committed` 的中断事务会回滚事务拥有的状态；已经记录 `committed` 且新状态校验通过的事务只完成清理，不会反向撤销成功安装。Godot 当前文件 API 不提供跨平台的原子 compare-and-swap/no-replace rename，因此实现会在每个可观察边界重复校验并保存被移动字节，但不宣称能封死拥有同一项目目录写权限的恶意本机进程在最后一次检查与 rename 之间交换路径。

`status`、`install`、`update`、`uninstall` 和显式 `recover` 都会在读取 lockfile 前检查遗留 journal。journal 仍由活进程持有时，新操作会返回 `blocked`，不会并发接管；owner 已失效时才执行幂等恢复。结果中的 `transaction` 与 `transaction_recovery` 使用同一版本化报告字段，包括 `outcome`、`rolled_back`、`recovered`、`recovery_required` 和 `warnings`。CLI 的 human 输出与 `--json` 都会呈现嵌套事务的 outcome、恢复义务和 warnings；例如主体提交成功但 cleanup 尚未完成时，顶层仍可为 `ok`，同时明确显示必须再次运行恢复。`--dry-run` 不会为本次计划写入 package 文件，但如果项目此前已有中断事务，仍会先恢复一致状态再计算预览。

安装时可以显式列出 package id，也可以用 selector 从当前 registry 选择一组具体 package：

```powershell
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- install --all-concrete --kind standard,extension --exclude-kind tool
```

`--all-concrete` 只选择有真实包内容的 package，不会把 preset 当成安装根；`--kind` 与 `--exclude-kind` 使用 registry 中的 package kind 过滤结果。选择器只基于 registry 元数据生成安装根，依赖闭包、兼容性检查、archive 校验、staging、回滚和 lockfile 写入仍由同一条安装事务处理。

`.gf/packages.lock.json` 会记录本次使用的 registry source、channel、offline bundle、mirror index、registry hash 和 size 等来源信息。后续 `verify`、`status`、更新预览或编辑器页面可以用这些字段解释项目当前 package 状态来自哪个源，而不是只保存包版本号。

每个有文件的已安装 package 还会记录精确 `files` 清单，以及每个文件的 SHA-256 和字节数。`verify` 会要求清单与摘要元数据一一对应并校验磁盘内容；更新或卸载遇到用户修改过的已安装文件时会 fail closed，不会静默覆盖或删除。新版本不再包含的旧文件只有在仍与安装基线一致时才会作为同一 package transaction 的删除项处理，事务失败时和其他 payload 一起回滚。

Package Manager 不是正在运行的 GF 框架自更新器。使用默认源时，GF `1.0.0` 项目执行 `install gf.kernel` 仍然会对齐 `1.0.0` registry；要升级到 GF `1.0.1`，应先用 GF `1.0.1` release 替换框架，再刷新 Package Manager 或运行 `status`，最后用 `update --all-installed` 同步已安装 package。

已安装 package 以 `.gf/packages.lock.json` 为准。手动替换或升级 `addons/gf` 不会自动同步更新 lockfile 中的 package；升级 GF 后应先刷新 Package Manager 或运行 `status`，再对需要对齐当前 registry 的 package 执行 `update <package-id>` 或 `update --all-installed`。`update` 不会隐式安装未在 lockfile 中的 package，新增功能包仍使用 `install`。
