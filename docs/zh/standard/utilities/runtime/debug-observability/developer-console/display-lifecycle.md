# 显示配置与生命周期

可选显示配置：

```gdscript
console.toggle_key = KEY_F2
console.max_output_lines = 500
console.max_history_size = 100

console.windowed = true
console.background_alpha = 0.8
console.initial_window_size_ratio = Vector2(0.7, 0.55)
console.minimum_window_size = Vector2(420, 260)
console.keep_topmost = true
```

`windowed = false` 是兼容默认值，适合只在需要时全屏覆盖查看日志。

`windowed = true` 更适合边运行边观察状态或执行调试命令；拖拽区域位于标题文本，右下角手柄用于缩放。

`debug_only = true` 会在非 debug 构建中跳过 GUI 创建，适合把控制台注册代码留在通用启动流程里，但仍由项目发布策略决定是否注册调试命令。

正常运行中，控制台 GUI 在 `dispose()` 时会立即脱离场景树，并断开日志信号，避免关闭架构后同一帧仍留下调试输入层。Gf AutoLoad 正在执行 `_exit_tree()` 的同步释放作用域时只断开连接并登记延迟释放，不会重入修改正在拆除子节点的父节点。
