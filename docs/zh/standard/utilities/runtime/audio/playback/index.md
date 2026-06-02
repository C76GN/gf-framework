# 播放基础

本组页面说明 `GFAudioUtility` 的 BGM、SFX、环境音、总线音量、混音控制和并发限制。GF 只提供通用播放入口、资源加载协作和播放器生命周期管理，不定义声音优先级、剧情状态或项目事件命名。

## 阅读入口

- [SFX 与音频片段](sfx-clips.md)：`play_sfx()`、`GFAudioClip`、异步加载、对象池复用和停止句柄。
- [BGM 控制](bgm-control.md)：切歌、crossfade、暂停恢复、seek、播放历史和自然结束信号。
- [环境音、总线与并发](ambient-bus-concurrency.md)：ambient channel、总线音量、混音快照、SFX 并发上限和溢出策略。
- [节拍时钟](beat-clock.md)：`GFAudioBeatClock`、BPM/拍号、offset、边界事件和时间量化。

## 使用边界

播放基础只处理通用播放入口、加载协作、总线/效果属性和并发限制。声音优先级、剧情状态、平台权限和项目事件命名应由项目或独立音频插件负责。
