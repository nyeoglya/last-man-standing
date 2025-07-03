extends CharacterBody3D

# https://www.youtube.com/watch?v=iV710Vm5qm0

@export var state: Utils.EntityState = Utils.EntityState.IDLE:
	set(value):
		state = value
		if is_instance_valid(anim_player):
			anim_player.stop()
		match value:
			Utils.EntityState.IDLE:
				if is_instance_valid(anim_player):
					anim_player.play("idle")
			Utils.EntityState.WALK:
				if is_instance_valid(anim_player):
					anim_player.play("slowrun")
			Utils.EntityState.DEATH:
				if is_instance_valid(anim_player):
					anim_player.play("death")
				collision.disabled = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var movement_timer: Timer = $MovementTimer
@onready var anim_player: AnimationPlayer = $PlayerModel/AnimationPlayer
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var dummy_synchronizer = $DummySynchronizer

const SPEED: float = 5.0
const GRAVITY: float = 10.0
const MOVEMENT_RANGE: float = 8.0
const ROTATION_SPEED: float = 10.0
const wait_time: float = 3.0

var target_position: Vector3 = Vector3.ZERO
@export var is_waiting: bool = true

func _ready() -> void:
	anim_player.animation_finished.connect(Callable(self, "_on_animation_finished"))
	
	if not is_multiplayer_authority(): return
	
	navigation_agent.velocity_computed.connect(Callable(self, "_on_navigation_velocity_computed"))
	movement_timer.timeout.connect(Callable(self, "_on_movement_timer_timeout"))
	start_wait_timer()

func start_wait_timer() -> void:
	is_waiting = true
	velocity = Vector3.ZERO
	change_state(Utils.EntityState.IDLE)
	movement_timer.start(wait_time)

func _on_movement_timer_timeout() -> void:
	is_waiting = false
	change_state(Utils.EntityState.WALK)
	set_random_target_position()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return
	
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0
	
	if is_waiting:
		velocity.x = 0
		velocity.z = 0
	elif navigation_agent.is_navigation_finished():
		start_wait_timer()
	else:
		var next_path_position: Vector3 = navigation_agent.get_next_path_position()
		var direct_direction = (next_path_position - global_transform.origin).normalized()
		var target_rotation_y = atan2(direct_direction.x, direct_direction.z)
		
		velocity.x = direct_direction.x * SPEED
		velocity.z = direct_direction.z * SPEED
		rotation.y = lerp_angle(rotation.y, target_rotation_y, ROTATION_SPEED * delta)

	move_and_slide()

func set_random_target_position() -> void:
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return

	var current_origin = global_transform.origin
	var random_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var random_distance = randf_range(0.0, MOVEMENT_RANGE)

	var random_potential_target = current_origin + random_direction * random_distance

	var map_rid = get_world_3d().get_navigation_map()
	var closest_valid_point = NavigationServer3D.map_get_closest_point(map_rid, random_potential_target)

	if closest_valid_point != Vector3.ZERO:
		target_position = closest_valid_point
		navigation_agent.target_position = target_position

@rpc("reliable", "call_local", "any_peer")
func receive_damage():
	change_state(Utils.EntityState.DEATH)

func change_state(value) -> void:
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return
	
	# print("receive_damage RPC on SERVER for: ", name)
	if state != value:
		state = value
