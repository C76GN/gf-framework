# GFBindingPlan

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_binding_plan.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

Installer 使用的显式、顺序、fail-fast required binding 计划。 声明时冻结每个 Builder 的配置；execute() 仅接纳尚未进入 init/READY 的候选 Architecture。首个失败会冻结类型化结果、使候选初始化失败并结算 Installer scope；成功不会替调用方 complete scope。READY 架构继续使用既有热拓扑 API， 不由本计划修改。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`require_singleton`](#member-gfbindingplan-methods-require_singleton) | `func require_singleton( binding_id: StringName, builder: GFBindBuilder ) -> GFBindingPlan:` |
| 方法 | [`require_transient`](#member-gfbindingplan-methods-require_transient) | `func require_transient( binding_id: StringName, builder: GFBindBuilder ) -> GFBindingPlan:` |
| 方法 | [`execute`](#member-gfbindingplan-methods-execute) | `func execute(scope: GFAsyncScope) -> GFBindingPlanResult:` |

## 方法

<a id="member-gfbindingplan-methods-require_singleton"></a>

### `require_singleton`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func require_singleton( binding_id: StringName, builder: GFBindBuilder ) -> GFBindingPlan:
```

追加一个 required singleton entry，并立即冻结 Builder 配置。 Plan 开始执行后调用保持 no-op；不会修改已经冻结的 entry。

参数：

| 名称 | 说明 |
|---|---|
| `binding_id` | 调用方定义的非空稳定 ID；同一 Plan 内必须唯一，最长 128 字符。 |
| `builder` | 由创建本 Plan 的同一 GFBinder 架构生成的 Builder。 |

返回：当前 Plan，便于继续声明 entry。

<a id="member-gfbindingplan-methods-require_transient"></a>

### `require_transient`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func require_transient( binding_id: StringName, builder: GFBindBuilder ) -> GFBindingPlan:
```

追加一个 required transient factory entry，并立即冻结 Builder 配置。 只有 bind_factory() 的 SELF 或 from_factory() 来源支持 transient。 Plan 开始执行后调用保持 no-op；不会修改已经冻结的 entry。

参数：

| 名称 | 说明 |
|---|---|
| `binding_id` | 调用方定义的非空稳定 ID；同一 Plan 内必须唯一，最长 128 字符。 |
| `builder` | 由创建本 Plan 的同一 GFBinder 架构生成的 Builder。 |

返回：当前 Plan，便于继续声明 entry。

<a id="member-gfbindingplan-methods-execute"></a>

### `execute`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func execute(scope: GFAsyncScope) -> GFBindingPlanResult:
```

按声明顺序执行 required entry，并在首个失败处停止。 仅接纳 pre-init candidate Architecture；READY 架构不会被 claim、失败或修改。 Plan 是 strict single-execute handle：执行中重入或结算后 replay 均返回 ALREADY_EXECUTED，且不会触碰重入调用的新 scope 或 Architecture。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前 Installer 拥有的异步取消作用域；成功时仍由调用方拥有。 |

返回：精确 GFBindingPlanResult 终态。
