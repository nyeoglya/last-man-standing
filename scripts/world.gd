extends Node

# 전체 플레이어 정보를 다룸
@export var player_name_list = []

# 메뉴화면
@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/AddressEntry
@onready var nickname_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/NickNameEntry
@onready var host_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/HostButton
@onready var host_local_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/HostLocalButton
@onready var join_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/JoinButton
@onready var quit_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/VBoxContainer/QuitButton
@onready var game_start_btn = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/GameStartButton
@onready var itemlist = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ItemList

# 게임 관련
@onready var navigation_region = $NavigationRegion3D
@onready var dummy_spawner = $DummySpawner
@onready var player_spawner = $PlayerSpawner
@onready var dummy_spawn_node = $DummySpawnNode
@onready var player_spawn_node = $PlayerSpawnNode
@onready var timer: Timer = $Timer

# 상수 정의
const Player = preload("res://scenes/player.tscn")
const Dummy = preload("res://scenes/dummy.tscn")
const PORT = 9999
const WAIT_TIME = 1
const NUM_DUMMIES = 30

# 관련 데이터 정의
var navigation_map: RID
var enet_peer = ENetMultiplayerPeer.new()
var game_state = Utils.GameState.IDLE
var dummy_list = []

# 게임 컴포넌트 로딩 완료
func _ready() -> void:
	navigation_map = navigation_region.get_navigation_map()
	player_spawner.set_spawn_function(player_spawn_function)
	dummy_spawner.set_spawn_function(dummy_spawn_function)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	timer.timeout.connect(Callable(self, "_on_timer_timeout"))

	print("[TLMS] Game Started.")

# 종료 이벤트 핸들링
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

# 로컬 호스트 버튼 관리
func _on_host_local_button_pressed() -> void:
	game_start_btn.disabled = false
	join_btn.disabled = true
	quit_btn.disabled = false
	host_btn.disabled = true
	host_local_btn.disabled = true

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	
	timer.start(1)

	add_player(multiplayer.get_unique_id()) # 자기자신 추가

# 호스트 버튼 관리
func _on_host_button_pressed() -> void:
	_on_host_local_button_pressed()
	# upnp_setup()

# 참가 버튼 관리
func _on_join_button_pressed() -> void:
	join_btn.disabled = true
	quit_btn.disabled = false
	host_btn.disabled = true
	host_local_btn.disabled = true

	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

# 게임 시작 버튼 관리
func _on_game_start_button_pressed() -> void:
	game_start.rpc()

# 방 탈퇴 버튼 관리
func _on_quit_button_pressed() -> void:
	multiplayer.multiplayer_peer = null
	reset_lobby_nodes()

# 방 연결 해제 이벤트
func _on_multiplayer_peer_disconnected(peer_id):
	print("[TLMS] Peer %d disconnected from the server" % peer_id)
	remove_player(peer_id)
	update_itemlist.rpc(player_name_list)

	if peer_id == 1: # 서버가 종료됨
		print("[TLMS] Server stopped.")
		reset_lobby_nodes()

# 방 연결 실패 이벤트
func _on_multiplayer_connection_failed():
	print("[TLMS] Failed to connect to the server.")
	reset_lobby_nodes()

# 게임 타이머
func _on_timer_timeout() -> void:
	if game_state == Utils.GameState.IDLE:
		print("[TIMER] Server current: IDLE")
	elif game_state == Utils.GameState.PLAY:
		print("[TIMER] Server current: PLAY")
		var remain_player_count = Utils.count_item(player_spawn_node.get_children(), func(x): return not x.death)
		if remain_player_count <= 1:
			print("[TLMS] Game end")
			game_end.rpc()

func reset_lobby_nodes():
	game_start_btn.disabled = true
	join_btn.disabled = false
	quit_btn.disabled = true
	host_btn.disabled = false
	host_local_btn.disabled = false
	
	multiplayer.multiplayer_peer = null # 현재 피어 연결 해제
	enet_peer = ENetMultiplayerPeer.new() # 새로운 ENetPeer 인스턴스 생성
	timer.stop()
	itemlist.clear()
	
	player_name_list = []
	clear_dummy()
	clear_player()

func player_spawn_function(peer_id: int):
	var player = Player.instantiate()
	player.set_name(str(peer_id))
	return player

func dummy_spawn_function(data):
	var dummy = Dummy.instantiate()
	dummy.set_name(str(data[0]))
	dummy.set_multiplayer_authority(1)
	dummy.set_position(data[1])
	dummy_list.append(str(data[0]))
	return dummy

func add_player(peer_id):
	var player_node = player_spawner.spawn(peer_id)
	player_node.global_position = NavigationServer3D.map_get_random_point(navigation_map, 1, true)
	
	player_name_list.append(str(peer_id))
	update_itemlist.rpc(player_name_list)
	
	print("[TLMS] New player has been joined: %s" % player_node.name)

func remove_player(peer_id):
	var player = null
	for p_data in player_spawn_node.get_children():
		if p_data.name == str(peer_id):
			p_data.queue_free()
			break
	player_name_list.erase(str(peer_id))
	update_itemlist.rpc(player_name_list)

@rpc("reliable", "call_local")
func update_itemlist(player_name_list):
	itemlist.clear()
	for player_info in player_name_list:
		itemlist.add_item(player_info, null, true)

@rpc("reliable", "call_local")
func game_start():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for player in player_spawn_node.get_children():
		player.set_new_position.rpc(NavigationServer3D.map_get_random_point(navigation_map, 1, true))
	
	if multiplayer.is_server(): spawn_dummies()
	
	main_menu.hide()
	game_state = Utils.GameState.PLAY

func spawn_dummies():
	for i in range(NUM_DUMMIES):
		var dummy_id = i
		var random_point = NavigationServer3D.map_get_random_point(navigation_map, 1, true)
		dummy_spawner.spawn([dummy_id, random_point])
		print("[TLMS] Spawned dummy %d at: " % dummy_id, random_point)

func clear_dummy():
	for dummy in dummy_spawn_node.get_children():
		dummy.queue_free()

func clear_player():
	for player in player_spawn_node.get_children():
		player.queue_free()

@rpc("reliable", "call_local")
func game_end():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	clear_dummy()
	
	for player in player_spawn_node.get_children():
		reset_player(player)
	
	game_state = Utils.GameState.IDLE
	main_menu.show()
	
	if multiplayer.get_unique_id() == 1:
		game_start_btn.disabled = false

func reset_player(player):
	if is_instance_valid(player):
		player.death = false

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
