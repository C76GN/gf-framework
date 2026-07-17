# 文本适配与富文本

如果项目需要让按钮、计数器、局部标签或富文本在固定区域内自动选择字体大小，可以使用 `GFTextFitter`。它是纯静态辅助类，不需要注册到架构，也不会修改布局规则；默认只把计算出的字体尺寸写入目标控件的 theme override。

```gdscript
GFTextFitter.fit_label(%TitleLabel, {
	"min_font_size": 12,
	"max_font_size": 32,
	"available_size": Vector2(220, 48),
})

GFTextFitter.fit_rich_text_label(%CostText, {
	"fit_height": true,
})

GFTextFitter.fit_control(%ApplyButton, {
	"min_font_size": 10,
	"max_font_size": 28,
})

GFTextFitter.fit_label(%CounterLabel, {
	"font_size_candidates": [12, 16, 20, 24],
})
```

`fit_control()` 会按常见 Godot 控件推导文本、主题字体名和内容边距，支持 `Button`、`LineEdit`、`TextEdit`、`Label` 和 `RichTextLabel`；无法识别的自定义控件可以通过 `options.text`、`font_name`、`font_size_name` 和 `content_insets` 显式提供信息。

`Label`、`RichTextLabel`、`Button`、`LineEdit` 和 `TextEdit` 的测量会尽量读取控件自身的 `horizontal_alignment` / `alignment`、`autowrap_mode`、`justification_flags` 和 `text_direction`，让自动字号与 Godot 实际文本排版保持一致。自定义控件也可以在 options 中显式传入 `horizontal_alignment`、`autowrap_mode`、`line_break_flags`、`justification_flags` 或 `text_direction`。

`measurement_mode` 默认是 `GFTextFitter.MeasurementMode.AUTO`，会保留上述完整排版语义。棋盘数字、计分、短计数器等确定不会换行的文本，可以显式选择 `SINGLE_LINE`：它只在最大字号调用一次单行字体测量，再按可用宽高比例推导连续字号或候选字号，避免二分搜索反复创建临时 shaped-text 数据。调用 `fit_control(label, options)` 时，显式 `options.text` 也会作为测量文本保留，不会因 Label 分派而丢失。

```gdscript
GFTextFitter.fit_control(%TileValue, {
	"text": value_text,
	"min_font_size": 12,
	"max_font_size": 48,
	"available_size": Vector2(100, 100),
	"measurement_mode": GFTextFitter.MeasurementMode.SINGLE_LINE,
})
```

`SINGLE_LINE` 是一次测量的比例估算，适合无换行短文本；它不会模拟自动换行。正文、本地化长句和需要严格换行高度的 Label 保持默认 `AUTO`，自定义测量宿主需要强制完整排版时可选择 `MULTILINE`。

如果界面有固定字阶或品牌字体规范，可以传入 `font_size_candidates`。候选集会先按 `min_font_size` / `max_font_size` 过滤并去重，然后从大到小选择第一个适配值；没有合法候选时仍回到普通连续字号搜索。

需要随控件 resize 或语言变化自动刷新时，把 `GFTextAutoFit` 挂到目标控件下，或用 `target_path` 指向目标 Control。`GFTextFitter` / `GFTextAutoFit` 只处理通用文本尺寸适配；换行策略、截断、省略号、本地化长词拆分和具体 UI 视觉仍应由项目自己的控件或主题决定。

## 富文本格式化

如果项目需要把玩家输入、配置文本、调试日志或本地化片段安全写入 `RichTextLabel`，可以使用 `GFRichTextFormatter`。它是纯静态辅助类，不注册架构、不加载资源，也不规定文本来源或图标集。

```gdscript
var bbcode := GFRichTextFormatter.to_bbcode("Hello {{name}} :confirm:", {
	"markup": GFRichTextFormatter.MARKUP_PLAIN,
	"variables": {
		"name": player_name,
	},
	"token_resolver": func(token: String) -> String:
		return "[img]res://ui/icons/%s.png[/img]" % token,
})
%RichTextLabel.text = bbcode
```

`MARKUP_PLAIN` 会转义所有 BBCode 控制字符；`MARKUP_MARKDOWN` 只转换粗体、斜体、删除线、行内 code、链接和图片这组常见子集，其余文本仍会转义；`MARKUP_BBCODE` 则保留项目已经构造好的 BBCode。

`replace_variables()` 默认转义变量值，适合用户文本、本地化参数和外部数据；`replace_tokens()` 默认允许 resolver 返回 `[img]...[/img]` 这类项目生成的 BBCode，但只会处理由字母、数字、下划线、短横线和点组成的安全 token。复杂排版、逐字播放、语言分词、图标资源存在性检查和 UI 交互仍应留在项目层。
