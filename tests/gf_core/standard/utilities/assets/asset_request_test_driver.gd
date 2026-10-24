extends RefCounted

# Old queue/cache regressions observe resource delivery through this test driver.
# Ownership and cancellation contract regressions use operations directly.
var _scopes: Array[GFAssetScope] = []
var _requests: Dictionary = {}


func close() -> void:
	for scope: GFAssetScope in _scopes:
		scope.close()
	_scopes.clear()
	_requests.clear()


func request(
	assets: GFAssetUtility,
	path: String,
	callback: Callable,
	type_hint: String = "",
	options: Dictionary = {}
) -> void:
	var scope: GFAssetScope = assets.create_scope()
	_scopes.append(scope)
	var operation: GFAssetLoadOperation = assets.load_async(
		path,
		scope,
		type_hint,
		options
	)
	var key: String = (
		"%s:%s"
		% [assets.get_instance_id(), path]
	)
	var requests: Array = _requests.get(key, [])
	requests.append(operation)
	_requests[key] = requests
	var deliver: Callable = func(result: GFAssetLoadResult) -> void:
		if result.get_status() != GFAssetLoadResult.Status.CANCELLED:
			var handle: GFAssetHandle = result.get_handle()
			callback.call(handle.get_resource() if handle != null else null)
		scope.close()
	if operation.is_completed():
		deliver.call(operation.get_result())
	else:
		var _connected: Error = operation.completed.connect(deliver, CONNECT_ONE_SHOT) as Error


func request_handle(
	assets: GFAssetUtility,
	path: String,
	callback: Callable,
	type_hint: String = "",
	owner: Object = null,
	_group_id: StringName = &"",
	options: Dictionary = {}
) -> void:
	var scope: GFAssetScope = assets.create_scope(owner)
	_scopes.append(scope)
	var operation: GFAssetLoadOperation = assets.load_async(
		path,
		scope,
		type_hint,
		options
	)
	var deliver: Callable = func(result: GFAssetLoadResult) -> void:
		if result.get_status() != GFAssetLoadResult.Status.CANCELLED:
			callback.call(result.get_handle())
	if operation.is_completed():
		deliver.call(operation.get_result())
	else:
		var _connected: Error = operation.completed.connect(deliver, CONNECT_ONE_SHOT) as Error


func acquire(
	assets: GFAssetUtility,
	path: String,
	owner: Object = null,
	_group_id: StringName = &"",
	type_hint: String = "",
	resource: Resource = null
) -> GFAssetHandle:
	var scope: GFAssetScope = assets.create_scope(owner)
	_scopes.append(scope)
	return assets.acquire_handle(
		path,
		scope,
		type_hint,
		resource
	)


func cancel(
	assets: GFAssetUtility,
	path: String,
	_type_hint: String = "",
	generation: int = -1
) -> void:
	var key: String = (
		"%s:%s"
		% [assets.get_instance_id(), path]
	)
	var requests: Array = _requests.get(key, [])
	if requests.is_empty():
		return
	# These existing regressions cancel one specific admission, including old-generation requests.
	var index: int = 0 if generation >= 0 else requests.size() - 1
	var operation: GFAssetLoadOperation = requests[index]
	var _cancelled: bool = operation.cancel()
