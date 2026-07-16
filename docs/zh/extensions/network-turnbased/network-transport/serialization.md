# 序列化与消息解码

`GFNetworkSerializer` 默认使用 Godot Variant 二进制格式；切到 `Format.JSON` 时使用 Godot JSON 可表达的普通结构。如果 JSON 通道需要保留 `Vector2`、`Color`、`NodePath`、PackedArray 等 Godot 类型，可显式启用类型化 JSON codec。

```gdscript
network.serializer.format = GFNetworkSerializer.Format.JSON
network.serializer.use_typed_json_codec = true
```

类型化 codec 由 `GFVariantJsonCodec` 提供，只改变当前 serializer 的 JSON 编码方式。解码时优先使用 `deserialize_message_result(bytes)` 或 `deserialize_dictionary_result(bytes)`，结果会包含 `ok`、`data` 和 `error`，可明确区分合法空字典、空 bytes、非字典 JSON 和消息结构错误。

字段级网络序列化会在 float、Vector 和 Color 边界把 `NaN` / `Infinity` 规范化为有限数值，避免不可表达的数进入 JSON、日志或跨端协议。需要保留特殊数值语义的项目应使用显式枚举、状态字段或项目自定义编码。

`GFNetworkUtility` 收到无法解码的包体时，会在 `message_rejected` 的 details 中带上同一份结果字典。
