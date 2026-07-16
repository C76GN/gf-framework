# Capability Node 能力与场景容器

这一页说明需要输入、动画、子节点引用或 Inspector 管理的节点能力。Node 能力可以保留场景树结构，同时通过 Capability 系统注册到 receiver。

## Node 能力与场景容器

需要输入、动画、子节点引用或编辑器 Inspector 管理的能力可以继承节点能力基类。`GFNodeCapability` 自身继承自普通 `Node`，适合做不依赖空间变换的能力根节点和依赖入口：

```gdscript
class_name HitboxCapability
extends GFNodeCapability

@export var damage: int = 1
```

如果能力本身需要继承空间变换或 UI 布局，请按 Godot 节点分支选择更具体的基类：

```gdscript
class_name Sensor2DCapability
extends GFNode2DCapability
```

```gdscript
class_name Attachment3DCapability
extends GFNode3DCapability
```

```gdscript
class_name PanelBindingCapability
extends GFControlCapability
```

当能力实例是 `Node`，且 receiver 也是 `Node` 时，能力会自动挂入 receiver 下的 `GFCapabilityContainer`。你也可以在场景中手动添加 `GFCapabilityContainer`，并把带脚本的能力节点放在容器下：

```text
Enemy
└── GFCapabilityContainer
	└── HitboxCapability
```

如果 receiver 与能力同属 `Node2D`、`Node3D` 或 `Control` 分支，框架会创建对应类型的能力容器，避免普通 `Node` 容器打断空间变换或 UI 继承。手动摆放 2D/3D/UI 能力时也推荐使用同分支容器，或直接通过 GF Inspector 添加能力，让框架自动创建匹配容器。已摆放在 receiver 直属能力容器下的子能力会被视为项目明确布局，注册时不会因为容器分支和能力节点分支不一致而强制迁移；这允许 `GFCapabilityContainer2D` 中挂载普通 `GFNodeCapability`，也避免容器进树扫描期间触发 Godot 的 children setup 限制。

碰撞类能力仍需要遵循 Godot 节点规则：`CollisionShape2D` 应放在 `Area2D`、`CharacterBody2D`、`StaticBody2D` 等 `CollisionObject2D` 下。能力根节点可以继承 `GFNode2DCapability` 保留 2D 变换，再在能力根节点下放一个 `Area2D`，并把 `CollisionShape2D` 放到该 `Area2D` 下；或者让能力场景根节点直接继承合适的 Godot 碰撞节点并实现 GF 能力 Hook。复杂场景能力的子节点如果实现了 `inject_dependencies(architecture)` 或 `inject(architecture)`，也会在能力挂载时递归收到当前架构注入。

容器进入场景树时会立即尝试把子节点能力注册到父节点 receiver，并保留一次延迟重试，便于宿主或状态机在 `_ready()` / `_enter()` 中查询已经随场景摆放好的 `GFNodeCapability`。如果旧场景或编辑器添加流程中留下的是带 `_gf_capability_container` 元数据、或命名为 `GFCapabilityContainer2D` / `GFCapabilityContainer3D` / `GFCapabilityContainerControl` / `GFCapabilityContainer` 的空间容器，但容器脚本没有成功附着，`GFCapabilityUtility.get_capability()` 也会在查询时同步扫描这些直属容器并注册其子能力。这样 Inspector 创建出的 2D/3D/UI 容器即使不是普通 `GFCapabilityContainer`，也应在 receiver `_ready()` 中可查询。该兜底只识别 GF 容器标记或 GF 容器命名，不会扫描任意普通子节点。

如果运行时代码在 receiver 自身进入场景树的 setup 阶段动态添加 Node 能力，能力记录会立即写入，容器节点挂树会延迟到安全时机，避免 Godot 拒绝在 children setup 阶段 `add_child()`；如果 receiver 在同一帧被释放，延迟挂载或移除会在执行前重新检查节点有效性并静默放弃。该功能需要当前上下文或全局架构中已注册 `GFCapabilityUtility`；如果项目在容器进树后才初始化架构，可在架构就绪后调用 `register_children_now()` 主动扫描。

能力实例具有单一 owner 语义，同一个 `GFCapability` / `GFNodeCapability` 实例不能同时挂到多个 receiver；需要复用配置时应创建新实例或使用 `GFCapabilityRecipe`。场景中的 `GFCapabilityContainer` 会跟踪已注册子能力的弱引用和退出树回调；子能力被提前 `remove_child()`、reparent 或释放时，也会从原 receiver 上注销，避免容器退出时只遍历当前子节点而漏掉已经移走的能力记录。`remove_capability()` 表示移除并释放由能力系统管理的实例；场景容器离树时会使用 `unregister_capability()` 只解除登记，不释放本来由场景树拥有的子节点。框架自动创建的空能力容器会在最后一个 Node 能力被移除后释放，避免场景树残留空容器。

`GFCapabilityUtility` 的销毁也遵循同一所有权边界：通过 `add_capability()` 创建的能力，以及通过 `add_scene_capability()` 实例化的能力场景，会在 Utility / 架构 `dispose()` 时先注销再释放；通过 `add_capability_instance()` 传入的外部实例、或原本就摆在场景容器中的节点能力，只会注销记录和 Hook，不会被 Utility 接管释放。如果销毁发生在 Gf AutoLoad 的 `_exit_tree()` 同步释放作用域内，受管节点和只包含待释放节点的自动容器会保持挂树并登记延迟释放，避免重入修改正在拆除子节点的父节点。项目希望节点生命周期由场景树或对象池控制时，应使用外部实例入口；希望能力跟随架构销毁时，应让 Utility 创建或实例化该能力。外部实例、provider 返回实例和场景根节点都必须用自身脚本类型注册，或注册为其脚本继承链上的基类；声明类型不匹配时会被拒绝，避免能力索引被错误类型污染。

启用 GF 插件后，选中普通 `Node` 时 Inspector 会显示 `GF Capabilities` 区域。这里可以添加、启停、编辑和移除继承 `GFNodeCapability`、`GFNode2DCapability`、`GFNode3DCapability` 或 `GFControlCapability` 的能力脚本或能力场景；也可以从 `Recipe` 菜单把 `GFCapabilityRecipe` 中的节点能力条目应用到当前节点。通过 Inspector 添加的容器和能力是可见场景节点，便于在场景树中检查与保存。添加、Recipe 应用、启停和移除会写入 Godot 编辑器撤销栈，便于和其他场景编辑操作一起撤销或重做。Inspector 内联区域只展示能力脚本自己的导出属性；需要编辑完整 Node 属性时可点击“编辑”进入能力节点自身 Inspector。

Inspector 的“校验”按钮会检查当前节点能力的重复脚本和 `required_capabilities` 声明缺失项，并用统一报告展示错误、警告和下一步建议。编辑器校验只读取场景结构与导出属性，不会执行非 `@tool` 的项目能力脚本方法；这避免业务逻辑在编辑器中运行。它只辅助编辑器排查节点能力组合，不会自动补齐业务能力，也不会替代运行时 `GFCapabilityUtility.inspect_receiver()`。编辑器菜单也提供 `工具 > GF > 生成 Capability`、`生成 NodeCapability`、`生成 Node2DCapability`、`生成 Node3DCapability` 与 `生成 ControlCapability` 模板入口。
