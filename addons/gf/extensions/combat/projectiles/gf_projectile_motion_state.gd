## GFProjectileMotionState: 单个 Projectile generation 独占的移动状态基类。
##
## 进入 Runtime 的实例由 [method GFProjectileMotion.create_state_2d] 或
## [method GFProjectileMotion.create_state_3d] 为一次 launch 创建。Runtime 会为该
## generation 强持有 state；prepare 失败或 Session 进入终态后会立即释放这份 Runtime
## ownership，旧 state 对 Runtime 随即失效。
## 外部持有这个 RefCounted 只会延长对象本身的存活时间，不会延长 Runtime generation、
## 恢复已结束 Session，也不会让旧 state 被后续 launch 复用。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFProjectileMotionState
extends RefCounted
