# 强类型访问器生成

编辑器菜单 `工具 > GF > 生成强类型访问器` 会扫描项目中的 `class_name`，为 `GFModel`、`GFSystem`、`GFUtility`、`GFCommand`、`GFQuery` 和 Capability 生成强类型 helper。

## 输出与调用

输出路径由 `Project Settings > gf/codegen/access_output_path` 控制，默认是：

```text
res://generated/gf_access.gd
```

生成后的调用示例：

```gdscript
var player := GFAccess.get_player_model() as PlayerModel
var battle := GFAccess.get_battle_system() as BattleSystem
var command := GFAccess.create_deal_damage_command()
var health := GFAccess.get_health_capability(enemy) as HealthCapability
```

## 局部上下文

生成访问器默认只使用显式传入的 `GFArchitecture`，未传入时回退到全局 `Gf` 架构；它不会沿场景树自动寻找最近的 `GFNodeContext`。

在局部上下文的 Controller 或普通节点中使用时，应传入 `await wait_for_context_ready()` / `context.get_architecture()` 得到的架构：

```gdscript
var architecture := await wait_for_context_ready()
var player := GFAccess.get_player_model(architecture) as PlayerModel
var command := GFAccess.create_deal_damage_command(architecture)
```

## 使用边界

Command / Query 创建时会优先使用当前架构中注册的工厂；如果没有工厂且脚本可实例化，则回退到 `new()` 并注入当前架构。回退路径适合无构造依赖的简单对象；如果某个 Command / Query 必须走项目自定义工厂，应在调用前用 `architecture.has_factory(Type)` 或项目层包装函数显式检查。

能力访问器会生成 `get_*_capability()`、`add_*_capability()`、`has_*_capability()`、`remove_*_capability()` 与 `if_has_*_capability()`，内部依赖已注册的 `GFCapabilityUtility`。
