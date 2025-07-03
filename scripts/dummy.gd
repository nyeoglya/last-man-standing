extends CharacterBody3D

# https://www.youtube.com/watch?v=iV710Vm5qm0

@export var death: bool = false:
	set(value):
		death = value
		if death and not is_death_anim_played:
			anim_player.stop()
			anim_player.play("death")
			collision.disabled = true
			is_death_anim_played = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var movement_timer: Timer = $MovementTimer
@onready var anim_player: AnimationPlayer = $PlayerModel/AnimationPlayer
@onready var collision: CollisionShape3D = $CollisionShape3D

const SCALE: float = .002
const SPEED: float = 5.0
const GRAVITY: float = 10.0
const MOVEMENT_RANGE: float = 8.0
const ROTATION_SPEED: float = 10.0

const is_dummy: bool = true
const wait_time: float = 3.0

var id: int = -1
var target_position: Vector3 = Vector3.ZERO
var is_waiting: bool = true
var is_death_anim_played: bool = false
var is_slowrun_anim_played: bool = false

func _ready() -> void:
	if not is_multiplayer_authority(): return
	
	navigation_agent.velocity_computed.connect(Callable(self, "_on_navigation_velocity_computed"))
	movement_timer.timeout.connect(Callable(self, "_on_movement_timer_timeout"))
	start_wait_timer()

func start_wait_timer() -> void:
	is_waiting = true
	anim_player.play("idle")
	velocity = Vector3.ZERO
	movement_timer.start(wait_time)
	# print("목표에 도달했습니다. ", wait_time, "초 대기합니다.")

func _on_movement_timer_timeout() -> void:
	is_waiting = false
	# print("대기 시간이 끝났습니다. 다음 목표를 설정합니다.")
	set_random_target_position()

func _physics_process(delta: float) -> void:
	if death: return
	
	if anim_player.current_animation != "slowrun" and \
			not is_waiting:
		anim_player.current_animation = "slowrun"
	
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	
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
	if death: return

	var current_origin = global_transform.origin
	var random_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var random_distance = randf_range(0.0, MOVEMENT_RANGE)

	var random_potential_target = current_origin + random_direction * random_distance

	var map_rid = get_world_3d().get_navigation_map()
	var closest_valid_point = NavigationServer3D.map_get_closest_point(map_rid, random_potential_target)

	if closest_valid_point != Vector3.ZERO:
		target_position = closest_valid_point
		navigation_agent.target_position = target_position

@rpc("call_local", "any_peer")
func receive_damage() -> void:
	if death: return
	print("receive_damage RPC (권한자에서 실행): ", name, " 사망 처리 시작.")
	death = true
