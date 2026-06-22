# API Surface Contract

API Surface Contract 用来明确 GF 源码中哪些符号属于公开承诺、哪些只属于框架内部实现。GDScript 本身没有访问修饰符，因此 GF 通过命名、section、`##` 文档注释和机器可读标签共同定义 API 边界。

核心原则是：公开必须显式，私有必须安静。`##` 不只是说明文字，而是 API 文档入口；私有实现细节不应使用 `##`，避免被半自动文档生成误收录。

## 可见性

| 可见性 | 用途 | 文档 | 兼容性 |
|---|---|---|---|
| `public` | 项目代码可直接依赖的稳定 API。 | 进入公开 API 文档。 | 受 SemVer 保护。 |
| `protected` | 子类或扩展实现可重写、可调用的扩展点。 | 进入扩展点 API 文档。 | 受 SemVer 保护，但只承诺重写契约。 |
| `framework_internal` | GF 内部跨文件协作入口。 | 可进入内部维护索引，不进入用户公开文档。 | 可调整，但必须通过维护测试保护。 |
| `layer_internal` | 只允许指定 layer 内部使用。 | 可进入内部维护索引，不进入用户公开文档。 | 可调整，调用范围必须受测试约束。 |
| `private` | 同文件实现细节。 | 不使用 `##`，不写 `@api`。 | 不承诺兼容。 |

允许的 `@api` 标签只有 `public`、`protected`、`framework_internal` 和 `layer_internal`。`private` 不是文档标签，而是由 `_` 前缀、私有 section 和同文件使用推导出来的状态。

## 类型分类

公开类、公开内部类和公开资源应使用 `@category` 声明类型分类：

| 分类 | 典型对象 | 重点约束 |
|---|---|---|
| `runtime_service` | Utility、运行时服务、带生命周期的协调器。 | 注入、初始化、释放、副作用必须清楚。 |
| `runtime_handle` | Handle、Token、Subscription 等运行时所有权句柄。 | 获取、释放、失效和所有权语义必须清楚。 |
| `domain_model` | Model、领域状态对象。 | 状态字段、快照和存档语义必须稳定。 |
| `resource_definition` | Resource 配置、Catalog Entry。 | 导出字段必须完整文档化。 |
| `value_object` | Result、Report、Snapshot。 | 字段语义稳定，适合生成 API 文档。 |
| `protocol` | 基类、接口式契约、扩展点。 | protected 方法必须说明重写契约。 |
| `event_contract` | Command、Query、Signal payload。 | 参数和载荷 schema 必须稳定。 |
| `editor_api` | Dock、Inspector、编辑器动作。 | 必须标明 editor-only 语义。 |
| `tool_api` | 可选 tool package 中的构建、导入、校验、批处理入口。 | 必须标明制作期、编辑器期或 CI 期语义，不能被运行时包依赖。 |
| `internal_helper` | 内部解析器、缓存、Builder。 | 不进入公开文档，不得出现在 public 签名中。 |

## 文档标签

`##` 文档块中的机器可读标签遵循以下格式：

```gdscript
## 注册一个配置资源。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @param config: 要注册的配置资源。
## [br]
## @return: 注册是否成功。
```

常用标签：

- `@api public|protected|framework_internal|layer_internal`：声明可见性。
- `@category ...`：声明公开类型分类，主要用于类和公开内部类。
- `@since x.y.z`：声明公开类型或公开入口首次出现的版本。
- `@since unreleased`：仅用于当前 `[未发布]` 中已经进入源码但尚未确定发行版本的新增公开入口。发布前必须替换为最终 SemVer；release 检查会拒绝任何非 SemVer 的 `@since`。
- `@deprecated x.y.z ...`：声明弃用版本和替代入口。
- `@layer kernel/editor`：声明内部 API 的允许调用范围，必须使用路径分隔形式。
- `@param name: ...`：声明函数参数，顺序必须和签名一致。
- `@return: ...`：声明非 `void` 返回值。
- `@schema name: ...`：描述公开签名中的裸 `Dictionary`、裸 `Array` 或 `Variant` 结构。说明文字优先使用中文，字段名、API key、类型名和枚举值保持代码原文。

为兼顾 Godot 编辑器悬停文档和机器可读标签，正文说明与机器标签之间、以及连续机器标签之间都应插入一行 `## [br]`。Godot 会把文档注释按 BBCode 渲染；没有显式分隔时，多行说明和 `@api` / `@param` / `@return` / `@schema` 等标签容易在悬停提示中合并为一段。`[br]` 只用于渲染换行，不改变标签语义。

历史迁移期间补齐的 `@since` 不再使用占位版本 `1.0.0`。完成 API Surface 迁移后，既有公开 API 的起算版本统一使用当次 GF 发布版本；新增 API 在版本已确定时使用它首次公开发布的 GF 版本，在版本未确定时临时使用 `@since unreleased`。不要使用 `x.x.x`、`未发布`、空值或其他占位写法，因为这些写法难以被机器稳定识别和发布前替换。

## 文件结构与 section

`##` 文档块必须绑定到一个明确声明：`class_name`、内部 `class`、`signal`、`enum`、`const`、`var` 或 `func`。没有绑定声明的脚本说明、维护说明、模板说明必须使用普通 `#`。这条规则避免半自动文档生成器把 classless helper 的顶部说明误判成公开 API。

对外公开或可重写的顶层 API 必须位于带 `class_name` 的脚本中。唯一例外是继承 `Node` 或已知 Node 派生类型的 Autoload / 插件单例脚本：这类脚本可以把顶层成员声明为 `public` / `protected`，因为它们的公开入口由场景树或编辑器插件生命周期持有。没有 `class_name` 的普通 helper、模板脚本和数据脚本只能暴露 `framework_internal` / `layer_internal` 协作入口，不能承诺 `public` / `protected` API。

section 注释必须使用以下格式：

```gdscript
# --- 常量 ---
```

允许的 canonical section 按顺序如下：

1. `信号`
2. `枚举`
3. `常量`
4. `导出变量`
5. `公共变量`
6. `私有变量`
7. `@onready 变量`
8. `Godot 生命周期方法`
9. `Godot 回调方法`
10. `GF 生命周期方法`
11. `公共方法`
12. `可重写钩子 / 虚方法`
13. `框架内部方法`
14. `层内方法`
15. `私有/辅助方法`
16. `信号处理函数`
17. `内部类`

大型文件可以在 canonical section 后追加括号说明，但不能改掉 section 基类。例如 `# --- 公共方法（注册） ---`、`# --- 公共方法 (类型事件) ---`、`# --- @onready 变量（节点引用） ---` 是允许的；`# --- 获取方法 ---`、`# --- 事件系统 ---`、`# --- 私有方法 ---` 不允许，因为它们无法稳定映射到文档结构。

`@onready` 变量只允许出现在继承 `Node` 或已知 Node 派生类型的脚本中。`RefCounted`、`Resource`、`Object` 以及无法证明为 Node 派生的类型不能使用 `@onready`，因为它依赖 Node 生命周期和场景树初始化时机。

## 新语法和新声明形态

GF 不对未知语法、未知声明形态或新的 GDScript 结构做猜测式兼容。任何会进入 API surface 的新结构，必须先回答并落地以下问题：

1. 它属于现有 canonical section 的哪一类，还是需要新增 section。
2. 它是 `public`、`protected`、`framework_internal`、`layer_internal` 还是 private。
3. 它的文档标签、参数、返回值、schema、layer 和兼容性承诺是什么。
4. API Surface 正例夹具是否覆盖它。
5. 严格校验器是否能解析并在缺失文档、错误 section、错误可见性时失败。

在这些问题落地前，带 `## @api` 的未知声明必须被测试拒绝。维护者不能通过把未知结构放进相近 section、删掉文档注释或添加迁移标记来绕过设计判断；如果它需要成为 API，就先扩展本文件、示例和校验器。

## 硬规则

- `public` / `protected` / `framework_internal` / `layer_internal` 成员必须使用 `##` 并写明 `@api`。
- 私有变量、私有方法和私有内部类不使用 `##`；确实需要解释实现原因时使用普通 `#`。
- `##` 文档块必须绑定到紧随其后的声明；悬空 `##` 视为违规。
- 带 `## @api` 的未知声明形态视为违规，必须先扩展 API Surface Contract 和校验器。
- 顶层 `public` / `protected` API 必须位于 `class_name` 脚本中；继承 `Node` 或已知 Node 派生类型的 Autoload / 插件单例脚本是唯一例外。
- `public` / `protected` 函数必须完整声明 `@param`；非 `void` 返回值必须声明 `@return`。
- `public` / `protected` 枚举的每个枚举值必须使用 `##` 说明。
- `protected` 方法必须以 `_` 开头，并位于明确的可重写钩子或虚方法 section。
- `layer_internal` 必须带 `@layer`；任何 `@layer` 都必须和源码路径匹配，例如 `addons/gf/kernel/editor/**` 使用 `kernel/editor`。
- `public` / `protected` 签名不得暴露任意文件中的 `framework_internal`、`layer_internal` 或私有类型。
- 公开签名中出现裸 `Dictionary`、裸 `Array`、`Variant`，或 `Array[Dictionary]` / `Array[Variant]` 等结构化泛型时，必须提供对应 `@schema`。
- 公开 Resource、value object 和 event contract 的字段必须完整文档化。
- section 名称和顺序必须符合本文件的 canonical section 列表。
- `@onready` 变量必须位于 Node 兼容类型中。
- 跨文件访问 `_` 私有成员默认违规；允许的例外必须通过专门测试列白。

## 迁移标记

规范文档注释无法一次性补齐时，允许在文件顶部使用维护标记：

```gdscript
# @api_surface_migration partial
```

该标记只允许使用普通 `#`，不能写成 `##`。它表示当前文件正在迁移到 API Surface Contract，严格校验器可以暂时放过该文件中的未完成项。

标记有两个硬约束：

- 标记存在且文件仍有 API Surface 违规时，测试允许通过，但该文件仍属于迁移债务。
- 标记存在但文件已经没有 API Surface 违规时，测试必须失败，提示移除标记。

因此，维护者不能在未完成时提前移除标记；一旦文件真的完成，也不能长期保留标记。

## 迁移策略

API Surface Contract 应分阶段落地：

1. 先维护规范、正例夹具和严格校验器，确保规则可执行。
2. 为现有 `addons/gf` 生成 API surface 报告，并按文件添加 `# @api_surface_migration partial`。
3. 后续新增或修改的公开 API 必须按本规范标注。
4. 分模块清理迁移标记，最终让全量 `addons/gf` 进入 hard fail。

这样可以先把自动文档生成和 API 边界判断的底座搭稳，再逐步把历史源码迁移到同一套严格规则下。
