## GFSettingsNullStoreUtility: 显式不可用的设置持久化 Store 哨兵。
##
## 该实现继承 GFSettingsStoreUtility 的明确 UNAVAILABLE 结果，适合测试隔离或显式
## 表达 Store capability 缺失。纯内存模式应在 GFSettingsUtility 上设置
## persistence_enabled=false。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSettingsNullStoreUtility
extends GFSettingsStoreUtility
