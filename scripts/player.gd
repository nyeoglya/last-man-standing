extends CharacterBody3D

# https://www.youtube.com/watch?v=n8D3vEx7NAE

@export var is_slowrun_anim_played: bool = false
@export var death: bool = false:
	set(value):
		death = value
		if value and not is_death_anim_played:
			is_slowrun_anim_played = false
			anim_player.stop()
			anim_player.play("death")
			collision.disabled = true
			is_death_anim_played = true
		elif not value:
			is_slowrun_anim_played = false
			if is_instance_valid(anim_player):
				anim_player.stop()
				anim_player.play("idle")
			if is_instance_valid(collision):
				collision.disabled = false
			is_death_anim_played = false
			velocity = Vector3.ZERO

@onready var camera = $Camera3D
@onready var anim_player = $PlayerModel/AnimationPlayer
@onready var raycast = $RayCast3D
@onready var collision = $CollisionShape3D
@onready var world_node = get_node("/root/World")

const SCALE: float = .002
const SPEED: float = 5.0
const JUMP_VELOCITY: float = 5.0
const GRAVITY: float = 10.0
const is_dummy: bool = false

var is_death_anim_played: bool = false

func _ready() -> void:
	set_multiplayer_authority(int(name))
	if not is_multiplayer_authority(): return
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if world_node.game_state != Utils.GameState.PLAY: return
	if not is_multiplayer_authority(): return
	if death: return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SCALE)
	
	if Input.is_action_just_pressed("attack") \
			and anim_player.current_animation != "attack":
		play_attack_effects.rpc()
		if raycast.is_colliding():
			var hit_entity = raycast.get_collider()
			hit_entity.receive_damage.rpc_id(hit_entity.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if is_slowrun_anim_played and anim_player.current_animation != "slowrun":
		anim_player.stop()
		anim_player.play("slowrun")
	elif not is_slowrun_anim_played and anim_player.current_animation == "slowrun":
		anim_player.stop()
		anim_player.play("idle")
	
	if world_node.game_state != Utils.GameState.PLAY: return
	if not is_multiplayer_authority(): return
	if death: return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	var input_dir := Input.get_vector("right", "left", "down", "up")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if anim_player.current_animation != "attack" and input_dir != Vector2.ZERO and is_on_floor():
		is_slowrun_anim_played = true
	else:
		is_slowrun_anim_played = false
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		anim_player.stop()
		anim_player.play("idle")

@rpc("reliable", "call_local")
func play_attack_effects():
	is_slowrun_anim_played = false
	anim_player.stop()
	anim_player.play("attack")

@rpc("reliable", "call_local")
func set_new_position(value: Vector3):
	set_position(value)

@rpc("reliable", "call_local", "any_peer")
func receive_damage():
	if not is_multiplayer_authority(): return
	if death: return
	
	print("receive_damage RPC (권한자에서 실행): ", name, " 사망 처리 시작.")
	death = true
