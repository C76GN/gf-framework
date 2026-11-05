# Model 属性定义

在没有 GF Framework 之前，如果 UI 想要在玩家等级发生变化时更新文字显示，往往需要玩家模块广播专门的 `PlayerLvlChangedEvent` 事件，然后 UI 端再订阅、解析 payload 并更新界面。

如果大量 UI 字段都用全局事件同步，事件总线会承担过多局部展示职责，也会让调试日志和事件追踪变得嘈杂。

`GFBindableProperty` 位于 `addons/gf/kernel/core/gf_bindable_property.gd`。它是对单实例值的封装槽体，内部含有一个 `value_changed` 响应信号。

工作模型是标准观察者模式：

```text
Model (Hold Property) -> Controller (Subscribe)
```

普通 `GFBindableProperty` 本身不阻止外部调用 `set_value()`。如果某个值只应该由 Model 内部修改，应在 Model 上封装业务方法，或对外暴露 `GFReadOnlyBindableProperty` 只读视图。

```gdscript
## 玩家可观察数据的归属模型；业务修改通过模型方法表达。
class_name PlayerModel extends GFModel

## 等级的可观察槽体；普通 GFBindableProperty 本身不限制外部写入。
var level := GFBindableProperty.new(1)

## 玩家名称的可观察槽体，供表现层读取和订阅。
var player_name := GFBindableProperty.new("Guest")

## 提交一次等级提升，并由属性槽体通知订阅者。
func level_up() -> void:
	level.set_value(level.get_value() + 1)
```
