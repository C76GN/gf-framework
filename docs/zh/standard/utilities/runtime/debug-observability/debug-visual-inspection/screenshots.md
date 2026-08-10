# 截图捕获与批量保存

`GFScreenshotUtility` 提供无 UI 的 Viewport 截图捕获、Image 保存和批量尺寸/语言截图流程。它只处理图像、路径、格式和结果记录，不创建调试菜单、不监听快捷键、不规定截图面板，也不负责上传或发布素材命名规则。

## 基本保存

```gdscript
var screenshots := Gf.get_utility(GFScreenshotUtility) as GFScreenshotUtility

var result := screenshots.save_viewport_screenshot("", {
	"directory": "user://screenshots",
	"prefix": "bug_report",
	"locale": TranslationServer.get_locale(),
	"resolution": DisplayServer.window_get_size(),
	"format": GFScreenshotUtility.FORMAT_PNG,
})

if result.ok:
	print(result.path)
```

`save_viewport_screenshot()` 默认捕获当前 SceneTree root，也可以通过 `viewport` 传入任意 `Viewport` / `SubViewport`。返回值是结构化字典，包含 `ok`、`path`、`format`、`size`、`locale`、`resolution`、`error` 和 `reason`，方便项目自己的调试菜单、QA 工具或自动化脚本统一处理。

## 保存已有 Image

如果项目已经通过渲染管线、编辑器工具或测试生成了 `Image`，可以直接调用 `save_image()`：

```gdscript
var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
image.fill(Color.BLACK)

var record := screenshots.save_image(image, "user://screenshots/mask_preview.png", {
	"unique": true,
})
```

支持格式包括 `png`、`jpg` 和 `webp`；`quality` 控制 JPEG/WebP 的有损质量。`unique` 默认为 true，会在目标文件存在时追加数字后缀，避免覆盖。

## 批量尺寸与语言

```gdscript
var report := await screenshots.capture_burst({
	"directory": "user://store_screenshots",
	"prefix": "main_menu",
	"locales": ["en", "zh_CN"],
	"resolutions": [Vector2i(1280, 720), Vector2i(1920, 1080)],
	"formats": [GFScreenshotUtility.FORMAT_PNG],
	"max_captures": 16,
	"use_subdirectories": true,
	"pause_tree": true,
})
```

`capture_burst()` 会临时切换窗口尺寸和 `TranslationServer` 语言，等待渲染帧后保存截图，并在结束时恢复原始窗口尺寸、语言和暂停状态。它不隐藏项目 UI，也不判断哪些界面适合截图；需要隐藏调试层、打开指定菜单、上传或打包到发布流水线时，应在项目层控制调用前后的状态。

批量截图默认最多执行 `GFScreenshotUtility.DEFAULT_MAX_BURST_CAPTURES` 张，组合数量由 `locales * resolutions * formats` 决定。项目确实需要更大批量时可以通过 `max_captures` 调高，传入 `0` 表示不限制；当前没有另一个不可关闭的总工作量或墙钟上限，所以该模式只适合受信内部自动化，不应把 `max_captures` 直接交给玩家或第三方插件。超限时返回报告会包含 `error = "max_captures_exceeded"`、`planned_count` 与 `max_captures`，不会切换语言或窗口尺寸。

`frame_delay_seconds` 必须是有限值；NaN 或 Infinity 会在解析 Viewport、切换语言/窗口和等待渲染之前返回 `error = "invalid_frame_delay_seconds"`。有限但极大的延迟仍由取消 token 和调用方调度策略负责。

## 使用边界

- 面向玩家的截图、隐私确认、平台相册和分享 SDK 都属于项目层。
- 批量截图可能暴露账号、存档、调试 watch 或未发布内容，项目应在调用前关闭敏感 Overlay。
- 支持报告需要截图附件时仍可使用 `GFSupportReportUtility.include_screenshot`；底层截图能力由 `GFScreenshotUtility` 复用。
