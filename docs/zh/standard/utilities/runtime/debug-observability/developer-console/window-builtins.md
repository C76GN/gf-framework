# 控制台窗口与内置命令

按下 **F1**（可配置）即可呼出半透明控制台。默认保持全屏覆盖；也可以启用窗口模式，让控制台以可拖拽、可缩放面板呈现。

控制台内置命令：

- `help`：列出所有指令。
- `clear`：清空输出。
- `scene.tree`：只读场景树摘要。
- `scene.node`：只读节点摘要。

控制台会自动接收 `GFLogUtility` 的日志信号并着色显示：Error/Fatal 红色、Warn 黄色、Debug 青色。

界面内置日志标签过滤输入框，支持 `Tab` 补全命令、上下方向键切换输入历史。未知命令也可通过 `suggest_similar_commands()` 给出相似候选。

命令需要参数补全时，可以在注册 metadata 中传入 `argument_suggester`，或在 `GFConsoleCommandDefinition.argument_suggester` 上挂运行时 Callable。回调接收 `command_name`、`args`、`argument_index`、`prefix` 和 `raw_input`，返回“参数语义值”字符串数组；控制台按当前参数前缀过滤，并用与命令 parser 对称的引号/反斜杠编码写回。空字符串、首尾空白、空格、单双引号和反斜杠都能作为一个 token 往返，suggester 不应预先加入展示用引号。

`argument_suggester` 当前是主线程同步、受信任的调试回调；普通快照不会调用它，但一次 Tab 会执行一次。应只返回已经缓存的小型候选集，不要在回调中同步扫描资源树、访问网络或构造无界数组。统一的候选数量、字符串长度与执行时限合同尚未建立，因此项目仍需主动保持该回调有界。
