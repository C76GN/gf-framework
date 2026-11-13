# GFUINavigationResolver

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_navigation_resolver.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

项目内容就绪与语义定位的异步协议。 回调及完成源必须在主线程运行。Router 为每次导航分配独立 scope；项目在异步返回后、 写入界面前必须检查 scope.is_active。完成源成功表示该阶段已完成，业务数据不进入结果。 默认实现拒绝，不能把页面入栈或资源已加载冒充内容已经可用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`prepare_content`](#member-gfuinavigationresolver-methods-prepare_content) | `func prepare_content( panel: Node, target: GFUINavigationTarget, scope: GFAsyncScope ) -> GFAsyncCompletion:` |
| 方法 | [`resolve_target`](#member-gfuinavigationresolver-methods-resolve_target) | `func resolve_target( panel: Node, target: GFUINavigationTarget, scope: GFAsyncScope ) -> GFAsyncCompletion:` |
| 方法 | [`_prepare_content`](#member-gfuinavigationresolver-methods-_prepare_content) | `func _prepare_content( _panel: Node, _target: GFUINavigationTarget, _scope: GFAsyncScope ) -> GFAsyncCompletion:` |
| 方法 | [`_resolve_target`](#member-gfuinavigationresolver-methods-_resolve_target) | `func _resolve_target( _panel: Node, _target: GFUINavigationTarget, _scope: GFAsyncScope ) -> GFAsyncCompletion:` |

## 方法

<a id="member-gfuinavigationresolver-methods-prepare_content"></a>

### `prepare_content`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_content( panel: Node, target: GFUINavigationTarget, scope: GFAsyncScope ) -> GFAsyncCompletion:
```

开始等待页面内容可用；成功之后 Router 才允许目标定位。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 已入栈页面，异步代码不能假定其一直有效。 |
| `target` | 冻结的语义请求。 |
| `scope` | 本次导航独有的作用域，不能由项目正常完成。 |

返回：阶段完成源；成功为内容就绪，失败或取消不回滚已提交页面。

<a id="member-gfuinavigationresolver-methods-resolve_target"></a>

### `resolve_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func resolve_target( panel: Node, target: GFUINavigationTarget, scope: GFAsyncScope ) -> GFAsyncCompletion:
```

在内容就绪后定位语义目标，例如选择页签、滚动到条目。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 已入栈且完成内容准备的页面。 |
| `target` | 冻结的非空语义目标。 |
| `scope` | 同一次导航的活动作用域。 |

返回：成功表示目标已定位；失败映射为 target_unavailable，保留页面。

<a id="member-gfuinavigationresolver-methods-_prepare_content"></a>

### `_prepare_content`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _prepare_content( _panel: Node, _target: GFUINavigationTarget, _scope: GFAsyncScope ) -> GFAsyncCompletion:
```

项目实现内容准备协议；无需等待时可以返回已成功的完成源。

参数：

| 名称 | 说明 |
|---|---|
| `_panel` | 已提交页面。 |
| `_target` | 冻结请求。 |
| `_scope` | 异步写回资格。 |

返回：默认返回 content_unavailable 失败。

<a id="member-gfuinavigationresolver-methods-_resolve_target"></a>

### `_resolve_target`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _resolve_target( _panel: Node, _target: GFUINavigationTarget, _scope: GFAsyncScope ) -> GFAsyncCompletion:
```

项目在内容准备之后实现具体定位；目标消失必须失败。

参数：

| 名称 | 说明 |
|---|---|
| `_panel` | 当前可用页面。 |
| `_target` | 冻结语义目标。 |
| `_scope` | 写入页面前必须仍活动。 |

返回：默认返回 target_unavailable 失败。
