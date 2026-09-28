# 私有维护文档编写指南

本页面向框架维护者，说明如何为现有私有实现补充文档。可见性和校验要求以根目录 [API_SURFACE.md](../../API_SURFACE.md) 为准，排版以 [CODING_STYLE.md](../../CODING_STYLE.md) 为准。

## 选择值得说明的内容

优先处理状态有效期、引用所有权、取消与释放顺序、缓存失效、异步写回资格、回调重入、特殊失败值和内部数据结构。不以注释数量为目标；显然的 getter、类型收窄、纯转发可以保持无文档。

写之前同时阅读声明、函数体和直接调用点。对字段还要检查赋值、清空和释放位置。不能仅从方法名猜测，也不能把同目录某个类的约束推广到所有类。

涉及并发、事务、快照身份或生命周期而无法从限定范围内证明的结论，应保留原状并记录疑问，交由熟悉该机制的维护者审阅。不要写“线程安全”“完全重入安全”“原子操作”等超出实现证据的承诺。

## 最小格式

```gdscript
## 保留快照对应资源的强引用，使对话结束后仍能校验结束态快照的资源身份。
## [br]
## @api private
var _snapshot_resource: GFDialogueResource = null
```

每个文档块紧邻一个声明，至少包含非空正文和唯一 `@api private`。多字段共享的不变量可以用普通 `#` 分组说明，不要让一个 `##` 块看似绑定多个声明。带文档的成员之后保留一个空行。

`@param name: 说明` 可只写需要额外解释的参数，但名称不得重复、不得虚构，按签名相对顺序排列。`@return: 说明` 用于非 `void` 函数，尤其应说明空值、失败值或回调后状态。`@schema name: 说明` 按需记录内部结构，目标必须对应本声明的属性/常量名、参数或非 `void` 返回值 `return`。这些标签的说明都不能为空。

正文和标签、连续标签间使用 `## [br]`。私有文档不强制 `@since`、`@category` 或完整参数表；不要添加没有机器消费者的新标签。中文说明中的字段名、类型名、枚举值保留代码原文。

## 有限范围内的真实示范

- `addons/gf/kernel/core/gf_async_scope.gd`：`_cleanup_callbacks` 和 `_run_cleanup_callbacks()` 说明取消批次、先清空后逆序执行的原因。
- `addons/gf/extensions/dialogue/runtime/gf_dialogue_runner.gd`：`_snapshot_resource` 说明资源强引用的用途；`_emit_line_blocked_for_lease()` 说明同步信号回调后的会话资格与返回值。
- `addons/gf/standard/utilities/assets/gf_resource_broker.gd`：`_active_requests` 和 `_admit_pending_requests()` 说明 draining 请求仍占配额，以及队首请求的 FIFO 约束。

这些示范用于学习说明方式，不能把它们的语义机械套到其他实现。

## 批量补写边界

全量补写应遍历 `addons/gf/**/*.gd`，并单独核对生成器使用的 `.gd.txt` 模板。批次只是组织阅读与检查的单位，不是文件白名单，也不构成完成范围的缩减。每批选择一个小目录或 5–10 个相关文件，完成阅读、编写、检查后继续下一批，直到完整清单收敛。只有本次确实读过的实现才写入结论。

逐声明清单使用文件路径、完整嵌套类路径、声明种类、名称与完整签名定位，覆盖无 `class_name` 脚本、内部类成员和 `static var`。继承的受保护契约与 Godot 回调单独分类，不因下划线前缀就计为私有欠项。证据绑定实际源码哈希与行号；重排后重新生成当前证据，旧记录只作为注明版本的历史材料保留。

- 只添加或改进私有声明文档及其必要空行。已有普通原因注释可以移到对应声明文档，避免重复。
- 不修改可执行代码、签名、命名、类型、默认值、section、导出声明或文件布局。
- 不改已有 `public`、`protected`、`framework_internal`、`layer_internal` 文档，尤其不改公开 `@schema` 或 `@since`。
- 不把跨文件协作入口或子类重写契约改成 `private`。全局 `class_name` 不使用 `private`。
- 无 `class_name` 脚本顶部继续使用普通 `#`；它的私有成员可以使用 `## @api private`。不要给 `extends` 添加私有文档 owner。
- 不改生成器、校验器、维护规范或生成的 Reference，不用迁移标记、白名单或忽略警告绕过检查。
- 不批量改第三方 `addons/gut`、测试夹具或工具脚本。这里的标签规则针对 GF 自有 GDScript 声明。

## 查询与验证

维护查询默认只提供公开 owner 投影。需要检查本文件内部说明时显式选择维护范围：

```powershell
python tools/gf_maintenance.py api-class GFAsyncScope --scope maintenance --json
python tools/gf_maintenance.py api-search _run_cleanup_callbacks --scope maintenance --json
python tools/gf_maintenance.py api-index --scope maintenance --json
```

维护结果会标注可见性；查询索引不是完整的私有实现清单，尤其不保证覆盖无 `class_name` 脚本的内部类或任意层级嵌套类型。未出现在索引中不等于不存在，也不能成为错误公开它的理由。

每批检查实际 diff，确保变化只有上述允许的注释与空行，并运行：

```powershell
git diff --check
python tools/gf_maintenance.py path-hygiene --json
python tools/generate_api_reference.py --check
```

在本轮结束时运行 API Surface / 参数同步 GUT 测试、相关 focused GUT 和 `gdscript_warnings`。本地 Godot 命令须使用现有受监督维护执行路径。遇到失败先定位本批注释，不通过放宽校验器解决。需要修正规范分段或可见性分类的项目应进入语义修复，由维护者连同调用证据处理；不能让批量补写边界成为永久遗留失败的理由。

私有注释插入可能改变公开声明的源码行号，进而使本地 AI 摘要的 `location_digest` 过期；可运行既有 `generate_ai_api.py` 重新生成忽略目录内的摘要，再执行 `--check`。公开 Catalog、公开 Reference 和公开语义摘要应保持不变。

交付时报告处理的文件和声明、跳过的疑点、执行过的检查与失败详情。检查通过只能证明格式和边界，不能代替对注释语义的复核。
