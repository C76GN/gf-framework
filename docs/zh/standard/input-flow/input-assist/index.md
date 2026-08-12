# 输入映射与手感辅助总览

这一组输入工具负责抽象动作、玩家设备、输入缓冲、连击窗口、虚拟输入、重映射、触发器和触屏辅助等通用输入流程。它们只把具体输入整理成稳定动作状态，不决定移动、战斗、UI 导航、玩家加入或任何项目业务规则。

## 阅读入口

- [输入动作、上下文与消费时机](input-mapping-actions.md)：`GFInputMappingUtility`、动作资源、上下文、一次性动作和读取位置。
- [Viewport 表面输入桥](viewport-surface-input-bridge.md)：把 provider 已解析的表面命中与标准化坐标安全转成鼠标或触摸事件，并以显式捕获回执防止迟到终止串代。
- [输入缓冲、指针活动与拖放](input-buffer-pointer-drag/index.md)：`GFInputAssistUtility`、`GFPointerActivityUtility` 和 `GFDragDropUtility`。
- [虚拟输入、录制回放与改键](virtual-recording-remap/index.md)：`GFVirtualInputSource`、`GFInputRecording`、`GFInputPlayback`、重映射配置、配置档和输入格式化。
- [输入修饰器与触发器](input-modifiers-triggers.md)：死区、缩放、归一化、范围映射、短按、长按、脉冲、组合和序列触发。
- [设备席位、方向历史与触屏输入](input-devices-touch/index.md)：`GFInputDeviceUtility`、本地多人、活跃设备、方向仲裁、加入输入、震动和触屏控件。

## 使用边界

输入层只表达“哪个抽象动作在什么时候产生什么值”。角色控制权、技能释放、UI 流程、按键图标资产、账号设置、回放文件格式和本地多人规则应在项目层组合这些工具。
