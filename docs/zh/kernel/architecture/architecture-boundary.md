# Kernel 核心单例与层级边界

这一页说明全局 `Gf`、纯代码容器 `GFArchitecture`、源码层级依赖方向，以及框架级工具在 AutoLoad 未就绪时应使用的安全入口。

## 核心单例与体系结构

整个框架的入口是全局 AutoLoad 节点 —— **`Gf`**。它挂载在 Godot 的全局根节点下，负责持有当前 `GFArchitecture`、执行项目级 Installer、代理常用注册/查询接口，并把 `_process` 与 `_physics_process` 转发给架构。

在 `Gf` 背后，真正承载所有业务的对象是 **`GFArchitecture`**。它是一个纯代码容器，负责管理所有 `Model`、`System`、`Utility` 的注册、生命周期调用以及事件总线的派发。主生命周期状态由内部 `GFKernelRuntime` 维护，项目通常只通过 `GFArchitecture.is_inited()`、`init()` 和 `dispose()` 观察或推进状态。`Foundation` 层则作为容器外的纯基础件，被这些运行时模块直接依赖。

## 层级依赖边界

GF 的源码层级必须保持单向依赖：

```text
addons/gf/kernel   <-  addons/gf/standard   <-  addons/gf/extensions
```

`kernel` 是最底层，只能放框架启动、注册、注入、生命周期、事件、绑定、扩展机制、编辑器扩展点和内核协议。`standard` 可以依赖 `kernel`，但 `kernel` 不能 `preload()`、`load()` 或直接引用 `standard` 的脚本路径和具体类名。`extensions` 是可选能力，必须通过 manifest、协议或用户显式装配接入；`kernel` 和 `standard` 都不能硬绑定、动态探测或弱联动某个 GF 内置扩展。

判断一个能力是否该进入 `kernel` 时，用一条规则：**如果 `kernel` 运行时必须直接知道它，它就是内核契约或内核基础设施。** 例如 `GFScriptTypeInspector` 被容器注册校验、事件可赋值派发、绑定和编辑器类型索引共同使用，因此属于 `addons/gf/kernel/core`；时间缩放则由 `GFTimeProvider` 定义为内核协议，标准库的 `GFTimeUtility` 只是一个实现。

根插件 `addons/gf/plugin.gd` 是组合入口，可以同时知道 `kernel` 与 `standard`，负责把标准库声明的编辑器增强记录传给 `kernel/editor` 辅助脚本。这个例外不改变内核边界：`addons/gf/kernel/**` 本身仍不能依赖 `addons/gf/standard/**`。

框架内部通过 `GFAutoload` 解析全局 AutoLoad 节点，避免插件首次导入、脚本解析或测试环境里直接引用全局 `Gf` 时出错。`get_architecture_or_null()` 只表示全局架构实例已经存在，不保证它完成 `init()`；需要读取 ready 后模块时，应使用 `get_ready_architecture_or_null()`。项目代码通常继续使用 `Gf.get_model()` 等入口；只有编写框架级工具、编辑器脚本或需要在 AutoLoad 未就绪时安全探测架构，才需要直接使用这些辅助入口。

```text
Godot SceneTree
 └── Root
	  └── Gf (AutoLoad) -> [GFArchitecture 容器]
							  ├── Models     (GFModel)
							  ├── Systems    (GFSystem)
							  ├── Utilities  (GFUtility)
							  └── EventBus   (GFTypeEventSystem)

Standard Foundation Layer
 ├── Numeric    (GFBigNumber / GFFixedDecimal)
 ├── Formatting (GFNumberFormatter)
└── Math       (GFProgressionMath)
```
