# 音频管理

`GFAudioUtility` 提供背景音乐、音效、环境音、音频片段、播放历史、资源化音频事件、音频 Bank、混音控制和可插拔后端协议。它是标准库的通用音频基础设施，不内置第三方 SDK、声音优先级、平台权限或项目事件命名。

## 阅读入口

- [播放基础](playback/index.md)：BGM、SFX、环境音、音频片段、播放历史、总线音量、节拍时钟和并发限制。
- [音频后端与事件资源](backend-events.md)：`GFAudioBackend`、后端能力、事件、参数、状态和开关。
- [Audio Bank 与配置工具](banks-tools/index.md)：`GFAudioBank`、分层事件 ID、扫描导入、校验和 Inspector 入口。
- [Bank 挂载、空间音效与句柄](mounting-spatial-handles.md)：`GFAudioBankMounter`、bank 栈、2D/3D 音效和 `GFAudioEmitterHandle`。

## 使用边界

GF 层只提供通用播放入口、资源加载协作、对象池复用、混音控制、后端协议和配置校验。声音优先级、剧情状态、场景预加载策略、距离规则、碰撞触发、音频权限和业务生命周期应由项目层或独立音频插件负责。
