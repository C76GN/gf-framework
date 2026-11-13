extends GFStorageSyncJournal


var intents: Dictionary = {}
var outcomes: Dictionary = {}
var pending: Array[Dictionary] = []
var calls: Array[StringName] = []
var held: Array[StringName] = []
var fail_next: StringName = &""


func _persist_intent(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _enqueue(
		&"intent",
		request,
		{}
	)


func _persist_outcome(request: GFStorageSyncRequest, outcome: Dictionary) -> GFAsyncCompletion:
	return _enqueue(
		&"outcome",
		request,
		outcome
	)


func _load_intent(record_namespace: String, record_key: String) -> GFAsyncCompletion:
	return _enqueue(
		&"load",
		GFStorageSyncRequest.create(
			record_namespace,
			record_key,
			"load"
		),
		{}
	)


func execute(index: int = 0) -> void:
	var invocation: Dictionary = pending.pop_at(index)
	var request: GFStorageSyncRequest = invocation["request"]
	var completion: GFAsyncCompletion = invocation["completion"]
	var kind: StringName = invocation["kind"]
	var key: String = JSON.stringify([request.get_namespace(), request.get_key()])
	if fail_next == kind:
		fail_next = &""
		var _failed: bool = completion.fail("simulated_disk_failure")
		return
	if kind == &"load":
		var _loaded: bool = completion.succeed(GFVariantData.get_option_dictionary(intents, key).duplicate(true))
	elif kind == &"intent":
		if intents.has(key) and intents[key] != request.to_record():
			var _busy: bool = completion.fail("unresolved_intent")
			return
		intents[key] = request.to_record()
		var _stored: bool = completion.succeed()
	else:
		if not intents.has(key) or intents[key] != request.to_record():
			var _missing: bool = completion.fail("intent_mismatch")
			return
		outcomes[key] = GFVariantData.get_option_dictionary(invocation, "outcome").duplicate(true)
		var _erased: bool = intents.erase(key)
		var _stored: bool = completion.succeed()


func _enqueue(
	kind: StringName,
	request: GFStorageSyncRequest,
	outcome: Dictionary
) -> GFAsyncCompletion:
	calls.append(kind)
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	pending.append(
		{
			"kind": kind,
			"request": request,
			"outcome": outcome,
			"completion": completion,
		}
	)
	if kind not in held:
		execute(pending.size() - 1)
	return completion
