# 读取结果与副本隔离

`GFStorageReadResult` 分离 `payload`、框架 `metadata`、`integrity_status`、Godot `error_code`、物理文档版本、数据迁移前后版本和 `migrated`。

`failure_kind` 区分非法请求、不存在、普通 IO、损坏、未来格式、迁移失败和服务不可用。上层恢复政策应根据该分类决定，不能仅凭同一个 `Error` 码把未来格式或迁移失败当成损坏。异步读取完成信号同样传递这个结果；`last_load_result` 只用于诊断最近一次读取，不应替代当前调用返回值。

## 保留一次结果副本

读取结果的 `duplicate_result()`、字典导出/导入，以及异步句柄的结果 getter 都保持副本隔离。修改取得的嵌套 payload 或 metadata 容器，不会改写句柄保存的终态。

需要反复访问大型读取结果时，先保存一次 `get_read_result()` 的返回值，再读取其中各字段，避免反复取得整份副本。以下代码在操作已物理完成后执行（`operation.is_completed()` 为 `true`）；caller 超时或取消不代表物理完成：

```gdscript
var physical_result := operation.get_result()
var read_result := physical_result.get_read_result()
if read_result != null and read_result.ok:
	_apply_payload(read_result.payload)
	_show_metadata(read_result.metadata)
```

## 完成信号的参数

同一次完成信号的参数会广播给该次所有监听者。需要自行修改 legacy `load_completed` 参数的监听者，应先取得自己的 `duplicate_result()`；框架没有为同一次信号的每个监听者分别复制完整载荷。

读取副本优化保留现有公开隔离行为，不提供独占领取或自动分帧保证。单次大型解码、校验与结果构造的时间，仍需结合项目实际载荷测量。返回[本地存档管理器](storage-utility.md)查看同步、异步和迁移入口。
