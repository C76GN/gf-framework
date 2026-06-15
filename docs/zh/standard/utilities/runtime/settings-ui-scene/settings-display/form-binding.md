# 表单控件绑定

设置界面可以使用 `GFControlValueAdapter` 和 `GFFormBinder` 读写常见 `Control` 值，避免每个设置页重复判断 `LineEdit`、`CheckBox`、`Slider`、`OptionButton` 等控件类型。

```gdscript
var binder := GFFormBinder.new()
binder.bind_field(&"player_name", %NameEdit)
binder.bind_field(&"fullscreen", %FullscreenCheck)
binder.bind_field(&"master_volume", %MasterVolumeSlider)

binder.write_values(settings.to_dict(false))
binder.field_changed.connect(func(key: StringName, value: Variant) -> void:
	settings.set_value(key, value)
)
```

`GFFormBinder.bind_field()` 会在重复绑定同一字段前清理旧连接，`unbind_field()` / `clear()` 也会断开由 `GFControlValueAdapter` 创建的值变化监听。

需要自己管理连接生命周期时，可使用 `connect_value_changed_with_handles()` 和 `disconnect_value_changed_handles()`。

如果需要把控件长期同步到一棵运行时状态树，而不是一次性批量 read/write 表单值，使用 [响应式状态与控件绑定](../../reactive-state.md) 中的 `GFReactiveStateStore` 和 `GFReactiveStateControlBinder`。`GFFormBinder` 负责表单字段读写，`GFReactiveStateControlBinder` 负责 store path 与单个控件的双向同步。
