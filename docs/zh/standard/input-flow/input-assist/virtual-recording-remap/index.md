# 虚拟输入、录制回放与改键

本组页面说明自动化测试、回放、AI 控制和改键界面如何写入或保存抽象动作，而不是伪造具体按键事件。

## 阅读入口

- [虚拟输入与录制回放](virtual-recording.md)：`GFVirtualInputSource`、`GFInputRecording` 和 `GFInputPlayback`。
- [共享键盘本地多人](shared-keyboard-local-multiplayer.md)：把互斥键区显式路由到玩家级 `GFVirtualInputSource`，并处理释放与失焦清理。
- [重映射配置与 Profile](remap-profiles.md)：`GFInputRemapConfig`、`GFInputProfileBank` 和持久化格式。
- [输入检测、格式化与图标](detection-formatting-icons.md)：`GFInputDetector`、`GFInputFormatter`、图标 provider、冲突分析和上下文结构诊断。

## 使用边界

这些工具只表达抽象动作的写入、记录、播放和显示。具体按键 UI、云同步、账号配置、反作弊、AI 策略和回放文件管理应由项目层负责。
