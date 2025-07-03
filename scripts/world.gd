extends Node

@export var player_info_list = []

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/AddressEntry
@onready var nickname_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/NickNameEntry
@onready var host_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/HostButton
@onready var host_local_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/HostLocalButton
@onready var join_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/JoinButton
@onready var quit_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/QuitButton
@onready var game_start_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/GameStartButton
@onready var itemlist = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ItemList
@onready var spawn_location = $DummySpawner/DummySpawnLocation
@onready var game_timer: Timer = $GameTimer
@onready var idle_timer: Timer = $IdleTimer

const Player = preload("res://scenes/player.tscn")
const PORT = 9999
const WAIT_TIME = 1

var enet_peer = ENetMultiplayerPeer.new()
var game_state = Utils.GameState.IDLE
var player_list = []

func _ready() -> void:
	idle_timer.timeout.connect(Callable(self, "_on_idle_timer_timeout"))
	idle_timer.start(WAIT_TIME)
	
	if not is_multiplayer_authority(): return

	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)

	game_timer.timeout.connect(Callable(self, "_on_game_timer_timeout"))

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_local_button_pressed() -> void:
	game_start_btn.disabled = false
	join_btn.disabled = true
	quit_btn.disabled = false
	host_btn.disabled = true
	host_local_btn.disabled = true

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	add_player(multiplayer.get_unique_id())

func _on_host_button_pressed() -> void:
	_on_host_local_button_pressed()
	# upnp_setup()

func _on_join_button_pressed() -> void:
	join_btn.disabled = true
	quit_btn.disabled = false
	host_btn.disabled = true
	host_local_btn.disabled = true

	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func _on_game_start_button_pressed() -> void:
	game_timer.start(WAIT_TIME)
	game_start.rpc()
	for player in player_list:
		add_child(player)

func _on_quit_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	reset_lobby_nodes()

func _on_multiplayer_peer_disconnected(peer_id):
	print("피어 연결 끊김: ", peer_id)

	remove_player(peer_id)
	update_itemlist(player_info_list)

	if peer_id == 1:
		print("서버와의 연결이 끊어졌습니다.")
		reset_lobby_nodes()

func _on_multiplayer_connection_failed():
	print("서버 연결 실패")
	reset_lobby_nodes()

func _on_idle_timer_timeout() -> void:
	if game_state != Utils.GameState.IDLE: return
	print("정상화 진행중", multiplayer.get_unique_id())
	for player in player_list:
		initiate_player(player)

func _on_game_timer_timeout() -> void:
	print(player_info_list)
	var remain_player_count = len(Utils.remove_item(player_info_list, func(x): return not x.death))
	if remain_player_count <= 1:
		print("게임이 끝났다.")
		game_end.rpc()
		game_timer.stop()

func reset_lobby_nodes():
	game_start_btn.disabled = true
	join_btn.disabled = false
	quit_btn.disabled = true
	host_btn.disabled = false
	host_local_btn.disabled = false
	multiplayer.multiplayer_peer = null # 현재 피어 연결 해제
	enet_peer = ENetMultiplayerPeer.new() # 새로운 ENetPeer 인스턴스 생성
	player_info_list = []
	player_list = []
	itemlist.clear()

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	player.id = peer_id
	player_list.append(player)
	player_info_list.append({
		"id": peer_id,
		"name": player.name,
		"death": false
	})
	update_itemlist.rpc(player_info_list)
	print("플레이어가 접속했습니다.", player.name)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))

	player_info_list = Utils.remove_item(player_info_list, func(x): return x.id != int(peer_id))
	player_list = Utils.remove_item(player_list, func(x): return x.id != int(peer_id))

	if player:
		player.queue_free()

'''
func upnp_setup():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discovered Failed! Error %s" % discover_result)
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
'''

@rpc("reliable", "call_local")
func update_itemlist(player_info_list):
	itemlist.clear()
	for player in player_info_list:
		itemlist.add_item(player.name, null, false)

func initiate_player(player):
	if is_instance_valid(player):
		player.death = false
		if is_instance_valid(player.collision):
			player.collision.disabled = false
		if is_instance_valid(player.anim_player):
			player.anim_player.stop()
			player.anim_player.play("idle")
		player.velocity = Vector3.ZERO

@rpc("reliable", "call_local")
func game_start():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for player in player_list:
		initiate_player(player)
		if is_instance_valid(player):
			player.position = spawn_location.global_position
	
	game_state = Utils.GameState.PLAY
	main_menu.hide()

@rpc("reliable", "call_local")
func game_end():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var temp_list = []
	for player in player_list:
		if is_instance_valid(player):
			player.death = false
			player.position = spawn_location.global_position
			player.collision.disabled = false
			player.velocity = Vector3.ZERO
			
			temp_list.append({
				"id": player.id,
				"name": player.name,
				"death": false
			})
	player_info_list = temp_list
	
	game_state = Utils.GameState.IDLE
	main_menu.show()
	
	if multiplayer.get_unique_id() == 1:
		game_start_btn.disabled = false
