extends Resource


const _SAFE_TYPED_CHILD_RESOURCE_SCRIPT = preload(
	"res://tests/gf_core/fixtures/storage/safe_typed_child_resource.gd"
)


static var last_instance: WeakRef = null


@export var value: int = 0
@export var numbers: Array[int] = []
@export var counts: Dictionary[String, int] = {}
@export var resources: Array[Resource] = []
@export var peer: Resource = null
@export var child: _SAFE_TYPED_CHILD_RESOURCE_SCRIPT = null


func _init() -> void:
	last_instance = weakref(self)
