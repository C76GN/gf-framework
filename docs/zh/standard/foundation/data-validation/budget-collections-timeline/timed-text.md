# 时间段文本轨道

时间段文本轨道用于保存“某段时间显示某段文本”的通用数据。它可以服务字幕、对白、教程提示、歌词、时间轴注释或项目自己的媒体标记，但不绑定任何 UI 控件或具体格式。

```gdscript
var parsed := GFTimedTextImporter.parse_srt(srt_text, &"caption")
var track := parsed["track"] as GFTimedTextTrack

var current_text := track.get_text_at_time(12.5)
var nearby_entries := track.get_entries_in_range(10.0, 15.0)
```

`GFTimedTextEntry` 只保存 `start_time`、`end_time`、`text` 和元数据；`GFTimedTextTrack` 负责排序、按时间查询、范围查询、总时长和字典转换；`GFTimedTextImporter` 只提供 SRT、WebVTT 和 LRC 的轻量解析入口。

无论通过 `add_entry()`、`apply_dictionary()`、脚本直接赋值还是 Inspector 写入，时间字段都会保持有限、非负且 `end_time >= start_time`。非有限值归零；提高 start 超过现有 end 时，end 会同步推进到新的 start。零长度条目仍是允许的数据形态，但半开区间查询不会命中它。

复杂字幕样式、富文本清洗、语音同步、动画注入和本地化选择仍应放在项目层或专门扩展里。
