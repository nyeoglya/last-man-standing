extends Area3D

# https://www.youtube.com/watch?v=Sc_pP_nKSL8

@export var spawn_location: Marker3D
@export var dummy_spawn_node: Node3D

@onready var dummy_spawner: MultiplayerSpawner = $DummySpawner

const Dummy = preload("res://scenes/dummy.tscn")

func _ready() -> void:
	if dummy_spawn_node:
		dummy_spawner.spawn_path = dummy_spawn_node.get_path()
	else:
		print("[DUMMY SPAWNER] No dummy spawn path provided!")

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("test_action"):
		if is_multiplayer_authority():
			call_deferred("add_dummy")

func add_dummy() -> void:
	var dummy = Dummy.instantiate()
	dummy.name = str(multiplayer.get_unique_id())
	dummy.position = spawn_location.global_position
	dummy_spawn_node.add_child(dummy, true)
	print("[DUMMY SPAWNER] New dummy has spawned. (id %s)" % dummy.name)

func clear_dummy() -> void:
	remove_child(dummy_spawn_node)
