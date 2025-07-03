extends CharacterBody3D

# https://www.youtube.com/watch?v=n8D3vEx7NAE

@export var state: Utils.EntityState = Utils.EntityState.IDLE:
	set(value):
		print("[TLMS] Change state of ", name , " from ", state, " to ", value, " (on authorized device)")
		state = value
		if is_instance_valid(anim_player):
			anim_player.stop()
		match value:
			Utils.EntityState.IDLE:
				if is_instance_valid(anim_player):
					anim_player.play("idle")
				if is_instance_valid(collision):
					collision.disabled = false
				velocity = Vector3.ZERO
			Utils.EntityState.WALK:
				if is_instance_valid(anim_player):
					anim_player.play("slowrun")
			Utils.EntityState.ATTACK:
				if is_instance_valid(anim_player):
					anim_player.play("attack")
			Utils.EntityState.DEATH:
				if is_instance_valid(anim_player):
					anim_player.play("death")
				collision.disabled = true
			Utils.EntityState.WIN:
				if is_instance_valid(anim_player):
					anim_player.play("win")

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

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	if not is_multiplayer_authority(): return
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if world_node.game_state != Utils.GameState.PLAY: return
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SCALE)
	
	if Input.is_action_just_pressed("attack") and state != Utils.EntityState.ATTACK:
		change_state(Utils.EntityState.ATTACK)
		if raycast.is_colliding():
			var hit_entity = raycast.get_collider()
			hit_entity.receive_damage.rpc_id(hit_entity.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if world_node.game_state != Utils.GameState.PLAY: return
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return
	
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = JUMP_VELOCITY
	
	var input_dir := Input.get_vector("right", "left", "down", "up")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if state == Utils.EntityState.ATTACK: pass
	elif input_dir != Vector2.ZERO: change_state(Utils.EntityState.WALK)
	else: change_state(Utils.EntityState.IDLE)
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack" and state == Utils.EntityState.ATTACK:
		change_state(Utils.EntityState.IDLE)

@rpc("reliable", "call_local", "any_peer")
func set_new_position(value: Vector3):
	set_position(value)

@rpc("reliable", "call_local", "any_peer")
func receive_damage():
	change_state(Utils.EntityState.DEATH)

@rpc("reliable", "call_local", "any_peer")
func reset_player():
	state = Utils.EntityState.IDLE

func change_state(value):
	if not is_multiplayer_authority(): return
	if state == Utils.EntityState.DEATH: return
	
	if state != value:
		state = value
