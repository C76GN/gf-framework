# API Surface Contract

API Surface Contract 用来明确 GF 源码中哪些符号属于公开承诺、哪些只属于框架内部实现。GDScript 本身没有访问修饰符，因此 GF 通过命名、section、`##` 文档注释和机器可读标签共同定义 API 边界。

核心原则是：公开承诺必须显式，私有实现也可以拥有维护文档。`##` 表示绑定到声明的文档，`@api` 独立决定可见性；是否有文档不改变调用边界或兼容性承诺。公开生成物只收录 `public` / `protected`，不能把所有带 `##` 的声明都当作公开 API。

## 可见性

| 可见性 | 用途 | 文档 | 兼容性 |
|---|---|---|---|
| `public` | 项目代码可直接依赖的稳定 API。 | 进入公开 API 文档。 | 受 SemVer 保护。 |
| `protected` | 子类或扩展实现可重写、可调用的扩展点。 | 进入扩展点 API 文档。 | 受 SemVer 保护，但只承诺重写契约。 |
| `framework_internal` | GF 内部跨文件协作入口。 | 可进入内部维护索引，不进入用户公开文档。 | 可调整，但必须通过维护测试保护。 |
| `layer_internal` | 只允许指定 layer 内部使用。 | 可进入内部维护索引，不进入用户公开文档。 | 可调整，调用范围必须受测试约束。 |
| `private` | 同文件实现细节。 | 可使用 `## @api private` 编写维护文档，不进入公开文档。 | 不承诺对外兼容。 |

允许的 `@api` 标签只有 `public`、`protected`、`framework_internal`、`layer_internal` 和 `private`。每个声明文档块只能声明一个可见性。未文档化的私有实现仍由 `_` 前缀、section 和使用范围判断；一旦使用 `##`，必须显式写明 `@api private`，不能靠省略标签推断。枚举值沿用枚举的可见性，不重复写 `@api`。

`private` 不能用来隐藏原本对外公开的声明：私有方法、变量、常量、信号、枚举和内部类仍须遵守 `_` 前缀及对应 section。注册全局类型的 `class_name` 不使用 `private`，内部全局类型使用 `framework_internal` / `layer_internal`。跨文件协作入口使用内部协作可见性，供子类重写的契约使用 `protected`；新增私有文档不扩大调用权限。

已有下划线命名的跨文件协作入口可以保留名称，显式声明 `framework_internal` / `layer_internal` 并放入相应内部方法 section；不能仅根据 `_` 前缀把它重新判为 `private`。它们继续执行完整参数、返回值、schema 和 layer 校验。私有导出字段位于“导出变量”section，私有性不改变其导出声明的布局要求。

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

- `@api public|protected|framework_internal|layer_internal|private`：声明可见性。
- `@api_owner autoload Gf`：只为 `addons/gf/kernel/core/gf.gd` 声明受控的 classless AutoLoad owner；必须位于文件级文档块中并紧邻绑定到 `extends Node`，不能用于发现或声明其他单例。
- `@category ...`：声明公开类型分类，主要用于类和公开内部类。
- `@since x.y.z`：声明公开类型或公开入口首次出现的版本。
- `@since unreleased`：仅用于当前 `[未发布]` 中已经进入源码但尚未确定发行版本的新增公开入口。发布前必须替换为最终 SemVer；release 检查会拒绝任何非 SemVer 的 `@since`。
- `@deprecated x.y.z ...`：声明弃用版本和替代入口。
- `@layer kernel/editor`：声明内部 API 的允许调用范围，必须使用路径分隔形式。
- `@param name: ...`：声明函数参数，顺序必须和签名一致。
- `@return: ...`：声明非 `void` 返回值。
- `@schema name: ...`：描述公开签名中的裸 `Dictionary`、裸 `Array` 或 `Variant` 结构。说明文字优先使用中文，字段名、API key、类型名和枚举值保持代码原文。

### 私有维护文档

私有声明有文档时，至少包含非空的职责说明和一个 `@api private`。说明应记录维护者无法仅从名称与类型得知的事实，例如状态有效期、引用所有权、取消与释放顺序、异步写回资格、回调重入、失败值或原子性边界。涉及这些约束的私有实现应在代码审查中要求文档；简单 getter、类型收窄和纯转发不强制补注释，不设全量私有注释覆盖率门槛。

```gdscript
## 保留快照对应资源的强引用，使对话结束后仍能校验结束态快照的资源身份。
## [br]
## @api private
var _snapshot_resource: GFDialogueResource = null
```

私有文档采用轻量标签规则：

- 不强制 `@since`、`@category`、完整参数表、返回值说明或结构 schema；不要为了凑齐模板复制签名或推测语义。
- `@param name: 说明` 可只记录需要额外解释的参数；已经记录的名称必须存在、不能重复、按签名相对顺序排列，说明不能为空。
- `@return: 说明` 按需使用，只能描述有返回值的函数，不能重复或为空；失败值和回调后的状态等不明显语义应明确说明。
- `@schema name: 说明` 按需描述内部结构，名称只能对应本声明的属性/常量、参数或非 `void` 返回值 `return`；不能重复或为空。不因出现简单 `Variant` 收窄就要求 schema。
- 正文及标签沿用 `## [br]` 分隔。函数体局部原因仍用 `#`，不要把局部变量或连续步骤改造成声明文档，也不要重复同一约束。

这些轻量规则仅适用于 `private`。公开、受保护和内部协作声明继续执行既有完整参数、返回值及结构 schema 校验。维护查询可显式选择 `maintenance` 范围读取私有文档；公开 Reference、公开 AI API 索引、API baseline 与公开语义摘要只消费公开投影。纯私有说明变化不构成公开 API 变更，但实现变化导致的公开行为变化仍需按兼容性规则判断。

无 `class_name` 脚本的成员也可使用私有文档；文件顶部维护说明继续用 `#`，不能用 `## @api private` 绑定 `extends` 或创造新的公开 owner。当前解析器的维护索引不承诺覆盖 classless 内部类或任意深度嵌套类型，源码和校验器仍是这些声明的依据。批量补写与检查流程见 [私有维护文档编写指南](docs/maintainers/private-doc-comments.md)。

为兼顾 Godot 编辑器悬停文档和机器可读标签，正文说明与机器标签之间、以及连续机器标签之间都应插入一行 `## [br]`。Godot 会把文档注释按 BBCode 渲染；没有显式分隔时，多行说明和 `@api` / `@param` / `@return` / `@schema` 等标签容易在悬停提示中合并为一段。`[br]` 只用于渲染换行，不改变标签语义。

历史迁移期间补齐的 `@since` 不再使用占位版本 `1.0.0`。完成 API Surface 迁移后，既有公开 API 的起算版本统一使用当次 GF 发布版本；新增 API 在版本已确定时使用它首次公开发布的 GF 版本，在版本未确定时临时使用 `@since unreleased`。唯一的 `1.0.0` 历史 owner 基线是已经由版本历史证明的 `Gf` AutoLoad 文件级契约；它不能作为其他类型或成员使用 `1.0.0` 的先例。不要使用 `x.x.x`、`未发布`、空值或其他占位写法，因为这些写法难以被机器稳定识别和发布前替换。

## 文件结构与 section

`##` 文档块必须绑定到一个明确声明：`class_name`、内部 `class`、`signal`、`enum`、`const`、`var` 或 `func`。唯一额外绑定形态是 `addons/gf/kernel/core/gf.gd` 的文件级 `## @api_owner autoload Gf` 文档块，它必须紧邻下一条顶层 `extends Node`。没有绑定声明的脚本说明、维护说明、模板说明必须使用普通 `#`。这条规则避免半自动文档生成器把 classless helper 的顶部说明误判成公开 API。

对外公开或可重写的顶层 API 必须位于带 `class_name` 的脚本中。唯一例外是上述受控 `Gf` AutoLoad owner；仅仅继承 `Node`、由项目设置注册为单例或参与编辑器插件生命周期，都不会自动获得公开 owner。没有 `class_name` 的其他 helper、模板、数据、插件和单例脚本只能暴露 `framework_internal` / `layer_internal` 协作入口，或记录 `private` 成员文档，不能承诺 `public` / `protected` API。未知 owner kind/name、错误路径、非 `Node` 基类、悬空或重复 `@api_owner` 必须失败关闭。

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
- 私有声明允许使用带非空正文和显式 `@api private` 的 `##`；函数体局部实现原因使用普通 `#`。缺少标签、重复可见性、错误命名或分区不能因为是维护文档而豁免。
- `##` 文档块必须绑定到紧随其后的声明；悬空 `##` 视为违规。
- `@api_owner` 只接受精确的 `autoload Gf`，只允许出现在 `addons/gf/kernel/core/gf.gd`，并必须紧邻绑定到顶层 `extends Node`；它必须同时声明 `@api public`、`@category runtime_service`、`@since 1.0.0` 和 `@layer kernel/core`。
- 带 `## @api` 的未知声明形态视为违规，必须先扩展 API Surface Contract 和校验器。
- 顶层 `public` / `protected` API 必须位于 `class_name` 脚本或精确受控的 `Gf` AutoLoad owner 中；普通 classless `Node` / 插件单例不是例外。
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
