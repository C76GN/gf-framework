# 三阶段初始化

调用 `Gf.init()` 后，框架会遍历所有模块组件，并依次触发 `init()`、`async_init()`、`ready()` 三个阶段。默认保持注册顺序；如果模块设置了 `lifecycle_priority`，同类模块会按数值从高到低初始化，释放时反向处理。

所有 `GFModel`、`GFSystem` 和 `GFUtility` 基类都提供这三个虚方法供模块重写。架构生命周期只调用这三个基类的强类型虚方法；普通 `Object` 或未继承对应基类的对象不能作为框架模块注册，也不会依靠同名方法参与生命周期。

## 同步初始化

```gdscript
func init() -> void:
	# 同步的初步设置。
```

`init()` 会首先遍历并调用所有实例。它适合执行没有外部依赖、立即完成的轻量设置，例如绑定初始响应式属性、设置默认数值等。

此时不能保证其他模块已经完成 `init()`，因此不建议在这里频繁跨模块调用。

## 异步等待

```gdscript
func async_init() -> void:
	var asset_utility := Gf.get_utility(GFAssetUtility) as GFAssetUtility
	var load_state := { "done": false, "resource": null }
	asset_utility.load_async("res://data/tables.json", func(resource: Resource) -> void:
		load_state.resource = resource
		load_state.done = true
	)
	while not load_state.done:
		await Engine.get_main_loop().process_frame
```

`async_init()` 会在所有 `init()` 执行完毕后串行运行。它返回 `void`，但 Godot 4 支持在 `void` 函数内部使用 `await`；框架的 `Gf.init()` 会自动等待每个模块的 `async_init()` 完成，避免模块在异步资源未就绪前进入 `ready()` 或 tick。

## 就绪完成

```gdscript
func ready() -> void:
	register_simple_event(&"GAME_STARTED", _on_game_started)
```

`ready()` 会在所有模块的 `async_init()` 结束后触发。此时整个架构已经完成挂载，模块可以安全获取其他 Model、System 或 Utility，并注册事件监听。

## 释放引用

```gdscript
func dispose() -> void:
	_stop_runtime_work()

func release_dependencies() -> void:
	_cached_utility = null
	super.release_dependencies()
```

架构注销模块或整体 `dispose()` 时，会先调用模块的 `dispose()`，再调用 `release_dependencies()`。`dispose()` 负责停止模块自身工作、断开业务监听和释放本模块拥有的对象；`release_dependencies()` 只负责清空模块缓存的外部 Model/System/Utility 引用，并释放框架注入作用域。

GF 不会自动扫描并清空模块的任意成员变量。需要释放哪些引用由模块自己声明，避免在错误生命周期点破坏模块自己的 dispose 逻辑。
