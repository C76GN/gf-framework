@tool

# GF Config Pipeline 有界 ZIP 支持：为可信消费方提供同一私有快照上的中央目录预检与受控读取。
#
# 这里只验证 ZIP 格式、portable 路径和资源预算，不解释 XLSX
# 布局或目标目录策略，也不提供通用解包入口或向调用方目标目录写入。快照
# 容量是同一进程内的硬上限，不宣称跨进程全局配额；框架不会自动删除其他
# 进程遗留的目录。GDScript 文件 API 无法固定父目录句柄，因此 user:// 根必须
# 位于调用方信任且不会被本机其他进程恶意交换 junction 的目录；当前进程只会
# 清理带内存登记身份且 process marker、大小与 SHA-256 均复核通过的快照。每个
# session 绑定创建线程；共享登记和快照状态由 Mutex 保护，跨线程 session 操作
# 失败关闭。
extends RefCounted


# --- 常量 ---

## 未显式提供时允许读取的最大归档压缩字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ARCHIVE_BYTES: int = 64 * 1024 * 1024

## 默认允许的归档 entry 数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ENTRY_COUNT: int = 4096

## 单个 entry 默认允许的最大压缩字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ENTRY_COMPRESSED_BYTES: int = 8 * 1024 * 1024

## 单个 entry 默认允许的最大声明解压字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ENTRY_UNCOMPRESSED_BYTES: int = 8 * 1024 * 1024

## 会话内所有 entry 默认允许的最大累计声明解压字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_TOTAL_UNCOMPRESSED_BYTES: int = 64 * 1024 * 1024

## 默认允许的最大压缩比。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_COMPRESSION_RATIO: int = 100

## entry 路径默认允许的最大字符数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_PATH_LENGTH: int = 512

## entry 路径默认允许的最大组件深度。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_PATH_DEPTH: int = 32

## central directory 默认允许的最大字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_CENTRAL_DIRECTORY_BYTES: int = 8 * 1024 * 1024

## 框架强制的最大归档压缩字节数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ARCHIVE_BYTES: int = 1024 * 1024 * 1024

## 框架强制的最大 entry 数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ENTRY_COUNT: int = 20_000

## 框架强制的单个 entry 最大压缩字节数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ENTRY_COMPRESSED_BYTES: int = 64 * 1024 * 1024

## 框架强制的单个 entry 最大声明解压字节数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ENTRY_UNCOMPRESSED_BYTES: int = 64 * 1024 * 1024

## 框架强制的会话累计声明解压字节数上限。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_TOTAL_UNCOMPRESSED_BYTES: int = 512 * 1024 * 1024

## 框架强制的最大压缩比。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_COMPRESSION_RATIO: int = 100

## 框架强制的 entry 路径最大字符数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_PATH_LENGTH: int = 512

## 框架强制的 entry 路径最大组件深度。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_PATH_DEPTH: int = 32

## 框架强制的 central directory 最大字节数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_CENTRAL_DIRECTORY_BYTES: int = 16 * 1024 * 1024

## 同一进程同时登记的会话最大数量。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_ACTIVE_SESSIONS: int = 32

## 同一进程保留的快照累计最大字节数。
## [br]
## @api private
## [br]
const _ABSOLUTE_MAX_PROCESS_SNAPSHOT_BYTES: int = 2 * 1024 * 1024 * 1024

## 单份预检报告最多保留的问题数。
## [br]
## @api private
## [br]
const _MAX_ISSUE_COUNT: int = 256

## 复制归档或哈希读取使用的缓冲块大小。
## [br]
## @api private
## [br]
const _COPY_BUFFER_BYTES: int = 64 * 1024

## opaque session 句柄使用的格式标识。
## [br]
## @api private
## [br]
const _SESSION_FORMAT: String = "gf.bounded_zip.session"

## opaque session 句柄当前格式版本。
## [br]
## @api private
## [br]
const _SESSION_VERSION: int = 1

## 会话快照目录的 user:// 根路径。
## [br]
## @api private
## [br]
const _SESSION_ROOT_BASE: String = "user://.gf_bounded_zip_sessions"

## 标识当前进程所有的快照根目录的 marker 文件名。
## [br]
## @api private
## [br]
const _PROCESS_ROOT_MARKER_FILE: String = ".gf-bounded-zip-owner"

## 进程根目录 marker 内容格式标识。
## [br]
## @api private
## [br]
const _PROCESS_ROOT_MARKER_FORMAT: String = "gf.bounded_zip.process_root@1"

## EOCD 固定结构所需的最小字节数。
## [br]
## @api private
## [br]
const _EOCD_FIXED_BYTES: int = 22

## 反向查找 EOCD 时检查的最大尾部字节数。
## [br]
## @api private
## [br]
const _MAX_EOCD_SEARCH_BYTES: int = 65_557

## ZIP central directory 固定 header 的字节数。
## [br]
## @api private
## [br]
const _CENTRAL_HEADER_BYTES: int = 46

## ZIP local file header 固定部分的字节数。
## [br]
## @api private
## [br]
const _LOCAL_HEADER_BYTES: int = 30

## ZIP64 extra field 的标识值。
## [br]
## @api private
## [br]
const _ZIP64_EXTRA_FIELD_ID: int = 0x0001

## ZIP encrypted 标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_ENCRYPTED: int = 0x0001

## ZIP data descriptor 标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_DATA_DESCRIPTOR: int = 0x0008

## ZIP patched-data 标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_PATCHED_DATA: int = 0x0020

## ZIP strong-encryption 标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_STRONG_ENCRYPTION: int = 0x0040

## ZIP UTF-8 文件名标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_UTF8: int = 0x0800

## ZIP masked local header 标志位。
## [br]
## @api private
## [br]
const _ZIP_FLAG_MASKED_HEADERS: int = 0x2000

## 本实现接受的 ZIP 压缩方法编号：store 与 deflate。
## [br]
## @api private
## [br]
const _SUPPORTED_COMPRESSION_METHODS: Array[int] = [0, 8]


# --- 私有变量 ---

## 进程内活动会话状态，以不透明 session ID 为键。
## [br]
## @api private
## [br]
static var _active_sessions: Dictionary[String, Dictionary] = {}

## 正在取得活动会话容量的请求数。
## [br]
## @api private
## [br]
static var _pending_session_reservations: int = 0

## 延迟生成并复用的 CRC32 查找表。
## [br]
## @api private
## [br]
static var _crc32_lookup: PackedInt64Array = PackedInt64Array()

## 当前进程使用的会话快照根目录。
## [br]
## @api private
## [br]
static var _process_session_root: String = ""

## 快照根目录 marker 文件内容的 SHA-256。
## [br]
## @api private
## [br]
static var _process_root_marker_sha256: String = ""

## 当前进程登记拥有的快照及身份数据，以快照路径为键。
## [br]
## @api private
## [br]
static var _owned_snapshots: Dictionary[String, Dictionary] = {}

## 当前已计入进程快照字节预算的总量。
## [br]
## @api private
## [br]
static var _reserved_snapshot_bytes: int = 0

## 等待稍后重试清理的快照路径。
## [br]
## @api private
## [br]
static var _pending_snapshot_cleanup: Dictionary[String, bool] = {}

## 串行化会话登记与容量预留访问的互斥锁。
## [br]
## @api private
## [br]
static var _session_mutex: Mutex = Mutex.new()

## 串行化快照登记、预算及清理状态访问的互斥锁。
## [br]
## @api private
## [br]
static var _snapshot_mutex: Mutex = Mutex.new()


# --- 框架内部方法 ---

## 打开一个绑定受控归档快照、中央目录预检和随机访问句柄生命周期的会话。
##
## 调用线程成为会话 owner，后续查询、读取和关闭必须由同一线程完成；这允许
## 调用方 worker 完整拥有 archive 生命周期，同时拒绝跨线程共享
## FileAccess 游标或代替 owner 清理快照。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param archive_path: ZIP 文件路径。
## [br]
## @param limits: 可包含 max_archive_bytes、max_entry_count、max_entry_uncompressed_bytes、
## max_entry_compressed_bytes、max_total_uncompressed_bytes、max_compression_ratio、
## max_path_length、max_path_depth 和 max_central_directory_bytes。
## [br]
## @param expected_identity: 可选的源归档大小与 SHA-256 身份。
## [br]
## @schema limits: Dictionary；预算必须为精确正整数，且不能越过框架绝对上限。
## [br]
## @schema expected_identity: Dictionary；只允许非负精确整数 size_bytes 和 64 位十六进制 sha256。
## [br]
## @return opaque session；成功后只能交给本脚本的读取/查询/关闭方法。
## [br]
## @schema return: Dictionary，包含 ok、format、format_version、session_id、
## session_token、issues 和 issue_codes；成功句柄绑定当前创建线程。
static func open_archive(
	archive_path: String,
	limits: Dictionary = {},
	expected_identity: Dictionary = {}
) -> Dictionary:
	var limits_result: Dictionary = _resolve_limits(limits)
	if not _option_bool(limits_result, "ok"):
		return _make_session_failure_from_limits(limits_result)
	var resolved_limits: Dictionary = _option_dictionary(
		limits_result,
		"limits"
	)
	if not _reserve_session_capacity():
		return _make_session_failure(
			"session_capacity",
			"bounded ZIP active and opening session capacity is exhausted."
		)
	var result: Dictionary = _open_archive_with_reserved_capacity(
		archive_path,
		resolved_limits,
		expected_identity
	)
	if not _option_bool(result, "ok"):
		_release_session_capacity_reservation()
	return result


## 返回 bounded ZIP 对归档压缩字节数施加的框架绝对硬上限。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @return 任何会话均不能越过的归档压缩字节数。
static func get_absolute_max_archive_bytes() -> int:
	return _ABSOLUTE_MAX_ARCHIVE_BYTES


## 返回 bounded ZIP 对会话累计解压字节数施加的框架绝对硬上限。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @return 任何会话均不能越过的累计解压字节数。
static func get_absolute_max_total_uncompressed_bytes() -> int:
	return _ABSOLUTE_MAX_TOTAL_UNCOMPRESSED_BYTES


## 在任何 entry 解压前，对受控快照执行 ZIP 格式、路径和资源预算预检。
##
## 只需要报告时可使用本入口；需要读取 entry 时必须使用 open_archive() 保持
## 同一不可变快照和会话生命周期。实现先完成全部 central/local 结构和
## 非重叠区间验证，再对唯一 compressed range 执行累计不超过 archive
## 字节数的 SHA-256 绑定；非法布局不会触发 compressed data 哈希。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param archive_path: ZIP 文件路径。
## [br]
## @param limits: 与 open_archive() 相同的受控读取预算。
## [br]
## @param expected_identity: 可选的源归档大小与 SHA-256 身份。
## [br]
## @return 归档预检报告。
## [br]
## @schema limits: Dictionary；预算必须为精确正整数，且不能越过框架绝对上限。
## [br]
## @schema expected_identity: Dictionary；只允许非负精确整数 size_bytes 和 64 位十六进制 sha256。
## [br]
## @schema return: Dictionary，包含 ok、archive_size_bytes、entries、total_declared_uncompressed_bytes、compressed_work_bytes、issues、issue_codes 和 limits。
static func inspect_archive(
	archive_path: String,
	limits: Dictionary = {},
	expected_identity: Dictionary = {}
) -> Dictionary:
	var session: Dictionary = open_archive(
		archive_path,
		limits,
		expected_identity
	)
	if not _option_bool(session, "ok"):
		return _option_dictionary(session, "inspection")
	var inspection: Dictionary = get_inspection(session)
	var close_error: Error = close_archive(session)
	if close_error != OK:
		_append_inspection_cleanup_issue(inspection)
	return inspection


## 返回 open_archive() 会话绑定的只读 inspection 副本。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param session: open_archive() 返回的 opaque session。
## [br]
## @return 会话绑定的只读预检报告副本。
## [br]
## @schema session: Dictionary，必须是当前进程中仍处于 active 状态、且由当前线程创建的原始会话句柄。
## [br]
## @schema return: Dictionary，包含 ok、archive_size_bytes、entries、total_declared_uncompressed_bytes、compressed_work_bytes、issues、issue_codes 和 limits。
static func get_inspection(session: Dictionary) -> Dictionary:
	var access: Dictionary = _get_session_access(session)
	if not _option_bool(access, "ok"):
		return _make_inspection(
			"",
			0,
			[],
			0,
			{},
			PackedStringArray([
				_option_string(
					access,
					"error",
					"bounded ZIP session access failed."
				),
			]),
			PackedStringArray([
				_option_string(access, "issue_code", "invalid_session"),
			])
		)
	var state: Dictionary = _option_dictionary(access, "state")
	return _option_dictionary(state, "inspection").duplicate(true)


## 返回 open_archive() 会话中按中央目录顺序排列的精确 entry 路径。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param session: open_archive() 返回的 opaque session。
## [br]
## @return 中央目录中的精确 entry 路径副本。
## [br]
## @schema session: Dictionary，必须是当前进程中仍处于 active 状态、且由当前线程创建的原始会话句柄。
static func get_files(session: Dictionary) -> PackedStringArray:
	var access: Dictionary = _get_session_access(session)
	if not _option_bool(access, "ok"):
		return PackedStringArray()
	var state: Dictionary = _option_dictionary(access, "state")
	return _option_packed_string_array(state, "files").duplicate()


## 只读取 open_archive() 会话已经预检的普通文件 entry。
##
## 每个普通文件 entry 在同一 session 中只能消费一次；开始读取后即使内容
## 校验失败也不能重试。读取直接使用同一受控快照中的预检 data offset，
## 避免 ZIPReader 按 entry 从头线性定位；实际解压长度与 CRC32 仍在返回前
## 复核，并计入 session 的累计 max_total_uncompressed_bytes 硬预算。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param session: open_archive() 返回的 opaque session。
## [br]
## @param entry_path: 中央目录中的精确 entry 路径。
## [br]
## @param max_actual_bytes: 调用方附加的单项实际字节上限；小于 1 时使用 session 上限。
## [br]
## @return 读取结果；ok 为 true 时 bytes 可用。
## [br]
## @schema session: Dictionary，必须是当前进程中仍处于 active 状态、且由当前线程创建的原始会话句柄。
## [br]
## @schema return: Dictionary，包含 ok、path、bytes、declared_size_bytes、
## actual_size_bytes、error 和 error_code。
static func read_entry(
	session: Dictionary,
	entry_path: String,
	max_actual_bytes: int = -1
) -> Dictionary:
	var access: Dictionary = _get_session_access(session)
	if not _option_bool(access, "ok"):
		var access_error_code: Error = (
			ERR_UNAUTHORIZED
			if _option_string(access, "issue_code") == "wrong_thread"
			else ERR_INVALID_PARAMETER
		)
		return _make_read_failure(
			entry_path,
			_option_string(
				access,
				"error",
				"bounded ZIP session access failed."
			),
			access_error_code
		)
	var state: Dictionary = _option_dictionary(access, "state")
	var entries_by_path: Dictionary = _option_dictionary(
		state,
		"entries_by_path"
	)
	var entry: Dictionary = _option_dictionary(
		entries_by_path,
		entry_path
	)
	if entry.is_empty():
		return _make_read_failure(entry_path, "ZIP entry is not present in inspection.", ERR_FILE_NOT_FOUND)
	if _option_bool(entry, "is_directory"):
		return _make_read_failure(entry_path, "ZIP directory entries cannot be read as files.", ERR_INVALID_PARAMETER)
	var consumed_entries: Dictionary = _option_dictionary(
		state,
		"consumed_entries"
	)
	if consumed_entries.has(entry_path):
		return _make_read_failure(
			entry_path,
			"ZIP entry has already been consumed by this session.",
			ERR_ALREADY_IN_USE
		)

	var declared_size: int = _option_int(entry, "uncompressed_size", -1)
	var inspection: Dictionary = _option_dictionary(state, "inspection")
	var limits: Dictionary = _option_dictionary(inspection, "limits")
	var effective_limit: int = _limit(limits, "max_entry_uncompressed_bytes")
	var consumed_actual_bytes: int = _option_int(
		state,
		"consumed_actual_bytes"
	)
	var session_actual_limit: int = _limit(
		limits,
		"max_total_uncompressed_bytes"
	)
	var remaining_session_bytes: int = (
		session_actual_limit - consumed_actual_bytes
	)
	if max_actual_bytes > 0:
		effective_limit = mini(effective_limit, max_actual_bytes)
	effective_limit = mini(effective_limit, remaining_session_bytes)
	if declared_size < 0 or declared_size > effective_limit:
		return _make_read_failure(
			entry_path,
			"ZIP entry declared size exceeds the caller or session read budget.",
			ERR_OUT_OF_MEMORY,
			declared_size
		)

	var archive_file_value: Variant = state.get("archive_file")
	if not archive_file_value is FileAccess:
		return _make_read_failure(
			entry_path,
			"bounded ZIP session archive handle is unavailable.",
			ERR_INVALID_DATA,
			declared_size
		)
	var archive_file: FileAccess = archive_file_value
	var data_offset: int = _option_int(entry, "data_offset", -1)
	var compressed_size: int = _option_int(entry, "compressed_size", -1)
	var compressed_limit: int = _limit(
		limits,
		"max_entry_compressed_bytes"
	)
	var compression_method: int = _option_int(
		entry,
		"compression_method",
		-1
	)
	if (
		data_offset < 0
		or compressed_size < 0
		or compressed_size > compressed_limit
	):
		return _make_read_failure(
			entry_path,
			"ZIP entry compressed data exceeds its bound or is invalid.",
			ERR_OUT_OF_MEMORY,
			declared_size
		)
	consumed_entries[entry_path] = true
	state["consumed_entries"] = consumed_entries
	archive_file.seek(data_offset)
	var compressed_bytes: PackedByteArray = archive_file.get_buffer(
		compressed_size
	)
	if (
		archive_file.get_error() != OK
		or compressed_bytes.size() != compressed_size
	):
		return _make_read_failure(
			entry_path,
			"ZIP entry compressed bytes could not be read completely.",
			ERR_FILE_CORRUPT,
			declared_size
		)
	var expected_compressed_sha256: String = _option_string(
		entry,
		"compressed_sha256"
	)
	var actual_compressed_sha256: String = _hash_bytes_sha256(
		compressed_bytes
	)
	if (
		not _is_sha256(expected_compressed_sha256)
		or actual_compressed_sha256 != expected_compressed_sha256
	):
		return _make_read_failure(
			entry_path,
			"ZIP entry no longer matches the inspected snapshot.",
			ERR_FILE_CORRUPT,
			declared_size
		)
	var bytes: PackedByteArray = PackedByteArray()
	var declared_crc32: int = _option_int(entry, "crc32", -1)
	if compression_method == 0:
		bytes = compressed_bytes
	elif compression_method == 8:
		bytes = _decompress_zip_deflate(
			compressed_bytes,
			declared_size,
			declared_crc32
		)
	else:
		return _make_read_failure(
			entry_path,
			"ZIP entry compression method is unsupported.",
			ERR_UNAVAILABLE,
			declared_size
		)
	var actual_size: int = bytes.size()
	if actual_size > remaining_session_bytes:
		state["consumed_actual_bytes"] = session_actual_limit
		return _make_read_failure(
			entry_path,
			"ZIP entry actual size exceeds the remaining session read budget.",
			ERR_OUT_OF_MEMORY,
			declared_size,
			actual_size
		)
	state["consumed_actual_bytes"] = consumed_actual_bytes + actual_size
	if actual_size > effective_limit:
		return _make_read_failure(
			entry_path,
			"ZIP entry actual size exceeds the read budget.",
			ERR_OUT_OF_MEMORY,
			declared_size,
			actual_size
		)
	if actual_size != declared_size:
		return _make_read_failure(
			entry_path,
			"ZIP entry actual size does not match its central-directory declaration.",
			ERR_FILE_CORRUPT,
			declared_size,
			actual_size
		)
	if declared_crc32 < 0 or _crc32_table(bytes) != declared_crc32:
		return _make_read_failure(
			entry_path,
			"ZIP entry CRC32 does not match its central-directory declaration.",
			ERR_FILE_CORRUPT,
			declared_size,
			actual_size
		)
	return {
		"ok": true,
		"path": entry_path,
		"bytes": bytes,
		"declared_size_bytes": declared_size,
		"actual_size_bytes": actual_size,
		"error": "",
		"error_code": OK,
	}


## 关闭会话持有的归档句柄并删除私有快照。
## [br]
## @api framework_internal
## [br]
## @layer tools/config_pipeline
## [br]
## @param session: open_archive() 返回的 opaque session。
## [br]
## @return 关闭句柄并清理受控快照的 Godot 错误码。
## [br]
## @schema session: Dictionary，必须是当前进程中仍处于 active 状态、且由当前线程创建的原始会话句柄。
static func close_archive(session: Dictionary) -> Error:
	var access: Dictionary = _take_session_access(session)
	if not _option_bool(access, "ok"):
		return (
			ERR_UNAUTHORIZED
			if _option_string(access, "issue_code") == "wrong_thread"
			else ERR_INVALID_PARAMETER
		)
	var state: Dictionary = _option_dictionary(access, "state")
	var archive_file_value: Variant = state.get("archive_file")
	if archive_file_value is FileAccess:
		var archive_file: FileAccess = archive_file_value
		archive_file.close()
	return _remove_or_defer_snapshot(
		_option_string(state, "snapshot_path")
	)


# --- 私有/辅助方法 ---

## 对快照执行有界 ZIP 结构预检，核对中央目录、本地记录、路径身份、尺寸和不重叠区间；无问题后才计算压缩区摘要，返回部分条目及有界问题列表。
## [br]
## @api private
static func _inspect_archive_file(
	archive_path: String,
	reported_archive_path: String,
	resolved_limits: Dictionary
) -> Dictionary:
	resolved_limits = resolved_limits.duplicate(true)
	resolved_limits["_reported_archive_path"] = reported_archive_path
	var issues: PackedStringArray = PackedStringArray()
	var issue_codes: PackedStringArray = PackedStringArray()
	var entries: Array[Dictionary] = []
	var archive_size: int = 0

	if not FileAccess.file_exists(archive_path):
		_append_issue(issues, issue_codes, "missing_archive", "archive file is missing.")
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	var file: FileAccess = FileAccess.open(archive_path, FileAccess.READ)
	if file == null:
		_append_issue(
			issues,
			issue_codes,
			"archive_open_failed",
			"archive file could not be opened: %s" % error_string(FileAccess.get_open_error())
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	archive_size = file.get_length()
	var max_archive_bytes: int = _limit(resolved_limits, "max_archive_bytes")
	if archive_size > max_archive_bytes:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"archive_size_limit",
			"archive file exceeds compressed size limit: %d > %d" % [
				archive_size,
				max_archive_bytes,
			]
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)
	if archive_size < _EOCD_FIXED_BYTES:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"truncated_archive",
			"archive is too small to contain a ZIP central directory."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	var search_size: int = mini(archive_size, _MAX_EOCD_SEARCH_BYTES)
	var search_offset: int = archive_size - search_size
	file.seek(search_offset)
	var search_buffer: PackedByteArray = file.get_buffer(search_size)
	if search_buffer.size() != search_size:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"truncated_archive",
			"archive end-of-central-directory region is truncated."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	var eocd_index: int = _find_eocd_index(search_buffer)
	if eocd_index < 0:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"missing_central_directory",
			"archive is missing a valid ZIP central directory footer."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	var eocd_offset: int = search_offset + eocd_index
	var disk_number: int = _read_uint16_le(search_buffer, eocd_index + 4)
	var central_disk_number: int = _read_uint16_le(search_buffer, eocd_index + 6)
	var disk_entry_count: int = _read_uint16_le(search_buffer, eocd_index + 8)
	var entry_count: int = _read_uint16_le(search_buffer, eocd_index + 10)
	var central_size: int = _read_uint32_le(search_buffer, eocd_index + 12)
	var central_offset: int = _read_uint32_le(search_buffer, eocd_index + 16)
	if (
		entry_count == 0xffff
		or disk_entry_count == 0xffff
		or central_size == 0xffffffff
		or central_offset == 0xffffffff
		or _has_zip64_locator(search_buffer, eocd_index)
	):
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"zip64_unsupported",
			"ZIP64 archives are not supported."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)
	if disk_number != 0 or central_disk_number != 0 or disk_entry_count != entry_count:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"multidisk_unsupported",
			"multi-disk ZIP archives are not supported."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)
	if entry_count > _limit(resolved_limits, "max_entry_count"):
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"entry_count_limit",
			"archive contains too many entries: %d > %d" % [
				entry_count,
				_limit(resolved_limits, "max_entry_count"),
			]
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)
	if central_size > _limit(
		resolved_limits,
		"max_central_directory_bytes"
	):
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"central_directory_size_limit",
			"ZIP central directory exceeds its byte budget: %d > %d"
			% [
				central_size,
				_limit(
					resolved_limits,
					"max_central_directory_bytes"
				),
			]
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)
	if (
		central_offset > eocd_offset
		or central_size > eocd_offset
		or central_offset + central_size != eocd_offset
	):
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"central_directory_bounds",
			"ZIP central directory is outside the archive bounds or contains unsupported records."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	file.seek(central_offset)
	var central_directory: PackedByteArray = file.get_buffer(central_size)
	if central_directory.size() != central_size:
		file.close()
		_append_issue(
			issues,
			issue_codes,
			"truncated_central_directory",
			"ZIP central directory is truncated."
		)
		return _make_inspection(
			archive_path,
			archive_size,
			entries,
			0,
			resolved_limits,
			issues,
			issue_codes
		)

	var seen_identities: Dictionary = {}
	var seen_file_identities: Dictionary = {}
	var required_directory_identities: Dictionary = {}
	var seen_local_offsets: Dictionary = {}
	var local_intervals: Array[Dictionary] = []
	var total_uncompressed_bytes: int = 0
	var central_entry_offset: int = 0
	for entry_index: int in range(entry_count):
		if _issues_exhausted(issue_codes):
			break
		if central_entry_offset + _CENTRAL_HEADER_BYTES > central_directory.size():
			_append_issue(
				issues,
				issue_codes,
				"truncated_central_entry",
				"ZIP central directory entry %d is truncated." % entry_index
			)
			break
		if not _signature_matches(
			central_directory,
			central_entry_offset,
			0x50,
			0x4b,
			0x01,
			0x02
		):
			_append_issue(
				issues,
				issue_codes,
				"invalid_central_entry",
				"ZIP central directory entry %d has an invalid header." % entry_index
			)
			break

		var flags: int = _read_uint16_le(central_directory, central_entry_offset + 8)
		var compression_method: int = _read_uint16_le(
			central_directory,
			central_entry_offset + 10
		)
		var crc32: int = _read_uint32_le(
			central_directory,
			central_entry_offset + 16
		)
		var compressed_size: int = _read_uint32_le(
			central_directory,
			central_entry_offset + 20
		)
		var uncompressed_size: int = _read_uint32_le(
			central_directory,
			central_entry_offset + 24
		)
		var file_name_length: int = _read_uint16_le(
			central_directory,
			central_entry_offset + 28
		)
		var extra_length: int = _read_uint16_le(
			central_directory,
			central_entry_offset + 30
		)
		var comment_length: int = _read_uint16_le(
			central_directory,
			central_entry_offset + 32
		)
		var entry_disk_number: int = _read_uint16_le(
			central_directory,
			central_entry_offset + 34
		)
		var local_header_offset: int = _read_uint32_le(
			central_directory,
			central_entry_offset + 42
		)
		var file_name_offset: int = central_entry_offset + _CENTRAL_HEADER_BYTES
		var extra_offset: int = file_name_offset + file_name_length
		var next_entry_offset: int = extra_offset + extra_length + comment_length
		if next_entry_offset > central_directory.size():
			_append_issue(
				issues,
				issue_codes,
				"truncated_central_entry",
				"ZIP central directory entry %d is truncated." % entry_index
			)
			break

		var file_name_bytes: PackedByteArray = central_directory.slice(
			file_name_offset,
			file_name_offset + file_name_length
		)
		var extra_bytes: PackedByteArray = central_directory.slice(
			extra_offset,
			extra_offset + extra_length
		)
		var entry_path: String = _decode_entry_path(file_name_bytes, flags)
		if entry_path.is_empty() and not file_name_bytes.is_empty():
			_append_issue(
				issues,
				issue_codes,
				"unsupported_entry_name",
				"archive entry %d has an unsupported or invalid path encoding." % entry_index
			)
		if (
			compressed_size == 0xffffffff
			or uncompressed_size == 0xffffffff
			or local_header_offset == 0xffffffff
			or _extra_fields_contain_zip64(extra_bytes)
		):
			_append_issue(
				issues,
				issue_codes,
				"zip64_unsupported",
				"ZIP64 archive entries are not supported: %s" % entry_path
			)
		if entry_disk_number != 0:
			_append_issue(
				issues,
				issue_codes,
				"multidisk_unsupported",
				"multi-disk ZIP entries are not supported: %s" % entry_path
			)
		if _flags_are_encrypted(flags):
			_append_issue(
				issues,
				issue_codes,
				"encrypted_entry_unsupported",
				"encrypted ZIP entries are not supported: %s" % entry_path
			)
		if (flags & _ZIP_FLAG_PATCHED_DATA) != 0:
			_append_issue(
				issues,
				issue_codes,
				"patched_entry_unsupported",
				"patched ZIP entries are not supported: %s" % entry_path
			)
		if not _SUPPORTED_COMPRESSION_METHODS.has(compression_method):
			_append_issue(
				issues,
				issue_codes,
				"compression_method_unsupported",
				"unsupported ZIP compression method %d: %s" % [
					compression_method,
					entry_path,
				]
			)

		var is_directory: bool = entry_path.ends_with("/")
		var normalized_path: String = _normalize_entry_path(entry_path, is_directory)
		if normalized_path.is_empty():
			_append_issue(
				issues,
				issue_codes,
				"unsafe_entry_path",
				"unsafe archive entry path: %s" % entry_path
			)
		else:
			var measured_path: String = normalized_path.trim_suffix("/") if is_directory else normalized_path
			if measured_path.length() > _limit(resolved_limits, "max_path_length"):
				_append_issue(
					issues,
					issue_codes,
					"path_length_limit",
					"archive entry path is too long: %s" % normalized_path
				)
			if (
				measured_path.split("/", false).size()
				> _limit(resolved_limits, "max_path_depth")
			):
				_append_issue(
					issues,
					issue_codes,
					"path_depth_limit",
					"archive entry path is too deep: %s" % normalized_path
				)
			var portable_identity: String = measured_path.to_lower()
			if seen_identities.has(portable_identity):
				_append_issue(
					issues,
					issue_codes,
					"duplicate_portable_path",
					"duplicate portable entry path: %s" % normalized_path
				)
			else:
				seen_identities[portable_identity] = true
			var path_parts: PackedStringArray = measured_path.split(
				"/",
				false
			)
			var parent_identity: String = ""
			for part_index: int in range(path_parts.size() - 1):
				parent_identity = (
					path_parts[part_index].to_lower()
					if parent_identity.is_empty()
					else "%s/%s" % [
						parent_identity,
						path_parts[part_index].to_lower(),
					]
				)
				if seen_file_identities.has(parent_identity):
					_append_issue(
						issues,
						issue_codes,
						"file_directory_prefix_conflict",
						"archive entry traverses a path already owned by a file: %s"
						% normalized_path
					)
				required_directory_identities[parent_identity] = true
			if is_directory:
				if seen_file_identities.has(portable_identity):
					_append_issue(
						issues,
						issue_codes,
						"file_directory_prefix_conflict",
						"archive directory conflicts with a file path: %s"
						% normalized_path
					)
				required_directory_identities[portable_identity] = true
			else:
				if required_directory_identities.has(portable_identity):
					_append_issue(
						issues,
						issue_codes,
						"file_directory_prefix_conflict",
						"archive file conflicts with a directory prefix: %s"
						% normalized_path
					)
				seen_file_identities[portable_identity] = true

		if uncompressed_size > _limit(resolved_limits, "max_entry_uncompressed_bytes"):
			_append_issue(
				issues,
				issue_codes,
				"entry_size_limit",
				"archive entry exceeds declared uncompressed size limit: %s" % entry_path
			)
		if compressed_size > _limit(resolved_limits, "max_entry_compressed_bytes"):
			_append_issue(
				issues,
				issue_codes,
				"entry_compressed_size_limit",
				"archive entry exceeds declared compressed size limit: %s"
				% entry_path
			)
		if compressed_size == 0 and uncompressed_size > 0:
			_append_issue(
				issues,
				issue_codes,
				"invalid_compressed_size",
				"archive entry has invalid compressed size: %s" % entry_path
			)
		elif (
			compressed_size > 0
			and uncompressed_size
			> compressed_size * _limit(resolved_limits, "max_compression_ratio")
		):
			_append_issue(
				issues,
				issue_codes,
				"compression_ratio_limit",
				"archive entry compression ratio exceeds limit: %s" % entry_path
			)
		total_uncompressed_bytes += uncompressed_size

		if seen_local_offsets.has(local_header_offset):
			_append_issue(
				issues,
				issue_codes,
				"duplicate_local_header",
				"multiple ZIP entries reference the same local header: %s" % entry_path
			)
		else:
			seen_local_offsets[local_header_offset] = true
		var local_layout: Dictionary = _validate_local_header(
			file,
			central_offset,
			local_header_offset,
			file_name_bytes,
			flags,
			compression_method,
			crc32,
			compressed_size,
			uncompressed_size,
			entry_path,
			issues,
			issue_codes
		)
		var compressed_sha256: String = ""
		if not local_layout.is_empty():
			local_intervals.append({
				"start": local_header_offset,
				"end": _option_int(local_layout, "record_end_offset"),
				"path": entry_path,
			})

		entries.append({
			"path": entry_path,
			"normalized_path": normalized_path,
			"portable_identity": (
				normalized_path.trim_suffix("/").to_lower()
				if not normalized_path.is_empty()
				else ""
			),
			"is_directory": is_directory,
			"flags": flags,
			"compression_method": compression_method,
			"crc32": crc32,
			"compressed_size": compressed_size,
			"compressed_sha256": compressed_sha256,
			"uncompressed_size": uncompressed_size,
			"local_header_offset": local_header_offset,
			"data_offset": _option_int(
				local_layout,
				"data_offset",
				-1
			),
			"record_end_offset": _option_int(
				local_layout,
				"record_end_offset",
				-1
			),
		})
		central_entry_offset = next_entry_offset

	if central_entry_offset != central_directory.size():
		_append_issue(
			issues,
			issue_codes,
			"central_directory_entry_mismatch",
			"ZIP central directory entry count or size does not match its footer."
		)
	local_intervals.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _option_int(left, "start") < _option_int(right, "start")
	)
	var previous_interval_end: int = 0
	for interval: Dictionary in local_intervals:
		var interval_start: int = _option_int(interval, "start", -1)
		var interval_end: int = _option_int(interval, "end", -1)
		if (
			interval_start < previous_interval_end
			or interval_end < interval_start
			or interval_end > central_offset
		):
			_append_issue(
				issues,
				issue_codes,
				"overlapping_entry_records",
				"ZIP local entry records overlap or escape data bounds: %s"
				% _option_string(interval, "path")
			)
		previous_interval_end = maxi(previous_interval_end, interval_end)
	if total_uncompressed_bytes > _limit(resolved_limits, "max_total_uncompressed_bytes"):
		_append_issue(
			issues,
			issue_codes,
			"total_size_limit",
			"archive declared uncompressed size exceeds limit: %d > %d" % [
				total_uncompressed_bytes,
				_limit(resolved_limits, "max_total_uncompressed_bytes"),
			]
		)
	var compressed_work_bytes: int = 0
	if issues.is_empty():
		for work_entry: Dictionary in entries:
			var work_compressed_size: int = _option_int(
				work_entry,
				"compressed_size",
				-1
			)
			if (
				work_compressed_size < 0
				or work_compressed_size
				> archive_size - compressed_work_bytes
			):
				_append_issue(
					issues,
					issue_codes,
					"compressed_work_limit",
					"ZIP compressed-data validation exceeds the archive work budget."
				)
				break
			compressed_work_bytes += work_compressed_size
	if issues.is_empty():
		for hash_entry: Dictionary in entries:
			var entry_hash: String = _hash_file_range_sha256(
				file,
				_option_int(hash_entry, "data_offset", -1),
				_option_int(hash_entry, "compressed_size", -1)
			)
			if entry_hash.is_empty():
				_append_issue(
					issues,
					issue_codes,
					"entry_snapshot_hash_failed",
					"ZIP entry compressed data could not be bound to its snapshot."
				)
				break
			hash_entry["compressed_sha256"] = entry_hash
	file.close()

	return _make_inspection(
		archive_path,
		archive_size,
		entries,
		total_uncompressed_bytes,
		resolved_limits,
		issues,
		issue_codes,
		compressed_work_bytes
	)

## 在外层已预留会话名额后物化并检查快照，以 ZIPReader 验证兼容性后关闭它，再注册 FileAccess 会话；失败清理快照，未消费名额由外层释放。
## [br]
## @api private
static func _open_archive_with_reserved_capacity(
	archive_path: String,
	resolved_limits: Dictionary,
	expected_identity: Dictionary
) -> Dictionary:
	var snapshot_result: Dictionary = _materialize_archive_snapshot(
		archive_path,
		resolved_limits,
		expected_identity
	)
	if not _option_bool(snapshot_result, "ok"):
		return snapshot_result
	var snapshot_path: String = _option_string(
		snapshot_result,
		"snapshot_path"
	)
	var inspection: Dictionary = _inspect_archive_file(
		snapshot_path,
		archive_path,
		resolved_limits
	)
	if not _option_bool(inspection, "ok"):
		var cleanup_error: Error = _remove_or_defer_snapshot(snapshot_path)
		if cleanup_error != OK:
			_append_inspection_cleanup_issue(inspection)
		return _make_session_failure_from_inspection(inspection)

	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(snapshot_path)
	if open_error != OK:
		var cleanup_error: Error = _remove_or_defer_snapshot(snapshot_path)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP rejected the archive and could not clean its snapshot."
			)
		return _make_session_failure(
			"unsupported_archive",
			"ZIPReader rejected the inspected archive: %s"
			% error_string(open_error)
		)
	var reader_close_error: Error = reader.close()
	if reader_close_error != OK:
		var cleanup_error: Error = _remove_or_defer_snapshot(snapshot_path)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not close the archive or clean its snapshot."
			)
		return _make_session_failure(
			"archive_close_failed",
			"ZIPReader could not close the validated archive."
		)
	var archive_file: FileAccess = FileAccess.open(
		snapshot_path,
		FileAccess.READ
	)
	if archive_file == null:
		var cleanup_error: Error = _remove_or_defer_snapshot(snapshot_path)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not reopen or clean its snapshot."
			)
		return _make_session_failure(
			"archive_open_failed",
			"bounded ZIP snapshot could not be reopened."
		)
	var entries_by_path: Dictionary[String, Dictionary] = {}
	var files: PackedStringArray = PackedStringArray()
	for entry_value: Variant in _option_array(inspection, "entries"):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_path: String = _option_string(entry, "path")
		entries_by_path[entry_path] = entry
		var _file_appended: bool = files.append(entry_path)
	var handle: Dictionary = _register_reserved_session({
		"archive_file": archive_file,
		"snapshot_path": snapshot_path,
		"inspection": inspection,
		"entries_by_path": entries_by_path,
		"files": files,
		"consumed_entries": {},
		"consumed_actual_bytes": 0,
	})
	if not _option_bool(handle, "ok"):
		archive_file.close()
		var cleanup_error: Error = _remove_or_defer_snapshot(snapshot_path)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not register a session or clean its snapshot."
			)
		return handle
	return handle.duplicate(true)


## 持有快照互斥锁先重试待清理文件，任何遗留清理失败都阻止新快照；成功后在同一锁内完成源文件复制和身份绑定。
## [br]
## @api private
static func _materialize_archive_snapshot(
	archive_path: String,
	limits: Dictionary,
	expected_identity: Dictionary
) -> Dictionary:
	_snapshot_mutex.lock()
	var result: Dictionary = {}
	var pending_cleanup_error: Error = (
		_retry_pending_snapshot_cleanup_locked()
	)
	if pending_cleanup_error != OK:
		result = _make_session_failure(
			"snapshot_cleanup_blocked",
			"bounded ZIP cannot open another snapshot until prior cleanup succeeds."
		)
	else:
		result = _materialize_archive_snapshot_locked(
			archive_path,
			limits,
			expected_identity
		)
	_snapshot_mutex.unlock()
	return result


## 在调用方持有快照锁时准入来源与期望身份，预留容量后边复制边哈希，再复核长度及快照哈希；失败清理或登记待清理，清理错误优先返回。
## [br]
## @api private
static func _materialize_archive_snapshot_locked(
	archive_path: String,
	limits: Dictionary,
	expected_identity: Dictionary
) -> Dictionary:
	var identity_error: String = _get_expected_identity_error(
		expected_identity
	)
	if not identity_error.is_empty():
		return _make_session_failure(
			"invalid_expected_identity",
			identity_error
		)
	if (
		not FileAccess.file_exists(archive_path)
		or _path_has_link_component(archive_path)
	):
		return _make_session_failure(
			"missing_or_linked_archive",
			"archive file is missing or crosses a filesystem link."
		)
	var source_file: FileAccess = FileAccess.open(
		archive_path,
		FileAccess.READ
	)
	if source_file == null:
		return _make_session_failure(
			"archive_open_failed",
			"archive file could not be opened."
		)
	var archive_size: int = source_file.get_length()
	var max_archive_bytes: int = _limit(limits, "max_archive_bytes")
	if archive_size < 0 or archive_size > max_archive_bytes:
		source_file.close()
		return _make_session_failure(
			"archive_size_limit",
			"archive file exceeds its compressed byte budget."
		)
	if expected_identity.has("size_bytes") or expected_identity.has(
		&"size_bytes"
	):
		var expected_size: int = _option_int(
			expected_identity,
			"size_bytes",
			-1
		)
		if archive_size != expected_size:
			source_file.close()
			return _make_session_failure(
				"archive_identity_mismatch",
				"archive size does not match its bound identity."
			)
	var snapshot_path: String = _allocate_snapshot_path(archive_size)
	if snapshot_path.is_empty():
		source_file.close()
		return _make_session_failure(
			"snapshot_create_failed",
			"bounded ZIP snapshot path could not be allocated."
		)
	var snapshot_file: FileAccess = FileAccess.open(
		snapshot_path,
		FileAccess.WRITE
	)
	if snapshot_file == null:
		source_file.close()
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not clean a rejected snapshot allocation."
			)
		return _make_session_failure(
			"snapshot_create_failed",
			"bounded ZIP snapshot could not be created."
		)
	var hash_context: HashingContext = HashingContext.new()
	var hash_start_error: Error = hash_context.start(
		HashingContext.HASH_SHA256
	)
	if hash_start_error != OK:
		source_file.close()
		snapshot_file.close()
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not clean a rejected snapshot."
			)
		return _make_session_failure(
			"snapshot_hash_failed",
			"bounded ZIP snapshot hash could not be initialized."
		)
	var copied_bytes: int = 0
	var copy_error: Error = OK
	while copied_bytes < archive_size:
		var chunk_size: int = mini(
			_COPY_BUFFER_BYTES,
			archive_size - copied_bytes
		)
		var chunk: PackedByteArray = source_file.get_buffer(chunk_size)
		if (
			source_file.get_error() != OK
			or chunk.size() != chunk_size
		):
			copy_error = ERR_FILE_CORRUPT
			break
		var hash_update_error: Error = hash_context.update(chunk)
		if hash_update_error != OK:
			copy_error = hash_update_error
			break
		var _store_result: Variant = snapshot_file.store_buffer(chunk)
		if snapshot_file.get_error() != OK:
			copy_error = snapshot_file.get_error()
			break
		copied_bytes += chunk.size()
	var source_final_size: int = source_file.get_length()
	var source_error: Error = source_file.get_error()
	source_file.close()
	var snapshot_error: Error = snapshot_file.get_error()
	snapshot_file.close()
	var copied_sha256: String = hash_context.finish().hex_encode()
	if (
		copy_error != OK
		or source_error != OK
		or snapshot_error != OK
		or copied_bytes != archive_size
		or source_final_size != archive_size
		or _file_size(snapshot_path) != archive_size
	):
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not clean an incomplete snapshot."
			)
		return _make_session_failure(
			"snapshot_copy_failed",
			"archive snapshot could not be copied completely."
		)
	if not _bind_snapshot_identity(
		snapshot_path,
		archive_size,
		copied_sha256
	):
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not clean an unbound snapshot."
			)
		return _make_session_failure(
			"snapshot_identity_mismatch",
			"bounded ZIP snapshot identity could not be bound."
		)
	if FileAccess.get_sha256(snapshot_path).to_lower() != copied_sha256:
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP refused to delete a snapshot whose identity drifted."
			)
		return _make_session_failure(
			"snapshot_identity_mismatch",
			"bounded ZIP snapshot identity verification failed."
		)
	var expected_sha256: String = _option_string(
		expected_identity,
		"sha256"
	).to_lower()
	if (
		not expected_sha256.is_empty()
		and copied_sha256 != expected_sha256
	):
		var cleanup_error: Error = _remove_or_defer_snapshot_locked(
			snapshot_path
		)
		if cleanup_error != OK:
			return _make_session_failure(
				"snapshot_cleanup_failed",
				"bounded ZIP could not clean an identity-mismatched snapshot."
			)
		return _make_session_failure(
			"archive_identity_mismatch",
			"archive content does not match its bound identity."
		)
	return {
		"ok": true,
		"snapshot_path": snapshot_path,
		"archive_size_bytes": archive_size,
		"sha256": copied_sha256,
		"issues": PackedStringArray(),
		"issue_codes": PackedStringArray(),
	}


## 允许空身份或 size_bytes、sha256 两个可选字段，要求精确非负整数和小写十六进制摘要；只检查形状，实际内容比较由复制阶段执行。
## [br]
## @api private
static func _get_expected_identity_error(identity: Dictionary) -> String:
	for raw_key: Variant in identity.keys():
		var key: String = ""
		if raw_key is String:
			key = raw_key
		elif raw_key is StringName:
			var key_name: StringName = raw_key
			key = String(key_name)
		if key not in ["size_bytes", "sha256"]:
			return "bounded ZIP expected identity contains an unsupported field."
	if identity.has("size_bytes") or identity.has(&"size_bytes"):
		var size_value: Variant = (
			identity.get("size_bytes")
			if identity.has("size_bytes")
			else identity.get(&"size_bytes")
		)
		if not size_value is int:
			return "bounded ZIP expected size_bytes must be a non-negative exact int."
		var expected_size: int = size_value
		if expected_size < 0:
			return "bounded ZIP expected size_bytes must be a non-negative exact int."
	if identity.has("sha256") or identity.has(&"sha256"):
		var sha_value: Variant = (
			identity.get("sha256")
			if identity.has("sha256")
			else identity.get(&"sha256")
		)
		if not sha_value is String:
			return "bounded ZIP expected sha256 must be 64 lowercase hexadecimal characters."
		var expected_sha256: String = sha_value
		if not _is_sha256(expected_sha256):
			return "bounded ZIP expected sha256 must be 64 lowercase hexadecimal characters."
	return ""


## 在受管进程目录与容量均有效时最多尝试八个新文件名，拒绝已存在或跨链接路径；只登记未就绪快照并预留字节，尚未创建文件。
## [br]
## @api private
static func _allocate_snapshot_path(archive_size: int) -> String:
	if archive_size < 0 or not _ensure_process_session_root():
		return ""
	if _process_snapshot_capacity_error(archive_size) != OK:
		return ""
	for _attempt: int in range(8):
		var candidate: String = _process_session_root.path_join(
			"%s.zip" % _make_session_id()
		)
		if (
			not FileAccess.file_exists(candidate)
			and not DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(candidate)
			)
			and not _path_has_link_component(candidate)
		):
			_owned_snapshots[candidate] = {
				"reserved_bytes": archive_size,
				"ready": false,
				"size_bytes": -1,
				"sha256": "",
			}
			_reserved_snapshot_bytes += archive_size
			return candidate
	return ""


## 要求已登记的预留字节数与完成大小一致，才在原登记中写入长度、摘要并标记就绪；失败不自行撤销预留。
## [br]
## @api private
static func _bind_snapshot_identity(
	snapshot_path: String,
	size_bytes: int,
	sha256: String
) -> bool:
	if (
		not _owned_snapshots.has(snapshot_path)
		or size_bytes < 0
		or not _is_sha256(sha256)
	):
		return false
	var record: Dictionary = _option_dictionary(
		_owned_snapshots,
		snapshot_path
	)
	if _option_int(record, "reserved_bytes", -1) != size_bytes:
		return false
	record["ready"] = true
	record["size_bytes"] = size_bytes
	record["sha256"] = sha256
	_owned_snapshots[snapshot_path] = record
	return true


## 删除前核对进程目录所有权、登记、路径和快照身份；就绪文件验证大小与哈希，未完成文件只允许预留大小内内容，确认删除后才释放容量。
## [br]
## @api private
static func _remove_snapshot(snapshot_path: String) -> Error:
	if (
		not _process_root_is_owned()
		or snapshot_path.is_empty()
		or snapshot_path.get_base_dir() != _process_session_root
		or not _is_snapshot_file_name(snapshot_path.get_file())
		or not _owned_snapshots.has(snapshot_path)
		or _path_has_link_component(snapshot_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(snapshot_path)
		)
	):
		return ERR_UNAUTHORIZED
	var record: Dictionary = _option_dictionary(
		_owned_snapshots,
		snapshot_path
	)
	if not FileAccess.file_exists(snapshot_path):
		_release_snapshot_reservation(snapshot_path, record)
		return OK
	var current_size: int = _file_size(snapshot_path)
	if _option_bool(record, "ready"):
		if (
			current_size != _option_int(record, "size_bytes", -1)
			or FileAccess.get_sha256(snapshot_path).to_lower()
			!= _option_string(record, "sha256")
		):
			return ERR_FILE_CORRUPT
	elif (
		current_size < 0
		or current_size > _option_int(record, "reserved_bytes", -1)
	):
		return ERR_FILE_CORRUPT
	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(snapshot_path)
	)
	if remove_error != OK:
		return remove_error
	if (
		not _process_root_is_owned()
		or FileAccess.file_exists(snapshot_path)
		or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(snapshot_path)
		)
	):
		return ERR_FILE_CORRUPT
	_release_snapshot_reservation(snapshot_path, record)
	return OK


## 扣减记录中的保留字节数并移除该快照的 owned registry 项。
## [br]
## @api private
## [br]
static func _release_snapshot_reservation(
	snapshot_path: String,
	record: Dictionary
) -> void:
	var reserved_bytes: int = maxi(
		_option_int(record, "reserved_bytes"),
		0
	)
	_reserved_snapshot_bytes = maxi(
		_reserved_snapshot_bytes - reserved_bytes,
		0
	)
	var _record_erased: bool = _owned_snapshots.erase(snapshot_path)


## 持有快照锁执行受管删除并返回原错误，使删除与待清理登记对其他快照操作保持串行。
## [br]
## @api private
static func _remove_or_defer_snapshot(snapshot_path: String) -> Error:
	_snapshot_mutex.lock()
	var remove_error: Error = _remove_or_defer_snapshot_locked(
		snapshot_path
	)
	_snapshot_mutex.unlock()
	return remove_error


## 调用方持有快照锁时删除文件；成功移除待清理记录，失败在容量允许时登记重试但不释放所有权及字节预留。
## [br]
## @api private
static func _remove_or_defer_snapshot_locked(
	snapshot_path: String
) -> Error:
	var remove_error: Error = _remove_snapshot(snapshot_path)
	if remove_error == OK:
		var _pending_erased: bool = _pending_snapshot_cleanup.erase(
			snapshot_path
		)
		return OK
	if _pending_snapshot_cleanup.size() < _ABSOLUTE_MAX_ACTIVE_SESSIONS:
		_pending_snapshot_cleanup[snapshot_path] = true
	return remove_error


## 取得快照锁后重试待清理集合，再原样返回结果；不持锁调用锁内帮助方法的外部入口。
## [br]
## @api private
static func _retry_pending_snapshot_cleanup() -> Error:
	_snapshot_mutex.lock()
	var cleanup_error: Error = _retry_pending_snapshot_cleanup_locked()
	_snapshot_mutex.unlock()
	return cleanup_error


## 按路径排序逐个重试受管删除，成功即移除记录；首个失败立即停止，保留该项及后续项供再次重试。
## [br]
## @api private
static func _retry_pending_snapshot_cleanup_locked() -> Error:
	if _pending_snapshot_cleanup.is_empty():
		return OK
	var pending_paths: PackedStringArray = PackedStringArray()
	for raw_path: Variant in _pending_snapshot_cleanup.keys():
		if raw_path is String:
			var snapshot_path: String = raw_path
			var _path_appended: bool = pending_paths.append(snapshot_path)
	pending_paths.sort()
	for snapshot_path: String in pending_paths:
		var remove_error: Error = _remove_snapshot(snapshot_path)
		if remove_error != OK:
			return remove_error
		var _pending_erased: bool = _pending_snapshot_cleanup.erase(
			snapshot_path
		)
	return OK


## 复用已验证的进程目录，或最多尝试八个 PID 加 nonce 目录并写入随机所有权标记；复核路径链接与标记哈希后才发布目录身份。
## [br]
## @api private
static func _ensure_process_session_root() -> bool:
	var absolute_base: String = ProjectSettings.globalize_path(
		_SESSION_ROOT_BASE
	)
	var make_base_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_base
	)
	if (
		make_base_error != OK
		or _path_has_link_component(_SESSION_ROOT_BASE)
	):
		return false
	if not _process_session_root.is_empty():
		return _process_root_is_owned()
	for _attempt: int in range(8):
		var candidate_name: String = "%d-%s" % [
			OS.get_process_id(),
			_make_session_id(),
		]
		var candidate: String = _SESSION_ROOT_BASE.path_join(candidate_name)
		var make_error: Error = DirAccess.make_dir_absolute(
			ProjectSettings.globalize_path(candidate)
		)
		if make_error != OK:
			continue
		if _path_has_link_component(candidate):
			return false
		var marker_token: String = _make_session_id()
		if marker_token.is_empty():
			return false
		var marker_text: String = "%s\n%s\n%s\n" % [
			_PROCESS_ROOT_MARKER_FORMAT,
			candidate_name,
			marker_token,
		]
		var marker_path: String = candidate.path_join(
			_PROCESS_ROOT_MARKER_FILE
		)
		if (
			FileAccess.file_exists(marker_path)
			or DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(marker_path)
			)
			or _path_has_link_component(marker_path)
		):
			return false
		var marker_file: FileAccess = FileAccess.open(
			marker_path,
			FileAccess.WRITE
		)
		if marker_file == null:
			return false
		var _store_result: Variant = marker_file.store_buffer(
			marker_text.to_utf8_buffer()
		)
		var marker_error: Error = marker_file.get_error()
		marker_file.close()
		var marker_sha256: String = marker_text.sha256_text()
		if (
			marker_error != OK
			or _path_has_link_component(candidate)
			or FileAccess.get_sha256(marker_path).to_lower()
			!= marker_sha256
		):
			return false
		_process_session_root = candidate
		_process_root_marker_sha256 = marker_sha256
		return _process_root_is_owned()
	return false


## 复核进程目录位置、名称、存在性和无链接路径，再要求标记文件哈希等于本进程创建时保存的摘要。
## [br]
## @api private
static func _process_root_is_owned() -> bool:
	if (
		_process_session_root.is_empty()
		or _process_root_marker_sha256.is_empty()
		or _process_session_root.get_base_dir() != _SESSION_ROOT_BASE
		or not _is_process_directory_name(
			_process_session_root.get_file()
		)
		or not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(_process_session_root)
		)
		or _path_has_link_component(_process_session_root)
	):
		return false
	var marker_path: String = _process_session_root.path_join(
		_PROCESS_ROOT_MARKER_FILE
	)
	return (
		not _path_has_link_component(marker_path)
		and not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(marker_path)
		)
		and FileAccess.file_exists(marker_path)
		and FileAccess.get_sha256(marker_path).to_lower()
		== _process_root_marker_sha256
	)


## 检查新增快照字节数是否会超过进程预算，并返回对应 Error。
## [br]
## @api private
## [br]
static func _process_snapshot_capacity_error(additional_bytes: int) -> Error:
	if additional_bytes < 0:
		return ERR_INVALID_PARAMETER
	if (
		_reserved_snapshot_bytes
		> _ABSOLUTE_MAX_PROCESS_SNAPSHOT_BYTES
		or additional_bytes
		> _ABSOLUTE_MAX_PROCESS_SNAPSHOT_BYTES
		- _reserved_snapshot_bytes
	):
		return ERR_OUT_OF_MEMORY
	return OK


## 进程目录名必须是正整数 PID、连字符和 32 位小写十六进制 nonce。
## [br]
## @api private
## [br]
static func _is_process_directory_name(directory_name: String) -> bool:
	var separator_index: int = directory_name.find("-")
	if separator_index <= 0:
		return false
	var pid_text: String = directory_name.substr(0, separator_index)
	var nonce: String = directory_name.substr(separator_index + 1)
	return (
		pid_text.is_valid_int()
		and pid_text.to_int() > 0
		and _is_lower_hex(nonce, 32)
	)


## 快照文件名必须是 32 位小写十六进制 nonce 加 .zip 后缀。
## [br]
## @api private
## [br]
static func _is_snapshot_file_name(file_name: String) -> bool:
	return (
		file_name.length() == 36
		and file_name.ends_with(".zip")
		and _is_lower_hex(file_name.trim_suffix(".zip"), 32)
	)


## 组装包含单条诊断和空 session 身份的失败句柄。
## [br]
## @api private
## [br]
static func _make_session_failure(
	issue_code: String,
	message: String
) -> Dictionary:
	var inspection: Dictionary = _make_inspection(
		"",
		0,
		[],
		0,
		{},
		PackedStringArray([message]),
		PackedStringArray([issue_code])
	)
	return {
		"ok": false,
		"format": _SESSION_FORMAT,
		"format_version": _SESSION_VERSION,
		"session_id": "",
		"session_token": "",
		"issues": PackedStringArray([message]),
		"issue_codes": PackedStringArray([issue_code]),
		"inspection": inspection,
	}


## 将 limits 解析诊断包装为失败 session 句柄和 inspection 报告。
## [br]
## @api private
## [br]
static func _make_session_failure_from_limits(
	limits_result: Dictionary
) -> Dictionary:
	var issues: PackedStringArray = _option_packed_string_array(
		limits_result,
		"issues"
	)
	var issue_codes: PackedStringArray = _option_packed_string_array(
		limits_result,
		"issue_codes"
	)
	var inspection: Dictionary = _make_inspection(
		"",
		0,
		[],
		0,
		_option_dictionary(limits_result, "limits"),
		issues,
		issue_codes
	)
	return {
		"ok": false,
		"format": _SESSION_FORMAT,
		"format_version": _SESSION_VERSION,
		"session_id": "",
		"session_token": "",
		"issues": issues,
		"issue_codes": issue_codes,
		"inspection": inspection,
	}


## 将 inspection 报告中的诊断复制到失败 session 句柄。
## [br]
## @api private
## [br]
static func _make_session_failure_from_inspection(
	inspection: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"format": _SESSION_FORMAT,
		"format_version": _SESSION_VERSION,
		"session_id": "",
		"session_token": "",
		"issues": _option_packed_string_array(
			inspection,
			"issues"
		),
		"issue_codes": _option_packed_string_array(
			inspection,
			"issue_codes"
		),
		"inspection": inspection.duplicate(true),
	}


## 在会话锁内把活动会话和未完成预留共同计入上限，成功即增加预留数，防止并发打开绕过容量限制。
## [br]
## @api private
static func _reserve_session_capacity() -> bool:
	_session_mutex.lock()
	var has_capacity: bool = (
		_active_sessions.size() + _pending_session_reservations
		< _ABSOLUTE_MAX_ACTIVE_SESSIONS
	)
	if has_capacity:
		_pending_session_reservations += 1
	_session_mutex.unlock()
	return has_capacity


## 在会话锁内释放一个尚未注册的打开预留；外层只在打开失败时调用，计数已为零时保持不变。
## [br]
## @api private
static func _release_session_capacity_reservation() -> void:
	_session_mutex.lock()
	if _pending_session_reservations > 0:
		_pending_session_reservations -= 1
	_session_mutex.unlock()


## 在会话锁内消费一个预留，生成句柄并把状态引用与当前线程绑定到活动登记；失败保持预留供外层释放，也不接管清理责任。
## [br]
## @api private
static func _register_reserved_session(state: Dictionary) -> Dictionary:
	_session_mutex.lock()
	var handle: Dictionary
	if (
		_pending_session_reservations <= 0
		or _active_sessions.size() >= _ABSOLUTE_MAX_ACTIVE_SESSIONS
	):
		handle = _make_session_failure(
			"session_capacity",
			"bounded ZIP session reservation is missing or exhausted."
		)
	else:
		var session_id: String = _make_unique_session_id_locked()
		if session_id.is_empty():
			handle = _make_session_failure(
				"session_identity",
				"bounded ZIP session identity could not be allocated."
			)
		else:
			handle = {
				"ok": true,
				"format": _SESSION_FORMAT,
				"format_version": _SESSION_VERSION,
				"session_id": session_id,
				"session_token": _make_session_id(),
				"issues": PackedStringArray(),
				"issue_codes": PackedStringArray(),
			}
			_pending_session_reservations -= 1
			_active_sessions[session_id] = {
				"handle": handle.duplicate(true),
				"owner_thread_id": OS.get_thread_caller_id(),
				"state": state,
			}
	_session_mutex.unlock()
	return handle


## 在会话锁内验证句柄及线程，返回登记状态引用；解锁后不移除登记，资源仍由会话持有。
## [br]
## @api private
static func _get_session_access(session: Dictionary) -> Dictionary:
	_session_mutex.lock()
	var access: Dictionary = _get_session_access_locked(session)
	_session_mutex.unlock()
	return access


## 在会话锁内验证句柄和所属线程，成功即移除登记并返回状态引用交由关闭路径清理，使同一旧句柄不能再次使用。
## [br]
## @api private
static func _take_session_access(session: Dictionary) -> Dictionary:
	_session_mutex.lock()
	var access: Dictionary = _get_session_access_locked(session)
	if _option_bool(access, "ok"):
		var session_id: String = _option_string(session, "session_id")
		var _session_erased: bool = _active_sessions.erase(session_id)
	_session_mutex.unlock()
	return access


## 调用方持有会话锁时先校验完整句柄，再核对当前线程；只在两者通过时返回登记状态引用，失败不暴露状态。
## [br]
## @api private
static func _get_session_access_locked(session: Dictionary) -> Dictionary:
	var validation_error: String = _get_session_validation_error_locked(
		session
	)
	if not validation_error.is_empty():
		return {
			"ok": false,
			"issue_code": "invalid_session",
			"error": validation_error,
			"state": {},
		}
	var session_id: String = _option_string(session, "session_id")
	var record: Dictionary = _active_sessions[session_id]
	var owner_thread_id: int = _option_int(
		record,
		"owner_thread_id",
		-1
	)
	if owner_thread_id != OS.get_thread_caller_id():
		return {
			"ok": false,
			"issue_code": "wrong_thread",
			"error": "bounded ZIP session belongs to another thread.",
			"state": {},
		}
	var state: Dictionary = _option_dictionary(record, "state")
	return {
		"ok": true,
		"issue_code": "",
		"error": "",
		"state": state,
	}


## 依次检查成功标志、格式、版本、活动 ID 和完整句柄字典相等性；线程归属由获取访问状态的上层另行检查。
## [br]
## @api private
static func _get_session_validation_error_locked(
	session: Dictionary
) -> String:
	if not _option_bool(session, "ok"):
		return "bounded ZIP session was not opened successfully."
	if _option_string(session, "format") != _SESSION_FORMAT:
		return "bounded ZIP session format is invalid."
	if _option_int(session, "format_version") != _SESSION_VERSION:
		return "bounded ZIP session version is invalid."
	var session_id: String = _option_string(session, "session_id")
	if session_id.is_empty() or not _active_sessions.has(session_id):
		return "bounded ZIP session is unknown or already closed."
	var record: Dictionary = _active_sessions[session_id]
	if session != _option_dictionary(record, "handle"):
		return "bounded ZIP session integrity validation failed."
	return ""


## 在会话锁内最多生成八次候选 ID，返回首个不与活动登记碰撞的非空值，耗尽返回空串。
## [br]
## @api private
static func _make_unique_session_id_locked() -> String:
	for _attempt: int in range(8):
		var candidate: String = _make_session_id()
		if not candidate.is_empty() and not _active_sessions.has(candidate):
			return candidate
	return ""


## 优先以 16 字节 Crypto 随机值生成 32 位十六进制标识；随机读取失败时回退进程 ID 和时间组合的摘要前缀。
## [br]
## @api private
static func _make_session_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if bytes.size() == 16:
		return bytes.hex_encode()
	return (
		"%d:%d:%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
			Time.get_unix_time_from_system(),
		]
	).sha256_text().substr(0, 32)


## 打开文件读取长度并关闭句柄；打开失败时返回 -1。
## [br]
## @api private
## [br]
static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


## 把路径转为绝对路径并向根逐段检查引擎可识别的链接；结果依赖 DirAccess 能力，不提供对并发路径替换的原子保护。
## [br]
## @api private
static func _path_has_link_component(path: String) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var current: String = absolute_path
	while not current.is_empty():
		if _path_component_is_link(current):
			return true
		var parent: String = current.get_base_dir()
		if parent == current or parent.is_empty():
			break
		current = parent
	return false


## 打开父目录查询单个路径段的链接标志；没有可查询的父目录或打开失败时返回 false，不能单独证明路径存在或安全。
## [br]
## @api private
static func _path_component_is_link(path: String) -> bool:
	var parent: String = path.get_base_dir()
	var component_name: String = path.get_file()
	if parent.is_empty() or component_name.is_empty():
		return false
	var directory: DirAccess = DirAccess.open(parent)
	if directory == null:
		return false
	return directory.is_link(component_name)


## 按闭合键集合解析归档预算并套用各自默认值和绝对上限；未知键或非法值保留诊断并使结果失败，仍返回完整已解析限额。
## [br]
## @api private
static func _resolve_limits(limits: Dictionary) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var issue_codes: PackedStringArray = PackedStringArray()
	var allowed_keys: Dictionary[String, bool] = {
		"max_archive_bytes": true,
		"max_entry_count": true,
		"max_entry_compressed_bytes": true,
		"max_entry_uncompressed_bytes": true,
		"max_total_uncompressed_bytes": true,
		"max_compression_ratio": true,
		"max_path_length": true,
		"max_path_depth": true,
		"max_central_directory_bytes": true,
	}
	for raw_key: Variant in limits.keys():
		var key: String = ""
		if raw_key is String:
			key = raw_key
		elif raw_key is StringName:
			var key_name: StringName = raw_key
			key = String(key_name)
		if key.is_empty() or not allowed_keys.has(key):
			_append_issue(
				issues,
				issue_codes,
				"invalid_limit_option",
				"bounded ZIP limits contain an unsupported option."
			)
	var resolved: Dictionary = {
		"max_archive_bytes": _resolve_limit_option(
			limits,
			"max_archive_bytes",
			_DEFAULT_MAX_ARCHIVE_BYTES,
			_ABSOLUTE_MAX_ARCHIVE_BYTES,
			issues,
			issue_codes
		),
		"max_entry_count": _resolve_limit_option(
			limits,
			"max_entry_count",
			_DEFAULT_MAX_ENTRY_COUNT,
			_ABSOLUTE_MAX_ENTRY_COUNT,
			issues,
			issue_codes
		),
		"max_entry_compressed_bytes": _resolve_limit_option(
			limits,
			"max_entry_compressed_bytes",
			_DEFAULT_MAX_ENTRY_COMPRESSED_BYTES,
			_ABSOLUTE_MAX_ENTRY_COMPRESSED_BYTES,
			issues,
			issue_codes
		),
		"max_entry_uncompressed_bytes": _resolve_limit_option(
			limits,
			"max_entry_uncompressed_bytes",
			_DEFAULT_MAX_ENTRY_UNCOMPRESSED_BYTES,
			_ABSOLUTE_MAX_ENTRY_UNCOMPRESSED_BYTES,
			issues,
			issue_codes
		),
		"max_total_uncompressed_bytes": _resolve_limit_option(
			limits,
			"max_total_uncompressed_bytes",
			_DEFAULT_MAX_TOTAL_UNCOMPRESSED_BYTES,
			_ABSOLUTE_MAX_TOTAL_UNCOMPRESSED_BYTES,
			issues,
			issue_codes
		),
		"max_compression_ratio": _resolve_limit_option(
			limits,
			"max_compression_ratio",
			_DEFAULT_MAX_COMPRESSION_RATIO,
			_ABSOLUTE_MAX_COMPRESSION_RATIO,
			issues,
			issue_codes
		),
		"max_path_length": _resolve_limit_option(
			limits,
			"max_path_length",
			_DEFAULT_MAX_PATH_LENGTH,
			_ABSOLUTE_MAX_PATH_LENGTH,
			issues,
			issue_codes
		),
		"max_path_depth": _resolve_limit_option(
			limits,
			"max_path_depth",
			_DEFAULT_MAX_PATH_DEPTH,
			_ABSOLUTE_MAX_PATH_DEPTH,
			issues,
			issue_codes
		),
		"max_central_directory_bytes": _resolve_limit_option(
			limits,
			"max_central_directory_bytes",
			_DEFAULT_MAX_CENTRAL_DIRECTORY_BYTES,
			_ABSOLUTE_MAX_CENTRAL_DIRECTORY_BYTES,
			issues,
			issue_codes
		),
	}
	return {
		"ok": issues.is_empty(),
		"limits": resolved,
		"issues": issues,
		"issue_codes": issue_codes,
	}


## 优先读取文本键，再读取 StringName 别名；缺值采用默认值，非精确正整数或超过框架绝对上限时记录问题并回退默认值。
## [br]
## @api private
static func _resolve_limit_option(
	options: Dictionary,
	key: String,
	fallback: int,
	absolute_maximum: int,
	issues: PackedStringArray,
	issue_codes: PackedStringArray
) -> int:
	var has_value: bool = options.has(key) or options.has(StringName(key))
	if not has_value:
		return fallback
	var value: Variant = (
		options.get(key)
		if options.has(key)
		else options.get(StringName(key))
	)
	if value is int:
		var int_value: int = value
		if int_value > 0 and int_value <= absolute_maximum:
			return int_value
	_append_issue(
		issues,
		issue_codes,
		"invalid_limit_value",
		"%s must be an exact positive int within the framework limit."
		% key
	)
	return fallback


## 对照中央目录核对本地名称、标志、方法和尺寸，验证可选的 12 或 16 字节描述符及数据边界；结构不可定位时返回空映射，其他冲突写入共享问题列表。
## [br]
## @api private
static func _validate_local_header(
	file: FileAccess,
	central_offset: int,
	local_header_offset: int,
	central_name_bytes: PackedByteArray,
	central_flags: int,
	central_method: int,
	central_crc32: int,
	central_compressed_size: int,
	central_uncompressed_size: int,
	entry_path: String,
	issues: PackedStringArray,
	issue_codes: PackedStringArray
) -> Dictionary:
	if (
		local_header_offset < 0
		or local_header_offset + _LOCAL_HEADER_BYTES > central_offset
	):
		_append_issue(
			issues,
			issue_codes,
			"local_header_bounds",
			"ZIP local header is outside archive data bounds: %s" % entry_path
		)
		return {}
	file.seek(local_header_offset)
	var local_header: PackedByteArray = file.get_buffer(_LOCAL_HEADER_BYTES)
	if (
		local_header.size() != _LOCAL_HEADER_BYTES
		or not _signature_matches(local_header, 0, 0x50, 0x4b, 0x03, 0x04)
	):
		_append_issue(
			issues,
			issue_codes,
			"invalid_local_header",
			"ZIP entry has an invalid or truncated local header: %s" % entry_path
		)
		return {}

	var local_flags: int = _read_uint16_le(local_header, 6)
	var local_method: int = _read_uint16_le(local_header, 8)
	var local_crc32: int = _read_uint32_le(local_header, 14)
	var local_compressed_size: int = _read_uint32_le(local_header, 18)
	var local_uncompressed_size: int = _read_uint32_le(local_header, 22)
	var local_name_length: int = _read_uint16_le(local_header, 26)
	var local_extra_length: int = _read_uint16_le(local_header, 28)
	var local_name_offset: int = local_header_offset + _LOCAL_HEADER_BYTES
	var data_offset: int = local_name_offset + local_name_length + local_extra_length
	if (
		data_offset > central_offset
		or central_compressed_size > central_offset
		or data_offset + central_compressed_size > central_offset
	):
		_append_issue(
			issues,
			issue_codes,
			"entry_data_bounds",
			"ZIP entry compressed data is outside archive data bounds: %s" % entry_path
		)
		return {}
	file.seek(local_name_offset)
	var local_name_bytes: PackedByteArray = file.get_buffer(local_name_length)
	if local_name_bytes != central_name_bytes:
		_append_issue(
			issues,
			issue_codes,
			"entry_name_mismatch",
			"ZIP local and central entry paths do not match: %s" % entry_path
		)
	file.seek(local_name_offset + local_name_length)
	var local_extra_bytes: PackedByteArray = file.get_buffer(local_extra_length)
	if (
		local_extra_bytes.size() != local_extra_length
		or _extra_fields_contain_zip64(local_extra_bytes)
	):
		_append_issue(
			issues,
			issue_codes,
			"zip64_or_extra_field_unsupported",
			"ZIP64 or malformed local extra fields are not supported: %s" % entry_path
		)
	if local_flags != central_flags or local_method != central_method:
		_append_issue(
			issues,
			issue_codes,
			"entry_header_mismatch",
			"ZIP local and central entry metadata do not match: %s" % entry_path
		)
	if (central_flags & _ZIP_FLAG_DATA_DESCRIPTOR) == 0 and (
		local_crc32 != central_crc32
		or local_compressed_size != central_compressed_size
		or local_uncompressed_size != central_uncompressed_size
	):
		_append_issue(
			issues,
			issue_codes,
			"entry_size_mismatch",
			"ZIP local and central entry sizes do not match: %s" % entry_path
		)
	if central_method == 0 and central_compressed_size != central_uncompressed_size:
		_append_issue(
			issues,
			issue_codes,
			"stored_entry_size_mismatch",
			"stored ZIP entry compressed and uncompressed sizes differ: %s"
			% entry_path
		)
	var record_end_offset: int = data_offset + central_compressed_size
	if (central_flags & _ZIP_FLAG_DATA_DESCRIPTOR) != 0:
		if record_end_offset + 12 > central_offset:
			_append_issue(
				issues,
				issue_codes,
				"data_descriptor_bounds",
				"ZIP data descriptor is outside archive data bounds: %s"
				% entry_path
			)
			return {}
		file.seek(record_end_offset)
		var descriptor: PackedByteArray = file.get_buffer(
			mini(16, central_offset - record_end_offset)
		)
		var descriptor_value_offset: int = 0
		if _signature_matches(
			descriptor,
			0,
			0x50,
			0x4b,
			0x07,
			0x08
		):
			if descriptor.size() < 16:
				_append_issue(
					issues,
					issue_codes,
					"data_descriptor_bounds",
					"ZIP signed data descriptor is truncated: %s"
					% entry_path
				)
				return {}
			descriptor_value_offset = 4
			record_end_offset += 16
		else:
			if descriptor.size() < 12:
				_append_issue(
					issues,
					issue_codes,
					"data_descriptor_bounds",
					"ZIP data descriptor is truncated: %s" % entry_path
				)
				return {}
			record_end_offset += 12
		if (
			_read_uint32_le(descriptor, descriptor_value_offset)
			!= central_crc32
			or _read_uint32_le(descriptor, descriptor_value_offset + 4)
			!= central_compressed_size
			or _read_uint32_le(descriptor, descriptor_value_offset + 8)
			!= central_uncompressed_size
		):
			_append_issue(
				issues,
				issue_codes,
				"data_descriptor_mismatch",
				"ZIP data descriptor does not match the central directory: %s"
				% entry_path
			)
	return {
		"data_offset": data_offset,
		"record_end_offset": record_end_offset,
	}


## 从字节数组末尾向前查找注释长度恰好覆盖数组尾部的 EOCD。
## [br]
## @api private
## [br]
static func _find_eocd_index(bytes: PackedByteArray) -> int:
	for index: int in range(bytes.size() - _EOCD_FIXED_BYTES, -1, -1):
		if not _signature_matches(bytes, index, 0x50, 0x4b, 0x05, 0x06):
			continue
		var comment_length: int = _read_uint16_le(bytes, index + 20)
		if index + _EOCD_FIXED_BYTES + comment_length == bytes.size():
			return index
	return -1


## 检查 EOCD 前 20 字节处是否有 ZIP64 locator 签名。
## [br]
## @api private
## [br]
static func _has_zip64_locator(bytes: PackedByteArray, eocd_index: int) -> bool:
	return (
		eocd_index >= 20
		and _signature_matches(bytes, eocd_index - 20, 0x50, 0x4b, 0x06, 0x07)
	)


## 扫描 extra-field 结构；发现 ZIP64 ID 或长度越界、尾部残余字节时返回 true。
## [br]
## @api private
## [br]
static func _extra_fields_contain_zip64(bytes: PackedByteArray) -> bool:
	var offset: int = 0
	while offset + 4 <= bytes.size():
		var field_id: int = _read_uint16_le(bytes, offset)
		var field_size: int = _read_uint16_le(bytes, offset + 2)
		var next_offset: int = offset + 4 + field_size
		if next_offset > bytes.size():
			return true
		if field_id == _ZIP64_EXTRA_FIELD_ID:
			return true
		offset = next_offset
	return offset != bytes.size()


## 按 UTF-8 解码 entry 名；未声明 UTF-8 的高位字节或非往返编码返回空串。
## [br]
## @api private
## [br]
static func _decode_entry_path(bytes: PackedByteArray, flags: int) -> String:
	if bytes.is_empty():
		return ""
	if (flags & _ZIP_FLAG_UTF8) == 0:
		for byte_value: int in bytes:
			if byte_value > 0x7f:
				return ""
	var decoded: String = bytes.get_string_from_utf8()
	if decoded.to_utf8_buffer() != bytes:
		return ""
	return decoded


## 统一分隔符并按目录标志保留尾斜线，拒绝绝对路径、协议、冒号和非 ASCII 或不可移植路径段；失败返回空串。
## [br]
## @api private
static func _normalize_entry_path(path: String, is_directory: bool) -> String:
	if path.is_empty() or path != path.strip_edges():
		return ""
	var normalized: String = path.replace("\\", "/")
	if is_directory:
		normalized = normalized.trim_suffix("/")
	if (
		normalized.is_empty()
		or normalized.begins_with("/")
		or normalized.begins_with("res://")
		or normalized.begins_with("user://")
		or normalized.contains(":")
	):
		return ""
	var safe_parts: PackedStringArray = PackedStringArray()
	for part: String in normalized.split("/", true):
		if (
			not _string_is_ascii(part)
			or not _is_portable_literal_path_component(part)
		):
			return ""
		var _part_appended: bool = safe_parts.append(part)
	var result: String = "/".join(safe_parts)
	return result + "/" if is_directory else result


## 检查传统加密、强加密或 masked-header 标志位是否设置。
## [br]
## @api private
## [br]
static func _flags_are_encrypted(flags: int) -> bool:
	return (
		(flags & _ZIP_FLAG_ENCRYPTED) != 0
		or (flags & _ZIP_FLAG_STRONG_ENCRYPTION) != 0
		or (flags & _ZIP_FLAG_MASKED_HEADERS) != 0
	)


## 在 offset 起始处比较四个签名字节；越界位置返回 false。
## [br]
## @api private
## [br]
static func _signature_matches(
	bytes: PackedByteArray,
	offset: int,
	first: int,
	second: int,
	third: int,
	fourth: int
) -> bool:
	return (
		offset >= 0
		and offset + 3 < bytes.size()
		and bytes[offset] == first
		and bytes[offset + 1] == second
		and bytes[offset + 2] == third
		and bytes[offset + 3] == fourth
	)


## 从字节数组读取 16 位小端整数；偏移无效时返回 0。
## [br]
## @api private
## [br]
static func _read_uint16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 1 >= bytes.size():
		return 0
	return bytes[offset] | (bytes[offset + 1] << 8)


## 从字节数组读取 32 位小端整数；偏移无效时返回 0。
## [br]
## @api private
## [br]
static func _read_uint32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 3 >= bytes.size():
		return 0
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)


## 初始化共享 CRC32 查找表后，计算并返回输入字节的 CRC32 值。
## [br]
## @api private
## [br]
static func _crc32_table(bytes: PackedByteArray) -> int:
	_session_mutex.lock()
	if _crc32_lookup.size() != 256:
		var _resize_error: int = _crc32_lookup.resize(256)
		for table_index: int in range(256):
			var table_value: int = table_index
			for _bit_index: int in range(8):
				table_value = (
					(table_value >> 1) ^ 0xedb88320
					if (table_value & 1) != 0
					else table_value >> 1
				)
			_crc32_lookup[table_index] = table_value & 0xffffffff
	_session_mutex.unlock()
	var crc: int = 0xffffffff
	for byte_value: int in bytes:
		var lookup_index: int = (crc ^ byte_value) & 0xff
		crc = (
			int(_crc32_lookup[lookup_index])
			^ ((crc >> 8) & 0x00ffffff)
		)
	return (crc ^ 0xffffffff) & 0xffffffff


## 从 offset 开始分块哈希 byte_count 字节；失败返回空串，文件游标留在读取末端。
## [br]
## @api private
## [br]
static func _hash_file_range_sha256(
	file: FileAccess,
	offset: int,
	byte_count: int
) -> String:
	if offset < 0 or byte_count < 0:
		return ""
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	file.seek(offset)
	var remaining_bytes: int = byte_count
	while remaining_bytes > 0:
		var chunk_size: int = mini(_COPY_BUFFER_BYTES, remaining_bytes)
		var chunk: PackedByteArray = file.get_buffer(chunk_size)
		if chunk.size() != chunk_size or file.get_error() != OK:
			return ""
		if context.update(chunk) != OK:
			return ""
		remaining_bytes -= chunk.size()
	return context.finish().hex_encode()


## 返回字节数组的 SHA-256 小写十六进制文本；HashingContext 失败时返回空串。
## [br]
## @api private
## [br]
static func _hash_bytes_sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


## 把 ZIP 原始 DEFLATE 数据及声明的 CRC32、大小包成最小 gzip 内容，交给引擎按声明大小解压；调用方继续检查解压结果。
## [br]
## @api private
static func _decompress_zip_deflate(
	compressed_bytes: PackedByteArray,
	declared_size: int,
	declared_crc32: int
) -> PackedByteArray:
	# ZIP method 8 stores a raw DEFLATE stream. Godot intentionally exposes
	# zlib/gzip wrappers rather than raw DEFLATE, so bind the already-declared
	# CRC32 and size into a minimal gzip envelope before bounded decompression.
	var wrapped: PackedByteArray = PackedByteArray([
		0x1f, 0x8b, 0x08, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0xff,
	])
	wrapped.append_array(compressed_bytes)
	_append_uint32_le(wrapped, declared_crc32)
	_append_uint32_le(wrapped, declared_size)
	return wrapped.decompress(
		declared_size,
		FileAccess.COMPRESSION_GZIP
	)


## 将 value 的低 32 位按小端顺序追加四个字节。
## [br]
## @api private
## [br]
static func _append_uint32_le(bytes: PackedByteArray, value: int) -> void:
	var _byte_appended: bool = bytes.append(value & 0xff)
	_byte_appended = bytes.append((value >> 8) & 0xff)
	_byte_appended = bytes.append((value >> 16) & 0xff)
	_byte_appended = bytes.append((value >> 24) & 0xff)


## 组装归档预检结果，并从公开 limits 中去掉内部归档路径键。
## [br]
## @api private
## [br]
static func _make_inspection(
	archive_path: String,
	archive_size: int,
	entries: Array[Dictionary],
	total_uncompressed_bytes: int,
	limits: Dictionary,
	issues: PackedStringArray,
	issue_codes: PackedStringArray,
	compressed_work_bytes: int = 0
) -> Dictionary:
	var public_limits: Dictionary = limits.duplicate(true)
	var reported_archive_path: String = _option_string(
		public_limits,
		"_reported_archive_path",
		archive_path
	)
	var _reported_path_erased: bool = public_limits.erase(
		"_reported_archive_path"
	)
	return {
		"ok": issues.is_empty(),
		"archive_path": reported_archive_path,
		"archive_size_bytes": archive_size,
		"entries": entries,
		"total_declared_uncompressed_bytes": total_uncompressed_bytes,
		"compressed_work_bytes": compressed_work_bytes,
		"issues": issues.duplicate(),
		"issue_codes": issue_codes.duplicate(),
		"limits": public_limits,
	}


## 构造读取失败报告，并将 bytes 初始化为空 PackedByteArray。
## [br]
## @api private
## [br]
static func _make_read_failure(
	entry_path: String,
	error_message: String,
	error_code: Error,
	declared_size: int = -1,
	actual_size: int = -1
) -> Dictionary:
	return {
		"ok": false,
		"path": entry_path,
		"bytes": PackedByteArray(),
		"declared_size_bytes": declared_size,
		"actual_size_bytes": actual_size,
		"error": error_message,
		"error_code": error_code,
	}


## 追加清理过的诊断；超过问题预算时用单条 issue_budget_exceeded 替代末项。
## [br]
## @api private
## [br]
static func _append_issue(
	issues: PackedStringArray,
	issue_codes: PackedStringArray,
	issue_code: String,
	message: String
) -> void:
	if issue_codes.size() >= _MAX_ISSUE_COUNT:
		if (
			not issue_codes.is_empty()
			and issue_codes[issue_codes.size() - 1]
			!= "issue_budget_exceeded"
		):
			issue_codes[issue_codes.size() - 1] = "issue_budget_exceeded"
			issues[issues.size() - 1] = (
				"ZIP inspection issue budget was exhausted."
			)
		return
	var _issue_appended: bool = issues.append(_sanitize_issue_message(message))
	var _code_appended: bool = issue_codes.append(issue_code)


## 将快照清理失败诊断追加到 inspection 并把 ok 置为 false。
## [br]
## @api private
## [br]
static func _append_inspection_cleanup_issue(inspection: Dictionary) -> void:
	var issues: PackedStringArray = _option_packed_string_array(
		inspection,
		"issues"
	).duplicate()
	var issue_codes: PackedStringArray = _option_packed_string_array(
		inspection,
		"issue_codes"
	).duplicate()
	_append_issue(
		issues,
		issue_codes,
		"snapshot_cleanup_failed",
		"bounded ZIP snapshot cleanup failed."
	)
	inspection["ok"] = false
	inspection["issues"] = issues
	inspection["issue_codes"] = issue_codes


## 最多保留 1024 个字符，将控制字符替换为 ?，超长文本追加省略号。
## [br]
## @api private
## [br]
static func _sanitize_issue_message(message: String) -> String:
	var safe: String = ""
	var max_characters: int = mini(message.length(), 1024)
	for index: int in range(max_characters):
		var codepoint: int = message.unicode_at(index)
		safe += "?" if codepoint < 32 or codepoint == 127 else message.substr(index, 1)
	if message.length() > max_characters:
		safe += "..."
	return safe


## 所有 Unicode code point 均不高于 0x7f 时返回 true。
## [br]
## @api private
## [br]
static func _string_is_ascii(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true


## 拒绝空段、点段、尾部点空格、控制或保留字符以及 DOS 设备名；ASCII 限制由路径规范化调用方单独执行。
## [br]
## @api private
static func _is_portable_literal_path_component(component: String) -> bool:
	if (
		component.is_empty()
		or component == "."
		or component == ".."
		or component != component.rstrip(" .")
	):
		return false
	var invalid_characters: String = "<>:\"/\\|?*"
	for index: int in range(component.length()):
		var character: String = component.substr(index, 1)
		var codepoint: int = component.unicode_at(index)
		if codepoint < 32 or codepoint == 127 or invalid_characters.contains(character):
			return false
	var device_stem: String = component.split(".", true)[0].to_upper()
	if ["CON", "PRN", "AUX", "NUL"].has(device_stem):
		return false
	if device_stem.length() == 4:
		var device_prefix: String = device_stem.substr(0, 3)
		var device_number: String = device_stem.substr(3, 1)
		if (
			(device_prefix == "COM" or device_prefix == "LPT")
			and "123456789".contains(device_number)
		):
			return false
	return true


## 验证字符串长度精确匹配且每个字符均为小写十六进制数字。
## [br]
## @api private
## [br]
static func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length or value != value.to_lower():
		return false
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if not "0123456789abcdef".contains(character):
			return false
	return true


## 末项为 issue_budget_exceeded 且数量达到上限时返回 true。
## [br]
## @api private
## [br]
static func _issues_exhausted(issue_codes: PackedStringArray) -> bool:
	return (
		issue_codes.size() >= _MAX_ISSUE_COUNT
		and not issue_codes.is_empty()
		and issue_codes[issue_codes.size() - 1]
		== "issue_budget_exceeded"
	)


## 读取整数限制并把结果夹到至少 1。
## [br]
## @api private
## [br]
static func _limit(limits: Dictionary, key: String) -> int:
	return maxi(_option_int(limits, key, 1), 1)


## 只接受布尔类型字典值，否则返回 fallback。
## [br]
## @api private
## [br]
static func _option_bool(options: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = options.get(key)
	return value if value is bool else fallback


## 只接受整数类型字典值，否则返回 fallback。
## [br]
## @api private
## [br]
static func _option_int(options: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = options.get(key)
	return value if value is int else fallback


## 只接受 String 类型字典值，否则返回 fallback。
## [br]
## @api private
## [br]
static func _option_string(options: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = options.get(key)
	return value if value is String else fallback


## 只接受 Dictionary 类型字典值，否则返回空字典。
## [br]
## @api private
## [br]
static func _option_dictionary(options: Dictionary, key: String) -> Dictionary:
	var value: Variant = options.get(key)
	return value if value is Dictionary else {}


## 只接受 Array 类型字典值，否则返回空数组。
## [br]
## @api private
## [br]
static func _option_array(options: Dictionary, key: String) -> Array:
	var value: Variant = options.get(key)
	return value if value is Array else []


## 只接受 PackedStringArray 类型字典值，否则返回空 packed 数组。
## [br]
## @api private
## [br]
static func _option_packed_string_array(
	options: Dictionary,
	key: String
) -> PackedStringArray:
	var value: Variant = options.get(key)
	if value is PackedStringArray:
		var strings: PackedStringArray = value
		return strings
	return PackedStringArray()


## 验证 value 是由 64 个小写十六进制字符组成的 SHA-256 文本。
## [br]
## @api private
## [br]
static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true
