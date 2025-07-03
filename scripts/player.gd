extends CharacterBody3D

# https://www.youtube.com/watch?v=n8D3vEx7NAE

@export var id: int = -1
@export var death: bool = false:
	set(value):
		death = value
		if death and not is_death_anim_played:
			anim_player.stop()
			anim_player.play("death")
			collision.disabled = true
			is_death_anim_played = true

@onready var camera = $Camera3D
@onready var anim_player = $PlayerModel/AnimationPlayer
@onready var raycast = $RayCast3D
@onready var collision = $CollisionShape3D

const SCALE: float = .002
const SPEED: float = 5.0
const JUMP_VELOCITY: float = 5.0
const GRAVITY: float = 10.0
const is_dummy: bool = false

var is_death_anim_played: bool = false
var is_slowrun_anim_played: bool = false
var world_node

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	world_node = get_tree().get_root().get_node("World")
	
	if not is_multiplayer_authority(): return
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if death: return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SCALE)
	
	if Input.is_action_just_pressed("attack") \
			and anim_player.current_animation != "attack":
		play_attack_effects.rpc()
		if raycast.is_colliding():
			var hit_entity = raycast.get_collider()
			print("[GAME] Attack id %s" % hit_entity.id)
			hit_entity.receive_damage.rpc()
			# hit_entity.receive_damage.rpc_id(hit_entity.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if death: return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("right", "left", "down", "up")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if anim_player.current_animation == "attack":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		if anim_player.current_animation != "slowrun":
			anim_player.play("slowrun")
	else:
		if anim_player.current_animation != "idle":
			anim_player.play("idle")

	move_and_slide()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		anim_player.play("idle")

@rpc("reliable", "call_local")
func play_attack_effects():
	anim_player.stop()
	anim_player.play("attack")

@rpc("reliable", "call_local", "any_peer")
func receive_damage():
	if death: return
	print("receive_damage RPC (권한자에서 실행): ", name, " 사망 처리 시작.")
	death = true
	
	world_node.player_info_list = Utils.fix_item(world_node.player_info_list, id, {
		"id": id,
		"name": name,
		"death": true
	})
	world_node.update_itemlist.rpc(world_node.player_info_list)
