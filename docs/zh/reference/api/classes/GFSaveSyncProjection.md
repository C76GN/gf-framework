# GFSaveSyncProjection

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/sync/gf_save_sync_projection.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

项目显式声明上传字段和下载合并边界的协议。 输入不包含框架 checkpoint。项目负责排除本地专用、凭证及服务端权威字段， 并将下载数据与本地专用状态合成为完整候选。默认实现拒绝，避免默认上传整份文档。 不在回调中修改运行状态或执行 IO；返回值由同步组合器再次验证并冻结。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`project_upload`](#member-gfsavesyncprojection-methods-project_upload) | `func project_upload(document: GFSaveDocument) -> GFSaveDocument:` |
| 方法 | [`prepare_download`](#member-gfsavesyncprojection-methods-prepare_download) | `func prepare_download(remote: GFSaveDocument, current: GFSaveDocument) -> GFSaveDocument:` |
| 方法 | [`_project_upload`](#member-gfsavesyncprojection-methods-_project_upload) | `func _project_upload(_document: GFSaveDocument) -> GFSaveDocument:` |
| 方法 | [`_prepare_download`](#member-gfsavesyncprojection-methods-_prepare_download) | `func _prepare_download(_remote: GFSaveDocument, _current: GFSaveDocument) -> GFSaveDocument:` |

## 方法

<a id="member-gfsavesyncprojection-methods-project_upload"></a>

### `project_upload`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func project_upload(document: GFSaveDocument) -> GFSaveDocument:
```

从已持久化本地文档构造明确允许上传的完整文档封套。

参数：

| 名称 | 说明 |
|---|---|
| `document` | 不含框架 checkpoint 的隔离本地文档。 |

返回：项目投影候选；拒绝时为 null。

<a id="member-gfsavesyncprojection-methods-prepare_download"></a>

### `prepare_download`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_download(remote: GFSaveDocument, current: GFSaveDocument) -> GFSaveDocument:
```

将远端投影与本地专用状态合成为完整本地候选。

参数：

| 名称 | 说明 |
|---|---|
| `remote` | 已验证封套的远端投影，不含框架 checkpoint。 |
| `current` | 当前已确认本地文档，不含框架 checkpoint。 |

返回：可由 Profile 验证和事务应用的完整文档；拒绝时为 null。

<a id="member-gfsavesyncprojection-methods-_project_upload"></a>

### `_project_upload`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _project_upload(_document: GFSaveDocument) -> GFSaveDocument:
```

由项目选择上传的分区、字段和项目元数据，默认拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `_document` | 独立本地文档。 |

返回：明确的上传投影或 null。

<a id="member-gfsavesyncprojection-methods-_prepare_download"></a>

### `_prepare_download`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _prepare_download(_remote: GFSaveDocument, _current: GFSaveDocument) -> GFSaveDocument:
```

由项目处理字段所有权，默认拒绝下载应用。

参数：

| 名称 | 说明 |
|---|---|
| `_remote` | 独立远端投影。 |
| `_current` | 独立当前本地文档。 |

返回：完整本地候选或 null。
